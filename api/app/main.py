from contextlib import asynccontextmanager
from datetime import date
from typing import Annotated
import psycopg
from psycopg_pool import PoolTimeout
from fastapi import FastAPI, Request, Query
from fastapi.responses import JSONResponse
from . import dal, models
from .db import create_pool

Limit=Annotated[int,Query(ge=1,le=100)]
Offset=Annotated[int,Query(ge=0)]

@asynccontextmanager
async def lifespan(app):
    app.state.pool=create_pool()
    try:
        yield
    finally:
        app.state.pool.close()

app=FastAPI(title='Bodegas del Atuel - H6',version='1.0.0',lifespan=lifespan,
 description='API local. PostgreSQL aplica importes, descuentos, stocks y estados. PUT reemplaza el recurso completo.')


def run(request,fn,*args):
    with request.app.state.pool.connection() as conn:
        # BEGIN/COMMIT/ROLLBACK emitidos por psycopg. El commit (y sus triggers
        # diferidos) termina ANTES de construir la respuesta HTTP exitosa.
        with conn.transaction():
            result=fn(conn,*args)
        return result

@app.exception_handler(psycopg.Error)
async def postgres_error(request,exc):
    code=exc.sqlstate or 'CONNECTION'
    message=exc.diag.message_primary or 'Error de base de datos'
    status={'23505':409,'23503':409,'23514':422,'23502':422,'P0001':409,
            'P0002':404,'22P02':400,'22023':422,'22003':422,'22001':422,
            '40001':503,'40P01':503,'55P03':503,'57014':503,'42501':403,'CONNECTION':503}.get(code,500)
    # La consigna pide 409 para venta sin stock; el trigger vigente usa 23514.
    if code=='23514' and 'stock' in message.lower():
        status=409
    if status>=500:
        message='Servicio de base temporalmente no disponible' if status==503 else 'Error interno de base de datos'
    headers={'Retry-After':'1'} if status==503 else None
    return JSONResponse(status_code=status,content={'error':message,'sqlstate':code},headers=headers)

@app.exception_handler(PoolTimeout)
async def pool_timeout(request,exc):
    return JSONResponse(status_code=503,content={'error':'No hay conexiones disponibles'},headers={'Retry-After':'1'})

@app.get('/salud')
def health(r:Request): return run(r,dal.salud)

@app.get('/vinos')
def wines(r:Request,tipo:str|None=None,cepa:int|None=None,bodega:str|None=None,anada:int|None=None,
          q:Annotated[str|None,Query(max_length=100)]=None,limit:Limit=20,offset:Offset=0):
    return run(r,dal.vinos,tipo,cepa,bodega,anada,q,limit,offset)
@app.get('/vinos/{cod}')
def wine(r:Request,cod:int): return run(r,dal.vino,cod)
@app.post('/vinos',status_code=201)
def new_wine(r:Request,data:models.Vino): return run(r,dal.guardar_vino,data)
@app.put('/vinos/{cod}')
def edit_wine(r:Request,cod:int,data:models.Vino): return run(r,dal.guardar_vino,data,cod)
@app.delete('/vinos/{cod}')
def del_wine(r:Request,cod:int): return run(r,dal.borrar_vino,cod)

@app.get('/clientes')
def customers(r:Request,limit:Limit=20,offset:Offset=0): return run(r,dal.clientes,limit,offset)
@app.get('/clientes/{cod}')
def customer(r:Request,cod:int): return run(r,dal.cliente,cod)
@app.post('/clientes',status_code=201)
def new_customer(r:Request,data:models.Cliente): return run(r,dal.guardar_cliente,data)
@app.put('/clientes/{cod}')
def edit_customer(r:Request,cod:int,data:models.Cliente): return run(r,dal.guardar_cliente,data,cod)
@app.delete('/clientes/{cod}')
def del_customer(r:Request,cod:int): return run(r,dal.borrar_cliente,cod)

@app.post('/comprobantes',status_code=201)
def new_sale(r:Request,data:models.Venta): return run(r,dal.venta,data)
@app.get('/comprobantes/{nro}')
def sale(r:Request,nro:int): return run(r,dal.comprobante,nro)

@app.post('/ingresos',status_code=201)
def new_income(r:Request,data:models.Ingreso): return run(r,dal.crear_ingreso,data)
@app.get('/ingresos/{cod}')
def income(r:Request,cod:int): return run(r,dal.documento,'ingresos',cod)
@app.post('/ingresos/{cod}/renglones',status_code=201)
def income_line(r:Request,cod:int,data:models.Renglon): return run(r,dal.agregar_renglon,'ingresos',cod,data)
@app.post('/ingresos/{cod}/terminar')
def finish_income(r:Request,cod:int): return run(r,dal.cambiar_estado,'ingresos',cod,'terminar')
@app.post('/ingresos/{cod}/procesar')
def process_income(r:Request,cod:int): return run(r,dal.cambiar_estado,'ingresos',cod,'procesar')

@app.post('/transferencias',status_code=201)
def new_transfer(r:Request,data:models.Transferencia): return run(r,dal.crear_transferencia,data)
@app.get('/transferencias/{nro}')
def transfer(r:Request,nro:int): return run(r,dal.documento,'transferencias',nro)
@app.post('/transferencias/{nro}/renglones',status_code=201)
def transfer_line(r:Request,nro:int,data:models.Renglon): return run(r,dal.agregar_renglon,'transferencias',nro,data)
@app.post('/transferencias/{nro}/terminar')
def finish_transfer(r:Request,nro:int): return run(r,dal.cambiar_estado,'transferencias',nro,'terminar')
@app.post('/transferencias/{nro}/procesar')
def process_transfer(r:Request,nro:int): return run(r,dal.cambiar_estado,'transferencias',nro,'procesar')

@app.get('/reportes/top-vinos')
def top(r:Request): return run(r,dal.top_vinos)
@app.get('/reportes/ventas-por-sala')
def sales_report(r:Request,fecha_ref:date|None=None,limit:Limit=20,offset:Offset=0):
    return run(r,dal.ventas_sala,fecha_ref or date.today(),limit,offset)
@app.get('/reportes/vinos-sin-stock')
def missing_stock(r:Request,sala:int,limit:Limit=20,offset:Offset=0):return run(r,dal.sin_stock,sala,limit,offset)
@app.get('/reportes/transportista-activo')
def transporter(r:Request,fecha_ref:date|None=None):return run(r,dal.transportista_activo,fecha_ref or date.today())
@app.get('/reportes/trazabilidad/{cod}')
def trace(r:Request,cod:int,limit:Limit=20,offset:Offset=0):return run(r,dal.trazabilidad,cod,limit,offset)
