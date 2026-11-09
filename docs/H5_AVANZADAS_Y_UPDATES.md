# H5: revision S9-S12 y U1-U6

## Cambios

- S9 utiliza public.vw_stock_total_vinos, creada por 006_vistas.sql. Conserva las
  columnas de salida stock_deposito, stock_salas y stock_total. Cepas y maridajes
  se agregan por separado para no multiplicar el stock al combinarlos.
- El validador Node instala ahora 006_vistas.sql antes de ejecutar S9.
- U3 documenta el trigger de auditoria ya integrado. Su ROLLBACK tambien revierte
  las filas de auditoria. No se cambiaron las sentencias UPDATE U1-U6.

## Interpretaciones conservadas

- S10: promedio aritmetico de kg/ha de parcelas cosechadas de la misma finca y
  campana. No se asigna rendimiento cero a parcelas sin cosecha.
- S11: RANK conserva empates y deja huecos. El acumulado es neto por sala, por mes;
  los meses sin ventas se omiten.
- S12: una bodega sin vinos no devuelve todos los clientes; el anti-join de tintos
  incluye clientes sin compras.
- U1: recalculo explicito con descuento vigente y precio historico del renglon,
  no precio actual de vino. No representa una actualizacion automatica de historia.
- U2: mas de cinco anios, excluyendo la fecha exacta del quinto aniversario.
- U4: intercambio lunes/miercoles con una sentencia CASE, usando los textos del esquema.
- U5: incluye vinos sin ventas, desempata por codigo y aplica el 15 por ciento a
  un maximo de diez vinos. Si hay menos de diez, se actualizan los existentes.
- U6: cuenta todos los permisos (tambien vencidos). Cambia la tasa vigente al 35
  por ciento sin recalcular ventas previas. Su repeticion no actualiza filas ya al 35.

## Prueba embebida

```powershell
npm.cmd --prefix tools/validacion_sql test
```

Paso en PGlite con los archivos entregados. El validador existente comprueba
S9 con dos cepas y dos maridajes, S10 por campana, ranking, acumulados, division,
anti-join, los seis UPDATE y pruebas adicionales de descuentos 0/3/4 permisos,
repeticion, persistencia e historia. Evidencia: h5_avanzadas_prevalidacion.txt.

## Ejecucion nativa completada en PostgreSQL 16.15

Ejecutar desde la raiz del repositorio. Las consultas SELECT no cambian datos;
cada UPDATE se ejecuta en una transaccion independiente que termina en ROLLBACK.
Se ejecutan como administrador en una base de pruebas. U1 recorre 500000 renglones
y devuelve 150000 cabeceras en H3 completo: puede demorar. La salida se guarda
adentro del contenedor para no saturar la consola y luego se copia al repositorio.

```powershell
docker compose cp ./consultas/select_avanzadas.sql db:/tmp/h5_select_avanzadas.sql
docker compose cp ./consultas/update.sql db:/tmp/h5_update.sql

docker compose exec -T db psql -X -P pager=off -v ON_ERROR_STOP=1 -v vino=1 -v bodega=99010000001 -U postgres -d bodegas_carga_h3_completa -f /tmp/h5_select_avanzadas.sql -o /tmp/h5_select_avanzadas_resultados.txt
$LASTEXITCODE

docker compose exec -T db psql -X -P pager=off -v ON_ERROR_STOP=1 -v bodega=99010000001 -U postgres -d bodegas_carga_h3_completa -f /tmp/h5_update.sql -o /tmp/h5_update_resultados.txt
$LASTEXITCODE
```

Continuar solo si ambas ejecuciones devuelven 0. Copiar sus resultados:

```powershell
docker compose cp db:/tmp/h5_select_avanzadas_resultados.txt ./docs/evidencias/h5_select_avanzadas_resultados.txt
docker compose cp db:/tmp/h5_update_resultados.txt ./docs/evidencias/h5_update_resultados.txt
```

La salida nativa complementa las aserciones de la prueba embebida. No implica
cobertura exhaustiva ni concurrencia. El bloque completo H5 requiere reunir las
evidencias S1-S12, I1-I6, D1-D6 y U1-U6 y revisar el estado de Git.

S9-S12 y U1-U6 finalizaron sin errores sobre bodegas_carga_h3_completa.
Resultados en docs/evidencias/h5_select_avanzadas_resultados.txt y
docs/evidencias/h5_update_resultados.txt.
S12a requirio agregar idx_comprobante_cliente_numero en 008_indices.sql.
La medicion posterior fue 1023.484 ms; detalle en h5_s12a_indice.txt.