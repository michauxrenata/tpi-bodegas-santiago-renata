-- H5: S1-S8 de la seccion 8.4 de la consigna.
-- psql -X -v ON_ERROR_STOP=1 -v sala=1 -v vino=1 -v fecha_ref=2025-01-15 -f ...
-- Ventanas moviles: [fecha_ref + 1 dia - intervalo, fecha_ref + 1 dia).
-- fecha_ref representa el cierre del dia indicado. Trimestre = tres meses.
-- Para los datos H3 usar fecha_ref=2025-01-15; por defecto se usa CURRENT_DATE.
\set ON_ERROR_STOP on
\if :{?sala}
\else
\set sala 1
\endif
\if :{?vino}
\else
\set vino 1
\endif
\if :{?fecha_ref}
\else
SELECT CURRENT_DATE::text AS fecha_ref \gset
\endif

\echo '=== S1: diez vinos mas vendidos en toda la red ==='
-- Se cuentan botellas, no cantidad de renglones. Empates: codigo ascendente.
SELECT v.cod_vino, v.nombre, SUM(r.cantidad) AS botellas_vendidas
FROM public.vino v
JOIN public.renglon_comprobante r USING (cod_vino)
GROUP BY v.cod_vino, v.nombre
ORDER BY botellas_vendidas DESC, v.cod_vino
LIMIT 10;

\echo '=== S2: vinos vendidos en todas las salas ==='
-- Division sobre todas las salas existentes. Se evita verdad vacia sin salas.
SELECT v.cod_vino, v.nombre
FROM public.vino v
WHERE EXISTS (SELECT FROM public.sala_venta)
  AND NOT EXISTS (
    SELECT FROM public.sala_venta s
    WHERE NOT EXISTS (
        SELECT FROM public.comprobante c
        JOIN public.renglon_comprobante r USING (numero_comprobante)
        WHERE c.id_sala = s.id_sala AND r.cod_vino = v.cod_vino
    )
  )
ORDER BY v.cod_vino;

\echo '=== S3: clientes distintos por tipo en una sala, ultima semana ==='
-- Compras repetidas de una persona cuentan una sola vez. Incluye tipos con cero.
WITH tipos AS (
    SELECT unnest(enum_range(NULL::public.tipo_cliente_enum)) AS tipo_cliente
), compradores AS (
    SELECT DISTINCT cl.id_cliente, cl.tipo_cliente
    FROM public.cliente cl JOIN public.comprobante c USING (id_cliente)
    WHERE c.id_sala = :'sala'::integer
      AND c.fecha >= :'fecha_ref'::date + INTERVAL '1 day' - INTERVAL '7 days'
      AND c.fecha < :'fecha_ref'::date + INTERVAL '1 day'
)
SELECT t.tipo_cliente, COUNT(c.id_cliente) AS clientes
FROM tipos t LEFT JOIN compradores c USING (tipo_cliente)
GROUP BY t.tipo_cliente ORDER BY t.tipo_cliente;

\echo '=== S4: cinco salas que mas solicitaron un vino, ultimos 15 dias ==='
-- Incluye solicitudes en cualquier estado: la consigna pide cantidad solicitada.
SELECT s.id_sala, s.calle, s.numero, SUM(r.cantidad) AS botellas_solicitadas
FROM public.sala_venta s JOIN public.transferencia t USING (id_sala)
JOIN public.renglon_transferencia r USING (numero_solicitud)
WHERE r.cod_vino = :'vino'::integer
  AND t.fecha_confeccion >= :'fecha_ref'::date - 14
  AND t.fecha_confeccion <= :'fecha_ref'::date
GROUP BY s.id_sala, s.calle, s.numero
ORDER BY botellas_solicitadas DESC, s.id_sala
LIMIT 5;

\echo '=== S5: salas con la minima cantidad de transferencias pendientes ==='
-- Incluye cero pendientes y devuelve todas las salas empatadas en el minimo.
WITH pendientes AS (
    SELECT s.id_sala, s.calle, s.numero,
           COUNT(t.numero_solicitud) AS cantidad_pendientes
    FROM public.sala_venta s
    LEFT JOIN public.transferencia t
      ON t.id_sala = s.id_sala AND t.estado <> 'procesado'
    GROUP BY s.id_sala, s.calle, s.numero
)
SELECT * FROM pendientes
WHERE cantidad_pendientes = (SELECT MIN(cantidad_pendientes) FROM pendientes)
ORDER BY id_sala;

\echo '=== S6: vinos sin stock en sala y con stock en deposito ==='
-- Una fila ausente en stock_sala equivale a cero, como fn_stock_sala.
SELECT v.cod_vino, v.nombre, d.cantidad AS stock_deposito
FROM public.vino v JOIN public.stock_deposito d USING (cod_vino)
LEFT JOIN public.stock_sala s
  ON s.cod_vino = v.cod_vino AND s.id_sala = :'sala'::integer
WHERE d.cantidad > 0 AND COALESCE(s.cantidad, 0) = 0
  AND EXISTS (SELECT FROM public.sala_venta WHERE id_sala = :'sala'::integer)
ORDER BY v.cod_vino;

\echo '=== S7: transportistas con mayor actividad del ultimo mes ==='
-- Actividad = numero de ingresos registrados, sin multiplicar por renglones.
-- Todos los estados; todos los empates. Sin ingresos en el periodo: cero filas.
WITH actividad AS (
    SELECT t.codigo_transportista, t.razon_social, COUNT(*) AS ingresos
    FROM public.transportista t JOIN public.ingreso i USING (codigo_transportista)
    WHERE i.fecha >= (:'fecha_ref'::date + INTERVAL '1 day' - INTERVAL '1 month')::date
      AND i.fecha <= :'fecha_ref'::date
    GROUP BY t.codigo_transportista, t.razon_social
)
SELECT * FROM actividad
WHERE ingresos = (SELECT MAX(ingresos) FROM actividad)
ORDER BY codigo_transportista;

\echo '=== S8: ventas netas por sala en los ultimos tres meses ==='
-- Se suman cabeceras, sin join a detalles que duplicaria los importes.
SELECT s.id_sala, s.calle, s.numero, COALESCE(SUM(c.total), 0) AS ventas_netas
FROM public.sala_venta s
LEFT JOIN public.comprobante c
  ON c.id_sala = s.id_sala
 AND c.fecha >= :'fecha_ref'::date + INTERVAL '1 day' - INTERVAL '3 months'
 AND c.fecha < :'fecha_ref'::date + INTERVAL '1 day'
GROUP BY s.id_sala, s.calle, s.numero
ORDER BY ventas_netas DESC, s.id_sala;
