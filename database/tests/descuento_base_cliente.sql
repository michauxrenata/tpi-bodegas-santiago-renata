\set ON_ERROR_STOP on
BEGIN;

INSERT INTO public.cliente
(id_cliente, nombre_razon_social, tipo_doc, nro_doc,
 direccion, localidad, tipo_cliente)
OVERRIDING SYSTEM VALUE
VALUES
(-960, 'Prueba socio', 'TEST', 'H2-DESC-1', 'Prueba', 'Prueba', 'socio'),
(-961, 'Prueba distribuidor', 'TEST', 'H2-DESC-2', 'Prueba', 'Prueba', 'distribuidor'),
(-962, 'Prueba exportador', 'TEST', 'H2-DESC-3', 'Prueba', 'Prueba', 'exportador');

DO $$
BEGIN
    IF public.fn_descuento_cliente(-960) IS DISTINCT FROM 0.10::numeric
       OR public.fn_descuento_cliente(-961) IS DISTINCT FROM 0.20::numeric
       OR public.fn_descuento_cliente(-962) IS DISTINCT FROM 0.30::numeric THEN
        RAISE EXCEPTION 'Fallo: descuentos base incorrectos';
    END IF;
    RAISE NOTICE 'OK: descuentos base 10, 20 y 30 por ciento';
END;
$$;

-- Simula la actualizacion del descuento que realiza U6.
UPDATE public.cliente SET descuento = 0.35 WHERE id_cliente = -962;

-- Mantener el mismo tipo no debe restablecer el descuento base.
UPDATE public.cliente
SET tipo_cliente = 'exportador', nombre_razon_social = 'Exportador actualizado'
WHERE id_cliente = -962;

DO $$
BEGIN
    IF public.fn_descuento_cliente(-962) IS DISTINCT FROM 0.35::numeric THEN
        RAISE EXCEPTION 'Fallo: no se conservo el 35 por ciento';
    END IF;
    RAISE NOTICE 'OK: se conserva el 35 por ciento sin cambio de tipo';
END;
$$;

-- Un cambio real de tipo debe asignar la nueva tasa base.
UPDATE public.cliente SET tipo_cliente = 'socio' WHERE id_cliente = -962;

DO $$
BEGIN
    IF public.fn_descuento_cliente(-962) IS DISTINCT FROM 0.10::numeric THEN
        RAISE EXCEPTION 'Fallo: cambiar a socio no asigno el 10 por ciento';
    END IF;
    RAISE NOTICE 'OK: cambio de tipo asigna la nueva tasa base';
END;
$$;

ROLLBACK;
\set ON_ERROR_STOP on
BEGIN;

INSERT INTO public.cliente
(id_cliente, nombre_razon_social, tipo_doc, nro_doc,
 direccion, localidad, tipo_cliente)
OVERRIDING SYSTEM VALUE
VALUES
(-960, 'Prueba socio', 'TEST', 'H2-DESC-1', 'Prueba', 'Prueba', 'socio'),
(-961, 'Prueba distribuidor', 'TEST', 'H2-DESC-2', 'Prueba', 'Prueba', 'distribuidor'),
(-962, 'Prueba exportador', 'TEST', 'H2-DESC-3', 'Prueba', 'Prueba', 'exportador');

INSERT INTO public.cliente_socio (id_cliente)
VALUES (-960);

INSERT INTO public.cliente_distribuidor
(id_cliente, zona_cobertura, nro_habilitacion)
VALUES (-961, 'Prueba', 'H2-DESC-HAB-2');

INSERT INTO public.cliente_exportador
(id_cliente, pais_destino_principal)
VALUES (-962, 'Chile');

-- Comprobar que las altas tienen subtipos coherentes.
SET CONSTRAINTS ALL IMMEDIATE;
SET CONSTRAINTS ALL DEFERRED;

DO $$
BEGIN
    IF public.fn_descuento_cliente(-960) IS DISTINCT FROM 0.10::numeric
       OR public.fn_descuento_cliente(-961) IS DISTINCT FROM 0.20::numeric
       OR public.fn_descuento_cliente(-962) IS DISTINCT FROM 0.30::numeric THEN
        RAISE EXCEPTION 'Fallo: descuentos base incorrectos';
    END IF;
    RAISE NOTICE 'OK: descuentos base 10, 20 y 30 por ciento';
END;
$$;

-- Simula la actualizacion del descuento que realiza U6.
UPDATE public.cliente
SET descuento = 0.35
WHERE id_cliente = -962;

-- Mantener el tipo no debe restablecer el descuento base.
UPDATE public.cliente
SET tipo_cliente = 'exportador',
    nombre_razon_social = 'Exportador actualizado'
WHERE id_cliente = -962;

DO $$
BEGIN
    IF public.fn_descuento_cliente(-962) IS DISTINCT FROM 0.35::numeric THEN
        RAISE EXCEPTION 'Fallo: no se conservo el 35 por ciento';
    END IF;
    RAISE NOTICE 'OK: se conserva el 35 por ciento sin cambio de tipo';
END;
$$;

-- Cambio completo de tipo y subtipo.
-- Las restricciones diferidas permiten estos pasos intermedios.
UPDATE public.cliente
SET tipo_cliente = 'socio'
WHERE id_cliente = -962;

DELETE FROM public.cliente_exportador
WHERE id_cliente = -962;

INSERT INTO public.cliente_socio (id_cliente)
VALUES (-962);

SET CONSTRAINTS ALL IMMEDIATE;

DO $$
BEGIN
    IF public.fn_descuento_cliente(-962) IS DISTINCT FROM 0.10::numeric THEN
        RAISE EXCEPTION 'Fallo: cambiar a socio no asigno el 10 por ciento';
    END IF;
    RAISE NOTICE 'OK: cambio de tipo y subtipo valido; nueva tasa base 10 por ciento';
END;
$$;

ROLLBACK;