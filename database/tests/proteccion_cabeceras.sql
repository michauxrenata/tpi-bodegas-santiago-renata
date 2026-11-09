\set ON_ERROR_STOP on
BEGIN;

-- Datos auxiliares creados como administrador.
INSERT INTO public.bodega
VALUES ('99000000001', 'Prueba permisos', 'Prueba');

INSERT INTO public.localidad
VALUES ('TEST-H2', 'Prueba', 'Mendoza', 'Responsable');

INSERT INTO public.sala_venta
(id_sala, calle, numero, dia_cierre, codigo_postal)
OVERRIDING SYSTEM VALUE
VALUES (-950, 'Prueba', '1', 'lunes', 'TEST-H2');

INSERT INTO public.transportista
(codigo_transportista, razon_social, cuit, email, telefono, domicilio)
OVERRIDING SYSTEM VALUE
VALUES (-950, 'Prueba', '99000000003', 'h2@example.invalid', '0', 'Prueba');

INSERT INTO public.vino
(cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
OVERRIDING SYSTEM VALUE
VALUES (-950, 'Prueba permisos', 'tinto', 2024, 750, 14, 100, '99000000001');

-- Fixture RN05 completo: vino de prueba con composicion del 100 %.
INSERT INTO public.cepa (id_cepa, nombre, tipo)
OVERRIDING SYSTEM VALUE
VALUES (-950, 'Cepa fixture RN05 -950', 'tinta');

INSERT INTO public.composicion_vino (cod_vino, id_cepa, porcentaje)
VALUES (-950, -950, 100);

-- Validar el fixture antes de ejecutar operaciones como operador.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;
-- Alternativas validas: los rechazos no deben deberse a una FK inexistente.
INSERT INTO public.bodega
VALUES ('99000000002', 'Otra bodega de prueba', 'Prueba');

INSERT INTO public.transportista
(codigo_transportista, razon_social, cuit, email, telefono, domicilio)
OVERRIDING SYSTEM VALUE
VALUES (-951, 'Otro transportista', '99000000004',
        'otro-h2@example.invalid', '0', 'Prueba');

INSERT INTO public.sala_venta
(id_sala, calle, numero, dia_cierre, codigo_postal)
OVERRIDING SYSTEM VALUE
VALUES (-951, 'Otra sala', '2', 'martes', 'TEST-H2');

SET LOCAL ROLE rol_operador_ventas;

DO $$
DECLARE
    v_ingreso INTEGER;
    v_transferencia INTEGER;
    v_estado TEXT;
    v_cambio TEXT;
BEGIN
    INSERT INTO public.ingreso
    (codigo_transportista, cuit_bodega)
    VALUES (-950, '99000000001')
    RETURNING codigo_ingreso INTO v_ingreso;

    -- En confeccion se permiten cambios de datos.
    UPDATE public.ingreso
    SET fecha = CURRENT_DATE - 1,
        codigo_transportista = -951,
        cuit_bodega = '99000000002'
    WHERE codigo_ingreso = v_ingreso;

    IF NOT EXISTS (
        SELECT 1 FROM public.ingreso
        WHERE codigo_ingreso = v_ingreso
          AND fecha = CURRENT_DATE - 1
          AND codigo_transportista = -951
          AND cuit_bodega = '99000000002'
    ) THEN
        RAISE EXCEPTION 'Fallo: cambio de ingreso en confeccion';
    END IF;

    -- Restaurar la bodega compatible antes de cargar el vino.
    UPDATE public.ingreso
    SET fecha = CURRENT_DATE,
        codigo_transportista = -950,
        cuit_bodega = '99000000001'
    WHERE codigo_ingreso = v_ingreso;

    INSERT INTO public.renglon_ingreso
    VALUES (v_ingreso, -950, 5);

    CALL public.sp_terminar_ingreso(v_ingreso);

    FOREACH v_estado IN ARRAY ARRAY['terminado', 'procesado']
    LOOP
        IF v_estado = 'procesado' THEN
            CALL public.sp_procesar_ingreso(v_ingreso);
        END IF;

        FOREACH v_cambio IN ARRAY ARRAY[
            'fecha = CURRENT_DATE - 1',
            'codigo_transportista = -951',
            'cuit_bodega = ''99000000002'''
        ]
        LOOP
            BEGIN
                EXECUTE format(
                    'UPDATE public.ingreso SET %s WHERE codigo_ingreso = $1',
                    v_cambio
                ) USING v_ingreso;

                RAISE EXCEPTION
                    'Fallo: permitio cambiar % en ingreso %',
                    v_cambio, v_estado;
            EXCEPTION WHEN check_violation THEN
                RAISE NOTICE
                    'OK: ingreso % rechaza %', v_estado, v_cambio;
            END;
        END LOOP;
    END LOOP;

    INSERT INTO public.transferencia (id_sala)
    VALUES (-950)
    RETURNING numero_solicitud INTO v_transferencia;

    UPDATE public.transferencia SET id_sala = -951
    WHERE numero_solicitud = v_transferencia;

    IF NOT EXISTS (
        SELECT 1 FROM public.transferencia
        WHERE numero_solicitud = v_transferencia AND id_sala = -951
    ) THEN
        RAISE EXCEPTION 'Fallo: cambio de sala en confeccion';
    END IF;

    UPDATE public.transferencia SET id_sala = -950
    WHERE numero_solicitud = v_transferencia;

    INSERT INTO public.renglon_transferencia
    VALUES (v_transferencia, -950, 3);

    CALL public.sp_terminar_transferencia(v_transferencia);

    FOREACH v_estado IN ARRAY ARRAY['terminado', 'procesado']
    LOOP
        IF v_estado = 'procesado' THEN
            CALL public.sp_procesar_transferencia(v_transferencia);
        END IF;

        BEGIN
            UPDATE public.transferencia SET id_sala = -951
            WHERE numero_solicitud = v_transferencia;

            RAISE EXCEPTION
                'Fallo: permitio cambiar sala en transferencia %', v_estado;
        EXCEPTION WHEN check_violation THEN
            RAISE NOTICE
                'OK: transferencia % rechaza cambio de sala', v_estado;
        END;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1 FROM public.stock_deposito
        WHERE cod_vino = -950 AND cantidad = 2
    ) OR NOT EXISTS (
        SELECT 1 FROM public.stock_sala
        WHERE id_sala = -950 AND cod_vino = -950 AND cantidad = 3
    ) OR EXISTS (
        SELECT 1 FROM public.stock_sala
        WHERE id_sala = -951 AND cod_vino = -950 AND cantidad <> 0
    ) THEN
        RAISE EXCEPTION 'Fallo: existencias incorrectas';
    END IF;

    RAISE NOTICE 'OK: cambios en confeccion y procedimientos compatibles';
    RAISE NOTICE 'OK: stock final deposito 2, sala original 3';
END;
$$;

RESET ROLE;

-- Como administrador: el rechazo debe venir del trigger,
-- no de la falta de permiso UPDATE sobre estado.
DO $$
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO public.ingreso (codigo_transportista, cuit_bodega)
    VALUES (-950, '99000000001')
    RETURNING codigo_ingreso INTO v_id;

    BEGIN
        UPDATE public.ingreso
        SET estado = 'terminado', cuit_bodega = '99000000002'
        WHERE codigo_ingreso = v_id;

        RAISE EXCEPTION 'Fallo: permitio cambiar bodega y cerrar simultaneamente';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: cambio de bodega junto con cierre rechazado';
    END;

    INSERT INTO public.transferencia (id_sala)
    VALUES (-950)
    RETURNING numero_solicitud INTO v_id;

    BEGIN
        UPDATE public.transferencia
        SET estado = 'terminado', id_sala = -951
        WHERE numero_solicitud = v_id;

        RAISE EXCEPTION 'Fallo: permitio cambiar sala y cerrar simultaneamente';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: cambio de sala junto con cierre rechazado';
    END;
END;
$$;

SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;


