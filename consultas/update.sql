-- Santiago · U1–U6. psql -v bodega=30123456789 -f consultas/update.sql
-- Pruebas reversibles; cada bloque es independiente. U6 requiere cliente.descuento (002 de Valentina).
\set ON_ERROR_STOP on

-- U1: ejercicio de recálculo con política ACTUAL. No ejecutar sobre historia real
-- sin autorización comercial. Precio histórico del renglón; jamás precio actual del vino.
BEGIN;
UPDATE renglon_comprobante r
SET descuento = ROUND(r.cantidad * r.precio_unitario * fn_descuento_cliente(c.id_cliente), 2),
    subtotal = r.cantidad * r.precio_unitario
               - ROUND(r.cantidad * r.precio_unitario * fn_descuento_cliente(c.id_cliente), 2)
FROM comprobante c WHERE c.numero_comprobante = r.numero_comprobante;
WITH importes AS (
    SELECT c.numero_comprobante,
           COALESCE(SUM(r.cantidad * r.precio_unitario), 0) AS bruto,
           COALESCE(SUM(r.descuento), 0) AS bonificacion
    FROM comprobante c LEFT JOIN renglon_comprobante r USING(numero_comprobante)
    GROUP BY c.numero_comprobante
)
UPDATE comprobante c SET subtotal = i.bruto, descuento = i.bonificacion,
    total = fn_total_comprobante(c.numero_comprobante)
FROM importes i WHERE i.numero_comprobante = c.numero_comprobante
RETURNING c.*;
ROLLBACK;

-- U2: 'más de 5' incluye cinco años y un día; no usar años completos > 5.
BEGIN;
UPDATE empleado SET salario = ROUND(salario * 1.20, 2)
WHERE fecha_ingreso < (CURRENT_DATE - INTERVAL '5 years')::date RETURNING *;
ROLLBACK;

-- U3: Sol debe integrar RN-13 para que este UPDATE también quede auditado.
BEGIN;
UPDATE vino SET precio = ROUND(precio * 1.13, 2)
WHERE cuit_bodega = :'bodega'::cuit_dom RETURNING *;
ROLLBACK;

-- U4: ambos cambios en una sola sentencia (convención minúsculas y acentos).
BEGIN;
UPDATE sala_venta SET dia_cierre = CASE dia_cierre
    WHEN 'lunes' THEN 'miércoles' WHEN 'miércoles' THEN 'lunes' END
WHERE dia_cierre IN ('lunes', 'miércoles') RETURNING *;
ROLLBACK;

-- U5: incluye vinos con cero ventas; desempate determinista por código.
BEGIN;
WITH menos_vendidos AS (
    SELECT v.cod_vino FROM vino v
    LEFT JOIN renglon_comprobante r USING(cod_vino)
    GROUP BY v.cod_vino ORDER BY COALESCE(SUM(r.cantidad), 0), v.cod_vino LIMIT 10
)
UPDATE vino v SET precio = ROUND(v.precio * 0.85, 2)
FROM menos_vendidos m WHERE m.cod_vino = v.cod_vino RETURNING v.*;
ROLLBACK;

-- U6: descuento vigente del 35 % para exportadores con más de tres permisos.
-- Cuenta TODOS los permisos, no solamente los vigentes (la consigna no filtra fechas).
-- No modifica comprobantes ni renglones históricos. Reejecutar no produce cambios extra.
-- Ejecutar con administrador autorizado; NO dar UPDATE(cliente) a la API por este ejercicio.
BEGIN;
UPDATE public.cliente AS c
SET descuento = 0.35
WHERE c.tipo_cliente = 'exportador'
  AND (SELECT COUNT(*) FROM public.permiso_exportacion AS p
       WHERE p.id_cliente_exportador = c.id_cliente) > 3
  AND c.descuento IS DISTINCT FROM 0.35
RETURNING c.id_cliente, c.tipo_cliente, c.descuento;
ROLLBACK;
