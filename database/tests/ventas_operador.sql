\set ON_ERROR_STOP on
BEGIN;

-- Datos auxiliares de prueba, creados como administrador.
INSERT INTO public.bodega
VALUES ('99000000001', 'Prueba ventas', 'Prueba');

INSERT INTO public.localidad
VALUES ('TEST-VENTA', 'Prueba', 'Mendoza', 'Responsable');

INSERT INTO public.sala_venta
(id_sala, calle, numero, dia_cierre, codigo_postal)
OVERRIDING SYSTEM VALUE
VALUES (-970, 'Prueba', '1', 'lunes', 'TEST-VENTA');

INSERT INTO public.vino
(cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
OVERRIDING SYSTEM VALUE
VALUES (-970, 'Vino prueba', 'tinto', 2024, 750, 14, 100, '99000000001');

INSERT INTO public.cliente
(id_cliente, nombre_razon_social, tipo_doc, nro_doc,
 direccion, localidad, tipo_cliente)
OVERRIDING SYSTEM VALUE
VALUES (-970, 'Cliente prueba', 'TEST', 'VENTA-H2-970',
        'Prueba', 'Prueba', 'socio');

INSERT INTO public.cliente_socio VALUES (-970);

INSERT INTO public.stock_sala (id_sala, cod_vino, cantidad)
VALUES (-970, -970, 5);

SET LOCAL ROLE rol_operador_ventas;

DO $$
DECLARE
    v_comprobante INTEGER;
    v_fallido INTEGER;
    v_rechazado BOOLEAN := FALSE;
BEGIN
    INSERT INTO public.comprobante (id_cliente, id_sala)
    VALUES (-970, -970)
    RETURNING numero_comprobante INTO v_comprobante;

    -- La API no proporciona precio ni importes.
    INSERT INTO public.renglon_comprobante
        (numero_comprobante, cod_vino, cantidad)
    VALUES (v_comprobante, -970, 3);

    IF NOT EXISTS (
        SELECT 1 FROM public.renglon_comprobante
        WHERE numero_comprobante = v_comprobante
          AND precio_unitario = 100
          AND descuento = 30
          AND subtotal = 270
    ) THEN
        RAISE EXCEPTION 'Fallo: importes incorrectos en el renglon';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.comprobante
        WHERE numero_comprobante = v_comprobante
          AND subtotal = 300
          AND descuento = 30
          AND total = 270
    ) THEN
        RAISE EXCEPTION 'Fallo: totales incorrectos';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.stock_sala
        WHERE id_sala = -970 AND cod_vino = -970 AND cantidad = 2
    ) THEN
        RAISE EXCEPTION 'Fallo: stock incorrecto';
    END IF;

    RAISE NOTICE 'OK: venta de 3 botellas, bruto 300, descuento 30, neto 270, stock 2';

    INSERT INTO public.comprobante (id_cliente, id_sala)
    VALUES (-970, -970)
    RETURNING numero_comprobante INTO v_fallido;

    -- Quedan 2 botellas: intentar vender 3 debe fallar.
    BEGIN
        INSERT INTO public.renglon_comprobante
            (numero_comprobante, cod_vino, cantidad)
        VALUES (v_fallido, -970, 3);
    EXCEPTION WHEN check_violation THEN
        v_rechazado := TRUE;
    END;

    IF NOT v_rechazado THEN
        RAISE EXCEPTION 'Fallo: se permitio vender sin stock';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.renglon_comprobante
        WHERE numero_comprobante = v_fallido
    ) OR NOT EXISTS (
        SELECT 1 FROM public.comprobante
        WHERE numero_comprobante = v_fallido
          AND subtotal = 0 AND descuento = 0 AND total = 0
    ) OR NOT EXISTS (
        SELECT 1 FROM public.stock_sala
        WHERE id_sala = -970 AND cod_vino = -970 AND cantidad = 2
    ) THEN
        RAISE EXCEPTION 'Fallo: la venta rechazada altero los datos';
    END IF;

    RAISE NOTICE 'OK: venta sin stock rechazada sin alterar existencias ni importes';
END;
$$;

ROLLBACK;