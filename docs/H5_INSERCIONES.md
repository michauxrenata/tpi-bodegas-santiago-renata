# H5: inserciones I1-I6

Archivo: `consultas/insert.sql`. Requiere las migraciones 001-008 y datos H3.
Ejecutar como administrador en una base de pruebas, con psql y ON_ERROR_STOP.

El archivo abre una transaccion y utiliza un SAVEPOINT por ejercicio. Cada
operacion muestra sus resultados y revierte las filas antes de la siguiente.
El ROLLBACK final revierte tambien las tablas temporales. Las secuencias identity
pueden avanzar: los numeros consumidos no se recuperan con ROLLBACK.
No reemplazar ROLLBACK por COMMIT para esta demostracion.

| Ejercicio | Operacion y criterio |
|---|---|
| I1 | Cobertura General Alvear (CP 5620) para el transportista con menos ingresos del trimestre movil, incluyendo cero; desempate por codigo. Cuenta ingresos sin filtrar estado. Si la cobertura ya existe, no duplica ni cambia de ganador. |
| I2 | Crea cordero al disco a 17 C solo si hay tintos de graduacion >=14; asocia todos los elegibles sin duplicar. Conserva la temperatura si el maridaje ya existe. |
| I3 | Cliente parametrizable, sala 1, vinos 1/2/3, una botella de cada uno. Usa fn_calcular_descuento_cliente y fn_total_comprobante, con triggers activos. Verifica tres renglones y total. |
| I4 | Bodega sintetica CUIT 99090000041. Una colision es un error, no se ignora. |
| I5 | Sala nueva con identidad generada y localidad existente CP 5600. |
| I6 | Ingreso de 120 botellas; verifica pertenencia del vino a la bodega. Queda en confeccion y no mueve stock. |

Parametros psql opcionales: fecha_ref (2025-01-15), cliente (1), vino (1 para I6).
Otros valores de ejemplo estan en h5_param; el detalle I3 esta en h5_detalle.
Al cambiar el vino I6, ajustar tambien bodega_ingreso para que coincidan.
La ventana I1 es [fecha_ref + 1 dia - 3 meses, fecha_ref + 1 dia).

## Ejecucion en PowerShell, desde la raiz del repositorio

```powershell
docker compose cp ./consultas/insert.sql db:/tmp/h5_insert.sql
docker compose exec -T db psql -X -P pager=off -v ON_ERROR_STOP=1 -v fecha_ref=2025-01-15 -v cliente=1 -v vino=1 -U postgres -d bodegas_carga_h3_completa -f /tmp/h5_insert.sql
$LASTEXITCODE
```

Resultado esperado: mensaje final I1-I6 finalizadas sin errores; datos revertidos,
y codigo 0. Sobre H3, I1 encuentra cobertura existente e I2 no encuentra tintos
con graduacion >=14. Son casos sin insercion, no errores.

## Alcance de validacion previa

Prevalidado en PGlite con las ocho migraciones y un fixture H3 pequeno. Se ejecuto
el SQL entregado, omitiendo unicamente metacomandos psql y sustituyendo parametros.
Se probaron ademas cobertura faltante, frontera de graduacion 14, repeticion I2,
stock de la venta y bodega incompatible. La evidencia esta en
`docs/evidencias/h5_insert_prevalidacion.txt`.
La ejecucion nativa en PostgreSQL 16.15 finalizo sin errores y con codigo 0; evidencia en docs/evidencias/h5_insert_postgresql.txt.
Este bloque no completa los DELETE D1-D6 ni toda la validacion H5.
