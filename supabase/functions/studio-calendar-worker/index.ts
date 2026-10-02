import { createClient } from "npm:@supabase/supabase-js@2.57.4";
const ORIGIN="https://lions-rock-mail.vercel.app", HOST=2390745, ZONE="America/Barbados";
const MAPPING={
 "0b305aae-87cc-4274-9656-bf1e921364ef":7314681,
 "8fc7f59d-cb46-4dd4-9d60-0c000fe7a814":7314682,
 "7e8ee2af-dbf6-4be3-80aa-8c9525a0aa15":7314683,
 "c1d6d89d-08ad-4a52-806c-fad0bab4eb51":7314684,
 "196c7505-e8e8-4638-b0bb-83b6b2adf4c6":7314685,
 "98954691-a825-48b9-8469-bf3bb4cd79ca":7314363
};
const equalTime=(a,b)=>Number.isFinite(Date.parse(a))&&Date.parse(a)===Date.parse(b);
const hex=bytes=>Array.from(new Uint8Array(bytes),x=>x.toString(16).padStart(2,"0")).join("");
async function digest(text){return hex(await crypto.subtle.digest("SHA-256",new TextEncoder().encode(text)));}
async function webhookSecret(key){const k=await crypto.subtle.importKey("raw",new TextEncoder().encode(key),{name:"HMAC",hash:"SHA-256"},false,["sign"]);return hex(await crypto.subtle.sign("HMAC",k,new TextEncoder().encode("lions-rock-os-calendar-webhook-v1")));}
async function verifySignature(secret,raw,signature){
 if(!/^[a-f0-9]{64}$/i.test(signature||""))return false;
 const k=await crypto.subtle.importKey("raw",new TextEncoder().encode(secret),{name:"HMAC",hash:"SHA-256"},false,["verify"]);
 const bytes=Uint8Array.from(signature.match(/../g),v=>parseInt(v,16));
 return crypto.subtle.verify("HMAC",k,bytes,new TextEncoder().encode(raw));
}
function providerClient(key){
 return async function cal(path,method="GET",body,version="2026-02-25"){
  const r=await fetch("https://api.cal.com/v2"+path,{method,headers:{Authorization:"Bearer "+key,"Content-Type":"application/json",...(version?{"cal-api-version":version}:{})},...(body?{body:JSON.stringify(body)}:{}),redirect:"error",signal:AbortSignal.timeout(10000)});
  if(!r.ok){console.error(JSON.stringify({component:"studio-calendar-worker",stage:"provider",method,path:path.split("?")[0],status:r.status}));throw Error("cal_http_"+r.status);}
  const j=await r.json();if(j.status!=="success")throw Error("cal_invalid_response");return j;
 };
}
function validateEvent(e,minutes){
 if(e?.ownerId!==HOST||e.hidden!==true||Number(e.price||0)!==0||e.lengthInMinutes!==minutes||e.confirmationPolicy?.type!=="always"||e.confirmationPolicy?.disabled===true)throw Error("hidden_event_mismatch");
 return e;
}
async function eventFor(cal,variant,minutes,create=false){
 const baseId=MAPPING[variant];if(!baseId)throw Error("service_not_mapped");
 const base=(await cal("/event-types/"+baseId,"GET",undefined,"2026-06-12")).data;
 validateEvent(base,base.lengthInMinutes);
 if(base.lengthInMinutes===minutes)return base;
 if(!Number.isInteger(minutes)||minutes<15||minutes>720)throw Error("invalid_duration");
 const slug=base.slug+"-"+minutes+"min";
 const list=(await cal("/event-types?username=bookleprokahn&eventSlug="+encodeURIComponent(slug),"GET",undefined,"2026-06-12")).data;
 const events=Array.isArray(list)?list:list?.eventTypes||[];
 let e=events.find(x=>x.slug===slug);
 if(!e&&!create)throw Error("duration_event_not_prepared");
 if(!e){
  const body={title:base.title+" · "+minutes+" minutes",slug,lengthInMinutes:minutes,hidden:true,confirmationPolicy:{type:"always",blockUnconfirmedBookingsInBooker:true,disabled:false},locations:base.locations};
  if(Number.isInteger(base.scheduleId))body.scheduleId=base.scheduleId;
  e=(await cal("/event-types","POST",body,"2026-06-12")).data;
 }
 return validateEvent((await cal("/event-types/"+e.id,"GET",undefined,"2026-06-12")).data,minutes);
}
async function matchingSlot(cal,event,start,end,bookingUid){
 const date=new Date(Date.parse(start)-4*3600000).toISOString().slice(0,10);
 const a=date+"T00:00:00-04:00",z=new Date(Date.parse(a)+86400000).toISOString();
 const q=new URLSearchParams({eventTypeId:String(event.id),start:new Date(a).toISOString(),end:z,timeZone:ZONE,format:"range"});
 if(bookingUid)q.set("bookingUidToReschedule",bookingUid);
 const data=(await cal("/slots?"+q,"GET",undefined,"2024-09-04")).data;
 return Object.values(data||{}).flat().some(s=>equalTime(s.start,start)&&equalTime(s.end,end));
}
function validateBooking(b,bookingId,eventId){
 if(!b?.uid||b.eventTypeId!==eventId||!b.hosts?.some(h=>h.id===HOST)||b.metadata?.osBookingId!==bookingId)throw Error("provider_booking_mismatch");
 return b;
}
async function currentBooking(cal,uid,bookingId,eventId){
 let b=validateBooking((await cal("/bookings/"+encodeURIComponent(uid))).data,bookingId,eventId);
 const seen=new Set([uid]);
 for(let i=0;b.rescheduledToUid&&i<8;i++){
  if(seen.has(b.rescheduledToUid))throw Error("provider_reschedule_loop");
  seen.add(b.rescheduledToUid);
  b=validateBooking((await cal("/bookings/"+encodeURIComponent(b.rescheduledToUid))).data,bookingId,eventId);
 }
 if(b.rescheduledToUid)throw Error("provider_reschedule_chain");
 return b;
}
function verifiedDesired(b,op){return op.desired_status==="cancelled"?b.status==="cancelled":b.status==="accepted"&&equalTime(b.start,op.desired_start)&&equalTime(b.end,op.desired_end);}
async function processOperation(cal,backend,job,recovery=false){
 const {operation:op,booking:b,link}=job;if(!op)return {processed:false};
 let providerUid=op.provider_uid||link?.provider_uid,eventId=link?.event_type_id,mutating=false;
 const checkpoint=async(phase,uid)=>backend("checkpoint",{id:op.id,phase,...(uid?{providerUid:uid}:{})});
 const finish=async(state,code,provider)=>backend("finish",{id:op.id,state,errorCode:code,providerUid:provider?.uid,eventTypeId:provider?.eventTypeId});
 try{
  if(recovery){
   let found;
   if(providerUid&&eventId){try{found=await currentBooking(cal,providerUid,b.id,eventId);}catch{ /* Search the operation metadata before making any decision. */ }}
   if(!found||!verifiedDesired(found,op)){
    let cursor="",matches=[],pages=0;
    do{
     const q=new URLSearchParams({limit:"100",afterCreatedAt:new Date(Date.parse(op.created_at)-60000).toISOString()});if(cursor)q.set("cursor",cursor);
     const page=await cal("/bookings?"+q,"GET",undefined,"2026-05-01");
     matches.push(...(Array.isArray(page.data)?page.data:[]).filter(x=>x.metadata?.osOperationId===op.id));
     cursor=page.pagination?.hasMore?page.pagination.nextCursor:"";pages++;
     if(pages>=10&&cursor)throw Error("recovery_scan_incomplete");
    }while(cursor);
    if(matches.length===1){const candidate=matches[0];found=await currentBooking(cal,candidate.uid,b.id,candidate.eventTypeId);}
    else if(matches.length>1)throw Error("recovery_multiple_matches");
   }
   if(found&&verifiedDesired(found,op)){
    if(op.desired_status==="confirmed"){const expected=await eventFor(cal,b.variant_id,(Date.parse(op.desired_end)-Date.parse(op.desired_start))/60000,false);if(found.eventTypeId!==expected.id)throw Error("recovery_event_mismatch");}await finish("synced",null,found);return {processed:true,state:"synced"};}
   await finish("review","recovery_requires_owner_review");return {processed:true,state:"review"};
  }
  if(Date.parse(op.desired_start)<=Date.now()&&op.desired_status!=="cancelled")throw Error("session_time_passed");
  if(op.desired_status==="cancelled"){
   if(!providerUid||!eventId)throw Error("linked_booking_missing");
   let current=await currentBooking(cal,providerUid,b.id,eventId);
   if(current.status!=="cancelled"){
    await checkpoint("cancel_requested",current.uid);mutating=true;
    await cal("/bookings/"+encodeURIComponent(current.uid)+"/cancel","POST",{cancellationReason:"Cancelled in Lions Rock Studio OS"});
    current=await currentBooking(cal,current.uid,b.id,eventId);
   }
   if(!verifiedDesired(current,op))throw Error("cancellation_not_verified");
   await finish("synced",null,current);return {processed:true,state:"synced"};
  }
  const minutes=(Date.parse(op.desired_end)-Date.parse(op.desired_start))/60000;
  const event=await eventFor(cal,b.variant_id,minutes,true);eventId=event.id;
  const contact=await backend("contact",{bookingId:b.id});
  let current=providerUid&&link?.event_type_id?await currentBooking(cal,providerUid,b.id,link.event_type_id):null;
  if(current&&verifiedDesired(current,op)){await finish("synced",null,current);return {processed:true,state:"synced"};}
  if(!await matchingSlot(cal,event,op.desired_start,op.desired_end,current?.status==="accepted"?current.uid:undefined))throw Error("provider_slot_unavailable");
  if(current&&current.status==="cancelled")throw Error("provider_cancelled_owner_review");
  if(current&&current.eventTypeId===event.id){
   await checkpoint("reschedule_requested",current.uid);mutating=true;
   const res=(await cal("/bookings/"+encodeURIComponent(current.uid)+"/reschedule","POST",{start:new Date(op.desired_start).toISOString(),rescheduledBy:current.hosts.find(h=>h.id===HOST).email,reschedulingReason:"Updated in Lions Rock Studio OS"})).data;
   if(!res?.uid)throw Error("reschedule_uid_missing");await checkpoint("rescheduled",res.uid);
   current=await currentBooking(cal,res.uid,b.id,event.id);
  }else{
   if(current){
    await checkpoint("replacement_cancel_requested",current.uid);mutating=true;
    await cal("/bookings/"+encodeURIComponent(current.uid)+"/cancel","POST",{cancellationReason:"Duration updated in Lions Rock Studio OS"});
    const cancelled=await currentBooking(cal,current.uid,b.id,current.eventTypeId);
    if(cancelled.status!=="cancelled")throw Error("replacement_cancellation_not_verified");
    await checkpoint("replacement_cancelled",current.uid);
   }
   await checkpoint("create_requested");mutating=true;
   const created=(await cal("/bookings","POST",{eventTypeId:event.id,start:new Date(op.desired_start).toISOString(),attendee:{name:contact.name,email:contact.email,timeZone:ZONE},location:{type:"address"},metadata:{osBookingId:b.id,osOperationId:op.id}})).data;
   if(!created?.uid)throw Error("creation_uid_missing");await checkpoint("created",created.uid);
   current=await currentBooking(cal,created.uid,b.id,event.id);
  }
  if(current.status==="pending"){
   await checkpoint("confirm_requested",current.uid);mutating=true;
   await cal("/bookings/"+encodeURIComponent(current.uid)+"/confirm","POST",{});
   current=await currentBooking(cal,current.uid,b.id,event.id);
  }
  if(!verifiedDesired(current,op))throw Error("provider_result_not_verified");
  await finish("synced",null,current);return {processed:true,state:"synced"};
 }catch(e){
  const state=mutating?"uncertain":"review";await finish(state,String(e.message||"calendar_operation_failed").replace(/[^a-z0-9_]/gi,"_").slice(0,80));
  return {processed:true,state};
 }
}
Deno.serve(async req=>{
 const headers={"Access-Control-Allow-Origin":ORIGIN,"Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Access-Control-Allow-Methods":"POST, OPTIONS","Content-Type":"application/json","Cache-Control":"no-store","Vary":"Origin"};
 const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers});
 if(req.method==="OPTIONS")return reply({ok:true});
 if(req.method!=="POST")return reply({error:"Method not allowed"},405);
 const key=Deno.env.get("CAL_COM_API_KEY")?.trim();if(!key)return reply({error:"Calendar connection is not configured"},503);
 const server=createClient(Deno.env.get("SUPABASE_URL"),Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),{auth:{persistSession:false,autoRefreshToken:false}});
 const backend=async(command,payload={})=>{const r=await server.rpc("studio_calendar_backend",{command,payload});if(r.error)throw Error(r.error.message);return r.data;};
 const cal=providerClient(key);
 try{
  const signature=req.headers.get("x-cal-signature-256");
  if(signature){
   const raw=await req.text();if(raw.length>131072)return reply({error:"Payload too large"},413);
   if(!await verifySignature(await webhookSecret(key),raw,signature))return reply({error:"Invalid signature"},401);
   const data=JSON.parse(raw),uid=data.payload?.uid;if(typeof uid!=="string")return reply({ignored:true});
   const hash=await digest(raw),known=await backend("lookup",{providerUid:uid,digest:hash});
   if(known.seen||!known.bookingId)return reply({ignored:true});
   const ctx=await backend("context",{bookingId:known.bookingId});if(!ctx.enabled)return reply({ignored:true});
   const fetched=(await cal("/bookings/"+encodeURIComponent(uid))).data;
   const current=await currentBooking(cal,uid,known.bookingId,fetched.eventTypeId);
   const event=(await cal("/event-types/"+current.eventTypeId,"GET",undefined,"2026-06-12")).data;validateEvent(event,(Date.parse(current.end)-Date.parse(current.start))/60000);
   const base=(await cal("/event-types/"+MAPPING[ctx.booking.variant_id],"GET",undefined,"2026-06-12")).data;
   if(event.slug!==base.slug&&!event.slug.startsWith(base.slug+"-"))throw Error("unmapped_provider_event");
   try{await backend("reconcile",{bookingId:known.bookingId,providerUid:current.uid,start:current.start,end:current.end,status:current.status,digest:hash});}
  catch(e){if(String(e.message).includes("busy"))throw e;await backend("external-review",{bookingId:known.bookingId,providerUid:current.uid,digest:hash});return reply({review:true});}
  return reply({ok:true});
  }
  let runner=false;
  const token=req.headers.get("x-calendar-runner-token");if(token){runner=(await backend("runner",{digest:await digest(token)})).allowed===true;if(!runner)return reply({error:"Invalid runner token"},401);}
  if(req.headers.get("origin")&&req.headers.get("origin")!==ORIGIN)return reply({error:"Origin not allowed"},403);
  let caller,user,m,owner=false;
  if(!runner){
   const authorization=req.headers.get("authorization")||"";if(!authorization.startsWith("Bearer "))return reply({error:"Sign in required"},401);
   caller=createClient(Deno.env.get("SUPABASE_URL"),Deno.env.get("SUPABASE_ANON_KEY"),{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
   const u=await caller.auth.getUser(authorization.slice(7));if(u.error||!u.data.user)return reply({error:"Sign in required"},401);user=u.data.user;
   const mr=await caller.from("app_memberships").select("*").eq("user_id",user.id).maybeSingle();m=mr.data;
   if(mr.error||!m||m.deleted_at||m.access_status!=="active"||!m.artist_member_enabled||!["paid","comped"].includes(m.payment_status)||(m.expires_at&&Date.parse(m.expires_at)<=Date.now()))return reply({error:"Active Artist access required"},403);
   owner=m.role==="owner"&&m.business_tools_enabled;if(m.role==="owner"){const gate=await caller.rpc("owner_mfa_status");if(!owner||gate.error||gate.data?.allowed!==true)return reply({error:"Owner security verification required"},403);}
  }
  let body;try{body=await req.json();}catch{return reply({error:"Invalid request"},400);}
  const action=body.action||"status";
  if(runner&&!["process","recover","diagnose"].includes(action))return reply({error:"Runner operation not allowed"},403);
  if(action==="diagnose"){
  if(!runner&&!owner)return reply({error:"Owner access required"},403);
  const checks=[];
  try{const profile=(await cal("/me")).data;checks.push({stage:"account",matches:profile.id===HOST&&profile.username==="bookleprokahn"});}catch(e){checks.push({stage:"account",error:e.message});}
  for(const eventId of Object.values(MAPPING)){try{const e=(await cal("/event-types/"+eventId,"GET",undefined,"2026-06-12")).data;checks.push({stage:"event",id:eventId,ownerMatches:e.ownerId===HOST,hidden:e.hidden,price:Number(e.price||0),minutes:e.lengthInMinutes,confirmationType:e.confirmationPolicy?.type,confirmationDisabled:e.confirmationPolicy?.disabled});}catch(e){checks.push({stage:"event",id:eventId,error:e.message});}}
  try{const list=(await cal("/webhooks","GET",undefined,"")).data;const hooks=Array.isArray(list)?list:list?.webhooks||[];const url=Deno.env.get("SUPABASE_URL")+"/functions/v1/studio-calendar-worker";checks.push({stage:"webhooks",array:Array.isArray(list),keys:Array.isArray(list)?[]:Object.keys(list||{}),matching:hooks.filter(h=>h.subscriberUrl===url).map(h=>({id:h.id,userId:h.userId,active:h.active,triggers:h.triggers,subscriberMatches:true}))});}catch(e){checks.push({stage:"webhooks",error:e.message});}
  for(const date of (Array.isArray(body.previewDates)?body.previewDates:[]).slice(0,3)){
  if(!/^\d{4}-\d{2}-\d{2}$/.test(date))continue;
  try{const start=date+"T00:00:00-04:00",end=new Date(Date.parse(start)+86400000).toISOString();const q=new URLSearchParams({eventTypeId:"7314681",start:new Date(start).toISOString(),end,timeZone:ZONE,format:"range"});const slots=Object.values((await cal("/slots?"+q,"GET",undefined,"2024-09-04")).data||{}).flat();checks.push({stage:"read_only_availability",date,count:slots.length,slots:slots.slice(0,12).map(x=>({start:x.start,end:x.end}))});}catch(e){checks.push({stage:"read_only_availability",date,error:e.message});}
 }
  return reply({checks});
 }
  if(["process","recover"].includes(action)){
   if(!runner&&!owner)return reply({error:"Owner access required"},403);
   const profile=(await cal("/me")).data;if(profile.id!==HOST||profile.username!=="bookleprokahn")throw Error("wrong_calendar_account");
   const job=await backend(action==="recover"?(body.bookingId&&!runner?"recover-review":"recover-claim"):"claim",body.bookingId&&!runner?{bookingId:body.bookingId}:{});
   return reply(await processOperation(cal,backend,job,action==="recover"));
  }
  if(action==="status"){const r=await caller.rpc("studio_calendar_status");if(r.error)throw r.error;return reply(r.data);}
  if(action==="activate"||action==="pause"){
   if(!owner)return reply({error:"Owner access required"},403);
   if(action==="activate"){
    const profile=(await cal("/me")).data;if(profile.id!==HOST||profile.username!=="bookleprokahn")throw Error("wrong_calendar_account");
    for(const variant of Object.keys(MAPPING)){const e=(await cal("/event-types/"+MAPPING[variant],"GET",undefined,"2026-06-12")).data;validateEvent(e,e.lengthInMinutes);}
    const subscriberUrl=Deno.env.get("SUPABASE_URL")+"/functions/v1/studio-calendar-worker";
    const list=(await cal("/webhooks","GET",undefined,"")).data;
    const hooks=Array.isArray(list)?list:list?.webhooks||[];
    const existing=hooks.filter(h=>h.subscriberUrl===subscriberUrl);
    if(existing.length>1)throw Error("duplicate_calendar_webhooks");
    const hookBody={active:true,subscriberUrl,triggers:["BOOKING_CREATED","BOOKING_RESCHEDULED","BOOKING_CANCELLED","BOOKING_REJECTED"],secret:await webhookSecret(key)};
    const installed=existing.length?(await cal("/webhooks/"+existing[0].id,"PATCH",hookBody,"")).data:(await cal("/webhooks","POST",hookBody,"")).data;
   if(installed?.subscriberUrl!==subscriberUrl||installed.active!==true||installed.userId!==HOST||!hookBody.triggers.every(t=>installed.triggers?.includes(t)))throw Error("webhook_not_verified");
   }
   await backend("configure",{enabled:action==="activate"});
   return reply({enabled:action==="activate"});
  }
  if(action!=="ticket"&&action!=="availability")return reply({error:"Unknown action"},400);
  let b,variantId=body.variantId,start=body.start,minutes=body.minutes;
  if(body.bookingId){
   const ctx=await backend("context",{bookingId:body.bookingId});b=ctx.booking;
   if(!b?.id||(!owner&&b.user_id!==user.id))return reply({error:"Booking access denied"},403);
   if(!owner)return reply({error:"Owner access required to change or confirm sessions"},403);
   variantId=b.variant_id;start=start||b.starts_at;minutes=minutes||(Date.parse(b.ends_at)-Date.parse(b.starts_at))/60000;
  }else{
   const vr=await server.from("studio_service_variants").select("duration_minutes").eq("id",variantId).maybeSingle();
   if(vr.error||!vr.data)throw Error("service_not_found");minutes=vr.data.duration_minutes;
  }
  if(action==="availability"){
   if(!/^\d{4}-\d{2}-\d{2}$/.test(body.date||""))return reply({error:"Choose a valid date"},400);
   const event=await eventFor(cal,variantId,minutes,false);
   const r=await caller.rpc("studio_availability",{booking_date:body.date,offering_id:variantId});if(r.error)throw r.error;
   const starts=(r.data||[]).filter(x=>x.available&&Date.parse(x.starts_at)>Date.now());
   const day=body.date+"T00:00:00-04:00",end=new Date(Date.parse(day)+86400000).toISOString();
   const q=new URLSearchParams({eventTypeId:String(event.id),start:new Date(day).toISOString(),end,timeZone:ZONE,format:"range"});
   const slots=Object.values((await cal("/slots?"+q,"GET",undefined,"2024-09-04")).data||{}).flat();
   return reply({slots:starts.filter(x=>slots.some(s=>equalTime(s.start,x.starts_at)&&Date.parse(s.end)-Date.parse(s.start)===minutes*60000))});
  }
  if(!Number.isInteger(minutes)||minutes<15||minutes>720||!Number.isFinite(Date.parse(start))||Date.parse(start)<=Date.now())return reply({error:"Choose a future session time and valid duration"},400);
  const end=new Date(Date.parse(start)+minutes*60000).toISOString();
  const event=await eventFor(cal,variantId,minutes,owner);
  let same=false,existingUid;
  if(b){
   const ctx=await backend("context",{bookingId:b.id});
   if(ctx.link?.provider_uid){
    const linked=await currentBooking(cal,ctx.link.provider_uid,b.id,ctx.link.event_type_id);
    if(linked.status!=="accepted")return reply({error:"The linked calendar session needs review before changing it."},409);
    existingUid=linked.uid;
    same=equalTime(linked.start,start)&&equalTime(linked.end,end);
   }
  }
  if(!same&&!await matchingSlot(cal,event,start,end,existingUid))return reply({error:"That time is unavailable in Cal.com. Choose another time."},409);
  return reply(await backend("ticket",{actorId:user.id,bookingId:b?.id,variantId,start,end}));
 }catch(e){console.error(JSON.stringify({component:"studio-calendar-worker",stage:"request_failed",code:String(e.code||e.message||"unknown").replace(/[^a-z0-9_ -]/gi,"_").slice(0,120)}));return reply({error:"Calendar operation could not be completed. Refresh and check its status before retrying."},503);}
});
