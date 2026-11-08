-- ============================================================
-- Archivo: 006_vistas.sql
-- Etapa 2: Creación de Vistas del Sistema
-- ============================================================

-- VISTA 1: Stock total de vinos (Depósito Central + Salas)

CREATE OR REPLACE VIEW vw_stock_total_vinos AS
SELECT 
    v.cod_vino,
    v.nombre AS vino_nombre,
    v.tipo,
    v.anada,
    COALESCE(sd.cantidad, 0) AS stock_deposito_central,
    COALESCE(SUM(ss.cantidad), 0) AS stock_total_en_salas,
    COALESCE(sd.cantidad, 0) + COALESCE(SUM(ss.cantidad), 0) AS stock_global
FROM vino v
LEFT JOIN stock_deposito sd ON v.cod_vino = sd.cod_vino
LEFT JOIN stock_sala ss ON v.cod_vino = ss.cod_vino
GROUP BY v.cod_vino, v.nombre, v.tipo, v.anada, sd.cantidad;


-- -------------------------------------------------------------

-- VISTA 2: Clientes Exportadores y sus Permisos


CREATE OR REPLACE VIEW vw_clientes_exportadores_info AS
SELECT 
    c.id_cliente,
    c.nombre_razon_social,
    c.nro_doc AS cuit_dni,
    ce.pais_destino_principal,
    pe.cod_permiso,
    pe.fecha_emision,
    pe.fecha_vencimiento
FROM cliente c
JOIN cliente_exportador ce ON c.id_cliente = ce.id_cliente
LEFT JOIN permiso_exportacion pe ON ce.id_cliente = pe.id_cliente_exportador;


-- -------------------------------------------------------------
-- VISTA 3: Resumen de Comprobantes de Venta por Sala

CREATE OR REPLACE VIEW vw_resumen_comprobantes AS
SELECT 
    comp.numero_comprobante,
    comp.fecha,
    s.calle AS sala_calle,
    l.nombre AS localidad_sala,
    c.nombre_razon_social AS cliente,
    comp.subtotal,
    comp.descuento,
    comp.total
FROM comprobante comp
JOIN sala_venta s ON comp.id_sala = s.id_sala
JOIN localidad l ON s.codigo_postal = l.codigo_postal
JOIN cliente c ON comp.id_cliente = c.id_cliente;