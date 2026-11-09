-- Suite de integracion H2.
-- Ejecutar en una base de pruebas con las migraciones 001-008 instaladas.
-- Cada archivo administra su transaccion y revierte sus datos.
-- Los errores detienen la ejecucion.

\set ON_ERROR_STOP on

\echo '=== Funciones y procedimientos ==='
\ir ../database/tests/santiago_tests.sql

\echo '=== Descuentos base ==='
\ir ../database/tests/descuento_base_cliente.sql

\echo '=== Composicion de vinos ==='
\ir ../database/tests/composicion_vino.sql

\echo '=== Ingresos y transferencias como operador ==='
\ir ../database/tests/operador_ingresos_transferencias.sql

\echo '=== Proteccion de renglones de transferencias ==='
\ir ../database/tests/proteccion_renglones_transferencia.sql

\echo '=== Ventas como operador ==='
\ir ../database/tests/ventas_operador.sql

\echo '=== Importes historicos ==='
\ir ../database/tests/ventas_historial.sql

\echo '=== Depuracion administrativa de ingresos ==='
\ir ../database/tests/depuracion_ingresos.sql

\echo '=== Proteccion de cabeceras ==='
\ir ../database/tests/proteccion_cabeceras.sql

\echo '=== Reglas basicas y auditoria ==='
\ir ../database/tests/reglas_basicas.sql

\echo '=== Jerarquia de clientes ==='
\ir ../database/tests/subtipos_cliente.sql

\echo '=== Suite finalizada sin errores ==='
