-- Solo para una base descartable, despues de santiago_tests.sql.
BEGIN;

INSERT INTO finca(id_finca,nombre,superficie_ha,departamento,provincia)
OVERRIDING SYSTEM VALUE
VALUES (-901,'Prueba',6,'San Rafael','Mendoza');

INSERT INTO parcela VALUES
(-901,1,2,2000,-901),(-901,2,4,2000,-902);

INSERT INTO lote_uva
(id_finca,nro_parcela,campana,fecha_cosecha,kg_cosechados,cuit_bodega_destino)
VALUES
(-901,1,2024,'2024-03-01',200,'99000000001'),
(-901,2,2024,'2024-03-01',800,'99000000001'),
(-901,1,2025,'2025-03-01',2000,'99000000001');

-- Existencias iniciales exclusivas del escenario de prueba.
-- El vino -903 ya tiene 2 botellas en sala y 7 en deposito.
INSERT INTO stock_sala (id_sala,cod_vino,cantidad)
VALUES (-901,-901,2),(-901,-902,4);

INSERT INTO permiso_exportacion VALUES
('STG-P1',-903,'2024-01-01','2025-01-01'),
('STG-P2',-903,'2024-01-01','2025-01-01'),
('STG-P3',-903,'2024-01-01','2025-01-01'),
('STG-P4',-903,'2024-01-01','2025-01-01');

-- Simular la tasa vigente cuando se registro la venta historica.
UPDATE cliente SET descuento=0.35 WHERE id_cliente=-903;

-- Los totales parten de cero y los calculan los triggers.
INSERT INTO comprobante
(numero_comprobante,fecha,id_cliente,id_sala)
OVERRIDING SYSTEM VALUE VALUES
(-903,'2024-01-10',-903,-901),
(-904,'2024-02-10',-901,-901);

INSERT INTO renglon_comprobante
(numero_comprobante,cod_vino,cantidad)
VALUES
(-903,-903,2),
(-903,-902,2),
(-903,-901,2),
(-904,-902,2);

-- Escenario actual: tasa del 30 %, con una venta historica al 35 %.
-- Esta modificacion no debe recalcular ventas anteriores.
UPDATE cliente SET descuento=0.30 WHERE id_cliente=-903;

INSERT INTO empleado VALUES
('99000000011','Exactamente cinco',
 (CURRENT_DATE-INTERVAL '5 years')::date,1000,-901),
('99000000012','Cinco y un dia',
 (CURRENT_DATE-INTERVAL '5 years')::date-1,1000,-901);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM comprobante
        WHERE numero_comprobante=-903
          AND subtotal=800 AND descuento=280 AND total=520
    ) THEN
        RAISE EXCEPTION 'Fixture: importes incorrectos del comprobante -903';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM comprobante
        WHERE numero_comprobante=-904
          AND subtotal=400 AND descuento=40 AND total=360
    ) THEN
        RAISE EXCEPTION 'Fixture: importes incorrectos del comprobante -904';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM stock_sala
        WHERE id_sala=-901 AND cod_vino=-903 AND cantidad=0
    ) THEN
        RAISE EXCEPTION 'Fixture: stock final incorrecto del vino -903';
    END IF;
END;
$$;

SET CONSTRAINTS ALL IMMEDIATE;
COMMIT;