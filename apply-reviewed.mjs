import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
assert.equal(process.env.GITHUB_ACTIONS,'true');
assert.equal(process.platform,'linux');
assert.equal(execFileSync('calcit',['-v'],{encoding:'utf8'}).trim(),'0.30.1');
const run=(...a)=>execFileSync('calcit',['calcit.cirru',...a],{encoding:'utf8',maxBuffer:32e6});
const norm=v=>Array.isArray(v)?v.map(norm):v&&typeof v==='object'?Object.fromEntries(Object.entries(v).map(([k,x])=>[k,k==='__edn_set'?x.map(norm).sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b))):norm(x)])):v;
const q=(...a)=>norm(JSON.parse(run('query',...a,'--format','json')).data);
const blob=()=>execFileSync('git',['hash-object','calcit.cirru'],{encoding:'utf8'}).trim();
const input=norm(JSON.parse(readFileSync('reviewed.json','utf8')));
assert.equal(input.snapshotBlob,'bec95ba66ab8a34f639bcedd7274d3bdf5a8a625');
assert.equal(blob(),input.snapshotBlob);
const before=input.before,expected=structuredClone(before),sites=[],counts={List:0,String:0};
assert.equal(before.defs.length,134);assert.equal(before.namespaces.length,6);
assert.equal(before.defs.reduce((n,d)=>n+d.tests.length,0),1);
assert.deepEqual(q('config'),before.config);
assert.deepEqual(q('ns').namespaces.map(ns=>q('ns',ns)),before.namespaces);
for(const d of before.defs)assert.deepEqual(q('def',d.id),d);
const receivers={
  'app.comp.container/call-genai-msg-v2!':{messages1:'List','function-calls':'List'},
  'app.comp.container/comp-container':{sessions:'List',messages:'List'},
  'app.comp.container/create-session':{'first-msg':'String'},
  'app.comp.container/handle-chapter-tool-call':{'sorted-keys':'List'},
  'app.comp.container/submit-message!':{'sorted-keys':'List'},
  'app.comp.container/upsert-assistant-message':{messages:'List'},
};
function walk(node,path,id){
  if(!Array.isArray(node)||['quote','quasiquote',';','comment','defmacro'].includes(node[0]))return;
  if(node[0]==='count'){
    assert.equal(node.length,2);
    const kind=receivers[id]?.[node[1]];assert.ok(kind);
    assert.deepEqual(JSON.parse(run('tree','show',id,'--path','@'+path.join('.'),'--format','json')).tree,node);
    sites.push({id,path:'@'+[...path,0].join('.'),before:'count',after:'.len',receiver:node[1],kind});
    node[0]='.len';counts[kind]++;
  }
  for(let i=0;i<node.length;i++)walk(node[i],[...path,i],id);
}
for(const d of expected.defs)walk(d.code,[],d.id);
assert.deepEqual(counts,{List:11,String:2});assert.equal(sites.length,13);
assert.deepEqual(sites,input.sites);assert.deepEqual(expected,input.expected);
const methods={};
for(const[name,type]of [['String',"'String"],['List',":: 'List 'String"]]){
  const method=q('type',type).methods.find(m=>m.name==='.len');
  assert.equal(method.status,'proven');
  assert.equal(method.definition,name==='String'?'calcit.core/&str:count':'calcit.core/&list:count');
  methods[name]=method;
}
const ops=sites.map(s=>['tree','replace',s.id,'--path',s.path,'--input-format','json-ast','--code',JSON.stringify(s.after)]);
mkdirSync('acceptance',{recursive:true});
for(const[name,value]of Object.entries({before,expected,sites,counts,methods,operations:ops}))writeFileSync('acceptance/'+name+'.json',JSON.stringify(value,null,2));
const txn=['edit','transaction','--file','acceptance/operations.json','--format','json'];
const preview=JSON.parse(run(...txn,'--dry-run'));assert.ok(preview.scoped_revision);
writeFileSync('acceptance/preview.json',JSON.stringify(preview,null,2));
writeFileSync('acceptance/applied.json',run(...txn,'--expect-revision',preview.scoped_revision));
const after={config:q('config'),namespaces:q('ns').namespaces.map(ns=>q('ns',ns)),defs:before.defs.map(d=>q('def',d.id))};
assert.deepEqual(after,expected);
writeFileSync('acceptance/after.json',JSON.stringify(after,null,2));
writeFileSync('acceptance/snapshot-after-blob.txt',blob());
