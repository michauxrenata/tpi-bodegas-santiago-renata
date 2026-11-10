import os
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool


def create_pool():
    # Keyword arguments avoid constructing DSNs with interpolated credentials.
    pool = ConnectionPool(conninfo='', kwargs={
        'host': os.getenv('API_DB_HOST','db'),
        'port': int(os.getenv('API_DB_PORT','5432')),
        'dbname': os.getenv('API_DB_NAME','bodegas_api_h6'),
        'user': os.getenv('API_DB_USER','bodegas_api_h6_login'),
        'password': os.environ['API_DB_PASSWORD'],
        'connect_timeout': 5, 'autocommit': True, 'row_factory': dict_row,
        'options': '-c search_path=pg_catalog,public -c statement_timeout=30000 -c lock_timeout=5000',
    }, min_size=1,max_size=5,timeout=10,open=False)
    pool.open(wait=True,timeout=20)
    try:
        with pool.connection() as conn:
            role = conn.execute('SELECT rolsuper,rolcreatedb,rolcreaterole,rolbypassrls FROM pg_roles WHERE rolname=current_user').fetchone()
            owner = conn.execute("SELECT EXISTS(SELECT FROM pg_tables WHERE schemaname='public' AND tableowner=current_user) AS owns").fetchone()
            if any(role.values()) or owner['owns']:
                raise RuntimeError('La API requiere un usuario sin privilegios administrativos ni tablas propias')
    except Exception:
        pool.close()
        raise
    return pool
