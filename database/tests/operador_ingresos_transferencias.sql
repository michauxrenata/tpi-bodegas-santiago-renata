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


-- Desde aqui se usan los permisos del operador.
SET LOCAL ROLE rol_operador_ventas;

INSERT INTO public.ingreso
(fecha, codigo_transportista, cuit_bodega)
VALUES (CURRENT_DATE, -950, '99000000001')
RETURNING codigo_ingreso AS ingreso_prueba
\gset

INSERT INTO public.renglon_ingreso
(codigo_ingreso, cod_vino, cantidad)
VALUES (:ingreso_prueba, -950, 5);

CALL public.sp_terminar_ingreso(:ingreso_prueba);
CALL public.sp_procesar_ingreso(:ingreso_prueba);

SELECT cantidad AS deposito_esperado_5
FROM public.stock_deposito
WHERE cod_vino = -950;

INSERT INTO public.transferencia (id_sala)
VALUES (-950)
RETURNING numero_solicitud AS transferencia_prueba
\gset

INSERT INTO public.renglon_transferencia
(numero_solicitud, cod_vino, cantidad)
VALUES (:transferencia_prueba, -950, 3);

CALL public.sp_terminar_transferencia(:transferencia_prueba);
CALL public.sp_procesar_transferencia(:transferencia_prueba);

SELECT cantidad AS deposito_esperado_2
FROM public.stock_deposito
WHERE cod_vino = -950;

SELECT cantidad AS sala_esperado_3
FROM public.stock_sala
WHERE id_sala = -950 AND cod_vino = -950;

-- Validar restricciones pendientes antes de revertir.
SET CONSTRAINTS ALL IMMEDIATE;
ROLLBACK;
