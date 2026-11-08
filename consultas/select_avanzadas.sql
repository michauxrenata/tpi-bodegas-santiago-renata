-- Santiago · S9–S12. Ejecutar con psql -v vino=... -v bodega=... -f ...
\set ON_ERROR_STOP on
-- S9: consulta directa. Integración con vista pendiente de coordinar con Valentina.
WITH cepas AS (
    SELECT cv.cod_vino, jsonb_agg(jsonb_build_object(
        'cepa', c.nombre, 'porcentaje', cv.porcentaje) ORDER BY c.nombre) AS composicion
    FROM composicion_vino cv JOIN cepa c USING(id_cepa) GROUP BY cv.cod_vino
), maridajes AS (
    SELECT vm.cod_vino, jsonb_agg(jsonb_build_object(
        'maridaje', m.nombre, 'temperatura_c', m.temp_servicio_sugerida_c)
        ORDER BY m.nombre) AS maridajes
    FROM vino_maridaje vm JOIN maridaje m USING(id_maridaje) GROUP BY vm.cod_vino
), salas AS (
    SELECT cod_vino, SUM(cantidad) AS stock_salas FROM stock_sala GROUP BY cod_vino
)
SELECT v.*, b.razon_social AS bodega,
       COALESCE(c.composicion, '[]'::jsonb) AS composicion,
       COALESCE(m.maridajes, '[]'::jsonb) AS maridajes,
       COALESCE(d.cantidad, 0) AS stock_deposito,
       COALESCE(s.stock_salas, 0) AS stock_salas,
       COALESCE(d.cantidad, 0) + COALESCE(s.stock_salas, 0) AS stock_total
FROM vino v JOIN bodega b ON b.cuit = v.cuit_bodega
LEFT JOIN cepas c USING(cod_vino) LEFT JOIN maridajes m USING(cod_vino)
LEFT JOIN stock_deposito d USING(cod_vino) LEFT JOIN salas s USING(cod_vino)
WHERE v.cod_vino = :'vino'::INTEGER;

-- S10: promedio aritmético de rendimientos de parcelas cosechadas de la misma
-- finca Y campaña. Una parcela sin cosecha no equivale a rendimiento cero.
WITH rendimientos AS (
    SELECT p.id_finca, p.nro_parcela, l.campana,
           l.kg_cosechados / NULLIF(p.superficie_ha, 0) AS kg_por_ha
    FROM parcela p JOIN lote_uva l USING(id_finca, nro_parcela)
), comparacion AS (
    SELECT r.*, (SELECT AVG(x.kg_por_ha) FROM rendimientos x
                 WHERE x.id_finca = r.id_finca AND x.campana = r.campana) AS promedio_finca
    FROM rendimientos r
)
SELECT *, kg_por_ha < promedio_finca AS bajo_promedio
FROM comparacion ORDER BY id_finca, campana, nro_parcela;

-- S11a: empates conservan posición y dejan huecos (RANK, no ROW_NUMBER).
WITH ventas AS (
    SELECT c.id_sala, r.cod_vino, SUM(r.cantidad) AS botellas
    FROM comprobante c JOIN renglon_comprobante r USING(numero_comprobante)
    GROUP BY c.id_sala, r.cod_vino
)
SELECT *, RANK() OVER(PARTITION BY id_sala ORDER BY botellas DESC) AS puesto
FROM ventas ORDER BY id_sala, puesto, cod_vino;

-- S11b: venta neta por mes y acumulado histórico por sala. Meses sin ventas se omiten.
WITH meses AS (
    SELECT id_sala, date_trunc('month', fecha)::date AS mes, SUM(total) AS ventas_mes
    FROM comprobante GROUP BY id_sala, date_trunc('month', fecha)::date
)
SELECT *, SUM(ventas_mes) OVER(PARTITION BY id_sala ORDER BY mes
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS ventas_acumuladas
FROM meses ORDER BY id_sala, mes;

-- S12a: división. Se excluye explícitamente la bodega sin vinos para evitar
-- devolver todos los clientes por verdad vacía; no exige comprar en una sola venta.
SELECT c.id_cliente, c.nombre_razon_social FROM cliente c
WHERE EXISTS (SELECT FROM vino WHERE cuit_bodega = :'bodega'::cuit_dom)
AND NOT EXISTS (
    SELECT FROM vino v WHERE v.cuit_bodega = :'bodega'::cuit_dom AND NOT EXISTS (
        SELECT FROM comprobante co JOIN renglon_comprobante r USING(numero_comprobante)
        WHERE co.id_cliente = c.id_cliente AND r.cod_vino = v.cod_vino
    )
) ORDER BY c.id_cliente;

-- S12b: anti-join; incluye clientes sin compras y evita la trampa NULL de NOT IN.
SELECT c.id_cliente, c.nombre_razon_social FROM cliente c
LEFT JOIN (
    SELECT DISTINCT co.id_cliente FROM comprobante co
    JOIN renglon_comprobante r USING(numero_comprobante)
    JOIN vino v USING(cod_vino) WHERE v.tipo = 'tinto'
) tintos ON tintos.id_cliente = c.id_cliente
WHERE tintos.id_cliente IS NULL ORDER BY c.id_cliente;
