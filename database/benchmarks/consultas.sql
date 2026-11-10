-- Comparar las mismas ventanas y parámetros antes y después de los índices.
-- fecha_ref representa el cierre del día.
-- Ventanas semiabiertas: [inicio, fecha_ref + 1 día).
\set ON_ERROR_STOP on

\if :{?fecha_ref}
\else
\set fecha_ref 2025-01-15
\endif

\if :{?vino}
\else
\set vino 1
\endif

\echo 'fecha_ref=:fecha_ref; vino=:vino'

-- S8 global: ventas por sala en los tres meses hasta fecha_ref.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT id_sala, SUM(total)
FROM comprobante
WHERE fecha >= (:'fecha_ref'::date + 1 - INTERVAL '3 months')::date
  AND fecha < (:'fecha_ref'::date + 1)
GROUP BY id_sala
ORDER BY SUM(total) DESC;

-- S4: cinco salas con más unidades del vino en los últimos 15 días.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT t.id_sala, SUM(r.cantidad)
FROM transferencia t
JOIN renglon_transferencia r USING (numero_solicitud)
WHERE r.cod_vino = :'vino'::INTEGER
  AND t.fecha_confeccion >= CURRENT_DATE - 14
  AND t.fecha_confeccion < CURRENT_DATE + 1
GROUP BY t.id_sala
ORDER BY SUM(r.cantidad) DESC, t.id_sala
LIMIT 5;

-- S5: salas ordenadas por cantidad actual de transferencias pendientes.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT s.id_sala, COUNT(t.numero_solicitud) AS pendientes
FROM sala_venta s
LEFT JOIN transferencia t
  ON t.id_sala = s.id_sala
 AND t.estado <> 'procesado'
GROUP BY s.id_sala
ORDER BY pendientes, s.id_sala;