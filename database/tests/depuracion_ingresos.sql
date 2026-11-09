\set ON_ERROR_STOP on
BEGIN;

-- Datos auxiliares creados como administrador.
INSERT INTO public.bodega
VALUES ('99000000981', 'Prueba permisos', 'Prueba');

INSERT INTO public.localidad
VALUES ('TEST-D5', 'Prueba', 'Mendoza', 'Responsable');

INSERT INTO public.sala_venta
(id_sala, calle, numero, dia_cierre, codigo_postal)
OVERRIDING SYSTEM VALUE
VALUES (-980, 'Prueba', '1', 'lunes', 'TEST-D5');

INSERT INTO public.transportista
(codigo_transportista, razon_social, cuit, email, telefono, domicilio)
OVERRIDING SYSTEM VALUE
VALUES (-980, 'Prueba', '99000000982', 'd5@example.invalid', '0', 'Prueba');

INSERT INTO public.vino
(cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
OVERRIDING SYSTEM VALUE
VALUES (-980, 'Prueba permisos', 'tinto', 2024, 750, 14, 100, '99000000981');

-- Fixture RN05 completo: vino de prueba con composicion del 100 %.
INSERT INTO public.cepa (id_cepa, nombre, tipo)
OVERRIDING SYSTEM VALUE
VALUES (-980, 'Cepa fixture RN05 -980', 'tinta');

INSERT INTO public.composicion_vino (cod_vino, id_cepa, porcentaje)
VALUES (-980, -980, 100);

-- Validar el fixture antes de ejecutar operaciones como operador.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;


-- La depuracion historica se prueba como administrador.

DO $$
DECLARE
    v_antiguo INTEGER;
    v_limite INTEGER;
    v_rechazado BOOLEAN;
    v_stock INTEGER;
BEGIN
    INSERT INTO public.ingreso
        (fecha, codigo_transportista, cuit_bodega)
    VALUES (CURRENT_DATE - 366, -980, '99000000981')
    RETURNING codigo_ingreso INTO v_antiguo;

    INSERT INTO public.renglon_ingreso
        (codigo_ingreso, cod_vino, cantidad)
    VALUES (v_antiguo, -980, 5);

    CALL public.sp_terminar_ingreso(v_antiguo);
    CALL public.sp_procesar_ingreso(v_antiguo);

    -- Incluso siendo antiguo, no se pueden borrar detalles directamente.
    v_rechazado := FALSE;
    BEGIN
        DELETE FROM public.renglon_ingreso
        WHERE codigo_ingreso = v_antiguo;
    EXCEPTION WHEN check_violation THEN
        v_rechazado := TRUE;
    END;

    IF NOT v_rechazado THEN
        RAISE EXCEPTION 'Fallo: se permitio borrar un renglon procesado';
    END IF;

    RAISE NOTICE 'OK: borrado directo de renglones procesados rechazado';

    -- D5 permite eliminar la cabecera antigua con sus detalles.
    DELETE FROM public.ingreso WHERE codigo_ingreso = v_antiguo;

    IF EXISTS (
        SELECT 1 FROM public.ingreso
        WHERE codigo_ingreso = v_antiguo
    ) OR EXISTS (
        SELECT 1 FROM public.renglon_ingreso
        WHERE codigo_ingreso = v_antiguo
    ) THEN
        RAISE EXCEPTION 'Fallo: quedaron datos del ingreso depurado';
    END IF;

    SELECT cantidad INTO v_stock
    FROM public.stock_deposito WHERE cod_vino = -980;

    IF v_stock IS DISTINCT FROM 5 THEN
        RAISE EXCEPTION 'Fallo: la depuracion modifico el stock';
    END IF;

    RAISE NOTICE 'OK: ingreso de 366 dias eliminado; stock conservado en 5';

    -- Exactamente 365 dias NO cumple "mas de 365".
    INSERT INTO public.ingreso
        (fecha, codigo_transportista, cuit_bodega)
    VALUES (CURRENT_DATE - 365, -980, '99000000981')
    RETURNING codigo_ingreso INTO v_limite;

    INSERT INTO public.renglon_ingreso
        (codigo_ingreso, cod_vino, cantidad)
    VALUES (v_limite, -980, 2);

    CALL public.sp_terminar_ingreso(v_limite);
    CALL public.sp_procesar_ingreso(v_limite);

    v_rechazado := FALSE;
    BEGIN
        DELETE FROM public.ingreso WHERE codigo_ingreso = v_limite;
    EXCEPTION WHEN check_violation THEN
        v_rechazado := TRUE;
    END;

    IF NOT v_rechazado THEN
        RAISE EXCEPTION 'Fallo: se elimino un ingreso de exactamente 365 dias';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.renglon_ingreso
        WHERE codigo_ingreso = v_limite AND cantidad = 2
    ) THEN
        RAISE EXCEPTION 'Fallo: el rechazo no conservo los renglones';
    END IF;

    SELECT cantidad INTO v_stock
    FROM public.stock_deposito WHERE cod_vino = -980;

    IF v_stock IS DISTINCT FROM 7 THEN
        RAISE EXCEPTION 'Fallo: stock incorrecto tras el rechazo';
    END IF;

    RAISE NOTICE 'OK: ingreso de 365 dias protegido; detalles y stock intactos';
END;
$$;

-- Validar restricciones pendientes antes de revertir.
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
