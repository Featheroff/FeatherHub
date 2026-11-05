// Credential-free fixtures only. These tests do not prove live Linkvertise or DB behavior.
import test from 'node:test';
import assert from 'node:assert/strict';
import { application } from '../functions/routes.mjs';

class MemoryDatabase {
  tables = {key_sessions:[],issued_keys:[],key_limits:[]};
  loseNextKeyInsert = false;
  failNextKeyInsert = false;
  from(name) {
    const database=this;
    return new class {
      filters=[];fields=null;maximum=Infinity;operation='read';record=null;conflict=null;
      select(fields){this.fields=fields.split(',');return this;}
      eq(field,value){this.filters.push([field,value]);return this;}
      limit(value){this.maximum=value;return this;}
      insert(value){this.operation='insert';this.record=value;return this;}
      insertIfAbsent(value,options){this.operation='insert';this.record=value;this.conflict=options.onConflict;return this;}
      update(value){this.operation='update';this.record=value;return this;}
      then(resolve,reject){return Promise.resolve().then(()=>this.execute()).then(resolve,reject);}
      execute(){
        let table=database.tables[name];if(!table) return {data:null,error:{code:'missing_table'}};
        let selected=[];
        if(this.operation==='insert') {
          if(name==='issued_keys'&&database.failNextKeyInsert){database.failNextKeyInsert=false;return {data:null,error:{code:'fixture_precommit_failure'}};}
          if(this.conflict && table.some(row=>row[this.conflict]===this.record[this.conflict])) return {data:[],error:null};
          const unique={key_sessions:['id','ticket_hash'],issued_keys:['id','session_id','proof_hash','key_hash'],key_limits:['id']}[name];
          if(unique.some(field=>table.some(row=>row[field]===this.record[field]))) return {data:null,error:{code:'23505'}};
          const saved=structuredClone(this.record);table.push(saved);selected=[saved];
          if(name==='issued_keys'&&database.loseNextKeyInsert){database.loseNextKeyInsert=false;throw new Error('fixture response lost after committed insert');}
        } else {
          selected=table.filter(row=>this.filters.every(([field,value])=>row[field]===value)).slice(0,this.maximum);
          if(this.operation==='update') for(const row of selected) Object.assign(row,this.record);
        }
        return {data:selected.map(row=>Object.fromEntries(this.fields.map(field=>[field,row[field]]))),error:null};
      }
    };
  }
}
const ORIGIN='https://featherhub-keys-i38bcl7sxej.qoder.website';
const hwid='fixture-device-identifier-AAAAAAAAAAAA';
function fixture() {
  const db=new MemoryDatabase();let now=Date.now();let count=0;const used=new Set();let format='text';
  const handle=application({db,clock:()=>now,readSecret:name=>name==='LINKVERTISE_TOKEN'?'a'.repeat(64):'123456',fetcher:async(url,options)=>{
    count++;const parsed=new URL(url);
    assert.equal(parsed.origin,'https://publisher.linkvertise.com');assert.equal(parsed.pathname,'/api/v1/anti_bypassing');assert.equal(options.method,'POST');
    assert.equal(parsed.searchParams.get('token'),'a'.repeat(64));
    const proof=parsed.searchParams.get('hash');
    if(format==='json') return new Response('{"status":true}');
    if(used.has(proof)) return new Response('FALSE');used.add(proof);return new Response('TRUE');
  }});
  async function request(path,body,cookie='',method=body===undefined?'GET':'POST') {
    const response=await handle({request:new Request(ORIGIN+'/functions/v1/app'+path,{method,headers:{...(body===undefined?{}:{'Content-Type':'application/json'}),...(cookie?{Cookie:cookie}:{}),Origin:ORIGIN},body:body===undefined?undefined:JSON.stringify(body)})});
    return {response,data:await response.json()};
  }
  async function begin(device=hwid) {
    const {data}=await request('/ticket',{hwid:device});assert.equal(data.ok,true);
    const ticket=new URLSearchParams(new URL(data.url).hash.slice(1)).get('ticket');
    const resumed=await request('/resume',{ticket});assert.equal(resumed.data.ok,true);
    const cookie=resumed.response.headers.get('set-cookie').split(';')[0];
    const sessionId=db.tables.key_sessions.at(-1).id;
    return {cookie,ticket,id:sessionId};
  }
  return {db,request,begin,used,calls:()=>count,advance:ms=>now+=ms,setFormat:value=>format=value};
}

test('primary flow: no key before a receipt, unique server key, device binding, expiry',async()=>{
  const f=fixture();const session=await f.begin();
  const pending=await f.request('/state',undefined,session.cookie);
  assert.equal(pending.data.stage,'pending');
  const link=new URL(pending.data.checkpointUrl);assert.equal(link.hostname,'link-to.net');assert.equal(link.searchParams.get('v'),'2');
  const destination=ORIGIN+'/return/'+session.id;
  const payload=link.searchParams.get('r');
  // Official v2 encrypts the first 67 ASCII bytes into 256 RSA bytes (344 base64 characters).
  assert.equal(Buffer.from(payload.slice(0,344),'base64').length,256);
  assert.equal(payload.slice(344),destination.slice(67));
  const denied=await f.request('/complete',{state:session.id,callback:''},session.cookie);
  assert.equal(denied.response.status,403);assert.equal(f.calls(),0);assert.equal(f.db.tables.issued_keys.length,0);
  const completed=await f.request('/complete',{state:session.id,callback:'?hash='+'b'.repeat(64)},session.cookie);
  assert.equal(completed.data.stage,'issued');assert.match(completed.data.key,/^FEATHER-[A-F0-9]{64}$/);assert.equal(f.calls(),1);
  const repeat=await f.request('/complete',{state:session.id,callback:'?hash='+'b'.repeat(64)},session.cookie);
  assert.equal(repeat.data.key,completed.data.key);assert.equal(f.calls(),1);assert.equal(f.db.tables.issued_keys.length,1);
  const verified=await f.request('/verify',{hwid,key:completed.data.key});assert.equal(verified.data.valid,true);
  const wrong=await f.request('/verify',{hwid:hwid+'OTHER',key:completed.data.key});assert.equal(wrong.data.valid,false);
  const text=JSON.stringify(f.db.tables);assert.ok(!text.includes(completed.data.key));assert.ok(!text.includes(hwid));assert.ok(!text.includes(session.ticket));
  f.advance(60*60*1000);const recovered=await f.request('/state',undefined,session.cookie);assert.equal(recovered.data.key,completed.data.key);
  f.advance(24*60*60*1000);const expired=await f.request('/verify',{hwid,key:completed.data.key});assert.equal(expired.data.valid,false);
});
test('wrong session, duplicate receipt and unexpected provider response never issue a key',async()=>{
  const f=fixture();const first=await f.begin();
  const mismatch=await f.request('/complete',{state:crypto.randomUUID(),callback:'?hash='+'b'.repeat(64)},first.cookie);
  assert.equal(mismatch.response.status,403);assert.equal(f.calls(),0);
  await f.request('/complete',{state:first.id,callback:'?hash='+'b'.repeat(64)},first.cookie);
  const second=await f.begin();
  const reused=await f.request('/complete',{state:second.id,callback:'?hash='+'b'.repeat(64)},second.cookie);
  assert.equal(reused.response.status,403);assert.equal(f.db.tables.issued_keys.length,1);
  f.setFormat('json');
  const unexpected=await f.request('/complete',{state:second.id,callback:'?hash='+'c'.repeat(64)},second.cookie);
  assert.equal(unexpected.response.status,503);assert.equal(f.db.tables.issued_keys.length,1);
});
test('lost issuance response recovers same key without replaying provider verification',async()=>{
  const f=fixture();const session=await f.begin();f.db.loseNextKeyInsert=true;
  const first=await f.request('/complete',{state:session.id,callback:'?hash='+'d'.repeat(64)},session.cookie);
  assert.equal(first.response.status,503);assert.equal(f.db.tables.issued_keys.length,1);
  const recovered=await f.request('/complete',{state:session.id,callback:'?hash='+'d'.repeat(64)},session.cookie);
  assert.equal(recovered.data.stage,'issued');assert.equal(f.calls(),1);assert.equal(f.db.tables.issued_keys.length,1);
});
test('method, input, expired session, absent secrets and ticket rate limits fail closed',async()=>{
  const f=fixture();
  assert.equal((await f.request('/ticket')).response.status,405);
  assert.equal((await f.request('/ticket',{hwid:'short'})).response.status,400);
  assert.equal((await f.request('/unknown')).response.status,404);
  const session=await f.begin();f.advance(31*60*1000);
  assert.equal((await f.request('/state',undefined,session.cookie)).response.status,410);
  const limited=fixture();for(let i=0;i<6;i++) await limited.begin();
  assert.equal((await limited.request('/ticket',{hwid})).response.status,429);
  assert.equal(limited.db.tables.key_sessions.length,6);
  const empty=application({db:new MemoryDatabase(),readSecret:()=>undefined});
  const denied=await empty({request:new Request(ORIGIN+'/functions/v1/app/ticket',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({hwid})})});
  assert.equal(denied.status,503);assert.equal((await denied.json()).error,'service_not_configured');
});
test('ticket recovery and cookie lifetime cover a late-issued active key',async()=>{
  const f=fixture();const session=await f.begin();
  const pendingResume=await f.request('/resume',{ticket:session.ticket});
  const pendingMaxAge=Number(pendingResume.response.headers.get('set-cookie').match(/Max-Age=(\d+)/)[1]);
  assert.equal(pendingMaxAge,24*60*60+30*60);
  f.advance(25*60*1000);
  const completed=await f.request('/complete',{state:session.id,callback:'?hash='+'e'.repeat(64)},session.cookie);
  assert.equal(completed.data.stage,'issued');
  f.advance(60*60*1000);
  const reopened=await f.request('/resume',{ticket:session.ticket});
  assert.equal(reopened.response.status,200);
  assert.equal(Number(reopened.response.headers.get('set-cookie').match(/Max-Age=(\d+)/)[1]),23*60*60);
  const recovered=await f.request('/state',undefined,reopened.response.headers.get('set-cookie').split(';')[0]);
  assert.equal(recovered.data.key,completed.data.key);
  f.advance(24*60*60*1000);
  assert.equal((await f.request('/resume',{ticket:session.ticket})).response.status,410);
});
test('issued-session recovery still validates JSON size, state and receipt shape',async()=>{
  const f=fixture();const session=await f.begin();
  await f.request('/complete',{state:session.id,callback:'?hash='+'f'.repeat(64)},session.cookie);
  assert.equal((await f.request('/complete',undefined,session.cookie,'POST')).response.status,400);
  assert.equal((await f.request('/complete',{state:session.id,callback:'x'.repeat(5000)},session.cookie)).response.status,413);
  assert.equal((await f.request('/complete',{state:crypto.randomUUID(),callback:'?hash='+'f'.repeat(64)},session.cookie)).response.status,403);
  assert.equal((await f.request('/complete',{state:session.id,callback:'?hash='+'f'.repeat(64)+'&hash='+'f'.repeat(64)},session.cookie)).response.status,403);
  assert.equal(f.calls(),1);
});
test('precommit database failure never fabricates a key or reuses consumed proof',async()=>{
  const f=fixture();const session=await f.begin();f.db.failNextKeyInsert=true;
  const first=await f.request('/complete',{state:session.id,callback:'?hash='+'1'.repeat(64)},session.cookie);
  assert.equal(first.response.status,503);assert.equal(f.db.tables.issued_keys.length,0);
  const retry=await f.request('/complete',{state:session.id,callback:'?hash='+'1'.repeat(64)},session.cookie);
  assert.equal(retry.response.status,403);assert.equal(f.db.tables.issued_keys.length,0);
  // Cross-service atomicity is unavailable: a fresh completion is required here.
  const fresh=await f.request('/complete',{state:session.id,callback:'?hash='+'2'.repeat(64)},session.cookie);
  assert.equal(fresh.data.stage,'issued');assert.equal(f.db.tables.issued_keys.length,1);
});
test('database rejects repeated receipt even if provider erroneously repeats success',async()=>{
  const f=fixture();const first=await f.begin();const proof='3'.repeat(64);
  await f.request('/complete',{state:first.id,callback:'?hash='+proof},first.cookie);
  f.used.delete(proof); // Defensive fault fixture, not documented provider behavior.
  const second=await f.begin();
  const duplicate=await f.request('/complete',{state:second.id,callback:'?hash='+proof},second.cookie);
  assert.equal(duplicate.response.status,403);assert.equal(duplicate.data.error,'proof_reused');
  assert.equal(f.db.tables.issued_keys.length,1);
});
test('concurrent ticket requests cannot bypass conditional counter limits',async()=>{
  const f=fixture();await f.begin();
  const responses=await Promise.all(Array.from({length:12},()=>f.request('/ticket',{hwid})));
  assert.ok(responses.every(({response})=>[201,429].includes(response.status)));
  assert.ok(responses.some(({response})=>response.status===429));
  assert.ok(f.db.tables.key_sessions.length<=6);
  const deviceCounter=f.db.tables.key_limits.find(row=>row.id.startsWith('tickets:')&&!row.id.startsWith('tickets:global:'));
  assert.ok(deviceCounter.count<=6);
});
