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

**S4 no mejoró.** El índice de fecha reduce trabajo en la cabecera, pero no elimina
el recorrido del detalle. Este fixture tiene un solo vino, por lo que filtrar por
vino no es selectivo. Con datos H3 de múltiples vinos, evaluar un índice
`renglon_transferencia(cod_vino, numero_solicitud) INCLUDE (cantidad)` y comparar
el plan completo. No se incorpora sin evidencia de beneficio: aumenta escrituras
y espacio. Tampoco se fuerza Nested Loop para fabricar una mejora.

## Justificación de los cinco índices

| Índice | Tipo | Motivo y límites |
|---|---|---|
| idx_comprobante_sala_fecha | B-tree compuesto | Igualdad por sala y luego rango de fecha. Para consulta por una sala; no reemplaza fecha como primera columna en S8 global. |
| idx_transferencia_pendientes | B-tree parcial | Reduce el conjunto a pendientes de S5. No sirve para buscar procesadas. El predicado debe ser compatible con `estado <> 'procesado'`. |
| idx_renglon_comprobante_vino | B-tree sobre FK | La PK empieza por comprobante. Permite acceso inverso por vino y comprobaciones de referencias; no garantiza acelerar un ranking global que lee todas las ventas. |
| idx_comprobante_fecha_incl | B-tree con INCLUDE | Rango global de fechas de S8; sala y total están incluidos. El plan observado usa bitmap, no Index Only Scan: este último depende también de visibilidad de páginas. |
| idx_transferencia_fecha_sala | B-tree compuesto | Fecha primero porque S4 consulta todas las salas. La mejora de cabecera no resolvió el costo total de S4. |

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
  El script sólo es para una copia de evaluación; elimina temporalmente los cinco
  índices propios, mide ambas fases y hace ROLLBACK para restaurar el estado.
- Repetir con vinos frecuentes/poco frecuentes, mantener el mismo dataset y
  parámetros, guardar versión, hardware, filas y configuración. No mezclar tiempos
  de importación con tiempos de consulta. Revisar variabilidad y usar medianas.
- Valentina/Renata consolidan la tabla con H3. Sol mide costo de escritura con/sin
  índices, explica un índice descartado por el planificador y registra ese caso.
- **Pendiente:** alcanzar mejora medida en al menos tres consultas con datos
  representativos, medir costo de escritura y confirmar índices finales en servidor.

Pruebas funcionales ejecutadas: [evidencias/pruebas_embebido.txt](evidencias/pruebas_embebido.txt).
Prueba multisesión todavía pendiente: [concurrencia_pendiente.md](concurrencia_pendiente.md).
