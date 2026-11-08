-- Usar los mismos parámetros y la misma instantánea para antes/después.
\set ON_ERROR_STOP on
-- S8 global: fecha inicial permite usar el índice con INCLUDE si hay selectividad.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT id_sala, SUM(total) FROM comprobante
WHERE fecha >= CURRENT_DATE - INTERVAL '3 months' AND fecha < CURRENT_DATE + INTERVAL '1 day'
GROUP BY id_sala ORDER BY SUM(total) DESC;
-- S4: top 5 salas que solicitaron un vino en los últimos 15 días.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT t.id_sala, SUM(r.cantidad) FROM transferencia t
JOIN renglon_transferencia r USING(numero_solicitud)
WHERE r.cod_vino = :'vino'::INTEGER
AND t.fecha_confeccion >= CURRENT_DATE - 15 AND t.fecha_confeccion <= CURRENT_DATE
GROUP BY t.id_sala ORDER BY SUM(r.cantidad) DESC, t.id_sala LIMIT 5;
-- S5: incluye salas con cero pendientes; posible índice parcial.
EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
SELECT s.id_sala, COUNT(t.numero_solicitud) AS pendientes FROM sala_venta s
LEFT JOIN transferencia t ON t.id_sala = s.id_sala AND t.estado <> 'procesado'
GROUP BY s.id_sala ORDER BY pendientes, s.id_sala;
