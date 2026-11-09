// Prueba aislada de procedimientos y permisos con migraciones locales.
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const root = fileURLToPath(new URL('../../', import.meta.url));
const local = ruta =>
  readFileSync(root + ruta, 'utf8').replace(/^\uFEFF/, '');

const db = new PGlite();

async function scalar(sql) {
  return (await db.query(sql)).rows[0].valor;
}

async function falla(sql, codigo) {
  await db.exec('SAVEPOINT error_esperado');
  try {
    await assert.rejects(db.exec(sql), error => error.code === codigo);
  } finally {
    await db.exec(
      'ROLLBACK TO SAVEPOINT error_esperado; RELEASE SAVEPOINT error_esperado'
    );
  }
}

try {
  const migraciones = [
    '001_esquema.sql',
    '002_constraints.sql',
    '003_funciones.sql',
    '004_procedimientos.sql',
    '005_triggers.sql',
    '006_vistas.sql',
    '007_roles.sql',
    '008_indices.sql'
  ];

  for (const archivo of migraciones) {
    await db.exec(local('database/migrations/' + archivo));
  }
  console.log('OK: migraciones locales 001-008');

  const fixture = local('database/tests/santiago_tests.sql');
  assert.match(fixture, /SET CONSTRAINTS ALL IMMEDIATE;/);
  assert.match(fixture, /ROLLBACK;\s*$/);

  // Conservar los datos solo en esta instancia temporal de PGlite.
  await db.exec(fixture.replace(/ROLLBACK;\s*$/, 'COMMIT;'));

  await db.exec(`
    BEGIN;
    CREATE ROLE stg_api_prueba LOGIN;
    GRANT rol_operador_ventas TO stg_api_prueba;
    CREATE ROLE stg_sin_permisos NOLOGIN;
  `);

  const procedimientos = [
    'sp_terminar_ingreso',
    'sp_procesar_ingreso',
    'sp_terminar_transferencia',
    'sp_procesar_transferencia'
  ];

  for (const nombre of procedimientos) {
    assert.equal(await scalar(`
      SELECT has_function_privilege(
        'stg_sin_permisos', 'public.${nombre}(integer)', 'EXECUTE'
      ) AS valor
    `), false);

    assert.equal(await scalar(`
      SELECT has_function_privilege(
        'rol_operador_ventas', 'public.${nombre}(integer)', 'EXECUTE'
      ) AS valor
    `), true);

    assert.equal(await scalar(`
      SELECT p.prosecdef
        AND pg_get_userbyid(p.proowner) = 'rol_propietario_procedimientos'
        AND 'search_path=pg_catalog, pg_temp' = ANY(p.proconfig)
        AS valor
      FROM pg_proc AS p
      WHERE p.oid = 'public.${nombre}(integer)'::regprocedure
    `), true);
  }

  console.log('OK: propiedad, SECURITY DEFINER, search_path y EXECUTE');

  await db.exec('SET SESSION AUTHORIZATION stg_api_prueba');

  await falla('UPDATE public.stock_sala SET cantidad=0', '42501');
  await falla('UPDATE public.stock_deposito SET cantidad=0', '42501');
  await falla(
    "UPDATE public.ingreso SET estado='terminado' WHERE codigo_ingreso=-901",
    '42501'
  );
  await falla(
    "UPDATE public.transferencia SET estado='terminado' WHERE numero_solicitud=-901",
    '42501'
  );

  // La API utiliza identidades generadas, sin escribir las claves.
  const ingreso = await scalar(`
    INSERT INTO public.ingreso (codigo_transportista, cuit_bodega)
    VALUES (-901, '99000000001')
    RETURNING codigo_ingreso AS valor
  `);
  const vacio = await scalar(`
    INSERT INTO public.ingreso (codigo_transportista, cuit_bodega)
    VALUES (-901, '99000000001')
    RETURNING codigo_ingreso AS valor
  `);
  const incompatible = await scalar(`
    INSERT INTO public.ingreso (codigo_transportista, cuit_bodega)
    VALUES (-901, '99000000002')
    RETURNING codigo_ingreso AS valor
  `);
  const transferencia = await scalar(`
    INSERT INTO public.transferencia (id_sala)
    VALUES (-901)
    RETURNING numero_solicitud AS valor
  `);
  const transferenciaVacia = await scalar(`
    INSERT INTO public.transferencia (id_sala)
    VALUES (-901)
    RETURNING numero_solicitud AS valor
  `);
  const sinStock = await scalar(`
    INSERT INTO public.transferencia (id_sala)
    VALUES (-901)
    RETURNING numero_solicitud AS valor
  `);

  await db.exec(`
    INSERT INTO public.renglon_ingreso VALUES
      (${ingreso}, -901, 5), (${incompatible}, -901, 1);
    INSERT INTO public.renglon_transferencia VALUES
      (${transferencia}, -901, 3), (${sinStock}, -901, 100);
  `);

  for (const nombre of procedimientos) {
    await falla(`CALL public.${nombre}(-999999)`, 'P0002');
    await falla(`CALL public.${nombre}(NULL)`, 'P0002');
    await falla(`CALL public.${nombre}(-901)`, '23514');
  }

  await falla(`CALL public.sp_terminar_ingreso(${vacio})`, '23514');
  await falla(
    `CALL public.sp_terminar_transferencia(${transferenciaVacia})`,
    '23514'
  );
  await falla(
    `CALL public.sp_terminar_ingreso(${incompatible})`,
    '23514'
  );
  await falla(`CALL public.sp_procesar_ingreso(${ingreso})`, '23514');
  await falla(
    `CALL public.sp_procesar_transferencia(${transferencia})`,
    '23514'
  );

  await db.exec(`CALL public.sp_terminar_ingreso(${ingreso})`);
  assert.equal(await scalar(`
    SELECT estado::text AS valor FROM public.ingreso
    WHERE codigo_ingreso=${ingreso}
  `), 'terminado');
  assert.equal(await scalar(`
    SELECT count(*)::int AS valor FROM public.stock_deposito
    WHERE cod_vino=-901
  `), 0);

  await falla(`CALL public.sp_terminar_ingreso(${ingreso})`, '23514');
  await db.exec(`CALL public.sp_procesar_ingreso(${ingreso})`);
  assert.equal(await scalar(`
    SELECT cantidad AS valor FROM public.stock_deposito WHERE cod_vino=-901
  `), 5);
  await falla(`CALL public.sp_procesar_ingreso(${ingreso})`, '23514');

  await db.exec(`CALL public.sp_terminar_transferencia(${transferencia})`);
  assert.equal(await scalar(`
    SELECT cantidad AS valor FROM public.stock_deposito WHERE cod_vino=-901
  `), 5);
  assert.equal(await scalar(`
    SELECT count(*)::int AS valor FROM public.stock_sala
    WHERE id_sala=-901 AND cod_vino=-901
  `), 0);

  await falla(
    `CALL public.sp_terminar_transferencia(${transferencia})`,
    '23514'
  );
  await db.exec(`CALL public.sp_procesar_transferencia(${transferencia})`);
  assert.equal(await scalar(`
    SELECT cantidad AS valor FROM public.stock_deposito WHERE cod_vino=-901
  `), 2);
  assert.equal(await scalar(`
    SELECT cantidad AS valor FROM public.stock_sala
    WHERE id_sala=-901 AND cod_vino=-901
  `), 3);
  await falla(
    `CALL public.sp_procesar_transferencia(${transferencia})`,
    '23514'
  );

  // Terminar no reserva stock: procesar vuelve a comprobarlo.
  await db.exec(`CALL public.sp_terminar_transferencia(${sinStock})`);
  await falla(
    `CALL public.sp_procesar_transferencia(${sinStock})`,
    '23514'
  );
  assert.equal(await scalar(`
    SELECT estado::text AS valor FROM public.transferencia
    WHERE numero_solicitud=${sinStock}
  `), 'terminado');
  assert.equal(await scalar(`
    SELECT cantidad AS valor FROM public.stock_deposito WHERE cod_vino=-901
  `), 2);

  await db.exec(`
    SET CONSTRAINTS ALL IMMEDIATE;
    RESET SESSION AUTHORIZATION;
    ROLLBACK;
  `);

  assert.equal(await scalar(`
    SELECT count(*)::int AS valor FROM public.ingreso
    WHERE codigo_ingreso=${ingreso}
  `), 0);
  assert.equal(await scalar(`
    SELECT count(*)::int AS valor FROM public.stock_deposito
    WHERE cod_vino=-901
  `), 0);

  console.log('OK: operador sin UPDATE directo de stock ni estados');
  console.log('OK: flujo confeccion -> terminado -> procesado');
  console.log('OK: IDs ausentes/nulos, documentos vacios y bodega incompatible');
  console.log('OK: repeticiones y stock insuficiente rechazados');
  console.log('OK: terminar no mueve stock; rollback revierte los movimientos');
  console.log('ALCANCE: prueba embebida; concurrencia multisesion se prueba en PostgreSQL.');
} finally {
  await db.close();
}