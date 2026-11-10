"""Instala H6 una sola vez en una base isolada bodegas_api_h6*."""
import os
from pathlib import Path
import psycopg
from psycopg import sql
admin_db=os.environ['POSTGRES_DB']; name=os.getenv('API_DB_NAME','bodegas_api_h6')
user=os.getenv('API_DB_USER','bodegas_api_h6_login'); password=os.environ['API_DB_PASSWORD']
if not name.startswith('bodegas_api_h6'):
    raise SystemExit('Por seguridad, API_DB_NAME debe empezar con bodegas_api_h6')
admin=dict(host=os.getenv('API_DB_HOST','db'),port=int(os.getenv('API_DB_PORT','5432')),
 user=os.environ['POSTGRES_USER'],password=os.environ['POSTGRES_PASSWORD'])
with psycopg.connect(dbname=admin_db,**admin,autocommit=True) as c:
    fresh=not c.execute('SELECT 1 FROM pg_database WHERE datname=%s',(name,)).fetchone()
    if fresh: c.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
    if not c.execute("SELECT 1 FROM pg_roles WHERE rolname='rol_api_catalogos'").fetchone():
        c.execute('CREATE ROLE rol_api_catalogos NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS')
    if c.execute('SELECT 1 FROM pg_roles WHERE rolname=%s',(user,)).fetchone():
        c.execute(sql.SQL('ALTER ROLE {} WITH LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD {}').format(sql.Identifier(user),sql.Literal(password)))
    else:
        c.execute(sql.SQL('CREATE ROLE {} LOGIN INHERIT NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD {}').format(sql.Identifier(user),sql.Literal(password)))
    c.execute(sql.SQL('GRANT CONNECT ON DATABASE {} TO {}').format(sql.Identifier(name),sql.Identifier(user)))
    c.execute(sql.SQL('GRANT rol_operador_ventas,rol_api_catalogos TO {}').format(sql.Identifier(user)))
if fresh:
    with psycopg.connect(dbname=name,**admin,autocommit=True) as c:
        for path in sorted(Path('/srv/migrations').glob('*.sql')):
            if path.name=='004_datos_prueba.sql': continue
            c.execute(path.read_text(encoding='utf-8'),prepare=False)
        c.execute('CREATE TABLE public.api_schema_version(version integer PRIMARY KEY, installed_at timestamptz NOT NULL DEFAULT now())')
        c.execute('INSERT INTO public.api_schema_version(version) VALUES(1)')
else:
    with psycopg.connect(dbname=name,**admin) as c:
        marker=c.execute("SELECT to_regclass('public.api_schema_version') AS marker").fetchone()[0]
        if marker is None or c.execute('SELECT 1 FROM public.api_schema_version WHERE version=1').fetchone() is None:
            raise SystemExit('La base H6 ya existe pero no tiene version completa; no se modifica automaticamente.')
print(f'API H6 preparada en {name}; migraciones instaladas={fresh}.')
