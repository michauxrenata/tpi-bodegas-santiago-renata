"""SQL visible y parametrizado. No calcula importes ni modifica stock."""
from fastapi import HTTPException
from psycopg import sql


def required(row):
    if row is None:
        raise HTTPException(404,'Recurso inexistente')
    return row


def salud(c):
    return c.execute('SELECT current_database() AS base, current_user AS usuario, 1 AS conexion').fetchone()


def vinos(c,tipo,cepa,bodega,anada,q,limit,offset):
    where = '''WHERE (%s::text IS NULL OR v.tipo::text=%s)
    AND (%s::integer IS NULL OR v.anada=%s)
    AND (%s::text IS NULL OR v.cuit_bodega=%s)
    AND (%s::integer IS NULL OR EXISTS(SELECT FROM composicion_vino cv WHERE cv.cod_vino=v.cod_vino AND cv.id_cepa=%s))
    AND (%s::text IS NULL OR v.nombre ILIKE %s)'''
    args=(tipo,tipo,anada,anada,bodega,bodega,cepa,cepa,q,None if q is None else '%'+q+'%')
    total=c.execute('SELECT count(*) AS n FROM vino v '+where,args).fetchone()['n']
    items=c.execute('SELECT v.* FROM vino v '+where+' ORDER BY v.cod_vino LIMIT %s OFFSET %s',args+(limit,offset)).fetchall()
    return {'total':total,'limit':limit,'offset':offset,'items':items}


def vino(c,cod):
    row=required(c.execute('''SELECT v.*,s.stock_deposito_central,s.stock_total_en_salas,s.stock_global
    FROM vino v JOIN vw_stock_total_vinos s USING(cod_vino) WHERE v.cod_vino=%s''',(cod,)).fetchone())
    row['composicion']=c.execute('''SELECT cv.id_cepa,ce.nombre,cv.porcentaje FROM composicion_vino cv
    JOIN cepa ce USING(id_cepa) WHERE cv.cod_vino=%s ORDER BY cv.id_cepa''',(cod,)).fetchall()
    row['maridajes']=c.execute('''SELECT m.* FROM vino_maridaje vm JOIN maridaje m USING(id_maridaje)
    WHERE vm.cod_vino=%s ORDER BY m.id_maridaje''',(cod,)).fetchall()
    return row


def guardar_vino(c,data,cod=None):
    fields=('nombre','tipo','anada','volumen_ml','graduacion','precio','cuit_bodega')
    vals=tuple(getattr(data,k) for k in fields)
    if cod is None:
        cod=c.execute('''INSERT INTO vino(nombre,tipo,anada,volumen_ml,graduacion,precio,cuit_bodega)
        VALUES(%s,%s,%s,%s,%s,%s,%s) RETURNING cod_vino''',vals).fetchone()['cod_vino']
    else:
        required(c.execute('''UPDATE vino SET nombre=%s,tipo=%s,anada=%s,volumen_ml=%s,graduacion=%s,precio=%s,cuit_bodega=%s
        WHERE cod_vino=%s RETURNING cod_vino''',vals+(cod,)).fetchone())
        c.execute('DELETE FROM composicion_vino WHERE cod_vino=%s',(cod,))
        c.execute('DELETE FROM vino_maridaje WHERE cod_vino=%s',(cod,))
    for component in data.composicion:
        c.execute('INSERT INTO composicion_vino(cod_vino,id_cepa,porcentaje) VALUES(%s,%s,%s)',(cod,component.id_cepa,component.porcentaje))
    for maridaje in data.maridajes:
        c.execute('INSERT INTO vino_maridaje(cod_vino,id_maridaje) VALUES(%s,%s)',(cod,maridaje))
    return vino(c,cod)


def borrar_vino(c,cod):
    return required(c.execute('DELETE FROM vino WHERE cod_vino=%s RETURNING cod_vino',(cod,)).fetchone())


def clientes(c,limit,offset):
    return {'total':c.execute('SELECT count(*) AS n FROM cliente').fetchone()['n'], 'limit':limit,'offset':offset,
    'items':c.execute('SELECT * FROM cliente ORDER BY id_cliente LIMIT %s OFFSET %s',(limit,offset)).fetchall()}


def cliente(c,cod):
    return required(c.execute('''SELECT c.*,d.zona_cobertura,d.nro_habilitacion,e.pais_destino_principal
    FROM cliente c LEFT JOIN cliente_distribuidor d USING(id_cliente) LEFT JOIN cliente_exportador e USING(id_cliente)
    WHERE c.id_cliente=%s''',(cod,)).fetchone())


def guardar_cliente(c,data,cod=None):
    vals=tuple(getattr(data,k) for k in ('nombre_razon_social','tipo_doc','nro_doc','direccion','localidad','tipo_cliente'))
    old=None
    if cod is None:
        cod=c.execute('''INSERT INTO cliente(nombre_razon_social,tipo_doc,nro_doc,direccion,localidad,tipo_cliente)
        VALUES(%s,%s,%s,%s,%s,%s) RETURNING id_cliente''',vals).fetchone()['id_cliente']
    else:
        old=required(c.execute('SELECT tipo_cliente FROM cliente WHERE id_cliente=%s FOR UPDATE',(cod,)).fetchone())['tipo_cliente']
        # Evitar que un cambio de tipo elimine permisos por cascada inadvertidamente.
        if old=='exportador' and data.tipo_cliente!=old and c.execute('SELECT 1 FROM permiso_exportacion WHERE id_cliente_exportador=%s LIMIT 1',(cod,)).fetchone():
            raise HTTPException(409,'El exportador conserva permisos: no se permite cambiar su tipo desde la API')
        c.execute('''UPDATE cliente SET nombre_razon_social=%s,tipo_doc=%s,nro_doc=%s,direccion=%s,localidad=%s,tipo_cliente=%s
        WHERE id_cliente=%s''',vals+(cod,))
    if old and old!=data.tipo_cliente:
        # Identifier comes from an internal fixed whitelist, never from raw input.
        tables={'socio':'cliente_socio','distribuidor':'cliente_distribuidor','exportador':'cliente_exportador'}
        c.execute(sql.SQL('DELETE FROM {} WHERE id_cliente=%s').format(sql.Identifier(tables[old])),(cod,))
    if data.tipo_cliente=='socio':
        c.execute('INSERT INTO cliente_socio(id_cliente) VALUES(%s) ON CONFLICT DO NOTHING',(cod,))
    elif data.tipo_cliente=='distribuidor':
        c.execute('''INSERT INTO cliente_distribuidor(id_cliente,zona_cobertura,nro_habilitacion) VALUES(%s,%s,%s)
        ON CONFLICT(id_cliente) DO UPDATE SET zona_cobertura=EXCLUDED.zona_cobertura,nro_habilitacion=EXCLUDED.nro_habilitacion''',
        (cod,data.zona_cobertura,data.nro_habilitacion))
    else:
        c.execute('''INSERT INTO cliente_exportador(id_cliente,pais_destino_principal) VALUES(%s,%s)
        ON CONFLICT(id_cliente) DO UPDATE SET pais_destino_principal=EXCLUDED.pais_destino_principal''',(cod,data.pais_destino_principal))
    return cliente(c,cod)


def borrar_cliente(c,cod):
    return required(c.execute('DELETE FROM cliente WHERE id_cliente=%s RETURNING id_cliente',(cod,)).fetchone())


def comprobante(c,nro):
    row=required(c.execute('SELECT * FROM comprobante WHERE numero_comprobante=%s',(nro,)).fetchone())
    row['renglones']=c.execute('SELECT * FROM renglon_comprobante WHERE numero_comprobante=%s ORDER BY cod_vino',(nro,)).fetchall()
    return row


def venta(c,data):
    nro=c.execute('INSERT INTO comprobante(id_cliente,id_sala) VALUES(%s,%s) RETURNING numero_comprobante',(data.id_cliente,data.id_sala)).fetchone()['numero_comprobante']
    for row in sorted(data.renglones,key=lambda r:r.cod_vino):
        c.execute('INSERT INTO renglon_comprobante(numero_comprobante,cod_vino,cantidad) VALUES(%s,%s,%s)',(nro,row.cod_vino,row.cantidad))
    return comprobante(c,nro)


# Table and routine names are fixed application constants, values remain parameters.
DOCS={'ingresos':('ingreso','codigo_ingreso','renglon_ingreso'),
      'transferencias':('transferencia','numero_solicitud','renglon_transferencia')}


def documento(c,kind,cod):
    table,key,detail=DOCS[kind]
    row=required(c.execute(sql.SQL('SELECT * FROM {} WHERE {}=%s').format(sql.Identifier(table),sql.Identifier(key)),(cod,)).fetchone())
    row['renglones']=c.execute(sql.SQL('SELECT * FROM {} WHERE {}=%s ORDER BY cod_vino').format(sql.Identifier(detail),sql.Identifier(key)),(cod,)).fetchall()
    return row


def crear_ingreso(c,data):
    cod=c.execute('INSERT INTO ingreso(codigo_transportista,cuit_bodega) VALUES(%s,%s) RETURNING codigo_ingreso',(data.codigo_transportista,data.cuit_bodega)).fetchone()['codigo_ingreso']
    return documento(c,'ingresos',cod)


def crear_transferencia(c,data):
    cod=c.execute('INSERT INTO transferencia(id_sala) VALUES(%s) RETURNING numero_solicitud',(data.id_sala,)).fetchone()['numero_solicitud']
    return documento(c,'transferencias',cod)


def agregar_renglon(c,kind,cod,data):
    _,key,table=DOCS[kind]
    c.execute(sql.SQL('INSERT INTO {} ({},cod_vino,cantidad) VALUES(%s,%s,%s)').format(sql.Identifier(table),sql.Identifier(key)),(cod,data.cod_vino,data.cantidad))
    return documento(c,kind,cod)


def cambiar_estado(c,kind,cod,action):
    routine={('ingresos','terminar'):'sp_terminar_ingreso',('ingresos','procesar'):'sp_procesar_ingreso',
             ('transferencias','terminar'):'sp_terminar_transferencia',('transferencias','procesar'):'sp_procesar_transferencia'}[(kind,action)]
    c.execute(sql.SQL('CALL public.{}(%s)').format(sql.Identifier(routine)),(cod,))
    return documento(c,kind,cod)


def top_vinos(c):
    return c.execute('''SELECT v.cod_vino,v.nombre,SUM(r.cantidad) AS botellas
    FROM vino v JOIN renglon_comprobante r USING(cod_vino) GROUP BY v.cod_vino,v.nombre
    ORDER BY botellas DESC,v.cod_vino LIMIT 10''').fetchall()


def ventas_sala(c,fecha,limit,offset):
    return c.execute('''SELECT s.id_sala,COALESCE(SUM(co.total),0) AS ventas_netas
    FROM sala_venta s LEFT JOIN comprobante co ON co.id_sala=s.id_sala
    AND co.fecha>=%s::date+INTERVAL '1 day'-INTERVAL '3 months' AND co.fecha<%s::date+INTERVAL '1 day'
    GROUP BY s.id_sala ORDER BY ventas_netas DESC,s.id_sala LIMIT %s OFFSET %s''',(fecha,fecha,limit,offset)).fetchall()


def sin_stock(c,sala,limit,offset):
    required(c.execute('SELECT id_sala FROM sala_venta WHERE id_sala=%s',(sala,)).fetchone())
    return c.execute('''SELECT v.cod_vino,v.nombre,d.cantidad AS stock_deposito
    FROM vino v JOIN stock_deposito d USING(cod_vino)
    LEFT JOIN stock_sala s ON s.cod_vino=v.cod_vino AND s.id_sala=%s
    WHERE d.cantidad>0 AND COALESCE(s.cantidad,0)=0 ORDER BY v.cod_vino LIMIT %s OFFSET %s''',(sala,limit,offset)).fetchall()


def transportista_activo(c,fecha):
    return c.execute('''WITH actividad AS (
    SELECT t.codigo_transportista,t.razon_social,COUNT(*) AS ingresos FROM transportista t
    JOIN ingreso i USING(codigo_transportista) WHERE i.fecha>=%s::date+INTERVAL '1 day'-INTERVAL '1 month'
    AND i.fecha<%s::date+INTERVAL '1 day' GROUP BY t.codigo_transportista,t.razon_social)
    SELECT * FROM actividad WHERE ingresos=(SELECT MAX(ingresos) FROM actividad) ORDER BY codigo_transportista''',(fecha,fecha)).fetchall()


def trazabilidad(c,cod,limit,offset):
    ficha=vino(c,cod)
    ficha['lotes_candidatos']=c.execute('''SELECT DISTINCT l.*,p.id_cepa FROM lote_uva l
    JOIN parcela p USING(id_finca,nro_parcela) JOIN composicion_vino cv ON cv.id_cepa=p.id_cepa
    JOIN vino v ON v.cod_vino=cv.cod_vino AND v.cuit_bodega=l.cuit_bodega_destino
    WHERE v.cod_vino=%s ORDER BY l.nro_lote LIMIT %s OFFSET %s''',(cod,limit,offset)).fetchall()
    ficha['alcance']='Lotes de las cepas y bodega del vino; el esquema no relaciona lotes con partidas de vino. No prueba origen fisico.'
    return ficha
