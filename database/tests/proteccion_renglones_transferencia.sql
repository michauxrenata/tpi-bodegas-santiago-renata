\set ON_ERROR_STOP on
BEGIN;

INSERT INTO public.bodega (cuit, razon_social, domicilio)
VALUES ('99000000985', 'Prueba RN12 transferencias', 'Domicilio de prueba');

INSERT INTO public.localidad
(codigo_postal, nombre, provincia, encargado_regional)
VALUES ('TEST-RN12', 'Localidad de prueba', 'Mendoza', 'Encargado');

INSERT INTO public.sala_venta
(id_sala, calle, numero, dia_cierre, codigo_postal)
OVERRIDING SYSTEM VALUE
VALUES (-985, 'Calle de prueba', 1, 'lunes', 'TEST-RN12');

INSERT INTO public.vino
(cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
OVERRIDING SYSTEM VALUE
VALUES (-985, 'Vino RN12', 'tinto', 2024, 750, 13, 100, '99000000985');

-- Fixture RN05 completo: vino de prueba con composicion del 100 %.
INSERT INTO public.cepa (id_cepa, nombre, tipo)
OVERRIDING SYSTEM VALUE
VALUES (-985, 'Cepa fixture RN05 -985', 'tinta');

INSERT INTO public.composicion_vino (cod_vino, id_cepa, porcentaje)
VALUES (-985, -985, 100);

-- Validar el fixture antes de ejecutar operaciones como operador.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;


INSERT INTO public.transferencia (numero_solicitud, id_sala)
OVERRIDING SYSTEM VALUE
VALUES (-985, -985), (-986, -985);

SET LOCAL ROLE rol_operador_ventas;

INSERT INTO public.renglon_transferencia
(numero_solicitud, cod_vino, cantidad)
VALUES (-985, -985, 1);

UPDATE public.renglon_transferencia
SET cantidad = 2
WHERE numero_solicitud = -985 AND cod_vino = -985;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM public.renglon_transferencia
        WHERE numero_solicitud = -985
          AND cod_vino = -985 AND cantidad = 2
    ) THEN
        RAISE EXCEPTION 'Fallo: no se actualizo el renglon en confeccion';
    END IF;
END;
$$;

DELETE FROM public.renglon_transferencia
WHERE numero_solicitud = -985 AND cod_vino = -985;

INSERT INTO public.renglon_transferencia
(numero_solicitud, cod_vino, cantidad)
VALUES (-985, -985, 1);

CALL public.sp_terminar_transferencia(-985);

DO $$
BEGIN
    BEGIN
        UPDATE public.renglon_transferencia
        SET cantidad = 3
        WHERE numero_solicitud = -985 AND cod_vino = -985;
        RAISE EXCEPTION 'Fallo: permitio editar una transferencia terminada';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: edicion de transferencia terminada rechazada';
    END;

    BEGIN
        DELETE FROM public.renglon_transferencia
        WHERE numero_solicitud = -985 AND cod_vino = -985;
        RAISE EXCEPTION 'Fallo: permitio borrar un renglon cerrado';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: borrado de renglon cerrado rechazado';
    END;
END;
$$;

-- El operador no puede cambiar numero_solicitud.
-- Usamos administrador para comprobar tambien el trigger.
RESET ROLE;

DO $$
BEGIN
    BEGIN
        UPDATE public.renglon_transferencia
        SET numero_solicitud = -986
        WHERE numero_solicitud = -985 AND cod_vino = -985;
        RAISE EXCEPTION 'Fallo: permitio mover desde una transferencia cerrada';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: movimiento desde transferencia cerrada rechazado';
    END;
END;
$$;

INSERT INTO public.renglon_transferencia
(numero_solicitud, cod_vino, cantidad)
VALUES (-986, -985, 2);

DO $$
BEGIN
    BEGIN
        UPDATE public.renglon_transferencia
        SET numero_solicitud = -985
        WHERE numero_solicitud = -986 AND cod_vino = -985;
        RAISE EXCEPTION 'Fallo: permitio mover hacia una transferencia cerrada';
    EXCEPTION WHEN check_violation THEN
        RAISE NOTICE 'OK: movimiento hacia transferencia cerrada rechazado';
    END;

    IF NOT EXISTS (
        SELECT 1 FROM public.renglon_transferencia
        WHERE numero_solicitud = -985 AND cod_vino = -985 AND cantidad = 1
    ) OR NOT EXISTS (
        SELECT 1 FROM public.renglon_transferencia
        WHERE numero_solicitud = -986 AND cod_vino = -985 AND cantidad = 2
    ) THEN
        RAISE EXCEPTION 'Fallo: los rechazos alteraron los renglones';
    END IF;

    RAISE NOTICE 'OK: renglones originales conservados';
END;
$$;

-- Validar restricciones pendientes antes de revertir.
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
