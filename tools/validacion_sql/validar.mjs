import {PGlite} from '@electric-sql/pglite';
import {readFileSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {leerConstraints} from './leer_constraints.mjs';
import {probarDescuentos} from './descuentos.mjs';
const root=fileURLToPath(new URL('../../',import.meta.url));
const db=new PGlite();
const files=['001_esquema.sql','003_funciones.sql','004_procedimientos.sql','005_triggers.sql','008_indices.sql'];
let log=[];
log.push(JSON.stringify((await db.query('SELECT version()')).rows));
for(const f of files){
if(f==='003_funciones.sql'){const dep=leerConstraints(root); await db.exec(dep.sql); log.push('OK constraints: '+dep.origen);}
await db.exec(readFileSync(root+'database/migrations/'+f,'utf8').replace(/^\uFEFF/,''));log.push('OK migration '+f)}
await db.exec(readFileSync(root+'database/tests/santiago_tests.sql','utf8'));log.push('OK pruebas funcionales y rollback');
const strip=s=>s.replace(/^\\.*$/gm,'').replaceAll(":'vino'", "'-903'").replaceAll(":'bodega'", "'99000000001'");
// Conservar fixture en esta instancia aislada para comprobar consultas.
let fixture=readFileSync(root+'database/tests/santiago_tests.sql','utf8').replace(/ROLLBACK;\s*$/,'COMMIT;');
await db.exec(fixture);
await db.exec(readFileSync(root+'database/tests/consultas_fixture.sql','utf8'));
const results=await db.exec(strip(readFileSync(root+'consultas/select_avanzadas.sql','utf8')));
if(results.length!==6 || results[0].rows[0].stock_total!==10) throw Error('S9 results');
assert.equal(results[1].rows.length,3);
assert.equal(Number(results[1].rows[0].promedio_finca),150);
assert.equal(results[1].rows[0].bajo_promedio,true);
assert.equal(results[1].rows[1].bajo_promedio,false);
assert.equal(Number(results[1].rows[2].promedio_finca),1000);
assert.equal(results[2].rows[0].cod_vino,-902);
assert.equal(Number(results[2].rows[0].botellas),4);
assert.equal(Number(results[2].rows[0].puesto),1);
assert.equal(Number(results[3].rows[1].ventas_acumuladas),880);
assert.deepEqual(results[4].rows.map(r=>r.id_cliente),[-903]);
assert.deepEqual(results[5].rows.map(r=>r.id_cliente),[-902]);
log.push('OK S9–S12: stock sin fanout, promedio por campaña, ranking, acumulado, división y anti-join');
const updates=await db.exec(strip(readFileSync(root+'consultas/update.sql','utf8')));
const changed=updates.filter(r=>r.rows?.length);
assert.equal(changed.length,6);
assert.deepEqual(changed[5].rows.map(r=>r.id_cliente),[-903]);
assert.equal(Number(changed[5].rows[0].descuento),.35);
assert.equal(Number(changed[0].rows.find(r=>r.numero_comprobante===-903).total),560);
assert.equal(changed[1].rows.length,1);
assert.equal(changed[1].rows[0].cuit.trim(),'99000000012');
assert.equal(Number(changed[1].rows[0].salario),1200);
assert.equal(changed[2].rows.length,3);
assert.equal(Number(changed[2].rows.find(r=>r.cod_vino===-903).precio),113);
assert.equal(changed[3].rows[0].dia_cierre,'miércoles');
assert.equal(changed[4].rows.length,3);
assert.equal(Number(changed[4].rows.find(r=>r.cod_vino===-903).precio),85);
assert.equal(Number((await db.query('SELECT precio FROM vino WHERE cod_vino=-903')).rows[0].precio),100);
assert.equal(Number((await db.query('SELECT fn_descuento_cliente(-903) tasa')).rows[0].tasa),.30);
log.push('OK U1–U6: importes, frontera de antigüedad, precios, día de cierre y rollback');

await probarDescuentos(db,root);
log.push('OK descuentos: 0/3/4 permisos, 35 %, idempotencia, persistencia, historia, recálculo explícito y rollback');
console.log(log.join('\n'));
await db.close();
