const vm=require("node:vm"),fs=require("node:fs"),assert=require("node:assert/strict");
async function run(mode){
 let handler,writes=0,event={id:123,ownerId:2390745,slug:"instrumental-creation",lengthInMinutes:180,hidden:true,confirmationPolicy:{type:"always",disabled:false}};
 const sb={auth:{getUser:async()=>({data:{user:{id:"owner"}}})},from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:{role:mode==="member"?"member":"owner",access_status:"active",business_tools_enabled:true,artist_member_enabled:true,payment_status:"paid"}})})})}),rpc:async()=>({data:{allowed:true}})};
 vm.runInNewContext(fs.readFileSync("supabase/functions/studio-cal-connection/index.ts","utf8").split("\n").slice(1).join("\n"),{Deno:{env:{get:()=>"fake"},serve:h=>handler=h},createClient:()=>sb,Response,AbortSignal,fetch:async(url,options)=>{
 if(url.endsWith("/me"))return {ok:true,json:async()=>({status:"success",data:{id:2390745,username:"bookleprokahn"}})};
 if(options.method==="POST"){writes++;const p=JSON.parse(options.body);assert.equal(p.lengthInMinutes,180);assert.equal(p.hidden,true);assert.equal(p.confirmationPolicy.type,"always");assert.equal(p.price,undefined);return {ok:true,json:async()=>({status:"success",data:event})};}
 return {ok:true,json:async()=>({status:"success",data:url.includes("?")?(mode==="new"?[]:[mode==="conflict"?{...event,lengthInMinutes:60}:event]):event})};
 }});
 const r=await handler(new Request("https://test",{method:"POST",headers:{Authorization:"Bearer test"},body:JSON.stringify({action:"instrumental-creation"})}));
 assert.equal(r.status,mode==="member"?403:mode==="conflict"?409:200);assert.equal(writes,mode==="new"?1:0);
}
(async()=>{for(const mode of ["new","existing","conflict","member"]){await run(mode);console.log(mode+": passed");}})().catch(e=>{console.error(e);process.exit(1)});
