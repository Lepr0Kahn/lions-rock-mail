const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');

async function verify(source) {
  let session = null, listener;
  const timers = [], elements = new Map();
  const element = id => {
    if (!elements.has(id)) elements.set(id, {innerHTML:'',textContent:'',classList:{toggle(){}},querySelectorAll(){return []}});
    return elements.get(id);
  };
  const sb = {
    auth: {
      getSession: async () => ({data:{session}}),
      onAuthStateChange: cb => { listener = cb; return {data:{subscription:{unsubscribe(){}}}}; }
    },
    from: () => ({select(){return this},eq(){return this},
      maybeSingle: async () => ({data:{role:'owner',access_status:'active'}}),
      order: async () => ({data:[{role:'member',access_status:'active',business_tools_enabled:true,artist_member_enabled:false}]})
    })
  };
  const context = {window:{supabase:{createClient:()=>sb}},document:{getElementById:element,querySelectorAll:()=>[]},setTimeout:fn=>timers.push(fn)};
  vm.runInNewContext(source.match(/<script>\s*([\s\S]*?)<\/script>/)[1], context);
  const settle = async () => { for(let i=0;i<12;i++){while(timers.length)timers.shift()();await Promise.resolve();} };
  await settle();
  assert.match(element('content').innerHTML, /Sign in to Lions Rock Studio first/);
  session = {user:{id:'test-owner'}};
  if(listener)listener('SIGNED_IN',session);
  await settle();
  assert.match(element('content').innerHTML,/Create Private Invite Link/,'Admin must load after parent sign-in');
  assert.equal(element('s-active').textContent,1);
  session = null;
  listener('SIGNED_OUT',null);
  await settle();
  assert.match(element('content').innerHTML,/Sign in to Lions Rock Studio first/,'Admin must close after sign-out');
}

(async()=>{
  const fixed = fs.readFileSync('studio-admin.html','utf8');
  const original = fixed.replace(' // Recheck access when the parent signs in or out. Keep queries outside the Auth callback.\n sb.auth.onAuthStateChange(()=>setTimeout(load,0));\n','');
  let caught = false;
  try { await verify(original); } catch(e) { caught=true; console.log('Original: reproduced stale Admin panel after sign-in.'); }
  assert.ok(caught,'Regression check must fail on original');
  await verify(fixed);
  console.log('Fixed: sign-in loads Admin; sign-out closes Admin. PASS');
})().catch(e=>{console.error(e);process.exitCode=1;});
