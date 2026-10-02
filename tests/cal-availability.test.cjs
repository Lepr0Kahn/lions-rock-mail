const vm=require("node:vm"),fs=require("node:fs"),assert=require("node:assert/strict");
async function run(mode){
 let handler;const date=new Date(Date.now()+3*86400000).toISOString().slice(0,10),start=date+"T14:00:00Z";
 const sb={auth:{getUser:async()=>({data:{user:{id:"owner"}}})},from:table=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:table==="studio_service_variants"?{duration_minutes:60}:{role:"owner",access_status:"active",business_tools_enabled:true,artist_member_enabled:true,payment_status:"paid"}})})})}),rpc:async name=>name==="owner_mfa_status"?{data:{allowed:true}}:{data:[{available:mode!=="held",starts_at:start},{available:true,starts_at:date+"T15:00:00Z"}]}};
 vm.runInNewContext(fs.readFileSync("supabase/functions/studio-cal-connection/index.ts","utf8").split("\n").slice(1).join("\n"),{Deno:{env:{get:()=>"fake"},serve:h=>handler=h},createClient:()=>sb,Response,AbortSignal,URLSearchParams,fetch:async url=>{
 if(url.endsWith("/me"))return {ok:true,json:async()=>({status:"success",data:{id:2390745,username:"bookleprokahn"}})};
 if(url.includes("/event-types/"))return {ok:true,json:async()=>({status:"success",data:{ownerId:2390745,lengthInMinutes:mode==="mismatch"?120:60,hidden:true,price:mode==="paid"?5:0,confirmationPolicy:{type:"always",disabled:false}}})};
 return {ok:mode!=="failure",json:async()=>({status:"success",data:{[date]:[{start,end:date+"T15:00:00Z"}]}})};
 }});
 const r=await handler(new Request("https://test",{method:"POST",headers:{Authorization:"Bearer test"},body:JSON.stringify({action:"availability-preview",offeringId:"0b305aae-87cc-4274-9656-bf1e921364ef",date})}));assert.equal(r.status,mode==="failure"?502:mode==="mismatch"||mode==="paid"?409:200);const body=await r.json();if(r.status===200){assert.equal(body.slots.length,mode==="held"?0:1);assert.equal(body.syncEnabled,false);}
}
(async()=>{for(const mode of ["intersection","held","failure","mismatch","paid"]){await run(mode);console.log(mode+": passed");}})().catch(e=>{console.error(e);process.exit(1)});

