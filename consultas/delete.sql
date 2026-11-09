-- H5: D1-D6. Solo demostracion administrativa en una base de pruebas.
-- Una transaccion, SAVEPOINT por ejercicio y ROLLBACK final.
-- Cada ejercicio parte de los mismos datos: se revierte antes del siguiente.
-- Se usa CURRENT_DATE, tambien utilizado por el trigger de depuracion D5.
-- Opcionales: -v sala=1 -v cp_sala=5620 -v localidad_cliente='General Alvear'
\set ON_ERROR_STOP on
\if :{?sala}
\else
\set sala 1
\endif
\if :{?cp_sala}
\else
\set cp_sala 5620
\endif
\if :{?localidad_cliente}
\else
\set localidad_cliente 'General Alvear'
\endif

BEGIN;
CREATE TEMP TABLE h5_d_param ON COMMIT DROP AS
SELECT CURRENT_DATE AS fecha_ref, :'sala'::integer AS sala,
       :'cp_sala'::text AS cp_sala, :'localidad_cliente'::text AS localidad_cliente;
SELECT * FROM h5_d_param;

\echo '=== D1: comprobantes de socios con mas de cinco anios ==='
SAVEPOINT d1;
-- Corte a las 00:00 de fecha_ref menos cinco anios; igualdad queda protegida.
CREATE TEMP TABLE h5_d1 ON COMMIT DROP AS
SELECT c.numero_comprobante FROM public.comprobante c
JOIN public.cliente cl USING(id_cliente) CROSS JOIN h5_d_param p
WHERE cl.tipo_cliente='socio' AND c.fecha < p.fecha_ref - INTERVAL '5 years';
CREATE TEMP TABLE h5_d1_stock ON COMMIT DROP AS SELECT * FROM public.stock_sala;
SELECT 'antes' AS momento,COUNT(*) AS comprobantes_candidatos FROM h5_d1;
SELECT 'antes' AS momento,COUNT(*) AS renglones_candidatos
FROM public.renglon_comprobante r JOIN h5_d1 d USING(numero_comprobante);
DELETE FROM public.comprobante c USING h5_d1 d
WHERE c.numero_comprobante=d.numero_comprobante RETURNING c.numero_comprobante,c.fecha,c.id_cliente;
DO $$ BEGIN
 IF EXISTS(SELECT FROM public.comprobante c JOIN h5_d1 d USING(numero_comprobante))
 OR EXISTS(SELECT FROM public.renglon_comprobante r JOIN h5_d1 d USING(numero_comprobante)) THEN
 RAISE EXCEPTION 'D1: quedaron cabeceras o detalles seleccionados'; END IF;
 IF EXISTS((SELECT * FROM public.stock_sala EXCEPT SELECT * FROM h5_d1_stock)
 UNION ALL (SELECT * FROM h5_d1_stock EXCEPT SELECT * FROM public.stock_sala)) THEN
 RAISE EXCEPTION 'D1: el borrado historico altero stock'; END IF;
END $$;
SELECT 'despues' AS momento,COUNT(*) AS comprobantes_restantes
FROM public.comprobante c JOIN h5_d1 d USING(numero_comprobante);
-- La cascada elimina detalles. No es una devolucion: no repone existencias.
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT d1;

\echo '=== D2: cepas sin composicion ni parcelas ==='
SAVEPOINT d2;
CREATE TEMP TABLE h5_d2 ON COMMIT DROP AS
SELECT c.id_cepa FROM public.cepa c
WHERE NOT EXISTS(SELECT FROM public.composicion_vino cv WHERE cv.id_cepa=c.id_cepa)
  AND NOT EXISTS(SELECT FROM public.parcela p WHERE p.id_cepa=c.id_cepa);
SELECT 'antes' AS momento,COUNT(*) AS cepas_candidatas FROM h5_d2;
DELETE FROM public.cepa c USING h5_d2 d WHERE c.id_cepa=d.id_cepa RETURNING c.*;
SELECT 'despues' AS momento,COUNT(*) AS cepas_restantes FROM public.cepa c JOIN h5_d2 d USING(id_cepa);
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT d2;

\echo '=== D3: empleados de sala dada de baja con menos de dos anios ==='
SAVEPOINT d3;
-- La baja de la sala es un dato externo: no existe un atributo de baja en el esquema.
-- Ejemplo: la baja ocurre en fecha_ref. No se borra la sala.
-- El CP verifica la localidad de la sala; no se afectan otras salas del mismo CP.
DO $$ BEGIN
 IF NOT EXISTS(SELECT FROM public.sala_venta s CROSS JOIN h5_d_param p
 WHERE s.id_sala=p.sala AND s.codigo_postal=p.cp_sala) THEN
 RAISE EXCEPTION 'D3: sala inexistente o localidad incompatible'; END IF;
END $$;
CREATE TEMP TABLE h5_d3 ON COMMIT DROP AS
SELECT e.cuit FROM public.empleado e CROSS JOIN h5_d_param p
WHERE e.id_sala=p.sala AND e.fecha_ingreso>p.fecha_ref-INTERVAL '2 years'
 AND e.fecha_ingreso<=p.fecha_ref;
SELECT 'antes' AS momento,COUNT(*) AS empleados_candidatos FROM h5_d3;
DELETE FROM public.empleado e USING h5_d3 d WHERE e.cuit=d.cuit RETURNING e.*;
SELECT 'despues' AS momento,COUNT(*) AS empleados_restantes FROM public.empleado e JOIN h5_d3 d USING(cuit);
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT d3;

\echo '=== D4: socios sin compras y alta de hace mas de cinco anios ==='
SAVEPOINT d4;
CREATE TEMP TABLE h5_d4 ON COMMIT DROP AS
SELECT c.id_cliente FROM public.cliente c CROSS JOIN h5_d_param p
WHERE c.tipo_cliente='socio' AND c.fecha_alta<p.fecha_ref-INTERVAL '5 years'
 AND NOT EXISTS(SELECT FROM public.comprobante co WHERE co.id_cliente=c.id_cliente);
SELECT 'antes' AS momento,COUNT(*) AS socios_candidatos FROM h5_d4;
DELETE FROM public.cliente c USING h5_d4 d WHERE c.id_cliente=d.id_cliente RETURNING c.id_cliente,c.fecha_alta;
DO $$ BEGIN
 IF EXISTS(SELECT FROM public.cliente_socio s JOIN h5_d4 d USING(id_cliente)) THEN
 RAISE EXCEPTION 'D4: no se elimino el subtipo por cascada'; END IF;
END $$;
SELECT 'despues' AS momento,COUNT(*) AS clientes_restantes FROM public.cliente c JOIN h5_d4 d USING(id_cliente);
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT d4;

\echo '=== D5: ingresos procesados con mas de 365 dias ==='
SAVEPOINT d5;
CREATE TEMP TABLE h5_d5 ON COMMIT DROP AS
SELECT codigo_ingreso FROM public.ingreso
WHERE estado='procesado' AND fecha<CURRENT_DATE-365;
CREATE TEMP TABLE h5_d5_stock ON COMMIT DROP AS SELECT * FROM public.stock_deposito;
SELECT 'antes' AS momento,COUNT(*) AS ingresos_candidatos FROM h5_d5;
SELECT 'antes' AS momento,COUNT(*) AS renglones_candidatos
FROM public.renglon_ingreso r JOIN h5_d5 d USING(codigo_ingreso);
DELETE FROM public.ingreso i USING h5_d5 d
WHERE i.codigo_ingreso=d.codigo_ingreso RETURNING i.codigo_ingreso,i.fecha,i.estado;
DO $$ BEGIN
 IF EXISTS(SELECT FROM public.ingreso i JOIN h5_d5 d USING(codigo_ingreso))
 OR EXISTS(SELECT FROM public.renglon_ingreso r JOIN h5_d5 d USING(codigo_ingreso)) THEN
 RAISE EXCEPTION 'D5: quedaron cabeceras o detalles seleccionados'; END IF;
 IF EXISTS((SELECT * FROM public.stock_deposito EXCEPT SELECT * FROM h5_d5_stock)
 UNION ALL (SELECT * FROM h5_d5_stock EXCEPT SELECT * FROM public.stock_deposito)) THEN
 RAISE EXCEPTION 'D5: depurar documentos no debe alterar existencias'; END IF;
END $$;
SELECT 'despues' AS momento,COUNT(*) AS ingresos_restantes
FROM public.ingreso i JOIN h5_d5 d USING(codigo_ingreso);
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT d5;

\echo '=== D6: socios sin compras de una localidad determinada ==='
SAVEPOINT d6;
-- cliente.localidad es texto: coincidencia exacta, no FK ni CP.
CREATE TEMP TABLE h5_d6 ON COMMIT DROP AS
SELECT c.id_cliente FROM public.cliente c CROSS JOIN h5_d_param p
WHERE c.tipo_cliente='socio' AND c.localidad=p.localidad_cliente
 AND NOT EXISTS(SELECT FROM public.comprobante co WHERE co.id_cliente=c.id_cliente);
SELECT 'antes' AS momento,COUNT(*) AS socios_candidatos FROM h5_d6;
DELETE FROM public.cliente c USING h5_d6 d WHERE c.id_cliente=d.id_cliente RETURNING c.id_cliente,c.localidad;
DO $$ BEGIN
 IF EXISTS(SELECT FROM public.cliente_socio s JOIN h5_d6 d USING(id_cliente)) THEN
 RAISE EXCEPTION 'D6: no se elimino el subtipo por cascada'; END IF;
END $$;
SELECT 'despues' AS momento,COUNT(*) AS clientes_restantes FROM public.cliente c JOIN h5_d6 d USING(id_cliente);
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT d6;
ROLLBACK;
\echo '=== D1-D6 finalizados sin errores; datos revertidos ==='
