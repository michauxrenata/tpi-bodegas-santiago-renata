import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';

export async function probarDescuentos(db,root) {
  const all=readFileSync(root+'consultas/update.sql','utf8');
  // Ejecuta el mismo UPDATE que se entrega, no una copia de su implementación.
  const u6=all.slice(all.indexOf('-- U6:')).replace(/^BEGIN;\s*$/gm,'').replace(/^ROLLBACK;\s*$/gm,'');
  const u1=all.slice(all.indexOf('-- U1:'),all.indexOf('-- U2:')).replace(/^BEGIN;\s*$/gm,'').replace(/^ROLLBACK;\s*$/gm,'');
  const rows=async sql=>(await db.query(sql)).rows;
  const tasa=async id=>Number((await rows(`SELECT public.fn_descuento_cliente(${id}) AS tasa`))[0].tasa);
  const historia=async()=>({
    cabecera:await rows('SELECT * FROM comprobante WHERE numero_comprobante=-903'),
    renglones:await rows('SELECT * FROM renglon_comprobante WHERE numero_comprobante=-903 ORDER BY cod_vino')
  });
  const antes=await historia();
  await db.exec('BEGIN');
  try {
    // No suplanta el trigger de Sol: asigna explícitamente datos válidos al fixture.
    await db.exec(`
      INSERT INTO cliente(id_cliente,nombre_razon_social,tipo_doc,nro_doc,direccion,localidad,tipo_cliente,descuento)
      OVERRIDING SYSTEM VALUE VALUES
      (-910,'Exportador sin permisos','TEST','STG10','Prueba','Prueba','exportador',.30),
      (-911,'Exportador tres permisos','TEST','STG11','Prueba','Prueba','exportador',.30),
      (-912,'Exportador ya bonificado','TEST','STG12','Prueba','Prueba','exportador',.35);
      INSERT INTO cliente_exportador VALUES (-910,'Chile'),(-911,'Chile'),(-912,'Chile');
      INSERT INTO permiso_exportacion
      SELECT 'U6-'||i, -911, DATE '2020-01-01', DATE '2021-01-01' FROM generate_series(1,3) i;
      INSERT INTO permiso_exportacion
      SELECT 'U6-YA-'||i, -912, DATE '2020-01-01', DATE '2021-01-01' FROM generate_series(1,4) i;
    `);
    assert.equal(await tasa(-901),.10);
    assert.equal(await tasa(-902),.20);
    assert.equal(await tasa(-903),.30);
    assert.equal(await tasa(-912),.35);
    const r=(await db.exec(u6)).flatMap(x=>x.rows);
    assert.deepEqual(r.map(x=>x.id_cliente),[-903]);
    assert.equal(await tasa(-903),.35);
    assert.equal(await tasa(-910),.30);
    assert.equal(await tasa(-911),.30);
    assert.equal(await tasa(-901),.10);
    assert.equal(await tasa(-902),.20);
    assert.equal(await tasa(-912),.35);
    assert.equal(Number((await rows('SELECT fn_calcular_descuento_cliente(-903,10000) AS neto'))[0].neto),6500);
    assert.equal(Number((await rows('SELECT fn_calcular_descuento_cliente(-903,0.05) AS neto'))[0].neto),.03);
    assert.deepEqual(await historia(),antes);
    assert.equal(Number((await rows('SELECT fn_total_comprobante(-903) AS total'))[0].total),520);
    assert.equal((await db.exec(u6)).flatMap(x=>x.rows).length,0);
    // Elimina elegibilidad: el descuento vigente no se revoca automáticamente.
    await db.exec("DELETE FROM permiso_exportacion WHERE cod_permiso='STG-P4'");
    await db.exec(u6);
    assert.equal(await tasa(-903),.35);
    // U1 es el ejercicio explícito de recálculo: conserva precios históricos.
    await db.exec('SAVEPOINT recalculo; UPDATE vino SET precio=precio*2');
    await db.exec(u1);
    assert.equal(Number((await rows('SELECT total FROM comprobante WHERE numero_comprobante=-903'))[0].total),520);
    assert.equal(Number((await rows('SELECT SUM(descuento) AS descuento FROM renglon_comprobante WHERE numero_comprobante=-903'))[0].descuento),280);
    await db.exec('ROLLBACK TO SAVEPOINT recalculo');
    // El helper mantiene el error documentado para un ID inexistente.
    await db.exec('SAVEPOINT ausente');
    await assert.rejects(db.query('SELECT fn_descuento_cliente(-999999)'),e=>e.code==='P0002');
    await db.exec('ROLLBACK TO SAVEPOINT ausente');
  } finally {
    await db.exec('ROLLBACK');
  }
  assert.equal(await tasa(-903),.30);
  assert.equal((await rows('SELECT * FROM cliente WHERE id_cliente IN (-910,-911,-912)')).length,0);
  assert.deepEqual(await historia(),antes);
}
