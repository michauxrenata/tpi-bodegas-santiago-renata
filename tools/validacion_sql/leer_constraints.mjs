import {existsSync,readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
// Dependencia del equipo, sin copiar ni modificar la migración de Valentina.
export function leerConstraints(root) {
  const path='database/migrations/002_constraints.sql';
  if(existsSync(root+path)) return {sql:readFileSync(root+path,'utf8').replace(/^\uFEFF/,''),origen:path+' local'};
  const ref='5cf3e0bedec0eac991428cb99526753706633c8e';
  try {
    return {sql:execFileSync('git',['show',ref+':'+path],{cwd:root,encoding:'utf8',stdio:['ignore','pipe','pipe']}).replace(/^\uFEFF/,''),origen:'Valentina '+ref+' (solo en memoria)'};
  } catch {
    throw new Error('Falta 002_constraints.sql. Ejecutá git fetch origin para disponer del commit de Valentina, o integrá su migración antes de probar.');
  }
}
