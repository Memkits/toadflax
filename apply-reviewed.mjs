import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
assert.equal(process.env.GITHUB_ACTIONS,'true');assert.equal(process.platform,'linux');
const run=(...a)=>execFileSync('calcit',['calcit.cirru',...a],{encoding:'utf8',maxBuffer:48e6,stdio:['ignore','pipe','pipe']});
assert.equal(execFileSync('calcit',['-v'],{encoding:'utf8'}).trim(),'0.30.1');
const blob=()=>execFileSync('git',['hash-object','calcit.cirru'],{encoding:'utf8'}).trim();
assert.equal(blob(),'6351a220bf1838e34c8164ea7ca4cc62b72b8f3a');
const norm=v=>Array.isArray(v)?v.map(norm):v&&typeof v==='object'?Object.fromEntries(Object.entries(v).map(([k,x])=>[k,k==='__edn_set'?x.map(norm).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b))):norm(x)])):v;
const q=(...a)=>norm(JSON.parse(run('query',...a,'--format','json')).data);
const input=JSON.parse(readFileSync('reviewed.json','utf8'));
const before={config:norm(input.config.data),namespaces:input.namespaces.map(x=>norm(x.data)),defs:input.definitions.map(x=>norm(x.data))};
assert.equal(before.defs.length,134);assert.equal(before.defs.reduce((n,d)=>n+d.tests.length,0),1);assert.equal(before.defs.reduce((n,d)=>n+d.examples.length,0),0);
assert.deepEqual(q('config'),before.config);assert.deepEqual(q('ns').namespaces.map(n=>q('ns',n)),before.namespaces);
for(const d of before.defs)assert.deepEqual(q('def',d.id),d);
const expected=structuredClone(before),ops=[],sites=[];
const aliases={'option:unwrap':'.unwrap','option:unwrap-or':'.unwrap-or','option:fold':'.fold','merge':'.merge'};
const codeCounts={'option:unwrap':0,'option:unwrap-or':0,'option:fold':0,merge:0},testCounts={'option:unwrap':0,'option:unwrap-or':0,'option:fold':0,merge:0};
const show=(id,path)=>JSON.parse(run('tree','show',id,'--path','@'+path.join('.'),'--format','json')).tree;
function walk(x,path,id,counts,attached=false){
  if(!Array.isArray(x)||['quote','quasiquote','comment',';','defmacro'].includes(x[0]))return;
  if(Object.hasOwn(aliases,x[0])){
    const old=x[0];
    if(!attached){assert.deepEqual(show(id,path),x);ops.push(['tree','replace',id,'--path','@'+[...path,0].join('.'),'--input-format','json-ast','--code',JSON.stringify(aliases[old]),'--expect','quote '+old]);}
    sites.push({id,path,attached,original:structuredClone(x),replacement:aliases[old]});x[0]=aliases[old];counts[old]++;
  }
  x.forEach((v,i)=>walk(v,[...path,i],id,counts,attached));
}
for(const d of expected.defs)walk(d.code,[],d.id,codeCounts);
assert.deepEqual(codeCounts,{'option:unwrap':20,'option:unwrap-or':22,'option:fold':23,merge:10});
const normalizer=expected.defs.find(d=>d.id==='app.schema/normalize-store');
assert.equal(normalizer.tests.length,1);const test=normalizer.tests[0];
assert.equal(test.name,'legacy-map-struct-roundtrip');assert.deepEqual(test.tags,['regression','storage']);
walk(test.code,[],normalizer.id,testCounts,true);
assert.deepEqual(testCounts,{'option:unwrap':3,'option:unwrap-or':0,'option:fold':0,merge:0});
ops.push(['edit','add-test',normalizer.id,test.name,'--overwrite','--tags',test.tags.join(','),'--input-format','json-ast','--code',JSON.stringify(test.code)]);
// The existing public tool result deliberately uses nil for an absent neighbor.
// Match exposes that nil/map union without forcing fold's single return slot
// from its first callback; keep both wire values and lazy branch evaluation.
const handler=expected.defs.find(d=>d.id==='app.comp.container/handle-chapter-tool-call');
for(const [index,receiver] of [[1,'previous'],[2,'next']]){
  const path=[4,1,3,1,3,2,index,1];
  const original=path.reduce((x,i)=>x[i],before.defs.find(d=>d.id===handler.id).code);
  assert.deepEqual(show(handler.id,path),original);
  const parent=path.slice(0,-1).reduce((x,i)=>x[i],handler.code),old=parent[path.at(-1)];
  assert.equal(old[0],'.fold');assert.equal(old[1],receiver);
  assert.deepEqual(old[2],['fn',[],'nil']);assert.deepEqual(old[3][1],['chapter']);
  const replacement=['match',receiver,[[":none"],'nil'],[[":some",'chapter'],old[3][2]]];
  parent[path.at(-1)]=replacement;
  ops.push(['tree','replace',handler.id,'--path','@'+path.join('.'),'--input-format','json-ast','--code',JSON.stringify(replacement)]);
}
const main=expected.defs.find(d=>d.id==='app.main/main!'),oldMain=before.defs.find(d=>d.id===main.id);
assert.deepEqual(show(main.id,[11]),oldMain.code[11]);assert.deepEqual(show(main.id,[5]),['render-app!']);
assert.equal(main.code[11][0],'match');assert.equal(main.code[11][1][0],'browser/storage-get');assert.equal(main.code[11][2][1][0],'dispatch!');
const restore=main.code.splice(11,1)[0];main.code.splice(5,0,restore);
ops.push(['tree','delete',main.id,'--path','@11']);
ops.push(['tree','insert',main.id,'--path','@5','--at','before','--input-format','json-ast','--code',JSON.stringify(restore),'--expect','quote $ render-app!']);
assert.equal(ops.length,80);
mkdirSync('acceptance',{recursive:true});
for(const [name,value] of Object.entries({before,expected,sites,operations:ops}))writeFileSync('acceptance/'+name+'.json',JSON.stringify(value,null,2));
const args=['edit','transaction','--file','acceptance/operations.json','--format','json'];
const preview=JSON.parse(run(...args,'--dry-run'));assert.ok(preview.scoped_revision);
writeFileSync('acceptance/preview.json',JSON.stringify(preview,null,2));writeFileSync('acceptance/applied.json',run(...args,'--expect-revision',preview.scoped_revision));
const after={config:q('config'),namespaces:q('ns').namespaces.map(n=>q('ns',n)),defs:before.defs.map(d=>q('def',d.id))};
assert.deepEqual(after,expected);
for(const id of ['app.main/reload!','app.main/persist-storage!'])assert.deepEqual(after.defs.find(d=>d.id===id),before.defs.find(d=>d.id===id));
assert.equal(after.defs.length,134);
writeFileSync('acceptance/after.json',JSON.stringify(after,null,2));writeFileSync('acceptance/snapshot-after-blob.txt',blob());
writeFileSync('acceptance/summary.json',JSON.stringify({definitions:134,attachedTests:1,examples:0,operations:80,codeCounts,testCounts,neighborResults:'Two nil/map fold expressions use explicit Option match; original nil and map wire values preserved',preserved:'All other code/schema/FFI/imports/config/tags/doc and original attached assertions/name/tags/input/expected, actual HUD/reload and persist format, all SDK/model/proxy/paid-service behavior unchanged; no new helper/test/cast/budget',startup:'restore now occurs before first render and before persistence/watch/devtools/input registrations'},null,2));
