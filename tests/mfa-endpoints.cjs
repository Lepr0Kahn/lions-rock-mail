const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
async function guard(source){
 const start=source.indexOf('  const callerClient ='),end=source.indexOf('  let body:',start);assert.ok(start>0&&end>start);
 assert.ok(end<source.indexOf('const upsert')||!source.includes('const upsert'));
 const code=source.slice(start,end).replace(/\)!/g,')');let result={data:{allowed:false}},calls=0;
 const context={Deno:{env:{get:()=> 'fixture'}},authHeader:'Bearer fixture',h:{},json:(body,status)=>({body,status}),createClient:(url,key,options)=>{assert.equal(options.global.headers.Authorization,'Bearer fixture');return{rpc:async name=>{assert.equal(name,'owner_mfa_status');calls++;return result;}}}};
 vm.createContext(context);const run=vm.runInContext('(async()=>{'+code+'return {status:200};})',context);
 assert.equal((await run()).status,403);result={error:{message:'unavailable'}};assert.equal((await run()).status,403);result={data:{allowed:true}};assert.equal((await run()).status,200);assert.equal(calls,3);
}
(async()=>{for(const slug of ['studio-create-invite','studio-claim-invite'])await guard(fs.readFileSync(require('node:path').join(__dirname,'../supabase/functions',slug,'index.ts'),'utf8'));console.log('Both endpoint guards deny blocked/error status and allow permitted callers using caller token');})().catch(e=>{console.error(e);process.exit(1)});
