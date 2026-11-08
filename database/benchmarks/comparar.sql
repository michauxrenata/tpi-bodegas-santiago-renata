-- SOLO copia local de evaluación: bloquea tablas y elimina temporalmente índices
-- propios; ROLLBACK restaura al final. No modifica PK/UNIQUE ni fuerza el planner.
-- Ejecutar psql -X -v vino=<codigo> -f database/benchmarks/comparar.sql > planes.txt
\set ON_ERROR_STOP on
BEGIN;
DROP INDEX IF EXISTS idx_comprobante_sala_fecha, idx_transferencia_pendientes,
    idx_renglon_comprobante_vino, idx_comprobante_fecha_incl, idx_transferencia_fecha_sala;
ANALYZE;
\echo ANTES
\ir consultas.sql
\ir ../migrations/008_indices.sql
ANALYZE;
\echo DESPUES
\ir consultas.sql
ROLLBACK;
