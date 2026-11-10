\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_salas INTEGER;
    v_vinos INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_salas FROM public.sala_venta;
    SELECT COUNT(*) INTO v_vinos FROM public.vino;

    IF v_salas < 1 OR v_vinos < 3 THEN
        RAISE EXCEPTION 'El benchmark necesita al menos una sala y tres vinos';
    END IF;

    IF EXISTS (
        SELECT FROM public.transferencia
        WHERE numero_solicitud BETWEEN 1000001 AND 1150000
    ) THEN
        RAISE EXCEPTION 'Ya existen IDs reservados por el fixture H4';
    END IF;
END $$;

-- Las salas se reparten uniformemente. El trigger asigna CURRENT_DATE.
WITH salas AS MATERIALIZED (
    SELECT id_sala,
           ROW_NUMBER() OVER (ORDER BY id_sala) AS rn,
           COUNT(*) OVER () AS total
    FROM public.sala_venta
)
INSERT INTO public.transferencia
    (numero_solicitud, id_sala, estado)
OVERRIDING SYSTEM VALUE
SELECT 1000000 + g,
       s.id_sala,
       'en_confeccion'
FROM generate_series(1, 150000) AS serie(g)
JOIN salas AS s
  ON s.rn = 1 + ((g - 1) % s.total);

-- 60 % del vino más frecuente, 30 % del segundo y 10 % repartido
-- entre los demás vinos.
WITH vinos AS MATERIALIZED (
    SELECT cod_vino,
           ROW_NUMBER() OVER (ORDER BY cod_vino) AS rn
    FROM public.vino
),
asignacion AS (
    SELECT g,
           CASE
               WHEN g % 10 < 6 THEN 1
               WHEN g % 10 < 9 THEN 2
               ELSE 3 + (((g - 1) / 10) % ((SELECT COUNT(*) FROM vinos) - 2))
           END AS rn_vino
    FROM generate_series(1, 150000) AS serie(g)
)
INSERT INTO public.renglon_transferencia
    (numero_solicitud, cod_vino, cantidad)
SELECT 1000000 + a.g, v.cod_vino, 1 + (a.g % 12)
FROM asignacion AS a
JOIN vinos AS v ON v.rn = a.rn_vino;

-- Transiciones válidas; 1 % queda en terminado y 99 % en procesado.
UPDATE public.transferencia
SET estado = 'terminado'
WHERE numero_solicitud BETWEEN 1000001 AND 1150000;

UPDATE public.transferencia
SET estado = 'procesado'
WHERE numero_solicitud BETWEEN 1000001 AND 1150000
  AND MOD(numero_solicitud - 1000001, 100) <> 0;

ANALYZE public.transferencia;
ANALYZE public.renglon_transferencia;
COMMIT;

SELECT estado, MIN(fecha_confeccion) AS primera_fecha,
       MAX(fecha_confeccion) AS ultima_fecha, COUNT(*) AS cantidad
FROM public.transferencia
WHERE numero_solicitud BETWEEN 1000001 AND 1150000
GROUP BY estado
ORDER BY estado;

SELECT cod_vino, COUNT(*) AS renglones
FROM public.renglon_transferencia
WHERE numero_solicitud BETWEEN 1000001 AND 1150000
GROUP BY cod_vino
ORDER BY COUNT(*), cod_vino
LIMIT 4;