-- H5: I1-I6. Ejecutar como administrador en una base de pruebas con H3.
-- Cada ejercicio usa SAVEPOINT y revierte sus cambios; la transaccion termina en ROLLBACK.
-- Las secuencias identity pueden avanzar aunque se reviertan las filas.
-- Parametros opcionales: -v fecha_ref=2025-01-15 -v cliente=1 -v vino=1
-- I3 usa sala 1 y vinos 1,2,3 (una botella cada uno). Editar h5_param si es necesario.
\set ON_ERROR_STOP on
\if :{?fecha_ref}
\else
\set fecha_ref 2025-01-15
\endif
\if :{?cliente}
\else
\set cliente 1
\endif
\if :{?vino}
\else
\set vino 1
\endif

BEGIN;
CREATE TEMP TABLE h5_param ON COMMIT DROP AS
SELECT :'fecha_ref'::date AS fecha_ref, :'cliente'::integer AS cliente,
       :'vino'::integer AS vino_ingreso,
       '99010000001'::text AS bodega_ingreso, 1::integer AS transportista,
       '5620'::text AS cp_alvear, '5600'::text AS cp_sala;

\echo '=== I1: cobertura del transportista con menos ingresos ==='
SAVEPOINT i1;
-- Trimestre movil: [fecha_ref + 1 dia - 3 meses, fecha_ref + 1 dia).
-- Incluye transportistas con cero ingresos; desempata por codigo ascendente.
-- Cuenta ingresos trasladados sin filtrar estado, conforme a esta interpretacion de envios.
CREATE TEMP TABLE h5_elegido ON COMMIT DROP AS
SELECT t.codigo_transportista, COUNT(i.codigo_ingreso) AS ingresos
FROM public.transportista t CROSS JOIN h5_param p
LEFT JOIN public.ingreso i ON i.codigo_transportista=t.codigo_transportista
 AND i.fecha >= p.fecha_ref + INTERVAL '1 day' - INTERVAL '3 months'
 AND i.fecha < p.fecha_ref + INTERVAL '1 day'
GROUP BY t.codigo_transportista
ORDER BY ingresos, t.codigo_transportista LIMIT 1;
DO $$ BEGIN
 IF NOT EXISTS (SELECT FROM h5_elegido) THEN RAISE EXCEPTION 'I1: no hay transportistas'; END IF;
 IF NOT EXISTS (SELECT FROM public.localidad l JOIN h5_param p ON l.codigo_postal=p.cp_alvear
                WHERE l.nombre='General Alvear') THEN
  RAISE EXCEPTION 'I1: el codigo postal no corresponde a General Alvear';
 END IF;
END $$;
SELECT 'antes' AS momento, e.*, EXISTS (
 SELECT FROM public.transportista_cobertura c CROSS JOIN h5_param p
 WHERE c.codigo_transportista=e.codigo_transportista AND c.codigo_postal=p.cp_alvear
) AS cobertura_existente FROM h5_elegido e;
INSERT INTO public.transportista_cobertura(codigo_transportista,codigo_postal)
SELECT e.codigo_transportista,p.cp_alvear FROM h5_elegido e CROSS JOIN h5_param p
ON CONFLICT (codigo_transportista,codigo_postal) DO NOTHING
RETURNING *;
-- Si ya existia, no se duplica ni se elige artificialmente otro transportista.
SELECT 'despues' AS momento, c.* FROM public.transportista_cobertura c
JOIN h5_elegido e USING(codigo_transportista) CROSS JOIN h5_param p
WHERE c.codigo_postal=p.cp_alvear;
ROLLBACK TO SAVEPOINT i1;

\echo '=== I2: cordero al disco para tintos de al menos 14 grados ==='
SAVEPOINT i2;
SELECT 'antes' AS momento, COUNT(*) AS asociaciones FROM public.vino_maridaje vm
JOIN public.maridaje m USING(id_maridaje) WHERE m.nombre='cordero al disco';
-- 17 grados C es el valor elegido para el atributo obligatorio de temperatura.
INSERT INTO public.maridaje(nombre,temp_servicio_sugerida_c)
SELECT 'cordero al disco',17 WHERE EXISTS (
 SELECT FROM public.vino WHERE tipo='tinto' AND graduacion>=14
) ON CONFLICT (nombre) DO NOTHING RETURNING *;
INSERT INTO public.vino_maridaje(cod_vino,id_maridaje)
SELECT v.cod_vino,m.id_maridaje FROM public.vino v CROSS JOIN public.maridaje m
WHERE v.tipo='tinto' AND v.graduacion>=14 AND m.nombre='cordero al disco'
ON CONFLICT (cod_vino,id_maridaje) DO NOTHING RETURNING *;
DO $$ BEGIN
 IF EXISTS (SELECT FROM public.vino v WHERE v.tipo='tinto' AND v.graduacion>=14
 AND NOT EXISTS (SELECT FROM public.vino_maridaje vm JOIN public.maridaje m USING(id_maridaje)
 WHERE vm.cod_vino=v.cod_vino AND m.nombre='cordero al disco')) THEN
 RAISE EXCEPTION 'I2: quedaron vinos elegibles sin asociar'; END IF;
END $$;
SELECT 'despues' AS momento, COUNT(*) AS asociaciones FROM public.vino_maridaje vm
JOIN public.maridaje m USING(id_maridaje) WHERE m.nombre='cordero al disco';
ROLLBACK TO SAVEPOINT i2;

\echo '=== I3: comprobante de tres renglones, sala 1 ==='
SAVEPOINT i3;
CREATE TEMP TABLE h5_detalle(cod_vino integer PRIMARY KEY,cantidad integer NOT NULL CHECK(cantidad>0)) ON COMMIT DROP;
INSERT INTO h5_detalle VALUES(1,1),(2,1),(3,1);
SELECT 'antes' AS momento,s.* FROM public.stock_sala s JOIN h5_detalle d USING(cod_vino) WHERE s.id_sala=1;
DO $$ BEGIN
 IF (SELECT COUNT(*) FROM public.vino v JOIN h5_detalle d USING(cod_vino))<>3 THEN
 RAISE EXCEPTION 'I3: deben existir los tres vinos'; END IF;
END $$;
CREATE TEMP TABLE h5_comprobante ON COMMIT DROP AS
WITH nuevo AS (
 INSERT INTO public.comprobante(id_cliente,id_sala)
 SELECT cliente,1 FROM h5_param RETURNING numero_comprobante
) SELECT * FROM nuevo;
-- La funcion devuelve NETO; los triggers vigentes vuelven a calcular y controlan stock.
INSERT INTO public.renglon_comprobante
(numero_comprobante,cod_vino,cantidad,precio_unitario,descuento,subtotal)
SELECT c.numero_comprobante,d.cod_vino,d.cantidad,v.precio,
 ROUND(v.precio*d.cantidad,2)-public.fn_calcular_descuento_cliente(p.cliente,v.precio*d.cantidad),
 public.fn_calcular_descuento_cliente(p.cliente,v.precio*d.cantidad)
FROM h5_detalle d JOIN public.vino v USING(cod_vino)
CROSS JOIN h5_comprobante c CROSS JOIN h5_param p ORDER BY d.cod_vino;
DO $$ DECLARE n integer; BEGIN
 SELECT numero_comprobante INTO STRICT n FROM h5_comprobante;
 IF (SELECT COUNT(*) FROM public.renglon_comprobante WHERE numero_comprobante=n)<>3 THEN
 RAISE EXCEPTION 'I3: se esperaban tres renglones'; END IF;
 IF (SELECT total FROM public.comprobante WHERE numero_comprobante=n)
 IS DISTINCT FROM public.fn_total_comprobante(n) THEN RAISE EXCEPTION 'I3: total incorrecto'; END IF;
END $$;
SELECT c.*,public.fn_total_comprobante(c.numero_comprobante) AS total_funcion
FROM public.comprobante c JOIN h5_comprobante n USING(numero_comprobante);
SELECT r.* FROM public.renglon_comprobante r JOIN h5_comprobante n USING(numero_comprobante);
SELECT 'despues' AS momento,s.* FROM public.stock_sala s JOIN h5_detalle d USING(cod_vino) WHERE s.id_sala=1;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT i3;

\echo '=== I4: nueva bodega ==='
SAVEPOINT i4;
SELECT 'antes' AS momento,COUNT(*) FROM public.bodega WHERE cuit='99090000041';
-- CUIT sintetico para esta demostracion; una colision detiene la prueba.
INSERT INTO public.bodega(cuit,razon_social,domicilio)
VALUES('99090000041','Bodega demostracion I4','Calle de prueba 41') RETURNING *;
SELECT 'despues' AS momento,COUNT(*) FROM public.bodega WHERE cuit='99090000041';
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT i4;

\echo '=== I5: nueva sala de venta ==='
SAVEPOINT i5;
SELECT 'antes' AS momento,COUNT(*) AS salas FROM public.sala_venta;
INSERT INTO public.sala_venta(calle,numero,dia_cierre,codigo_postal)
SELECT 'Calle demostracion I5','51','martes',cp_sala FROM h5_param RETURNING *;
SELECT 'despues' AS momento,COUNT(*) AS salas FROM public.sala_venta;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT i5;

\echo '=== I6: ingreso en confeccion de 120 botellas ==='
SAVEPOINT i6;
DO $$ BEGIN
 IF NOT EXISTS (SELECT FROM public.vino v CROSS JOIN h5_param p
 WHERE v.cod_vino=p.vino_ingreso AND v.cuit_bodega=p.bodega_ingreso) THEN
 RAISE EXCEPTION 'I6: el vino no existe o no pertenece a la bodega indicada'; END IF;
END $$;
CREATE TEMP TABLE h5_stock_antes ON COMMIT DROP AS
SELECT s.* FROM public.stock_deposito s JOIN h5_param p ON s.cod_vino=p.vino_ingreso;
SELECT 'antes' AS momento,* FROM h5_stock_antes;
CREATE TEMP TABLE h5_ingreso ON COMMIT DROP AS
WITH nuevo AS (
 INSERT INTO public.ingreso(codigo_transportista,cuit_bodega)
 SELECT transportista,bodega_ingreso FROM h5_param RETURNING codigo_ingreso
) SELECT * FROM nuevo;
INSERT INTO public.renglon_ingreso(codigo_ingreso,cod_vino,cantidad)
SELECT i.codigo_ingreso,p.vino_ingreso,120 FROM h5_ingreso i CROSS JOIN h5_param p RETURNING *;
DO $$ BEGIN
 IF EXISTS (SELECT FROM public.ingreso i JOIN h5_ingreso n USING(codigo_ingreso)
 WHERE i.estado<>'en_confeccion') THEN RAISE EXCEPTION 'I6: estado incorrecto'; END IF;
 IF EXISTS ((SELECT s.* FROM public.stock_deposito s JOIN h5_param p ON s.cod_vino=p.vino_ingreso
 EXCEPT SELECT * FROM h5_stock_antes) UNION ALL
 (SELECT * FROM h5_stock_antes EXCEPT SELECT s.* FROM public.stock_deposito s JOIN h5_param p ON s.cod_vino=p.vino_ingreso))
 THEN RAISE EXCEPTION 'I6: un ingreso en confeccion no debe mover stock'; END IF;
END $$;
SELECT i.* FROM public.ingreso i JOIN h5_ingreso n USING(codigo_ingreso);
SELECT 'despues' AS momento,s.* FROM public.stock_deposito s JOIN h5_param p ON s.cod_vino=p.vino_ingreso;
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK TO SAVEPOINT i6;
ROLLBACK;
\echo '=== I1-I6 finalizadas sin errores; datos revertidos ==='
