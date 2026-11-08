import {PGlite} from '@electric-sql/pglite';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const db=new PGlite();
await db.exec(readFileSync(root+'database/migrations/001_esquema.sql','utf8'));
await db.exec(readFileSync(root+'database/benchmarks/fixture_sintetico.sql','utf8'));
const sql=readFileSync(root+'database/benchmarks/consultas.sql','utf8').replace(/^\\.*$/gm,'').replaceAll(":'vino'", "'1'");
const out={version:(await db.query('SELECT version()')).rows[0].version,fecha:(await db.query('SELECT CURRENT_DATE::text fecha')).rows[0].fecha,iteraciones:[]};
for(const phase of ['antes','despues']) {
 if(phase==='despues') await db.exec(readFileSync(root+'database/migrations/008_indices.sql','utf8')+'\nANALYZE;');
 await db.exec(sql); // warmup no incluido
 for(let rep=1;rep<=3;rep++) {
   const r=await db.exec(sql);
   out.iteraciones.push({fase:phase,repeticion:rep,planes:r.map(x=>x.rows[0]['QUERY PLAN'][0])});
 }
}
mkdirSync(root+'docs/evidencias',{recursive:true});
writeFileSync(root+'docs/evidencias/planes_embebido.json',JSON.stringify(out,null,2));
console.log(out.iteraciones.map(x=>({fase:x.fase,rep:x.repeticion,ms:x.planes.map(p=>p['Execution Time'])})));
await db.close();
