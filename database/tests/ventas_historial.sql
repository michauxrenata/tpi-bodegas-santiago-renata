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

-- Fixture RN05 completo: vino de prueba con composicion del 100 %.
INSERT INTO public.cepa (id_cepa, nombre, tipo)
OVERRIDING SYSTEM VALUE
VALUES (-970, 'Cepa fixture RN05 -970', 'tinta');

INSERT INTO public.composicion_vino (cod_vino, id_cepa, porcentaje)
VALUES (-970, -970, 100);

-- Validar el fixture antes de ejecutar operaciones como operador.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;


INSERT INTO public.cliente
(id_cliente, nombre_razon_social, tipo_doc, nro_doc,
 direccion, localidad, tipo_cliente)
OVERRIDING SYSTEM VALUE
VALUES (-970, 'Cliente prueba', 'TEST', 'VENTA-H2-970',
        'Prueba', 'Prueba', 'socio');

INSERT INTO public.cliente_socio VALUES (-970);

INSERT INTO public.stock_sala (id_sala, cod_vino, cantidad)
VALUES (-970, -970, 5);


-- Preparar un exportador con descuento vigente del 35 %.
DELETE FROM public.cliente_socio WHERE id_cliente = -970;
UPDATE public.cliente
SET tipo_cliente = 'exportador'
WHERE id_cliente = -970;

INSERT INTO public.cliente_exportador VALUES (-970, 'Chile');

UPDATE public.cliente SET descuento = 0.35 WHERE id_cliente = -970;

SET LOCAL ROLE rol_operador_ventas;

DO $$
DECLARE
    v_numero INTEGER;
BEGIN
    INSERT INTO public.comprobante (id_cliente, id_sala)
    VALUES (-970, -970)
    RETURNING numero_comprobante INTO v_numero;

    INSERT INTO public.renglon_comprobante
        (numero_comprobante, cod_vino, cantidad)
    VALUES (v_numero, -970, 3);

    IF NOT EXISTS (
        SELECT 1 FROM public.renglon_comprobante
        WHERE numero_comprobante = v_numero
          AND precio_unitario = 100
          AND descuento = 105
          AND subtotal = 195
    ) OR NOT EXISTS (
        SELECT 1 FROM public.comprobante
        WHERE numero_comprobante = v_numero
          AND subtotal = 300
          AND descuento = 105
          AND total = 195
    ) THEN
        RAISE EXCEPTION 'Fallo: calculo de venta con descuento del 35 por ciento';
    END IF;

    RAISE NOTICE 'OK: bruto 300, descuento 105 y neto 195';
END;
$$;

-- Como administrador, cambiar los valores actuales del catalogo y cliente.
RESET ROLE;
UPDATE public.vino SET precio = 200 WHERE cod_vino = -970;
UPDATE public.cliente SET descuento = 0.30 WHERE id_cliente = -970;

SET LOCAL ROLE rol_operador_ventas;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM public.renglon_comprobante AS r
        JOIN public.comprobante AS c
          ON c.numero_comprobante = r.numero_comprobante
        WHERE r.cod_vino = -970
          AND c.id_cliente = -970
          AND r.precio_unitario = 100
          AND r.descuento = 105
          AND r.subtotal = 195
          AND c.subtotal = 300
          AND c.descuento = 105
          AND c.total = 195
    ) THEN
        RAISE EXCEPTION 'Fallo: se modificaron los importes historicos';
    END IF;

    RAISE NOTICE 'OK: cambiar precio y descuento no modifica la venta anterior';
END;
$$;

-- Validar restricciones pendientes antes de revertir.
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
