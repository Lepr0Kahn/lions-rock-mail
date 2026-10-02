const fs=require("node:fs"),vm=require("node:vm"),assert=require("node:assert/strict"),{webcrypto}=require("node:crypto");
const code=fs.readFileSync(fs.existsSync(__dirname+"/calendar-worker.ts")?__dirname+"/calendar-worker.ts":__dirname+"/../supabase/functions/studio-calendar-worker/index.ts","utf8").replace(/^import[^\n]+\n/,"");
let handler;
const context=vm.createContext({Deno:{serve:f=>handler=f,env:{get:()=>undefined}},crypto:webcrypto,TextEncoder,Uint8Array,URLSearchParams,AbortSignal,Response,Date,console});
vm.runInContext(code,context);
const variant="0b305aae-87cc-4274-9656-bf1e921364ef",id="booking-a",opid="operation-a",eventId=7314681;
const event={id:eventId,ownerId:2390745,hidden:true,price:0,lengthInMinutes:60,slug:"os-record-an-ad",confirmationPolicy:{type:"always"}};
function job(){return {operation:{id:opid,desired_start:"2026-12-01T14:00:00Z",desired_end:"2026-12-01T15:00:00Z",desired_status:"confirmed",created_at:"2026-10-02T03:00:00Z"},booking:{id,variant_id:variant},link:null};}
function booking(status="accepted",uid="cal-a"){return {uid,status,eventTypeId:eventId,hosts:[{id:2390745,email:"owner@example.test"}],metadata:{osBookingId:id,osOperationId:opid},start:"2026-12-01T14:00:00Z",end:"2026-12-01T15:00:00Z"};}
async function run(name,alter,mode){
 const j=job();alter?.(j);let current=booking(mode==="pending"?"pending":"accepted"),calls=[],outcomes=[];if(mode==="reschedule") {current.start="2026-12-02T14:00:00Z";current.end="2026-12-02T15:00:00Z";}
 const cal=async(path,method="GET",body)=>{
  calls.push({path,method,body});
  if(path.startsWith("/event-types/"))return {data:event};
  if(path.startsWith("/slots?"))return {data:{date:mode==="unavailable"?[]:[{start:j.operation.desired_start,end:j.operation.desired_end}]}};
  if(path.startsWith("/bookings?"))return {data:mode==="recoverFound"?[current]:[],pagination:{hasMore:false}};
  if(path==="/bookings"&&method==="POST"){if(mode==="timeout")throw Error("timeout");return {data:current};}
  if(path.endsWith("/confirm")){current.status="accepted";return {data:current};}
  if(path.endsWith("/cancel")){current.status="cancelled";return {data:current};}
  if(path.endsWith("/reschedule")){current={...current,uid:"cal-b",start:j.operation.desired_start,end:j.operation.desired_end};return {data:current};}
  if(path.startsWith("/bookings/"))return {data:current};
  throw Error("unexpected "+path);
 };
 const backend=async(command,payload)=>{if(command==="contact")return {name:"Artist",email:"artist@example.test"};if(command==="finish")outcomes.push(payload);return {ok:true};};
 context.calMock=cal;context.backendMock=backend;context.jobMock=j;context.recoveryMock=mode?.startsWith("recover");
 const result=await vm.runInContext("processOperation(calMock,backendMock,jobMock,recoveryMock)",context);
 return {result,calls,outcomes};
}
(async()=>{
 let r=await run("create");assert.equal(r.result.state,"synced");assert.equal(r.calls.filter(x=>x.path==="/bookings"&&x.method==="POST").length,1);assert.deepEqual(JSON.parse(JSON.stringify(r.calls.find(x=>x.path==="/bookings").body.metadata)),{osBookingId:id,osOperationId:opid});
 r=await run("pending",null,"pending");assert.equal(r.result.state,"synced");assert.equal(r.calls.filter(x=>x.path.endsWith("/confirm")).length,1);
 r=await run("unavailable",null,"unavailable");assert.equal(r.result.state,"review");assert.equal(r.calls.filter(x=>x.method==="POST").length,0);
 r=await run("timeout",null,"timeout");assert.equal(r.result.state,"uncertain");assert.equal(r.calls.filter(x=>x.path==="/bookings"&&x.method==="POST").length,1);
 r=await run("recovery",null,"recoverFound");assert.equal(r.result.state,"synced");assert.equal(r.calls.filter(x=>x.method==="POST").length,0);
 r=await run("recovery absent",null,"recoverAbsent");assert.equal(r.result.state,"review");assert.equal(r.calls.filter(x=>x.method==="POST").length,0);
 r=await run("cancel",j=>{j.operation.desired_status="cancelled";j.link={provider_uid:"cal-a",event_type_id:eventId};});assert.equal(r.result.state,"synced");assert.equal(r.calls.filter(x=>x.path.endsWith("/cancel")).length,1);
 r=await run("reschedule",j=>{j.link={provider_uid:"cal-a",event_type_id:eventId};}, "reschedule");assert.equal(r.result.state,"synced");assert.equal(r.calls.filter(x=>x.path.endsWith("/reschedule")).length,1);assert.ok(r.calls.find(x=>x.path.startsWith("/slots?")).path.includes("bookingUidToReschedule=cal-a"));assert.equal(r.calls.filter(x=>x.path==="/bookings"&&x.method==="POST").length,0);
context.goodEvent=event;vm.runInContext("validateEvent(goodEvent,60)",context);
 context.badEvent={...event,price:100};assert.throws(()=>vm.runInContext("validateEvent(badEvent,60)",context));
 context.badEvent={...event,ownerId:1};assert.throws(()=>vm.runInContext("validateEvent(badEvent,60)",context));
 context.badBooking={...booking(),metadata:{osBookingId:"other"}};assert.throws(()=>vm.runInContext('validateBooking(badBooking,"booking-a",7314681)',context));
 const replacement=job();replacement.operation.desired_end="2026-12-01T16:00:00Z";replacement.link={provider_uid:"old-booking",event_type_id:eventId};
let replacementCurrent={...booking(),uid:"old-booking",start:"2026-12-02T14:00:00Z",end:"2026-12-02T15:00:00Z"},replacementCalls=[],replacementOutcome;
const extended={...event,id:9001,lengthInMinutes:120,slug:event.slug+"-120min"};
context.jobMock=replacement;context.recoveryMock=false;
context.backendMock=async(c,p)=>{if(c==="contact")return {name:"Guardian",email:"guardian@example.test"};if(c==="finish")replacementOutcome=p;return {ok:true};};
context.calMock=async(path,method="GET",body)=>{
 replacementCalls.push({path,method,body});
 if(path==="/event-types/"+eventId)return {data:event};
 if(path.startsWith("/event-types?"))return {data:[extended]};
 if(path==="/event-types/9001")return {data:extended};
 if(path.startsWith("/slots?"))return {data:{date:[{start:replacement.operation.desired_start,end:replacement.operation.desired_end}]}};
 if(path.endsWith("/cancel")){replacementCurrent.status="cancelled";return {data:replacementCurrent};}
 if(path==="/bookings"&&method==="POST"){replacementCurrent={...booking(),uid:"replacement",eventTypeId:9001,end:replacement.operation.desired_end};return {data:replacementCurrent};}
 if(path.startsWith("/bookings/"))return {data:replacementCurrent};
 throw Error("unexpected replacement "+path);
};
const replaced=await vm.runInContext("processOperation(calMock,backendMock,jobMock,false)",context);
assert.equal(replaced.state,"synced");assert.equal(replacementOutcome.eventTypeId,9001);assert.ok(replacementCalls.find(x=>x.path.startsWith("/slots?")).path.includes("bookingUidToReschedule=old-booking"));
assert.ok(replacementCalls.findIndex(x=>x.path.endsWith("/cancel"))<replacementCalls.findIndex(x=>x.path==="/bookings"&&x.method==="POST"));
assert.equal(replacementCalls.find(x=>x.path==="/bookings").body.attendee.email,"guardian@example.test");
const secret="test-only-secret",raw='{"payload":{"uid":"one"}}';
 const k=await webcrypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
 const signature=Buffer.from(await webcrypto.subtle.sign("HMAC",k,new TextEncoder().encode(raw))).toString("hex");
 Object.assign(context,{testSecret:secret,testRaw:raw,testSignature:signature});assert.equal(await vm.runInContext("verifySignature(testSecret,testRaw,testSignature)",context),true);
 context.testRaw=raw+" ";assert.equal(await vm.runInContext("verifySignature(testSecret,testRaw,testSignature)",context),false);
 const response=await handler(new Request("https://test",{method:"POST",body:"{}"}));assert.equal(response.status,503);
 context.Deno.env.get=n=>({CAL_COM_API_KEY:"test-only-key",SUPABASE_URL:"https://test",SUPABASE_SERVICE_ROLE_KEY:"test-server",SUPABASE_ANON_KEY:"test-anon"}[n]);
let member={user_id:"user-a",role:"artist",artist_member_enabled:true,business_tools_enabled:false,access_status:"active",payment_status:"comped",deleted_at:null};
context.createClient=(url,key,options)=>({
 auth:{getUser:async()=>({data:{user:{id:"user-a"}}})},
 from:()=>({select:()=>({eq:()=>({maybeSingle:async()=>({data:member})})})}),
 rpc:async name=>({data:name==="owner_mfa_status"?{allowed:false}:{enabled:false,bookings:[]}})
});
let response2=await handler(new Request("https://test",{method:"POST",body:"{}"}));assert.equal(response2.status,401);
response2=await handler(new Request("https://test",{method:"POST",headers:{authorization:"Bearer test"},body:JSON.stringify({action:"process"})}));assert.equal(response2.status,403);
member={...member,role:"owner",business_tools_enabled:true};response2=await handler(new Request("https://test",{method:"POST",headers:{authorization:"Bearer test"},body:JSON.stringify({action:"status"})}));assert.equal(response2.status,403);
member={...member,role:"artist",access_status:"suspended"};response2=await handler(new Request("https://test",{method:"POST",headers:{authorization:"Bearer test"},body:"{}"}));assert.equal(response2.status,403);
// Delayed cancellation for the old duration must not cancel its replacement.
const webhookRaw=JSON.stringify({payload:{uid:"old-booking"}}),webhookCalls=[];
context.createClient=()=>({rpc:async(name,args)=>{webhookCalls.push(args.command);return {data:args.command==="lookup"?{bookingId:id,seen:false}:args.command==="context"?{enabled:true,booking:{variant_id:variant},link:{provider_uid:"replacement",event_type_id:9001}}:{ok:true}};}});
context.fetch=async url=>new Response(JSON.stringify({status:"success",data:String(url).endsWith("/bookings/old-booking")?{...booking("cancelled","old-booking")}:String(url).endsWith("/bookings/replacement")?{...booking("accepted","replacement"),eventTypeId:9001,end:"2026-12-01T16:00:00Z"}:extended}),{status:200,headers:{"content-type":"application/json"}});
const signingSecret=await vm.runInContext('webhookSecret("test-only-key")',context);
const signingKey=await webcrypto.subtle.importKey("raw",new TextEncoder().encode(signingSecret),{name:"HMAC",hash:"SHA-256"},false,["sign"]);
const webhookSignature=Buffer.from(await webcrypto.subtle.sign("HMAC",signingKey,new TextEncoder().encode(webhookRaw))).toString("hex");
const staleResponse=await handler(new Request("https://test",{method:"POST",headers:{"x-cal-signature-256":webhookSignature},body:webhookRaw}));
assert.equal(staleResponse.status,200);assert.equal((await staleResponse.json()).ignored,true);assert.equal(webhookCalls.includes("reconcile"),false);assert.equal(webhookCalls.includes("external-review"),false);
console.log("PASS: signed delayed cancellation cannot reconcile a replacement.");
console.log("PASS: create, confirm, availability failure, ambiguous timeout, metadata recovery, no blind retries, cancel, reschedule, duration replacement, guardian contact, event/booking isolation, raw-body signatures, missing secret.");
})().catch(e=>{console.error(e);process.exit(1);});
