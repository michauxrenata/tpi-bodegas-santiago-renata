"""Carga H3 sintetica y reproducible. Solo en bodegas_carga_h3* vacia.
Una transaccion, triggers de negocio activos salvo fecha historica de transferencia.
Ver docs/H3_EJECUCION.md antes de ejecutar.
"""
import argparse
import csv
import getpass
import hashlib
import json
import os
import random
import sys
import time
from collections import Counter
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path
from importlib.metadata import version

from faker import Faker
import psycopg2
from psycopg2.extras import execute_values

ROOT = Path(__file__).resolve().parent
TABLAS = '''localidad sala_venta empleado bodega cepa finca parcela lote_uva
analisis_calidad vino composicion_vino maridaje vino_maridaje cliente cliente_socio
cliente_distribuidor cliente_exportador permiso_exportacion transportista
transportista_cobertura stock_deposito ingreso renglon_ingreso transferencia
renglon_transferencia stock_sala comprobante renglon_comprobante auditoria_precio'''.split()
IDENTIDADES = dict(sala_venta='id_sala', cepa='id_cepa', finca='id_finca',
    lote_uva='nro_lote', analisis_calidad='id_analisis', vino='cod_vino',
    maridaje='id_maridaje', cliente='id_cliente', transportista='codigo_transportista',
    ingreso='codigo_ingreso', transferencia='numero_solicitud',
    comprobante='numero_comprobante', auditoria_precio='id_auditoria')
PERFILES = {'prueba': (60, 200, 700, 20, 3),
            'completo': (20000, 150000, 500000, 300, 15)}


def leer_catalogo(nombre):
    with (ROOT / 'data' / nombre).open(encoding='utf-8-sig', newline='') as f:
        rows = list(csv.DictReader(f))
    if not rows:
        raise ValueError(f'Catalogo vacio: {nombre}')
    return rows


def construir(perfil, semilla, referencia):
    """Planifica demanda antes de abastecer: no inventa stock final independiente."""
    rng = random.Random(semilla)
    fake = Faker('es_AR')
    fake.seed_instance(semilla)
    nc, nv, nr, vinos, salas = PERFILES[perfil]
    datos = {}
    def poner(tabla, columnas, filas):
        datos[tabla] = (columnas.split(), list(filas))
    loc = leer_catalogo('localidades.csv')
    cepas = leer_catalogo('cepas.csv')
    dep = leer_catalogo('departamentos.csv')
    mar = leer_catalogo('maridajes.csv')
    if not {'tinta', 'blanca'} <= {c['tipo'] for c in cepas}:
        raise ValueError('Se requieren cepas tintas y blancas')
    poner('localidad', 'codigo_postal nombre provincia encargado_regional',
          [(r['codigo_postal'], r['nombre'], r['provincia'], f'Responsable sintetico {i}')
           for i, r in enumerate(loc, 1)])
    poner('cepa', 'id_cepa nombre tipo',
          [(i, r['nombre'], r['tipo']) for i, r in enumerate(cepas, 1)])
    poner('maridaje', 'id_maridaje nombre temp_servicio_sugerida_c',
          [(i, r['nombre'], Decimal(r['temp_servicio_sugerida_c'])) for i, r in enumerate(mar, 1)])
    bodegas = [str(99010000000 + i) for i in range(1, 11)]
    poner('bodega', 'cuit razon_social domicilio',
          [(c, f'Bodega sintetica H3 {i}', fake.street_address()[:200]) for i, c in enumerate(bodegas, 1)])
    poner('transportista', 'codigo_transportista razon_social cuit email telefono domicilio',
          [(i, f'Transportista H3 {i}', str(99020000000+i), f'transporte{i}@example.invalid',
            '0000000000', fake.street_address()[:200]) for i in range(1, 16)])
    poner('transportista_cobertura', 'codigo_transportista codigo_postal',
          [(i, r['codigo_postal']) for i in range(1, 16) for r in loc])
    poner('sala_venta', 'id_sala calle numero dia_cierre codigo_postal',
          [(i, f'Calle sintetica {i}', str(i), ['lunes','martes','miércoles','jueves','viernes','sábado','domingo'][(i-1)%7],
            loc[(i-1)%len(loc)]['codigo_postal']) for i in range(1, salas+1)])
    poner('empleado', 'cuit nombre fecha_ingreso salario id_sala',
          [(str(99030000000+i), fake.name()[:150], referencia-timedelta(days=1000+i),
            Decimal('850000.00'), (i-1)%salas+1) for i in range(1, 301)])
    poner('finca', 'id_finca nombre superficie_ha departamento provincia',
          [(i, f'Finca H3 {i}', Decimal('100.00'), dep[(i-1)%len(dep)]['nombre_departamento'],
            dep[(i-1)%len(dep)]['provincia']) for i in range(1, 51)])
    poner('parcela', 'id_finca nro_parcela superficie_ha anio_plantacion id_cepa',
          [(i, j, Decimal('40.00'), referencia.year-15, (i+j)%len(cepas)+1)
           for i in range(1,51) for j in (1,2)])
    lotes = []
    for i in range(1,51):
        for j in (1,2):
            for anio in (referencia.year-3, referencia.year-2, referencia.year-1):
                lotes.append((len(lotes)+1, i, j, anio, date(anio,3,15),
                              Decimal('120000.00'), bodegas[(i-1)%10]))
    poner('lote_uva', 'nro_lote id_finca nro_parcela campana fecha_cosecha kg_cosechados cuit_bodega_destino', lotes)
    poner('analisis_calidad', 'id_analisis nro_lote fecha grado_brix ph acidez_total',
          [(r[0], r[0], r[4]+timedelta(days=1), Decimal('22'), Decimal('3.5'), Decimal('6')) for r in lotes])
    vv, comp, vm = [], [], []
    for i in range(1,vinos+1):
        tipo = 'tinto' if i%2 else 'blanco'
        pool = [j for j,c in enumerate(cepas,1) if c['tipo']==('tinta' if tipo=='tinto' else 'blanca')]
        elegidas = rng.sample(pool, min(2,len(pool)))
        for j, ce in enumerate(elegidas):
            comp.append((i, ce, 100 if len(elegidas)==1 else (60 if j==0 else 40)))
        vv.append((i, f'Blend sintetico H3 {i:04d}', tipo, referencia.year-3,
                   750, Decimal('13.50'), Decimal(rng.randrange(350000,4500000))/100, bodegas[(i-1)%10]))
        vm.append((i, (i-1)%len(mar)+1))
    poner('vino', 'cod_vino nombre tipo anada volumen_ml graduacion precio cuit_bodega', vv)
    poner('composicion_vino', 'cod_vino id_cepa porcentaje', comp)
    poner('vino_maridaje', 'cod_vino id_maridaje', vm)
    tipos = ['socio', 'distribuidor', 'exportador']
    clientes, socios, dist, exp, permisos = [], [], [], [], []
    for i in range(1,nc+1):
        tipo = tipos[(i-1)%3]
        clientes.append((i, fake.name()[:150], 'TEST-H3', f'H3-{i:08d}', fake.street_address()[:200],
                         loc[(i-1)%len(loc)]['nombre'], referencia-timedelta(days=1800), tipo))
        if tipo=='socio': socios.append((i,))
        elif tipo=='distribuidor': dist.append((i, 'Mendoza', f'H3-HAB-{i:08d}'))
        else:
            exp.append((i, 'Chile'))
            for j in range(1, 2+(i//3)%5):
                permisos.append((f'H3-EXP-{i}-{j}', i, referencia-timedelta(days=600+j), referencia+timedelta(days=365+j)))
    poner('cliente', 'id_cliente nombre_razon_social tipo_doc nro_doc direccion localidad fecha_alta tipo_cliente', clientes)
    poner('cliente_socio', 'id_cliente', socios)
    poner('cliente_distribuidor', 'id_cliente zona_cobertura nro_habilitacion', dist)
    poner('cliente_exportador', 'id_cliente pais_destino_principal', exp)
    poner('permiso_exportacion', 'cod_permiso id_cliente_exportador fecha_emision fecha_vencimiento', permisos)
    ventas, lineas, demanda = [], [], Counter()
    for i in range(1,nv+1):
        sala = (i-1)%salas+1
        fecha = referencia-timedelta(days=rng.randrange(365))
        ventas.append((i, datetime.combine(fecha,datetime.min.time()), rng.randrange(1,nc+1), sala))
        n = nr//nv + (i <= nr%nv)
        for vino in rng.sample(range(1,vinos+1), n):
            cantidad = rng.randrange(1,7)
            lineas.append((i,vino,cantidad))
            demanda[sala,vino] += cantidad
    poner('comprobante', 'numero_comprobante fecha id_cliente id_sala', ventas)
    poner('renglon_comprobante', 'numero_comprobante cod_vino cantidad', lineas)
    # Cada sala conserva 20 botellas por vino; deposito conserva 100.
    abastecimiento = {(s,v): demanda[s,v]+20 for s in range(1,salas+1) for v in range(1,vinos+1)}
    poner('ingreso', 'codigo_ingreso fecha codigo_transportista cuit_bodega',
          [(i, referencia-timedelta(days=400), i, b) for i,b in enumerate(bodegas,1)])
    poner('renglon_ingreso', 'codigo_ingreso cod_vino cantidad',
          [((v-1)%10+1, v, sum(abastecimiento[s,v] for s in range(1,salas+1))+100) for v in range(1,vinos+1)])
    poner('transferencia', 'numero_solicitud id_sala fecha_confeccion',
          [(s,s,referencia-timedelta(days=390)) for s in range(1,salas+1)])
    poner('renglon_transferencia', 'numero_solicitud cod_vino cantidad',
          [(s,v,abastecimiento[s,v]) for s in range(1,salas+1) for v in range(1,vinos+1)])
    return datos


def insertar(cur, tabla, datos, metodo):
    cols, filas = datos[tabla]
    ident = ' OVERRIDING SYSTEM VALUE' if tabla in IDENTIDADES else ''
    # Identificadores de constantes locales, valores siempre parametrizados.
    base = f'INSERT INTO public.{tabla} ({",".join(cols)}){ident} VALUES '
    if metodo=='individual':
        for fila in filas:
            cur.execute(base+'('+','.join(['%s']*len(cols))+')', fila)
    else:
        execute_values(cur, base+'%s', filas, page_size=1000)


def cargar(cur, datos, metodo):
    inicio = time.perf_counter()
    orden = '''localidad cepa maridaje bodega transportista transportista_cobertura
    sala_venta empleado finca parcela lote_uva analisis_calidad vino composicion_vino
    vino_maridaje cliente cliente_socio cliente_distribuidor cliente_exportador permiso_exportacion'''.split()
    for tabla in orden:
        insertar(cur,tabla,datos,metodo)
    cur.execute('SET CONSTRAINTS ALL IMMEDIATE')
    # Auditoria verdadera: un cambio real de precio mediante su trigger.
    cur.execute('UPDATE public.vino SET precio=precio+1 WHERE cod_vino=1')
    for tabla in ['ingreso','renglon_ingreso']:
        insertar(cur,tabla,datos,metodo)
    for fila in datos['ingreso'][1]:
        cur.execute('CALL public.sp_terminar_ingreso(%s)', (fila[0],))
        cur.execute('CALL public.sp_procesar_ingreso(%s)', (fila[0],))
    for tabla in ['transferencia','renglon_transferencia']:
        insertar(cur,tabla,datos,metodo)
    for fila in datos['transferencia'][1]:
        cur.execute('CALL public.sp_terminar_transferencia(%s)', (fila[0],))
        cur.execute('CALL public.sp_procesar_transferencia(%s)', (fila[0],))
    for tabla in ['comprobante','renglon_comprobante']:
        print(f'Cargando {tabla}: {len(datos[tabla][1]):,} ({metodo})', flush=True)
        insertar(cur,tabla,datos,metodo)
    return round(time.perf_counter()-inicio, 4)


def validar(cur, perfil):
    controles = {
      'composicion_100': '''SELECT count(*) FROM (SELECT v.cod_vino FROM public.vino v LEFT JOIN public.composicion_vino c USING(cod_vino) GROUP BY v.cod_vino HAVING coalesce(sum(porcentaje),0)<>100) q''',
      'subtipos': '''SELECT count(*) FROM public.cliente c LEFT JOIN public.cliente_socio s USING(id_cliente) LEFT JOIN public.cliente_distribuidor d USING(id_cliente) LEFT JOIN public.cliente_exportador e USING(id_cliente) WHERE (s.id_cliente IS NOT NULL)::int+(d.id_cliente IS NOT NULL)::int+(e.id_cliente IS NOT NULL)::int<>1 OR (c.tipo_cliente='socio')<>(s.id_cliente IS NOT NULL) OR (c.tipo_cliente='distribuidor')<>(d.id_cliente IS NOT NULL) OR (c.tipo_cliente='exportador')<>(e.id_cliente IS NOT NULL)''',
      'maridaje': 'SELECT count(*) FROM public.vino v WHERE NOT EXISTS (SELECT FROM public.vino_maridaje m WHERE m.cod_vino=v.cod_vino)',
      'bodega_ingreso': '''SELECT count(*) FROM public.renglon_ingreso r JOIN public.ingreso i USING(codigo_ingreso) JOIN public.vino v USING(cod_vino) WHERE i.cuit_bodega<>v.cuit_bodega''',
      'deposito': '''WITH i AS (SELECT cod_vino,sum(cantidad) n FROM public.renglon_ingreso JOIN public.ingreso USING(codigo_ingreso) WHERE estado='procesado' GROUP BY cod_vino), t AS (SELECT cod_vino,sum(cantidad) n FROM public.renglon_transferencia JOIN public.transferencia USING(numero_solicitud) WHERE estado='procesado' GROUP BY cod_vino) SELECT count(*) FROM public.vino v LEFT JOIN i USING(cod_vino) LEFT JOIN t USING(cod_vino) LEFT JOIN public.stock_deposito s USING(cod_vino) WHERE s.cantidad IS DISTINCT FROM coalesce(i.n,0)-coalesce(t.n,0) OR s.cantidad<0''',
      'sala': '''WITH t AS (SELECT id_sala,cod_vino,sum(cantidad) n FROM public.renglon_transferencia JOIN public.transferencia USING(numero_solicitud) WHERE estado='procesado' GROUP BY 1,2), v AS (SELECT id_sala,cod_vino,sum(cantidad) n FROM public.renglon_comprobante JOIN public.comprobante USING(numero_comprobante) GROUP BY 1,2), claves AS (SELECT id_sala,cod_vino FROM t UNION SELECT id_sala,cod_vino FROM v UNION SELECT id_sala,cod_vino FROM public.stock_sala) SELECT count(*) FROM claves k LEFT JOIN t USING(id_sala,cod_vino) LEFT JOIN v USING(id_sala,cod_vino) LEFT JOIN public.stock_sala s USING(id_sala,cod_vino) WHERE s.cantidad IS DISTINCT FROM coalesce(t.n,0)-coalesce(v.n,0) OR s.cantidad<0''',
      'importes': '''SELECT count(*) FROM (SELECT c.numero_comprobante FROM public.comprobante c LEFT JOIN public.renglon_comprobante r USING(numero_comprobante) GROUP BY c.numero_comprobante HAVING count(r.cod_vino)=0 OR c.subtotal<>sum(r.cantidad*r.precio_unitario) OR c.descuento<>sum(r.descuento) OR c.total<>sum(r.subtotal)) q''',
      'renglones_importes': '''SELECT count(*) FROM public.renglon_comprobante r JOIN public.comprobante c USING(numero_comprobante) JOIN public.cliente cl USING(id_cliente) WHERE r.descuento<>round(r.cantidad*r.precio_unitario*cl.descuento,2) OR r.subtotal<>r.cantidad*r.precio_unitario-r.descuento''',
      'documentos': '''SELECT (SELECT count(*) FROM public.ingreso i WHERE estado<>'procesado' OR NOT EXISTS (SELECT FROM public.renglon_ingreso r WHERE r.codigo_ingreso=i.codigo_ingreso))+(SELECT count(*) FROM public.transferencia t WHERE estado<>'procesado' OR NOT EXISTS (SELECT FROM public.renglon_transferencia r WHERE r.numero_solicitud=t.numero_solicitud))''',
      'superficies': '''SELECT count(*) FROM (SELECT id_finca FROM public.finca JOIN public.parcela USING(id_finca) GROUP BY id_finca, finca.superficie_ha HAVING sum(parcela.superficie_ha)>finca.superficie_ha) q''',
      'fechas': '''SELECT (SELECT count(*) FROM public.comprobante c JOIN public.cliente cl USING(id_cliente) WHERE c.fecha::date<cl.fecha_alta)+(SELECT count(*) FROM public.analisis_calidad a JOIN public.lote_uva l USING(nro_lote) WHERE a.fecha<l.fecha_cosecha)+(SELECT count(*) FROM public.comprobante c WHERE c.fecha::date<(SELECT max(fecha_confeccion) FROM public.transferencia))+(SELECT count(*) FROM public.transferencia WHERE fecha_confeccion<(SELECT max(fecha) FROM public.ingreso))''',
      'stocks_planificados': '''SELECT (SELECT count(*) FROM public.stock_deposito WHERE cantidad<>100)+(SELECT count(*) FROM public.stock_sala WHERE cantidad<>20)''',
      'auditoria': '''SELECT CASE WHEN count(*)=1 AND bool_and(precio_nuevo=precio_anterior+1) THEN 0 ELSE 1 END FROM public.auditoria_precio'''
    }
    for nombre, consulta in controles.items():
        cur.execute(consulta)
        n = cur.fetchone()[0]
        if n:
            raise ValueError(f'Control {nombre}: {n} inconsistencias')
    # Auditoria de huerfanos para TODAS las FK, incluso compuestas.
    cur.execute('''SELECT c.conrelid::regclass::text AS origen, c.confrelid::regclass::text AS destino,
        array_agg(a.attname ORDER BY k.ord) AS columnas_origen, array_agg(b.attname ORDER BY k.ord) AS columnas_destino
        FROM pg_constraint c
        CROSS JOIN LATERAL unnest(c.conkey,c.confkey) WITH ORDINALITY k(src,dst,ord)
        JOIN pg_attribute a ON a.attrelid=c.conrelid AND a.attnum=k.src
        JOIN pg_attribute b ON b.attrelid=c.confrelid AND b.attnum=k.dst
        WHERE c.contype='f' AND c.connamespace='public'::regnamespace
        GROUP BY c.oid''')
    for origen, destino, origen_cols, destino_cols in cur.fetchall():
        def ident(nombre):
            return '.'.join('"'+p.replace('"','""')+'"' for p in nombre.split('.'))
        condicion = ' AND '.join(f'a.{ident(a)}=b.{ident(b)}' for a,b in zip(origen_cols,destino_cols))
        cur.execute(f'SELECT count(*) FROM {ident(origen)} a WHERE NOT EXISTS (SELECT FROM {ident(destino)} b WHERE {condicion})')
        if cur.fetchone()[0]:
            raise ValueError(f'Huerfanos: {origen} -> {destino}')
    conteos = {}
    for tabla in TABLAS:
        cur.execute(f'SELECT count(*) FROM public.{tabla}')
        conteos[tabla] = cur.fetchone()[0]
    if any(n==0 for n in conteos.values()):
        raise ValueError('Hay tablas vacias: '+str(conteos))
    nc,nv,nr,_,_ = PERFILES[perfil]
    for t,n in [('cliente',nc),('comprobante',nv),('renglon_comprobante',nr)]:
        if conteos[t]!=n: raise ValueError(f'Conteo incorrecto: {t}')
    if perfil=='completo' and (sum(n>10000 for n in conteos.values())<3 or max(conteos.values())<=100000):
        raise ValueError('No se cumple el volumen H3')
    cur.execute('SET CONSTRAINTS ALL IMMEDIATE')
    return conteos


def preparar(cur):
    cur.execute('SELECT current_database(),version()')
    base, motor = cur.fetchone()
    if not base.startswith('bodegas_carga_h3'):
        raise ValueError('Solo se admite una base cuyo nombre empiece por bodegas_carga_h3')
    cur.execute('SELECT tablename FROM pg_tables WHERE schemaname=\'public\'')
    existentes = {r[0] for r in cur.fetchall()}
    if existentes!=set(TABLAS): raise ValueError('El esquema no coincide con las 29 tablas H1/H2')
    # Bloqueo exclusivo: nadie puede escribir entre la comprobacion y la carga.
    cur.execute('LOCK TABLE '+','.join('public.'+t for t in sorted(TABLAS))+' IN ACCESS EXCLUSIVE MODE')
    for t in TABLAS:
        cur.execute(f'SELECT EXISTS(SELECT FROM public.{t})')
        if cur.fetchone()[0]: raise ValueError(f'La base debe estar vacia; {t} contiene datos. No se borro nada.')
    cur.execute("SELECT count(*) FROM pg_trigger WHERE tgrelid IN (SELECT oid FROM pg_class WHERE relnamespace='public'::regnamespace) AND tgenabled<>'O'")
    if cur.fetchone()[0]: raise ValueError('Se requieren todos los triggers habilitados en modo normal')
    cur.execute("SELECT tgenabled FROM pg_trigger WHERE tgrelid='public.transferencia'::regclass AND tgname='trg_proteger_fecha_transferencia'")
    if cur.fetchone()!=('O',): raise ValueError('Falta el trigger de fecha esperado')
    cur.execute('ALTER TABLE public.transferencia DISABLE TRIGGER trg_proteger_fecha_transferencia')
    return base,motor


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--perfil', choices=PERFILES, default='prueba')
    p.add_argument('--metodo', choices=['individual','lotes'], default='lotes')
    p.add_argument('--comparar', action='store_true', help='Mismo conjunto: individual con rollback y lotes confirmado')
    p.add_argument('--seed', type=int, default=42)
    p.add_argument('--fecha', type=date.fromisoformat, default=date(2025,1,15))
    p.add_argument('--reporte', type=Path, default=ROOT/'docs/evidencias/h3_resultado.json')
    args=p.parse_args()
    args.reporte.parent.mkdir(parents=True,exist_ok=True)
    if args.reporte.exists(): raise ValueError('El reporte ya existe; use otro nombre para conservar la evidencia')
    datos=construir(args.perfil,args.seed,args.fecha)
    print('Datos generados. Se pedira la clave PostgreSQL si DB_PASSWORD no esta definida.',flush=True)
    config=dict(dbname=os.getenv('DB_NAME','bodegas_carga_h3'), user=os.getenv('DB_USER','postgres'),
                host=os.getenv('DB_HOST','127.0.0.1'),port=os.getenv('DB_PORT','5433'),
                password=os.getenv('DB_PASSWORD') or getpass.getpass('Clave PostgreSQL: '),
                connect_timeout=10,client_encoding='UTF8',application_name='tpi_h3')
    resumen={'perfil':args.perfil,'semilla':args.seed,'fecha_referencia':str(args.fecha),
             'faker':version('Faker'),'psycopg2':psycopg2.__version__,
             'python':sys.version,'tiempos_carga_segundos':{},
             'catalogos_sha256':{f:hashlib.sha256((ROOT/'data'/f).read_bytes()).hexdigest()
              for f in ['cepas.csv','departamentos.csv','maridajes.csv','localidades.csv']}}
    conn=psycopg2.connect(**config)
    try:
        with conn:
            with conn.cursor() as cur:
                base,motor=preparar(cur)
                resumen.update(base=base,motor=motor)
                for metodo in (['individual','lotes'] if args.comparar else [args.metodo]):
                    cur.execute('SAVEPOINT carga')
                    cur.execute('SET CONSTRAINTS ALL DEFERRED')
                    resumen['tiempos_carga_segundos'][metodo]=cargar(cur,datos,metodo)
                    conteos=validar(cur,args.perfil)
                    if args.comparar and metodo=='individual':
                        cur.execute('ROLLBACK TO SAVEPOINT carga')
                    cur.execute('RELEASE SAVEPOINT carga')
                cur.execute('ALTER TABLE public.transferencia ENABLE TRIGGER trg_proteger_fecha_transferencia')
                cur.execute("SELECT count(*) FROM pg_trigger WHERE tgrelid IN (SELECT oid FROM pg_class WHERE relnamespace='public'::regnamespace) AND tgenabled<>'O'")
                if cur.fetchone()[0]: raise ValueError('Quedaron triggers deshabilitados')
                # IDs explicitos: ajustar cada secuencia para que la siguiente alta no colisione.
                for tabla,col in IDENTIDADES.items():
                    cur.execute(f"SELECT setval(pg_get_serial_sequence('public.{tabla}','{col}'), (SELECT max({col}) FROM public.{tabla}), true)")
                cur.execute('ANALYZE')
                resumen['conteos']=conteos
                resumen['controles']='OK: conteos, FK, subtipos, composicion, fechas, importes, stocks, auditoria y triggers'
        print('COMMIT realizado; guardando reporte.',flush=True)
        resumen['commit']='confirmado'
        args.reporte.write_text(json.dumps(resumen,ensure_ascii=False,indent=2),encoding='utf-8')
        print(json.dumps(resumen,ensure_ascii=False,indent=2))
        print('CARGA H3 CONFIRMADA. Reporte:',args.reporte)
    finally:
        conn.close()


if __name__=='__main__':
    try:
        main()
    except Exception as exc:
        print(f'ERROR: {exc}',file=sys.stderr)
        sys.exit(1)
