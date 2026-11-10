import os
import pytest
import psycopg
from fastapi.testclient import TestClient
from api.app.main import app

ADMIN=dict(host=os.getenv('API_DB_HOST','db'),port=int(os.getenv('API_DB_PORT','5432')),
 user=os.environ['POSTGRES_USER'],password=os.environ['POSTGRES_PASSWORD'],dbname=os.environ['API_DB_NAME'])
CEPA_ID=None
TRANSPORTISTA_ID=None

@pytest.fixture(scope='module')
def client():
    global CEPA_ID, TRANSPORTISTA_ID
    with psycopg.connect(**ADMIN) as c:
        c.execute("INSERT INTO public.localidad(codigo_postal,nombre,provincia,encargado_regional) VALUES('99601','H6 QA','Mendoza','Prueba') ON CONFLICT DO NOTHING")
        c.execute("INSERT INTO public.bodega(cuit,razon_social,domicilio) VALUES('99123456789','H6 Bodega QA','Calle prueba') ON CONFLICT DO NOTHING")
        c.execute("INSERT INTO public.cepa(nombre,tipo) VALUES('H6 Cepa QA','tinta') ON CONFLICT DO NOTHING")
        CEPA_ID=c.execute("SELECT id_cepa FROM cepa WHERE nombre='H6 Cepa QA'").fetchone()[0]
        c.execute("INSERT INTO public.transportista(razon_social,cuit,email,telefono,domicilio) VALUES('H6 Transportista QA','99123456788','h6@example.invalid','0','Prueba') ON CONFLICT(cuit) DO NOTHING")
        TRANSPORTISTA_ID=c.execute("SELECT codigo_transportista FROM transportista WHERE cuit='99123456788'").fetchone()[0]
        c.execute("INSERT INTO public.sala_venta(calle,numero,dia_cierre,codigo_postal) SELECT 'H6 Sala QA','1','lunes','99601' WHERE NOT EXISTS(SELECT FROM sala_venta WHERE calle='H6 Sala QA')")
        c.execute("INSERT INTO public.cliente(nombre_razon_social,tipo_doc,nro_doc,direccion,localidad,tipo_cliente) VALUES('H6 Cliente QA','DNI','H6-TEST-CLIENTE','Prueba','H6 QA','socio') ON CONFLICT(nro_doc) DO NOTHING")
        c.execute("INSERT INTO public.cliente_socio(id_cliente) SELECT id_cliente FROM cliente WHERE nro_doc='H6-TEST-CLIENTE' ON CONFLICT DO NOTHING")
        c.execute("INSERT INTO public.vino(nombre,tipo,anada,volumen_ml,graduacion,precio,cuit_bodega) VALUES('H6 Vino stock cero','tinto',2024,750,14,100,'99123456789') ON CONFLICT DO NOTHING")
        c.execute("INSERT INTO public.composicion_vino(cod_vino,id_cepa,porcentaje) SELECT v.cod_vino,ce.id_cepa,100 FROM vino v CROSS JOIN cepa ce WHERE v.nombre='H6 Vino stock cero' AND ce.nombre='H6 Cepa QA' ON CONFLICT DO NOTHING")
        sala=c.execute("SELECT id_sala FROM sala_venta WHERE calle='H6 Sala QA'").fetchone()[0]
        vino=c.execute("SELECT cod_vino FROM vino WHERE nombre='H6 Vino stock cero'").fetchone()[0]
        c.execute('INSERT INTO stock_sala(id_sala,cod_vino,cantidad) VALUES(%s,%s,0) ON CONFLICT DO NOTHING',(sala,vino))
        c.execute('SET CONSTRAINTS ALL IMMEDIATE')
    with TestClient(app) as tc:
        yield tc
    # La base bodegas_api_h6_test es desechable y tiene prefijo reservado H6.
    with psycopg.connect(**ADMIN) as c:
        c.execute("DELETE FROM ingreso WHERE codigo_transportista=%s",(TRANSPORTISTA_ID,))
        c.execute('ALTER TABLE public.renglon_transferencia DISABLE TRIGGER trg_bloquear_renglon_transferencia')
        c.execute("DELETE FROM transferencia WHERE id_sala IN(SELECT id_sala FROM sala_venta WHERE calle='H6 Sala QA')")
        c.execute('ALTER TABLE public.renglon_transferencia ENABLE TRIGGER trg_bloquear_renglon_transferencia')
        c.execute("DELETE FROM comprobante WHERE id_cliente=(SELECT id_cliente FROM cliente WHERE nro_doc='H6-TEST-CLIENTE')")
        c.execute("DELETE FROM stock_sala WHERE id_sala IN(SELECT id_sala FROM sala_venta WHERE calle='H6 Sala QA')")
        c.execute("DELETE FROM stock_deposito WHERE cod_vino IN(SELECT cod_vino FROM vino WHERE cuit_bodega='99123456789')")
        c.execute("DELETE FROM vino WHERE cuit_bodega='99123456789'")
        c.execute("DELETE FROM cliente WHERE nro_doc='H6-TEST-CLIENTE'")
        c.execute("DELETE FROM sala_venta WHERE calle='H6 Sala QA'")
        c.execute("DELETE FROM bodega WHERE cuit='99123456789'")
        c.execute("DELETE FROM cepa WHERE nombre='H6 Cepa QA'")
        c.execute("DELETE FROM transportista WHERE codigo_transportista=%s",(TRANSPORTISTA_ID,))
        c.execute("DELETE FROM localidad WHERE codigo_postal='99601'")


def wine(**overrides):
    data={'nombre':'H6 API '+os.urandom(4).hex(),'tipo':'tinto','anada':2024,'volumen_ml':750,
          'graduacion':14,'precio':100,'cuit_bodega':'99123456789','composicion':[{'id_cepa':CEPA_ID,'porcentaje':100}], 'maridajes':[]}
    data.update(overrides); return data

def test_health_uses_api_login(client):
    r=client.get('/salud'); assert r.status_code==200 and r.json()['usuario']=='bodegas_api_h6_test_login'

def test_api_login_has_no_admin_or_direct_stock_write_privileges(client):
    with client.app.state.pool.connection() as c:
        row=c.execute('''SELECT r.rolsuper,r.rolcreatedb,r.rolcreaterole,r.rolbypassrls,
          has_table_privilege(current_user,'public.stock_sala','UPDATE') AS stock_update,
          has_table_privilege(current_user,'public.comprobante','UPDATE') AS sale_update
          FROM pg_roles r WHERE r.rolname=current_user''').fetchone()
    assert not any(row[k] for k in ('rolsuper','rolcreatedb','rolcreaterole','rolbypassrls','stock_update','sale_update'))

def test_catalog_pagination_and_parameterized_filter(client):
    r=client.get('/vinos',params={'q':"%' OR 1=1 --",'limit':5,'offset':0})
    assert r.status_code==200 and r.json()['items']==[] and r.json()['limit']==5

def test_wine_crud_and_audit(client):
    d=wine(); created=client.post('/vinos',json=d); assert created.status_code==201
    cod=created.json()['cod_vino']; assert created.json()['composicion'][0]['porcentaje']==100
    assert client.get(f'/vinos/{cod}').status_code==200
    d['precio']=120; edited=client.put(f'/vinos/{cod}',json=d); assert edited.status_code==200
    with psycopg.connect(**ADMIN) as c:
        assert c.execute('SELECT count(*) FROM auditoria_precio WHERE cod_vino=%s',(cod,)).fetchone()[0]>=1
    assert client.delete(f'/vinos/{cod}').status_code==200

def test_invalid_price_translates_check(client):
    r=client.post('/vinos',json=wine(precio=-1)); assert r.status_code==422 and r.json()['sqlstate']=='23514'

def test_missing_winery_translates_foreign_key(client):
    r=client.post('/vinos',json=wine(cuit_bodega='99999999999')); assert r.status_code==409 and r.json()['sqlstate']=='23503'

def test_deferred_composition_rolls_back(client):
    d=wine(); d['composicion']=[{'id_cepa':CEPA_ID,'porcentaje':90}]
    r=client.post('/vinos',json=d); assert r.status_code==422 and r.json()['sqlstate']=='23514'
    with psycopg.connect(**ADMIN) as c: assert c.execute('SELECT count(*) FROM vino WHERE nombre=%s',(d['nombre'],)).fetchone()[0]==0

def test_client_subtype_and_crud(client):
    d={'nombre_razon_social':'H6 Test Customer','tipo_doc':'TEST','nro_doc':'H6-'+os.urandom(5).hex(),
       'direccion':'Prueba','localidad':'H6 QA','tipo_cliente':'distribuidor','zona_cobertura':'Mendoza','nro_habilitacion':'H6-'+os.urandom(5).hex()}
    r=client.post('/clientes',json=d); assert r.status_code==201 and r.json()['tipo_cliente']=='distribuidor'
    cod=r.json()['id_cliente']; assert client.get(f'/clientes/{cod}').status_code==200
    d['nombre_razon_social']='H6 Updated'; assert client.put(f'/clientes/{cod}',json=d).status_code==200
    assert client.delete(f'/clientes/{cod}').status_code==200

def test_sale_without_stock_is_409_and_atomic(client):
    with psycopg.connect(**ADMIN) as c:
        customer=c.execute("SELECT id_cliente FROM cliente WHERE nro_doc='H6-TEST-CLIENTE'").fetchone()[0]
        sala=c.execute("SELECT id_sala FROM sala_venta WHERE calle='H6 Sala QA'").fetchone()[0]
        wine_id=c.execute("SELECT cod_vino FROM vino WHERE nombre='H6 Vino stock cero'").fetchone()[0]
        before=c.execute('SELECT count(*) FROM comprobante').fetchone()[0]
    r=client.post('/comprobantes',json={'id_cliente':customer,'id_sala':sala,'renglones':[{'cod_vino':wine_id,'cantidad':1}]})
    assert r.status_code==409 and r.json()['sqlstate']=='23514'
    with psycopg.connect(**ADMIN) as c: assert c.execute('SELECT count(*) FROM comprobante').fetchone()[0]==before

def test_successful_sale_returns_database_amounts_and_retrieves_receipt(client):
    with psycopg.connect(**ADMIN) as c:
        customer=c.execute("SELECT id_cliente FROM cliente WHERE nro_doc='H6-TEST-CLIENTE'").fetchone()[0]
        sala=c.execute("SELECT id_sala FROM sala_venta WHERE calle='H6 Sala QA'").fetchone()[0]
        wine_id=c.execute("SELECT cod_vino FROM vino WHERE nombre='H6 Vino stock cero'").fetchone()[0]
        c.execute('UPDATE stock_sala SET cantidad=2 WHERE id_sala=%s AND cod_vino=%s',(sala,wine_id))
    r=client.post('/comprobantes',json={'id_cliente':customer,'id_sala':sala,'renglones':[{'cod_vino':wine_id,'cantidad':1}]})
    assert r.status_code==201, r.text
    receipt=r.json()
    assert receipt['subtotal']==100 and receipt['descuento']==10 and receipt['total']==90
    assert receipt['renglones'][0]['precio_unitario']==100
    assert client.get(f"/comprobantes/{receipt['numero_comprobante']}").json()['total']==90
    with psycopg.connect(**ADMIN) as c:
        assert c.execute('SELECT cantidad FROM stock_sala WHERE id_sala=%s AND cod_vino=%s',(sala,wine_id)).fetchone()[0]==1
        c.execute('UPDATE stock_sala SET cantidad=0 WHERE id_sala=%s AND cod_vino=%s',(sala,wine_id))

def test_transfer_invalid_state_is_translated_and_does_not_move_stock(client):
    with psycopg.connect(**ADMIN) as c:
        sala=c.execute("SELECT id_sala FROM sala_venta WHERE calle='H6 Sala QA'").fetchone()[0]
        wine_id=c.execute("SELECT cod_vino FROM vino WHERE nombre='H6 Vino stock cero'").fetchone()[0]
        c.execute('INSERT INTO stock_deposito(cod_vino,cantidad) VALUES(%s,3) ON CONFLICT(cod_vino) DO UPDATE SET cantidad=3',(wine_id,))
    transfer=client.post('/transferencias',json={'id_sala':sala}); assert transfer.status_code==201
    number=transfer.json()['numero_solicitud']
    line=client.post(f'/transferencias/{number}/renglones',json={'cod_vino':wine_id,'cantidad':1})
    assert line.status_code==201
    failed=client.post(f'/transferencias/{number}/procesar')
    assert failed.status_code==422 and failed.json()['sqlstate']=='23514'
    with psycopg.connect(**ADMIN) as c:
        assert c.execute('SELECT cantidad FROM stock_deposito WHERE cod_vino=%s',(wine_id,)).fetchone()[0]==3

def test_transfer_lifecycle_uses_procedures_and_moves_stock_atomically(client):
    with psycopg.connect(**ADMIN) as c:
        sala=c.execute("SELECT id_sala FROM sala_venta WHERE calle='H6 Sala QA'").fetchone()[0]
        wine_id=c.execute("SELECT cod_vino FROM vino WHERE nombre='H6 Vino stock cero'").fetchone()[0]
        c.execute('INSERT INTO stock_deposito(cod_vino,cantidad) VALUES(%s,3) ON CONFLICT(cod_vino) DO UPDATE SET cantidad=3',(wine_id,))
    transfer=client.post('/transferencias',json={'id_sala':sala}); number=transfer.json()['numero_solicitud']
    assert client.post(f'/transferencias/{number}/renglones',json={'cod_vino':wine_id,'cantidad':2}).status_code==201
    assert client.post(f'/transferencias/{number}/terminar').json()['estado']=='terminado'
    result=client.post(f'/transferencias/{number}/procesar')
    assert result.status_code==200 and result.json()['estado']=='procesado'
    with psycopg.connect(**ADMIN) as c:
        assert c.execute('SELECT cantidad FROM stock_deposito WHERE cod_vino=%s',(wine_id,)).fetchone()[0]==1
        assert c.execute('SELECT cantidad FROM stock_sala WHERE id_sala=%s AND cod_vino=%s',(sala,wine_id)).fetchone()[0]==2

def test_income_invalid_state_is_translated_without_moving_stock(client):
    with psycopg.connect(**ADMIN) as c:
        wine_id=c.execute("SELECT cod_vino FROM vino WHERE nombre='H6 Vino stock cero'").fetchone()[0]
        before=c.execute('SELECT cantidad FROM stock_deposito WHERE cod_vino=%s',(wine_id,)).fetchone()
        before=before[0] if before else None
    income=client.post('/ingresos',json={'codigo_transportista':TRANSPORTISTA_ID,'cuit_bodega':'99123456789'})
    assert income.status_code==201, income.text
    code=income.json()['codigo_ingreso']
    assert client.post(f'/ingresos/{code}/renglones',json={'cod_vino':wine_id,'cantidad':1}).status_code==201
    failed=client.post(f'/ingresos/{code}/procesar')
    assert failed.status_code==422 and failed.json()['sqlstate']=='23514'
    with psycopg.connect(**ADMIN) as c:
        after=c.execute('SELECT cantidad FROM stock_deposito WHERE cod_vino=%s',(wine_id,)).fetchone()
        assert (after[0] if after else None)==before

def test_report_endpoints(client):
    assert client.get('/reportes/top-vinos').status_code==200
    assert client.get('/reportes/ventas-por-sala',params={'fecha_ref':'2025-01-15','limit':3}).status_code==200
    with psycopg.connect(**ADMIN) as c:
        sala=c.execute("SELECT id_sala FROM sala_venta WHERE calle='H6 Sala QA'").fetchone()[0]
        wine_id=c.execute("SELECT cod_vino FROM vino WHERE nombre='H6 Vino stock cero'").fetchone()[0]
    assert client.get('/reportes/vinos-sin-stock',params={'sala':sala}).status_code==200
    assert client.get('/reportes/transportista-activo').status_code==200
    assert client.get(f'/reportes/trazabilidad/{wine_id}').status_code==200
