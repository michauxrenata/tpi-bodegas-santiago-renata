# H4 · Diseño de índices y evidencia preliminar

Responsable: Santiago. Fecha: 21/10/2026. Esta es una medición funcional/preliminar,
**no el cierre de H4**. Se ejecutó PostgreSQL 18.6 embebido (PGlite 0.5.11, wasm32),
porque no hay Docker ni servidor PostgreSQL en el entorno de trabajo. No permite
extrapolar latencias al servidor de producción ni medir concurrencia real.

## Método y resultados observados

Base nueva con el DDL actual. Fixture determinista de 150.000 comprobantes,
150.000 transferencias y 150.000 renglones de transferencia; 30 salas, 1 vino,
fechas distribuidas en diez años, 1 % de transferencias pendientes. Se ejecutó
ANALYZE, una pasada de calentamiento y tres repeticiones por fase. Mismo conjunto
de filas en ambas fases, sin desactivar Seq Scan ni forzar índices. Tiempos de
Execution Time, en ms, mediana de tres. El fixture usa CURRENT_DATE para mantener
ventanas de consulta comparables; no pretende ser el generador histórico H3.

| Consulta | Antes (ms) | Después (ms) | Cambio | Plan relevante después |
|---|---:|---:|---:|---|
| S8, ventas por sala del último trimestre | 146,108 | 28,470 | 80,5 % menos tiempo | Bitmap Index + Heap Scan sobre fecha de comprobante |
| S4, top 5 salas que solicitaron un vino en 15 días | 365,193 | 476,659 | 30,5 % más tiempo | Bitmap por fecha, pero Seq Scan de 150.000 renglones |
| S5, salas con menos transferencias pendientes | 55,192 | 43,952 | 20,4 % menos tiempo | Bitmap usando índice parcial |

Los planes completos, buffers, filas, loops y las seis tandas de ejecución se
conservan en [evidencias/planes_embebido.json](evidencias/planes_embebido.json).
Los tiempos varían considerablemente entre repeticiones; no atribuir toda la
diferencia al índice en un entorno embebido compartido. Los planes antes de S8/S5
recorren 150.000 cabeceras; después devuelven 3.905 comprobantes y 1.500 pendientes
mediante bitmap. S4 filtra 671 transferencias, pero sigue leyendo 150.000 detalles.

Resultado preliminar en PGlite (21/10/2026): S4 no mejoró en el fixture de un solo vino. La validación posterior con PostgreSQL 16.15 y datos con vinos frecuentes y poco frecuentes sí mostró mejoras; sus resultados están en la actualización final de este documento.

## Justificación de los seis índices

| Índice | Tipo | Motivo y límites |
|---|---|---|
| idx_comprobante_sala_fecha | B-tree compuesto | Igualdad por sala y luego rango de fecha. Para consulta por una sala; no reemplaza fecha como primera columna en S8 global. |
| idx_transferencia_pendientes | B-tree parcial | Reduce el conjunto a pendientes de S5. No sirve para buscar procesadas. El predicado debe ser compatible con `estado <> 'procesado'`. |
| idx_renglon_comprobante_vino | B-tree sobre FK | La PK empieza por comprobante. Permite acceso inverso por vino y comprobaciones de referencias; no garantiza acelerar un ranking global que lee todas las ventas. |
| idx_comprobante_fecha_incl | B-tree con INCLUDE | Rango global de fechas de S8; sala y total están incluidos. El plan observado usa bitmap, no Index Only Scan: este último depende también de visibilidad de páginas. |
| idx_transferencia_fecha_sala | B-tree compuesto | Fecha primero porque S4 consulta todas las salas. En PGlite, la mejora de cabecera por sí sola no resolvió S4; en PostgreSQL el índice por vino redujo el tiempo de esa consulta. |
| idx_renglon_transferencia_vino_solicitud | B-tree compuesto con INCLUDE | Filtra por vino para S4 y cubre cantidad. El costo de escritura se midió en PostgreSQL 16.15 y mostró variación entre repeticiones. |

No se agregan índices duplicados de PRIMARY KEY o UNIQUE. PostgreSQL ya crea los
índices que respaldan esas restricciones, pero no los de todas las FK referentes.
Los dos índices de comprobante cubren accesos distintos; su conveniencia conjunta
requiere medir el costo de carga. Un índice compuesto no acelera cualquier filtro
independientemente del orden de sus columnas.

## Reproducción y cierre con el equipo

- `tools/validacion_sql`: `npm ci && npm run bench` reproduce la prueba embebida.
  La fixture es deliberadamente parcial y NO cumple H3 ni todas las RN históricas.
- En PostgreSQL servidor, después de la carga H3, ejecutar
  `psql -X -v vino=<codigo_real> -f database/benchmarks/comparar.sql > planes.txt`.
  El script sólo es para una copia de evaluación; elimina temporalmente los seis índices H4, mide ambas fases y hace ROLLBACK para restaurar el estado.
- Repetir con vinos frecuentes/poco frecuentes, mantener el mismo dataset y
  parámetros, guardar versión, hardware, filas y configuración. No mezclar tiempos
  de importación con tiempos de consulta. Revisar variabilidad y usar medianas.
- Estado al 21/10/2026: quedaba pendiente la validación en servidor. La actualización final de este documento registra esa validación y cierra H4 para el alcance medido.

Pruebas funcionales ejecutadas: [evidencias/pruebas_embebido.txt](evidencias/pruebas_embebido.txt).
Prueba multisesión todavía pendiente: [concurrencia_pendiente.md](concurrencia_pendiente.md).

## Actualización final H4 — PostgreSQL 16.15 (10/11/2026)

Esta medición en servidor actualiza y completa la evidencia preliminar de PGlite del 21/10/2026. Se usó la copia descartable `bodegas_h4_bench`, con la carga H3 y un fixture sintético de transferencias. El fixture agregó 150.000 transferencias y renglones, con 1 % pendientes y distribución desigual por vino: el vino 1 fue frecuente y el 103, poco frecuente. Las fechas de transferencia quedaron en `CURRENT_DATE` por el trigger existente.

Se compararon tres repeticiones antes y después, sin desactivar `Seq Scan` ni forzar índices. Las medianas de `EXPLAIN (ANALYZE, BUFFERS)` fueron:

| Consulta | Vino frecuente: antes → después | Cambio | Vino poco frecuente: antes → después | Cambio |
|---|---:|---:|---:|---:|
| S8 | 46,169 → 27,958 ms | 39,4 % menos | 48,246 → 45,941 ms | 4,8 % menos |
| S4 | 154,703 → 139,343 ms | 9,9 % menos | 25,443 → 0,895 ms | 96,5 % menos |
| S5 | 28,608 → 10,575 ms | 63,0 % menos | 30,991 → 6,153 ms | 80,1 % menos |

El plan de S4 usó `idx_renglon_transferencia_vino_solicitud` para buscar los renglones por vino. Las seis salidas completas están en `docs/evidencias/h4_final_*.txt`. Se observa variación entre repeticiones, especialmente para S8 con el vino poco frecuente; las cifras describen esta carga y este entorno.

### Costo de escritura del índice S4

Se midió la inserción de 10.000 renglones en tres comparaciones sobre la copia descartable. Sin el índice, los tiempos fueron 863,149, 845,868 y 1.177,192 ms; con el índice, 1.160,121, 893,096 y 1.051,814 ms. La variación impide afirmar un porcentaje fijo de sobrecosto. Con el índice se observó mayor actividad de buffers compartidos. Cada prueba terminó con `ROLLBACK`.

El índice queda incluido en `database/migrations/008_indices.sql`:

`idx_renglon_transferencia_vino_solicitud (cod_vino, numero_solicitud) INCLUDE (cantidad)`.

El comparador elimina temporalmente los seis índices H4 antes de medir y vuelve a aplicar la migración para la fase posterior. Cada comparación termina con `ROLLBACK`. Con esta evidencia se completa H4 para estas consultas y esta carga de evaluación; no se afirma una mejora universal ni se certifica rendimiento bajo concurrencia.
