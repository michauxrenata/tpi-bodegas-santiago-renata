\set ON_ERROR_STOP on
BEGIN;

-- Alta valida: primero cliente, despues subtipo.
INSERT INTO public.cliente
(id_cliente, nombre_razon_social, tipo_doc, nro_doc,
 direccion, localidad, tipo_cliente)
OVERRIDING SYSTEM VALUE
VALUES
(-1100, 'Prueba jerarquia', 'TEST', 'JER-1100',
 'Prueba', 'Prueba', 'socio');

INSERT INTO public.cliente_socio VALUES (-1100);

SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

DO $$
BEGIN
    RAISE NOTICE 'OK: cliente con subtipo correcto aceptado';

    -- Quitar su unico subtipo debe fallar.
    BEGIN
        DELETE FROM public.cliente_socio
        WHERE id_cliente = -1100;

        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO: acepto cliente sin subtipo';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: cliente sin subtipo rechazado';
    END;

    -- Agregar otro subtipo debe fallar.
    BEGIN
        INSERT INTO public.cliente_exportador
        VALUES (-1100, 'Chile');

        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO: acepto dos subtipos';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: multiples subtipos rechazados';
    END;

    -- Tener un unico subtipo incompatible tambien debe fallar.
    BEGIN
        DELETE FROM public.cliente_socio
        WHERE id_cliente = -1100;

        INSERT INTO public.cliente_exportador
        VALUES (-1100, 'Chile');

        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO: acepto subtipo incompatible';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: subtipo incompatible rechazado';
    END;

    -- Cambiar solo el discriminador tampoco alcanza.
    BEGIN
        UPDATE public.cliente
        SET tipo_cliente = 'exportador'
        WHERE id_cliente = -1100;

        SET CONSTRAINTS ALL IMMEDIATE;
        RAISE EXCEPTION 'FALLO: acepto cambio de tipo incompleto';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: cambio de tipo incompleto rechazado';
    END;
END;
$$;

-- Cambio valido, resuelto en varios pasos dentro de la transaccion.
UPDATE public.cliente
SET tipo_cliente = 'exportador'
WHERE id_cliente = -1100;

DELETE FROM public.cliente_socio
WHERE id_cliente = -1100;

INSERT INTO public.cliente_exportador
VALUES (-1100, 'Chile');

SET CONSTRAINTS ALL IMMEDIATE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.cliente
        WHERE id_cliente = -1100
          AND tipo_cliente = 'exportador'
          AND descuento = 0.30
    ) THEN
        RAISE EXCEPTION 'FALLO: tipo o descuento incorrecto';
    END IF;

    RAISE NOTICE 'OK: cambio completo de tipo aceptado, descuento 30 por ciento';
END;
$$;

SET CONSTRAINTS ALL DEFERRED;

-- Borrar el cliente debe permitir la cascada de su subtipo.
DELETE FROM public.cliente
WHERE id_cliente = -1100;

SET CONSTRAINTS ALL IMMEDIATE;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.cliente_exportador
        WHERE id_cliente = -1100
    ) THEN
        RAISE EXCEPTION 'FALLO: quedo un subtipo tras borrar el cliente';
    END IF;

    RAISE NOTICE 'OK: borrado del cliente y cascada aceptados';
END;
$$;

ROLLBACK;