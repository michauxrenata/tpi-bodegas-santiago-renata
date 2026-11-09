\set ON_ERROR_STOP on
BEGIN;

INSERT INTO public.bodega (cuit, razon_social, domicilio)
VALUES ('99000000990', 'Prueba composicion', 'Domicilio de prueba');

INSERT INTO public.cepa (id_cepa, nombre, tipo)
OVERRIDING SYSTEM VALUE
VALUES (
    -990,
    'Cepa prueba RN05',
    (enum_range(NULL::public.tipo_cepa))[1]
);

INSERT INTO public.vino
(cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
OVERRIDING SYSTEM VALUE
VALUES (
    -990, 'Vino composicion valida', 'tinto',
    2024, 750, 13, 100, '99000000990'
);

INSERT INTO public.composicion_vino (cod_vino, id_cepa, porcentaje)
VALUES (-990, -990, 100);

-- Fuerza la validacion pendiente antes del ROLLBACK.
SET CONSTRAINTS ALL IMMEDIATE;

DO $$
BEGIN
    RAISE NOTICE 'OK: vino con composicion del 100 por ciento aceptado';
END;
$$;

SET CONSTRAINTS ALL DEFERRED;

DO $$
BEGIN
    BEGIN
        UPDATE public.composicion_vino
        SET porcentaje = 90
        WHERE cod_vino = -990 AND id_cepa = -990;

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION 'Fallo: acepto una composicion del 90 por ciento';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: composicion del 90 por ciento rechazada';
    END;

    BEGIN
        DELETE FROM public.composicion_vino
        WHERE cod_vino = -990 AND id_cepa = -990;

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION 'Fallo: permitio dejar un vino sin componentes';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: eliminacion del ultimo componente rechazada';
    END;

    BEGIN
        INSERT INTO public.vino
        (cod_vino, nombre, tipo, anada, volumen_ml,
         graduacion, precio, cuit_bodega)
        OVERRIDING SYSTEM VALUE
        VALUES (
            -991, 'Vino sin componentes', 'tinto',
            2024, 750, 13, 100, '99000000990'
        );

        SET CONSTRAINTS ALL IMMEDIATE;

        RAISE EXCEPTION 'Fallo: acepto un vino nuevo sin componentes';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: vino nuevo sin componentes rechazado';
    END;

    IF NOT EXISTS (
        SELECT 1 FROM public.composicion_vino
        WHERE cod_vino = -990 AND id_cepa = -990
          AND porcentaje = 100
    ) OR EXISTS (
        SELECT 1 FROM public.vino WHERE cod_vino = -991
    ) THEN
               RAISE EXCEPTION 'Fallo: los rechazos no conservaron los datos esperados';
    END IF;
END;
$$;

-- El vino no tiene movimientos: puede eliminarse junto con su composicion.
DELETE FROM public.vino WHERE cod_vino = -990;

SET CONSTRAINTS ALL IMMEDIATE;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.vino WHERE cod_vino = -990
    ) OR EXISTS (
        SELECT 1 FROM public.composicion_vino WHERE cod_vino = -990
    ) THEN
        RAISE EXCEPTION 'Fallo: no se completo el borrado en cascada';
    END IF;

    RAISE NOTICE 'OK: vino y composicion eliminados sin rechazo incorrecto';
END;
$$;

ROLLBACK;