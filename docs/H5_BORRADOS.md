# H5: borrados D1-D6

Archivo `consultas/delete.sql`. Ejecutar como administrador en una base de pruebas
con migraciones 001-008 y carga H3. No reemplazar los ROLLBACK por COMMIT.

Se abre una transaccion y cada ejercicio tiene un SAVEPOINT. Se consultan los
candidatos, se borran con RETURNING, se revisa el resultado y se revierte antes
del siguiente ejercicio. Al final se revierte toda la transaccion.

| Ejercicio | Criterio |
|---|---|
| D1 | Comprobantes de socios anteriores a CURRENT_DATE menos cinco anios. Corte a medianoche; igualdad protegida. Los detalles se eliminan por cascada y el stock no se repone. |
| D2 | Cepas sin referencias tanto en composicion_vino como en parcela. |
| D3 | Empleados de una sala dada de baja, con alta posterior a la fecha de baja menos dos anios y no posterior a la baja. El ejemplo supone baja hoy; valida el CP de la sala. No elimina la sala. |
| D4 | Socios con alta anterior a hoy menos cinco anios y sin comprobantes. El subtipo se elimina por cascada. |
| D5 | Ingresos procesados con fecha anterior a CURRENT_DATE menos 365 dias. Los detalles se eliminan por cascada; existencias sin cambios. |
| D6 | Socios sin comprobantes cuya localidad coincide exactamente con el texto parametrizado. No aplica antiguedad. |

## Parametros y alcance

- sala: 1 por defecto; cp_sala: 5620 (General Alvear en H3).
- localidad_cliente: General Alvear por defecto. Es texto, no una FK a localidad.
- Se utiliza CURRENT_DATE, en concordancia con el trigger que autoriza D5.
- La baja de la sala D3 es un supuesto del ejercicio: el modelo no tiene estado
  ni fecha de baja. No se afirma que la sala H3 este realmente dada de baja.
- Cada ejercicio es independiente: D4/D6 no usan los efectos del borrado D1.
- Sin compras significa sin comprobantes conservados en la base. No permite
  probar ausencia historica absoluta si se purgaron ventas previamente.
- D1/D5 son depuraciones historicas, no anulaciones operativas. No revierten
  movimientos fisicos; una conciliacion historica necesitaría conservar saldos
  iniciales o archivos de los documentos purgados si estos borrados se confirmaran.
- Sobre H3 pueden aparecer cero candidatos. Eso no es un error.

## Ejecucion en PowerShell desde el repositorio

```powershell
docker compose cp ./consultas/delete.sql db:/tmp/h5_delete.sql
docker compose exec -T db psql -X -P pager=off -v ON_ERROR_STOP=1 -v sala=1 -v cp_sala=5620 -v "localidad_cliente=General Alvear" -U postgres -d bodegas_carga_h3_completa -f /tmp/h5_delete.sql
$LASTEXITCODE
```

Se espera el mensaje D1-D6 finalizados sin errores; datos revertidos y codigo 0.

## Validacion previa

En PGlite se ejecutaron las seis secciones SQL entregadas y se comparo el contenido
de las 29 tablas antes y despues. Ademas se prepararon casos positivos, negativos
y fronteras para los seis ejercicios. Detalle en
`docs/evidencias/h5_delete_prevalidacion.txt`.
La ejecucion nativa en PostgreSQL 16.15 finalizo sin errores y con codigo 0; evidencia en docs/evidencias/h5_delete_postgresql.txt.
Estas pruebas no certifican todos los escenarios concurrentes ni cierran todo H5.
