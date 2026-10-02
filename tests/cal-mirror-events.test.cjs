const vm=require("node:vm"),fs=require("node:fs"),assert=require("node:assert/strict");
async function run(mode){
 let handler,posts=0,id=8000000;const events=[];
 const specs=[["os-record-an-ad",60],["os-record-a-song",60],["os-instrumental-mix",60],["os-vocal-mix",60],["os-full-mix",120]];
 if(mode!=="new")for(const [slug,lengthInMinutes] of specs)events.push({id:++id,slug,lengthInMinutes,ownerId:2390745,hidden:true,price:mode==="conflict"?5:0,confirmationPolicy:{type:"always",disabled:false}});
 const sb={auth:{getUser:async()=>({data:{user:{id:"owner"}}})},from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:{role:"owner",access_status:"active",business_tools_enabled:true,artist_member_enabled:true,payment_status:"paid"}})})})}),rpc:async()=>({data:{allowed:true}})};
 vm.runInNewContext(fs.readFileSync("supabase/functions/studio-cal-connection/index.ts","utf8").split("\n").slice(1).join("\n"),{Deno:{env:{get:()=>"fake"},serve:h=>handler=h},createClient:()=>sb,Response,AbortSignal,fetch:async(url,options)=>{
 assert.notEqual(options.method,"PATCH");
 let data;if(url.endsWith("/me"))data={username:"bookleprokahn",id:2390745};
 else if(options.method==="POST"){posts++;const p=JSON.parse(options.body);assert(p.slug.startsWith("os-"));assert.equal(p.price,undefined);assert.equal(p.hidden,true);data={...p,id:++id,ownerId:2390745,price:0};events.push(data);}
 else if(url.endsWith("/event-types"))data=events;
 else data=events.find(e=>url.endsWith("/"+e.id))||{ownerId:2390745,scheduleId:999};
 return {ok:true,json:async()=>({status:"success",data})};
 }});
 const r=await handler(new Request("https://test",{method:"POST",headers:{Authorization:"Bearer test"},body:JSON.stringify({action:"prepare-os-events"})}));assert.equal(r.status,mode==="conflict"?409:200);assert.equal(posts,mode==="new"?5:0);if(r.status===200)assert.equal((await r.json()).events.length,5);
}
(async()=>{for(const mode of ["new","existing","conflict"]){await run(mode);console.log(mode+": passed");}})().catch(e=>{console.error(e);process.exit(1)});
