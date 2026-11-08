-- ======================================================================
-- ARCHIVO: 002_constraints.sql
-- ETAPA 2: Restricciones de Dominio, Integridad y Valores DEFAULT
-- ======================================================================

-- 1. VALORES POR DEFECTO (DEFAULT)

-- Presentación estándar del vino: 750 ml.
ALTER TABLE vino
ALTER COLUMN volumen_ml SET DEFAULT 750;

-- Los demas DEFAULT están incluidas en el archivo 001_esquema.sql


-- ============================================================
-- DESCUENTO VIGENTE DE CLIENTES (RN-06)
-- ============================================================

-- 1) Agregar la columna descuento.
ALTER TABLE cliente
ADD COLUMN descuento NUMERIC(4,2);

-- 2) Asignar el descuento correspondiente
-- a los clientes que ya existen.
UPDATE cliente
SET descuento = CASE tipo_cliente
    WHEN 'socio' THEN 0.10
    WHEN 'distribuidor' THEN 0.20
    WHEN 'exportador' THEN 0.30
END;

-- 3) Impedir descuentos nulos.
ALTER TABLE cliente
ALTER COLUMN descuento SET NOT NULL;

-- 4) El descuento debe estar entre 0 y 1.
ALTER TABLE cliente
ADD CONSTRAINT chk_cliente_descuento_rango
CHECK (descuento BETWEEN 0 AND 1);

-- ¿Qué logramos con esto? Creamos la columna descuento en cliente; Asignamos los porcentajes correctos a los clientes existentes;
-- impedimos guardar descuentos nulos; evitamos descuentos negativos o superiores al 100 % y permitimos el descuento especial del 35 % previsto para U6.


-- ==========================================================================================


-- 2. RESTRICCIONES CHECK (Límites y Reglas de Negocio)

-- 1) La fecha de vencimiento debe ser posterior a la fecha de emisión (RN-07)
ALTER TABLE permiso_exportacion
ADD CONSTRAINT chk_fechas_permiso
CHECK (fecha_vencimiento > fecha_emision);

-- 2) Los precios de los vinos deben ser positivos (RN-01 y RN-15)
ALTER TABLE vino
ADD CONSTRAINT chk_vino_precio_positivo
CHECK (precio > 0);

-- 3) El volumen del vino debe ser mayor a cero (RN-15)
ALTER TABLE vino
ADD CONSTRAINT chk_vino_volumen_positivo
CHECK (volumen_ml > 0);

-- 4) La graduación alcohólica debe estar entre 5 y 20 inclusive (RN-15)
ALTER TABLE vino
ADD CONSTRAINT chk_vino_graduacion
CHECK (graduacion BETWEEN 5 AND 20);

-- 5) El porcentaje de cepa en la composición debe estar entre 0.01% y 100%   (RN-05   validación parcial)
ALTER TABLE composicion_vino
ADD CONSTRAINT chk_composicion_porcentaje
CHECK (porcentaje > 0 AND porcentaje <= 100);

-- 6) Las cantidades ingresadas en depósito deben ser estrictamente positivas (RN-15)
ALTER TABLE renglon_ingreso
ADD CONSTRAINT chk_cant_ingreso_positiva
CHECK (cantidad > 0);

-- 7) Las cantidades de venta en comprobantes deben ser mayores a cero (RN-15)
ALTER TABLE renglon_comprobante
ADD CONSTRAINT chk_cant_comprobante_positiva
CHECK (cantidad > 0);

-- 8) Las cantidades de las transferencias deben ser mayores a cero (RN-15)
ALTER TABLE renglon_transferencia
ADD CONSTRAINT chk_cant_transferencia_positiva
CHECK (cantidad > 0);

-- 9) RN-09 y RN-11: stocks no negativos (cero es válido).
-- RN-09: el stock de las salas no puede ser negativo.
ALTER TABLE stock_sala
ADD CONSTRAINT chk_stock_sala_no_negativo
CHECK (cantidad >= 0);

-- RN-11: el stock del depósito central no puede ser negativo al procesar transferencias.
ALTER TABLE stock_deposito
ADD CONSTRAINT chk_stock_deposito_no_negativo
CHECK (cantidad >= 0);

-- 10) RN-15: superficies y cosecha positivas.
ALTER TABLE finca
ADD CONSTRAINT chk_finca_superficie_positiva
CHECK (superficie_ha > 0);

ALTER TABLE parcela
ADD CONSTRAINT chk_parcela_superficie_positiva
CHECK (superficie_ha > 0);

ALTER TABLE lote_uva
ADD CONSTRAINT chk_lote_kilos_positivos
CHECK (kg_cosechados > 0);

-- 11) Validación adicional coherente con el dominio: salario positivo.

ALTER TABLE empleado
ADD CONSTRAINT chk_empleado_salario_positivo
CHECK (salario > 0);
-- ==========================================================================================


-- 3. UNICIDAD Y FORMATOS (UNIQUE / NOT NULL)

-- 1) Validación adicional: El email del transportista debe ser único
ALTER TABLE transportista
ADD CONSTRAINT uq_transportista_email
UNIQUE (email);

-- 2)Validación adicional: La razón social de la bodega debe ser única
ALTER TABLE bodega
ADD CONSTRAINT uq_bodega_razon_social
UNIQUE (razon_social);

-- 3) Validación adicional: Evita registrar dos veces el mismo vino de una bodega, añada y presentación.
ALTER TABLE vino
ADD CONSTRAINT uq_vino_bodega_nombre_anada_volumen
UNIQUE (cuit_bodega, nombre, anada, volumen_ml);

-- 4) RN-04: una parcela puede cosecharse como máximo una vez por campaña.
ALTER TABLE lote_uva
ADD CONSTRAINT uq_lote_parcela_campana
UNIQUE (id_finca, nro_parcela, campana);






