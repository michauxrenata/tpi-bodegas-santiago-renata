// Diagnóstico reproducible de versiones publicadas. No modifica archivos del equipo.
import {PGlite} from '@electric-sql/pglite';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../../',import.meta.url));
const vale='5cf3e0bedec0eac991428cb99526753706633c8e';
const sol='ede9c69ad62cdb1df9ba30158965a815fd58469f';
const remoto=(ref,path)=>execFileSync('git',['show',ref+':'+path],{cwd:root,encoding:'utf8'}).replace(/^\uFEFF/,'');
const local=path=>readFileSync(root+path,'utf8').replace(/^\uFEFF/,'');
const db=new PGlite();
let bloqueos=0;
try {
  for(const sql of [local('database/migrations/001_esquema.sql'),remoto(vale,'database/migrations/002_constraints.sql'),local('database/migrations/003_funciones.sql'),local('database/migrations/004_procedimientos.sql')]) await db.exec(sql);
  console.log('Versiones: Vale '+vale+'; Sol '+sol);
  await db.exec('BEGIN');
  try {
    await db.exec(remoto(sol,'database/migrations/005_triggers.sql'));
    console.log('OK instalación de triggers de Sol');
  } catch(e) {
    bloqueos++;
    console.log('BLOQUEO triggers de Sol: '+e.code+' '+e.message);
  } finally { await db.exec('ROLLBACK'); }
  // Roles separados del fallo de instalación de triggers, sin sustituir estos.
  await db.exec(remoto(vale,'database/migrations/006_vistas.sql'));
  await db.exec(remoto(vale,'database/migrations/007_roles.sql'));
  await db.exec(`
    INSERT INTO bodega VALUES ('99000000001','Integración','Prueba');
    INSERT INTO transportista(codigo_transportista,razon_social,cuit,email,telefono,domicilio) OVERRIDING SYSTEM VALUE
    VALUES (-901,'Prueba','99000000003','integracion@example.invalid','0','Prueba');
    INSERT INTO ingreso(codigo_ingreso,codigo_transportista,cuit_bodega) OVERRIDING SYSTEM VALUE
    VALUES (-901,-901,'99000000001');
    CREATE ROLE prueba_api LOGIN;
    GRANT rol_operador_ventas TO prueba_api;
    SET SESSION AUTHORIZATION prueba_api;
  `);
  await assert.rejects(db.exec('UPDATE public.stock_sala SET cantidad=0'),e=>e.code==='42501');
  console.log('OK: API no puede escribir stock_sala directamente');
  try { await db.exec('CALL public.sp_procesar_ingreso(-901)'); }
  catch(e) { bloqueos++; console.log('BLOQUEO CALL API con 007 actual: '+e.code+' '+e.message); }
  try { await db.exec("UPDATE public.ingreso SET estado='terminado' WHERE codigo_ingreso=-901"); }
  catch(e) { bloqueos++; console.log('BLOQUEO transición a terminado: '+e.code+' '+e.message); }
  console.log('No se certifica integración. Bloqueos reproducidos: '+bloqueos);
} finally { await db.close(); }
process.exitCode=bloqueos?1:0;
