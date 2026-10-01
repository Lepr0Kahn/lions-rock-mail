const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const html=fs.readFileSync(process.argv[2]||'studio.html','utf8');
const start=html.indexOf('if(e.data.type==="lions-rock-vault-invoice"){');
const end=html.indexOf('if(e.data.type==="lions-rock-booking-invoice"){',start);
assert.ok(start>0&&end>start,'Current vault handler missing');
const body=html.slice(start,end);
async function check(mode){
const frame={},doc={id:'lease-doc',user_id:'owner',doc_type:'invoice',doc_number:'INV-0042',currency:'BBD',total:150,amount_paid:0,client_id:null,client_name:'Artist',client_email:'artist@example.com',notes:'Nonexclusive terms',updated_at:'2026-10-01T21:30:00Z'};
let posted,queries=0,errors=0;const ctx={member:{contentWindow:frame},currentSession:{user:{id:'owner'}},currentMembership:{role:mode==='business'?'member':'owner',access_status:'active'},canBusiness:m=>m.access_status==='active',activate:(...args)=>posted=args,toast:()=>errors++};
ctx.sb={from(table){const filters={};const chain={select(){return chain},eq(k,v){filters[k]=v;return chain},single(){assert.equal(filters.user_id,'owner');assert.equal(filters.id,'lease-doc');queries++;if(mode==='suspend_doc')ctx.currentMembership.access_status='suspended';return Promise.resolve({data:doc,error:mode==='error'?new Error('Unavailable'):null});},order(){assert.equal(filters.document_id,'lease-doc');assert.equal(filters.user_id,'owner');queries++;if(mode==='switch_items')ctx.currentSession={user:{id:'different-owner'}};return Promise.resolve({data:[{name:'Instrumental lease',description:'Licence terms',qty:1,unit_price:150}],error:null});}};return chain;}};
vm.createContext(ctx);const run=vm.runInContext('(async function(e){'+body+'})',ctx);
await run({source:mode==='wrong_frame'?{}:frame,data:{type:'lions-rock-vault-invoice',documentId:'lease-doc'}});
if(mode==='valid'){assert.equal(queries,2);assert.equal(posted[0],'documents');assert.equal(posted[1],'generator');const p=posted[2];assert.equal(p.document.doc_number,'INV-0042');assert.equal(p.document.type,'invoice');assert.equal(p.document.total,150);assert.equal(p.document.items[0].price,150);assert.equal(p.document.items[0].desc,'Licence terms');assert.equal(p.client.email,'artist@example.com');assert.equal(p.document.payment_status,'due');}
else{assert.equal(posted,undefined,mode+' forwarded private invoice');if(['wrong_frame','business'].includes(mode))assert.equal(queries,0);if(mode==='error')assert.equal(errors,1);}
}
(async()=>{for(const mode of ['valid','wrong_frame','business','suspend_doc','switch_items','error'])await check(mode);console.log('PASS current-source vault invoice handoff, recipient/number/items, frame boundary, non-Owner denial, suspension/account-switch races and query error');})().catch(e=>{console.error(e);process.exitCode=1});
