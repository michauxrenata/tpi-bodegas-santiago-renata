"""Exporta la base H3 a SQL gzip sin pasar binarios por PowerShell."""
import argparse
import gzip
from pathlib import Path
import subprocess
import sys


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--base',required=True)
    p.add_argument('--salida',type=Path,default=Path('dump_completo.sql.gz'))
    a=p.parse_args()
    if not a.base.startswith('bodegas_carga_h3'):
        raise ValueError('Solo se exportan bases bodegas_carga_h3*')
    if a.salida.exists():raise ValueError('El archivo ya existe; use otro nombre')
    a.salida.parent.mkdir(parents=True,exist_ok=True)
    temporal=a.salida.with_name(a.salida.name+'.partial')
    proc=subprocess.Popen(['docker','compose','exec','-T','db','pg_dump','-U','postgres',
        '--no-owner','--no-privileges','--format=plain',a.base],stdout=subprocess.PIPE)
    try:
        with gzip.open(temporal,'wb') as dest:
            while bloque:=proc.stdout.read(1024*1024):dest.write(bloque)
        proc.stdout.close()
        if proc.wait()!=0:raise RuntimeError('pg_dump fallo; no se genero un dump valido')
        temporal.replace(a.salida)
        print('Dump generado:',a.salida.resolve())
    except BaseException:
        if proc.poll() is None:proc.kill()
        proc.wait()
        temporal.unlink(missing_ok=True)
        raise

if __name__=='__main__':
    try:main()
    except Exception as exc:
        print('ERROR:',exc,file=sys.stderr)
        sys.exit(1)
