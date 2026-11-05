// All key creation runs on the server. No license or provider token is public.
const PUBLIC_ORIGIN = 'https://featherhub-keys-i38bcl7sxej.qoder.website';
const COOKIE = 'fh_session';
const MAX_BODY = 4096;
const SESSION_MS = 30 * 60 * 1000;
const KEY_MS = 24 * 60 * 60 * 1000;
const PUBLIC_KEY = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA1piHDY9WRIehbfC3FpolLy/WrJF8TKFVdDMobj3fkNjN/69dTv9JgXt+gcJxVn/h4NCMtQ2mCQXNBMXzLOkyHJipiFMoyPtOOlMlbWRAiaQE1GpMebGNRcsxYnWzF53v63+hUQgrMahH9X0Ii/NJhvDyFlPX77+z9xiyd45L+xrgayePpOxvQpj6VJDlpNNKWbuIkFvkMmUVRM2TLulLJSgs4EgoBZgTYRpmhgR8tYfDOW+cOctffggcMAzKUC2CzYNmhzX15O7DKaZdYgfaBR/hqvyNAxBepHOJnBfHkQqaox5diHGqdwXXLwiJKzoK5R26vaI3jg2+d69VPSGL0QIDAQAB';
const encoder = new TextEncoder();
const hex = bytes => Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, '0')).join('');
const sha = async text => hex(await crypto.subtle.digest('SHA-256', encoder.encode(text)));
const validHex = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const uuid = value => typeof value === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(value);
const randomToken = () => hex(crypto.getRandomValues(new Uint8Array(32)));
const keyFor = async (ticket, sessionId) => 'FEATHER-' + (await sha('FeatherHub:key:v1:' + ticket + ':' + sessionId)).toUpperCase();

async function dynamicLink(publisher, destination) {
  // Mirrors the official v2 generator's RSA-OAEP/SHA-256 prefix encoding.
  const points = [...decodeURI(destination)];
  const prefix = [];
  while (points.length) {
    prefix.push(...encoder.encode(points.shift()));
    if (prefix.length > 66) break;
  }
  const spki = Uint8Array.from(atob(PUBLIC_KEY), c => c.charCodeAt(0));
  const key = await crypto.subtle.importKey('spki', spki, {name:'RSA-OAEP',hash:'SHA-256'}, false, ['encrypt']);
  const encrypted = await crypto.subtle.encrypt({name:'RSA-OAEP'}, key, new Uint8Array(prefix));
  const payload = btoa(String.fromCharCode(...new Uint8Array(encrypted))) + points.join('');
  const url = new URL('https://link-to.net/' + publisher + '/' + crypto.getRandomValues(new Uint32Array(1))[0] + '/dynamic/');
  url.searchParams.set('r', payload);
  url.searchParams.set('v', '2');
  return url.href;
}

export function application({db, readSecret, fetcher = fetch, clock = () => Date.now()}) {
  const fail = (code, status = 503) => { const error = new Error(code); error.publicCode=code; error.httpStatus=status; throw error; };
  const json = (data, status = 200, headers = {}) => Response.json(data, {status, headers:{'Cache-Control':'no-store','X-Content-Type-Options':'nosniff',...headers}});
  const rows = result => {
    if (!result || result.error || !Array.isArray(result.data)) fail('service_unavailable');
    return result.data;
  };
  const configured = () => {
    const token=readSecret('LINKVERTISE_TOKEN');
    const publisher=readSecret('LINKVERTISE_PUBLISHER_ID');
    if (typeof token!=='string' || token.length!==64 || typeof publisher!=='string' || !/^[1-9][0-9]{0,14}$/.test(publisher)) fail('service_not_configured');
    return {token,publisher};
  };
  async function input(request) {
    if (request.headers.get('content-type')?.split(';')[0].trim().toLowerCase()!=='application/json') fail('invalid_input',400);
    const reader=request.body?.getReader();
    if (!reader) fail('invalid_input',400);
    let size=0; const chunks=[];
    try {
      while(true) {
        const {done,value}=await reader.read(); if(done)break;
        size+=value.byteLength;
        if(size>MAX_BODY) { await reader.cancel(); fail('payload_too_large',413); }
        chunks.push(value);
      }
    } finally { reader.releaseLock(); }
    const bytes=new Uint8Array(size);let offset=0;
    for(const part of chunks){bytes.set(part,offset);offset+=part.length;}
    let value;
    try { value=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes)); } catch { fail('invalid_input',400); }
    if (!value || typeof value!=='object' || Array.isArray(value)) fail('invalid_input',400);
    return value;
  }
  async function limit(id, maximum, expiresAt) {
    const inserted=rows(await db.from('key_limits').insertIfAbsent({id,count:1,expires_at:expiresAt},{onConflict:'id'}).select('id,count'));
    if(inserted.length) return;
    const found=rows(await db.from('key_limits').select('id,count').eq('id',id).limit(1));
    if(!found.length || !Number.isSafeInteger(found[0].count)) fail('service_unavailable');
    const count=found[0].count;
    if(count>=maximum) fail('rate_limited',429);
    const updated=rows(await db.from('key_limits').update({count:count+1}).eq('id',id).eq('count',count).select('id,count'));
    // A lost write is never automatically replayed. A CAS race can be retried by the caller.
    if(updated.length!==1) fail('rate_limited',429);
  }
  async function session(request) {
    const cookies=(request.headers.get('cookie')||'').split(';').map(v=>v.trim());
    const values=cookies.filter(v=>v.startsWith(COOKIE+'=')).map(v=>v.slice(COOKIE.length+1));
    if(values.length!==1 || !validHex(values[0])) return null;
    const ticket=values[0];
    const found=rows(await db.from('key_sessions').select('id,ticket_hash,device_hash,expires_at').eq('ticket_hash',await sha(ticket)).limit(1));
    if(!found.length) return null;
    return {...found[0],ticket};
  }
  async function issued(current) {
    const found=rows(await db.from('issued_keys').select('id,session_id,key_hash,device_hash,expires_at,revoked').eq('session_id',current.id).eq('device_hash',current.device_hash).limit(1));
    return found[0]||null;
  }
  function validTime(value) { const time=Date.parse(value); if(!Number.isFinite(time)) fail('service_unavailable'); return time; }
  async function keyResult(current, license) {
    if(license.revoked!==false || validTime(license.expires_at)<=clock()) fail('session_expired',410);
    const key=await keyFor(current.ticket,current.id);
    if(await sha(key)!==license.key_hash) fail('service_unavailable');
    return json({ok:true,stage:'issued',key,expiresAt:license.expires_at});
  }
  async function receipt(token, proof) {
    const url=new URL('https://publisher.linkvertise.com/api/v1/anti_bypassing');
    url.searchParams.set('token',token); url.searchParams.set('hash',proof);
    let response;
    try { response=await fetcher(url.href,{method:'POST',cache:'no-store',redirect:'error',signal:AbortSignal.timeout(6000)}); }
    catch { fail('service_unavailable'); }
    if(!response.ok || !response.body) fail('service_unavailable');
    const reader=response.body.getReader();const pieces=[];let size=0;
    try {
      while(true) {
        const {done,value}=await reader.read();if(done)break;
        size+=value.length;if(size>256){await reader.cancel();fail('service_unavailable');}pieces.push(value);
      }
    } finally { reader.releaseLock(); }
    const bytes=new Uint8Array(size);let offset=0;for(const p of pieces){bytes.set(p,offset);offset+=p.length;}
    const text=new TextDecoder().decode(bytes).trim();
    // Official specification documents textual TRUE/FALSE, not a JSON envelope.
    if(text==='TRUE') return;
    if(text==='FALSE') fail('checkpoint_rejected',403);
    if(text==='Invalid token.' || text==='"Invalid token."') fail('service_not_configured');
    fail('service_unavailable');
  }
  return async context => {
    try {
      const request=context.request;
      const match=new URL(request.url).pathname.match(/^\/(?:functions\/v1\/)?(?:app|app-d[0-9a-f]{32})(\/.*)?$/);
      if(!match) fail('not_found',404);
      const path=match[1]||'/';
      const methods={'/health':'GET','/state':'GET','/ticket':'POST','/resume':'POST','/complete':'POST','/verify':'POST'};
      if(!methods[path]) fail('not_found',404);
      if(request.method!==methods[path]) return json({ok:false,error:'method_not_allowed'},405,{Allow:methods[path]});
      const origin=request.headers.get('origin');
      if(request.method==='POST' && origin && origin!==PUBLIC_ORIGIN) fail('origin_rejected',403);
      if(path==='/health') {
        let ready=true;try{configured();}catch{ready=false;}
        return json({ok:true,configured:ready,provider:'linkvertise',keyLifetimeHours:24});
      }
      const {token,publisher}=configured();
      if(path==='/ticket') {
        const body=await input(request);
        if(typeof body.hwid!=='string'||body.hwid.length<20||body.hwid.length>512||/[\x00-\x1f\x7f]/.test(body.hwid)) fail('invalid_input',400);
        const deviceHash=await sha(body.hwid);
        const hour=Math.floor(clock()/3600000), ends=new Date((hour+1)*3600000).toISOString();
        await limit('tickets:global:'+hour,1200,ends);
        await limit('tickets:'+deviceHash+':'+hour,6,ends);
        const ticket=randomToken(), id=crypto.randomUUID();
        const created=rows(await db.from('key_sessions').insert({id,ticket_hash:await sha(ticket),device_hash:deviceHash,created_at:new Date(clock()).toISOString(),expires_at:new Date(clock()+SESSION_MS).toISOString()}).select('id'));
        if(created.length!==1) fail('service_unavailable');
        return json({ok:true,url:PUBLIC_ORIGIN+'/#ticket='+ticket},201);
      }
      if(path==='/verify') {
        const body=await input(request);
        if(typeof body.key!=='string'||!/^FEATHER-[A-F0-9]{64}$/.test(body.key)||typeof body.hwid!=='string'||body.hwid.length<20||body.hwid.length>512||/[\x00-\x1f\x7f]/.test(body.hwid)) fail('invalid_input',400);
        const minute=Math.floor(clock()/60000),ends=new Date((minute+1)*60000).toISOString();
        await limit('verify:global:'+minute,2400,ends);
        const found=rows(await db.from('issued_keys').select('key_hash,device_hash,expires_at,revoked').eq('key_hash',await sha(body.key)).limit(1));
        const license=found[0];
        const valid=!!license && license.revoked===false && license.device_hash===await sha(body.hwid) && validTime(license.expires_at)>clock();
        return json({ok:true,valid,expiresAt:valid?license.expires_at:null});
      }
      if(path==='/resume') {
        const body=await input(request);if(!validHex(body.ticket)) fail('invalid_input',400);
        const found=rows(await db.from('key_sessions').select('id,device_hash,expires_at').eq('ticket_hash',await sha(body.ticket)).limit(1));
        if(!found.length) fail('session_expired',410);
        const recovered={...found[0],ticket:body.ticket};
        const license=await issued(recovered);
        let cookieUntil;
        if(license) {
          await keyResult(recovered,license);
          cookieUntil=validTime(license.expires_at);
        } else {
          const sessionUntil=validTime(recovered.expires_at);
          if(sessionUntil<=clock()) fail('session_expired',410);
          // Cover a key issued just before the checkpoint session expires.
          cookieUntil=sessionUntil+KEY_MS;
        }
        const maxAge=Math.max(1,Math.ceil((cookieUntil-clock())/1000));
        return json({ok:true},200,{'Set-Cookie':COOKIE+'='+body.ticket+'; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age='+maxAge});
      }
      const current=await session(request);
      if(!current) {
        if(path==='/state') return json({ok:true,stage:'none'});
        fail('session_required',401);
      }
      let proof;
      if(path==='/complete') {
        const body=await input(request);
        if(typeof body.callback!=='string'||body.callback.length>1024||!uuid(body.state)||body.state!==current.id) fail('checkpoint_rejected',403);
        const hashes=new URLSearchParams(body.callback).getAll('hash');
        if(hashes.length!==1||!validHex(hashes[0])) fail('checkpoint_rejected',403);
        proof=hashes[0];
      }
      const existing=await issued(current);
      if(existing) return await keyResult(current,existing);
      if(validTime(current.expires_at)<=clock()) fail('session_expired',410);
      if(path==='/state') {
        const checkpointUrl=await dynamicLink(publisher,PUBLIC_ORIGIN+'/return/'+current.id);
        return json({ok:true,stage:'pending',checkpointUrl});
      }
      await receipt(token,proof);
      const key=await keyFor(current.ticket,current.id);
      const license={id:crypto.randomUUID(),session_id:current.id,proof_hash:await sha(proof),key_hash:await sha(key),device_hash:current.device_hash,created_at:new Date(clock()).toISOString(),expires_at:new Date(clock()+KEY_MS).toISOString(),revoked:false};
      const inserted=await db.from('issued_keys').insertIfAbsent(license,{onConflict:'session_id'}).select('id');
      if(inserted?.error?.code==='23505') fail('proof_reused',403);
      rows(inserted);
      // The unique session_id makes recovery deterministic after a lost insert response.
      const saved=await issued(current);
      if(!saved) fail('service_unavailable');
      return await keyResult(current,saved);
    } catch(error) {
      return json({ok:false,error:error?.publicCode||'service_unavailable'},error?.httpStatus||503);
    }
  };
}
