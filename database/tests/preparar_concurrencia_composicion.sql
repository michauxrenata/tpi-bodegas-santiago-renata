\set ON_ERROR_STOP on

-- Preparacion persistente para una prueba manual con dos sesiones.
-- Ejecutar solamente en la base de QA.
BEGIN;

INSERT INTO public.bodega (cuit, razon_social, domicilio)
VALUES ('99000000995', 'Prueba concurrencia composicion', 'Prueba');

INSERT INTO public.cepa (id_cepa, nombre, tipo)
OVERRIDING SYSTEM VALUE
VALUES
(-995, 'Concurrencia RN05 A', 'tinta'),
(-996, 'Concurrencia RN05 B', 'tinta');

INSERT INTO public.vino
(cod_vino, nombre, tipo, anada, volumen_ml, graduacion, precio, cuit_bodega)
OVERRIDING SYSTEM VALUE
VALUES (
    -995, 'Vino concurrencia RN05', 'tinto',
    2024, 750, 14, 100, '99000000995'
);

INSERT INTO public.composicion_vino (cod_vino, id_cepa, porcentaje)
VALUES (-995, -995, 50), (-995, -996, 50);

SET CONSTRAINTS ALL IMMEDIATE;
COMMIT;

SELECT cod_vino, SUM(porcentaje) AS porcentaje_total
FROM public.composicion_vino
WHERE cod_vino = -995
GROUP BY cod_vino;