-- Sólo base VACÍA de pruebas. No aplicar a una base con datos existentes.
\set ON_ERROR_STOP on
BEGIN;
\ir migrations/001_esquema.sql
-- Integrar antes database/migrations/002_constraints.sql desde la rama de Valentina.
\ir migrations/002_constraints.sql
\ir migrations/003_funciones.sql
\ir migrations/004_procedimientos.sql
\ir migrations/005_triggers.sql
\ir migrations/008_indices.sql
COMMIT;
