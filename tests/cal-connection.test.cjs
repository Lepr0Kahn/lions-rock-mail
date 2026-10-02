const vm=require("node:vm"),assert=require("node:assert/strict"),fs=require("node:fs");
const source=fs.readFileSync("supabase/functions/studio-cal-connection/index.ts","utf8").split("\n").slice(1).join("\n");
async function run(mode){
let handler,calls=0;
const member={role:"owner",access_status:"active",business_tools_enabled:true,artist_member_enabled:true,payment_status:"comped"};
const sb={auth:{getUser:async()=>({data:{user:{id:"owner"}}})},from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:mode==="member"?{...member,role:"member"}:member})})})}),rpc:async()=>({data:{allowed:mode!=="mfa"}})};
vm.runInNewContext(source,{Deno:{env:{get:n=>n==="CAL_COM_API_KEY"?(mode==="missing"?undefined:"fake-secret"):"fake"},serve:h=>handler=h},createClient:()=>sb,Response,AbortSignal,fetch:async()=>{calls++;if(mode==="timeout")throw Error("fake-secret");return {ok:mode!=="rejected",status:403,json:async()=>({status:"success",data:{username:mode==="wrong"?"other":"bookleprokahn",id:2390745}})}}});
const r=await handler(new Request("https://test",{method:"POST",body:"{}",headers:mode==="anon"?{}:{Authorization:"Bearer fake"}}));const body=await r.json();assert(!JSON.stringify(body).includes("fake-secret"));return {mode,status:r.status,body,calls};
}
(async()=>{for(const [mode,status,calls] of [["anon",401,0],["member",403,0],["mfa",403,0],["missing",200,0],["wrong",409,1],["rejected",502,1],["timeout",502,1],["valid",200,1]]){const r=await run(mode);assert.equal(r.status,status);assert.equal(r.calls,calls);if(mode==="valid"){assert.equal(r.body.verified,true);assert.equal(r.body.syncEnabled,false);}console.log(mode+": passed");}})().catch(e=>{console.error(e);process.exit(1)});
