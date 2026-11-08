// Integra rutinas locales con 002/006/007 publicados por Vale, sólo en memoria.
import {PGlite} from '@electric-sql/pglite';
import {readFileSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('../../',import.meta.url));
const vale='657ec99c3b38b58d98865e514716850059a5aca5';
const local=p=>readFileSync(root+p,'utf8').replace(/^\uFEFF/,'');
const remoto=p=>execFileSync('git',['show',vale+':database/migrations/'+p],{cwd:root,encoding:'utf8'}).replace(/^\uFEFF/,'');
const db=new PGlite();
const scalar=async sql=>(await db.query(sql)).rows[0].valor;
async function falla(sql,code){
  await db.exec('SAVEPOINT error_esperado');
  try { await assert.rejects(db.exec(sql),e=>e.code===code); }
  finally { await db.exec('ROLLBACK TO SAVEPOINT error_esperado; RELEASE SAVEPOINT error_esperado'); }
}
try {
  await db.exec(local('database/migrations/001_esquema.sql'));
  await db.exec(remoto('002_constraints.sql'));
  await db.exec(local('database/migrations/003_funciones.sql'));
  await db.exec(local('database/migrations/004_procedimientos.sql'));
  await db.exec(local('database/migrations/005_triggers.sql'));
  await db.exec(local('database/tests/santiago_tests.sql').replace(/ROLLBACK;\s*$/,'COMMIT;'));
  await db.exec(remoto('006_vistas.sql'));
  await db.exec(remoto('007_roles.sql'));
  console.log('Roles publicados de Vale: '+vale);
  await db.exec('BEGIN');
  await db.exec(`CREATE ROLE stg_api_prueba LOGIN;
    GRANT rol_operador_ventas TO stg_api_prueba;
    CREATE ROLE stg_sin_permisos NOLOGIN;`);
  for(const nombre of ['sp_terminar_ingreso','sp_terminar_transferencia']) {
    assert.equal(await scalar(`SELECT has_function_privilege('stg_sin_permisos','public.${nombre}(integer)','EXECUTE') AS valor`),false);
    assert.equal(await scalar(`SELECT has_function_privilege('rol_operador_ventas','public.${nombre}(integer)','EXECUTE') AS valor`),false);
  }
  console.log('OK: rutinas nuevas cerradas a PUBLIC y operador antes de integración');
  // Propuesta para Vale, no modificación de 007: propiedad y EXECUTE en la prueba.
  await db.exec(`ALTER PROCEDURE public.sp_terminar_ingreso(INTEGER) OWNER TO rol_propietario_procedimientos;
    ALTER PROCEDURE public.sp_terminar_transferencia(INTEGER) OWNER TO rol_propietario_procedimientos;
    GRANT EXECUTE ON PROCEDURE public.sp_terminar_ingreso(INTEGER), public.sp_terminar_transferencia(INTEGER) TO rol_operador_ventas;
    SET SESSION AUTHORIZATION stg_api_prueba;`);
  await falla('UPDATE public.stock_sala SET cantidad=0','42501');
  await falla('UPDATE public.stock_deposito SET cantidad=0','42501');
  await falla("UPDATE public.ingreso SET estado='terminado' WHERE codigo_ingreso=-901",'42501');
  await falla("UPDATE public.transferencia SET estado='terminado' WHERE numero_solicitud=-901",'42501');
  await db.exec(`INSERT INTO public.ingreso(codigo_ingreso,codigo_transportista,cuit_bodega) OVERRIDING SYSTEM VALUE
    VALUES (-920,-901,'99000000001'),(-921,-901,'99000000001'),(-922,-901,'99000000002');
    INSERT INTO public.renglon_ingreso VALUES(-920,-901,5),(-922,-901,1);
    INSERT INTO public.transferencia(numero_solicitud,id_sala) OVERRIDING SYSTEM VALUE
    VALUES(-920,-901),(-921,-901),(-922,-901);
    INSERT INTO public.renglon_transferencia VALUES(-920,-901,3),(-922,-901,100);`);
  await falla('CALL public.sp_procesar_ingreso(-920)','23514');
  await falla('CALL public.sp_procesar_transferencia(-920)','23514');
  for(const nombre of ['sp_terminar_ingreso','sp_terminar_transferencia']) {
    await falla(`CALL public.${nombre}(-999999)`,'P0002');
    await falla(`CALL public.${nombre}(NULL)`,'P0002');
    await falla(`CALL public.${nombre}(-921)`,'23514');
    await falla(`CALL public.${nombre}(-901)`,'23514'); // ya procesado
  }
  await falla('CALL public.sp_terminar_ingreso(-922)','23514');
  assert.equal(await scalar("SELECT estado::text AS valor FROM public.ingreso WHERE codigo_ingreso=-922"),'en_confeccion');
  assert.equal(await scalar("SELECT estado::text AS valor FROM public.transferencia WHERE numero_solicitud=-921"),'en_confeccion');
  await db.exec('CALL public.sp_terminar_ingreso(-920)');
  assert.equal(await scalar("SELECT estado::text AS valor FROM public.ingreso WHERE codigo_ingreso=-920"),'terminado');
  assert.equal(await scalar('SELECT count(*)::int AS valor FROM public.stock_deposito WHERE cod_vino=-901'),0);
  await falla('CALL public.sp_terminar_ingreso(-920)','23514');
  await db.exec('CALL public.sp_procesar_ingreso(-920)');
  assert.equal(await scalar('SELECT cantidad AS valor FROM public.stock_deposito WHERE cod_vino=-901'),5);
  await falla('CALL public.sp_procesar_ingreso(-920)','23514');
  await db.exec('CALL public.sp_terminar_transferencia(-920)');
  assert.equal(await scalar('SELECT cantidad AS valor FROM public.stock_deposito WHERE cod_vino=-901'),5);
  assert.equal(await scalar('SELECT count(*)::int AS valor FROM public.stock_sala WHERE cod_vino=-901'),0);
  await falla('CALL public.sp_terminar_transferencia(-920)','23514');
  await db.exec('CALL public.sp_procesar_transferencia(-920)');
  assert.equal(await scalar('SELECT cantidad AS valor FROM public.stock_deposito WHERE cod_vino=-901'),2);
  assert.equal(await scalar('SELECT cantidad AS valor FROM public.stock_sala WHERE id_sala=-901 AND cod_vino=-901'),3);
  await falla('CALL public.sp_procesar_transferencia(-920)','23514');
  // Terminar no reserva stock ni promete disponibilidad futura.
  await db.exec('CALL public.sp_terminar_transferencia(-922)');
  await falla('CALL public.sp_procesar_transferencia(-922)','23514');
  assert.equal(await scalar("SELECT estado::text AS valor FROM public.transferencia WHERE numero_solicitud=-922"),'terminado');
  assert.equal(await scalar('SELECT cantidad AS valor FROM public.stock_deposito WHERE cod_vino=-901'),2);
  await db.exec('RESET SESSION AUTHORIZATION; ROLLBACK');
  assert.equal(await scalar('SELECT count(*)::int AS valor FROM public.ingreso WHERE codigo_ingreso=-920'),0);
  assert.equal(await scalar('SELECT count(*)::int AS valor FROM public.stock_deposito WHERE cod_vino=-901'),0);
  console.log('OK: flujo confección → terminado → procesado como operador restringido');
  console.log('OK: IDs ausentes/nulos, documentos vacíos, bodega incompatible y repeticiones rechazados');
  console.log('OK: terminar no mueve stock; procesar valida disponibilidad; rollback restaura datos');
  console.log('LÍMITE: 005 local básico; no certifica triggers pendientes de Sol ni concurrencia multisesión');
} finally { await db.close(); }
