import { createClient } from "npm:@supabase/supabase-js@2.57.4";
const origin = "https://lions-rock-mail.vercel.app";
Deno.serve(async (req) => {
 const headers = {"Access-Control-Allow-Origin":origin,"Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Access-Control-Allow-Methods":"POST, OPTIONS","Vary":"Origin","Content-Type":"application/json","Cache-Control":"no-store"};
 const reply = (body, status=200) => new Response(JSON.stringify(body), {status,headers});
 if(req.method==="OPTIONS") return reply({ok:true});
 if(req.method!=="POST") return reply({error:"Method not allowed"},405);
 if(req.headers.get("origin") && req.headers.get("origin")!==origin) return reply({error:"Origin not allowed"},403);
 const authorization=req.headers.get("authorization")||"";
 if(!authorization.startsWith("Bearer ")) return reply({error:"Sign in required"},401);
 try {
 const sb=createClient(Deno.env.get("SUPABASE_URL"),Deno.env.get("SUPABASE_ANON_KEY"),{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
 const user=await sb.auth.getUser(authorization.slice(7));
 if(user.error||!user.data.user) return reply({error:"Sign in required"},401);
 const mr=await sb.from("app_memberships").select("*").eq("user_id",user.data.user.id).maybeSingle();
 const m=mr.data;
 if(mr.error||!m||m.role!=="owner"||m.access_status!=="active"||m.deleted_at||!m.business_tools_enabled||!m.artist_member_enabled||!["paid","comped"].includes(m.payment_status)||(m.expires_at&&Date.parse(m.expires_at)<=Date.now())) return reply({error:"Active Owner access required"},403);
 const gate=await sb.rpc("owner_mfa_status");
 if(gate.error||gate.data?.allowed!==true) return reply({error:"Owner security verification required"},403);
 const key=Deno.env.get("CAL_COM_API_KEY")?.trim();
 if(!key) return reply({configured:false,verified:false,syncEnabled:false,message:"Add CAL_COM_API_KEY in Edge Function Secrets."});
 const response=await fetch("https://api.cal.com/v2/me",{headers:{Authorization:"Bearer "+key},redirect:"error",signal:AbortSignal.timeout(10000)});
 if(!response.ok) return reply({configured:true,verified:false,syncEnabled:false,error:response.status===401||response.status===403?"Cal.com rejected the key or its permissions.":"Cal.com is unavailable; try again later."},502);
 const profile=await response.json();
 if(profile.status!=="success"||profile.data?.username!=="bookleprokahn"||profile.data?.id!==2390745) return reply({configured:true,verified:false,syncEnabled:false,error:"Key does not match the configured Lions Rock Cal.com account."},409);
 let body;try{body=await req.json();}catch{return reply({error:"Invalid request"},400);}
 const action=body.action||"check";
 if(!["check","full-mix-duration","instrumental-creation"].includes(action))return reply({error:"Unknown action"},400);
 if(action==="instrumental-creation"){
   const base="https://api.cal.com/v2/event-types";
   const h={Authorization:"Bearer "+key,"cal-api-version":"2026-06-12","Content-Type":"application/json"};
   const listResponse=await fetch(base+"?username=bookleprokahn&eventSlug=instrumental-creation",{headers:h,redirect:"error",signal:AbortSignal.timeout(10000)});
   if(!listResponse.ok)return reply({error:"Cal.com event access could not be verified."},502);
   const listed=await listResponse.json();
   if(listed.status!=="success"||!Array.isArray(listed.data))return reply({error:"Unexpected event response; no event was created."},502);
   const existing=listed.data.filter(e=>e.slug==="instrumental-creation");
   let id;
   if(existing.length){
     if(existing.length!==1||existing[0].ownerId!==2390745||existing[0].lengthInMinutes!==180||existing[0].hidden!==true||existing[0].confirmationPolicy?.type!=="always"||existing[0].confirmationPolicy?.disabled===true)return reply({error:"An Instrumental creation event already exists with different settings. Review it in Cal.com; it was not changed."},409);
     id=existing[0].id;
   }else{
     const payload={title:"Instrumental creation",slug:"instrumental-creation",lengthInMinutes:180,hidden:true,confirmationPolicy:{type:"always",blockUnconfirmedBookingsInBooker:true,disabled:false},locations:[{type:"address",address:"Gunhill St.George",public:true}],description:"Three-hour instrumental creation session. Studio confirmation required. Service pricing and 50% deposit are managed through Lions Rock Studio OS."};
     const created=await fetch(base,{method:"POST",headers:h,body:JSON.stringify(payload),redirect:"error",signal:AbortSignal.timeout(10000)});
     if(!created.ok)return reply({error:"Event creation was not confirmed. Check Cal.com before trying again; no automatic retry was made."},502);
     const result=await created.json();id=result.data?.id;
     if(result.status!=="success"||!Number.isSafeInteger(id))return reply({error:"Event creation result is uncertain. Check Cal.com before trying again."},502);
   }
   const verifyResponse=await fetch(base+"/"+id,{headers:h,redirect:"error",signal:AbortSignal.timeout(10000)});
   if(!verifyResponse.ok)return reply({error:"Event may exist, but verification failed. Check Cal.com before trying again."},502);
   const verified=await verifyResponse.json(),event=verified.data;
   if(verified.status!=="success"||event?.slug!=="instrumental-creation"||event?.ownerId!==2390745||event?.lengthInMinutes!==180||event?.hidden!==true||event?.confirmationPolicy?.type!=="always"||event?.confirmationPolicy?.disabled===true)return reply({error:"Event settings could not be verified. Review the event in Cal.com."},502);
   return reply({verified:true,eventTypeId:id,syncEnabled:false,message:"Instrumental creation is verified at 3 hours, hidden from your public profile and requiring studio confirmation. OS pricing and deposits are not synchronized yet."});
 }
 if(action==="full-mix-duration"){
   const url="https://api.cal.com/v2/event-types/5500456";
   const h={Authorization:"Bearer "+key,"cal-api-version":"2026-06-12","Content-Type":"application/json"};
   const read=async()=>{const r=await fetch(url,{headers:h,redirect:"error",signal:AbortSignal.timeout(10000)});if(!r.ok)throw Error("read");const p=await r.json();if(p.status!=="success"||p.data?.id!==5500456||p.data?.slug!=="full-mix")throw Error("event");return p.data;};
   const before=await read();
   if(before.lengthInMinutes!==120){
     // Only the duration changes; all payment and booking settings are omitted.
     const changed=await fetch(url,{method:"PATCH",headers:h,body:JSON.stringify({lengthInMinutes:120}),redirect:"error",signal:AbortSignal.timeout(10000)});
     if(!changed.ok)return reply({error:"Cal.com could not update Full mix. Check event permissions; no automatic retry was made."},502);
   }
   const after=await read();
   if(after.lengthInMinutes!==120)return reply({error:"Duration could not be verified. Check Cal.com before retrying."},502);
   return reply({verified:true,syncEnabled:false,message:"Full mix is verified at 2 hours in Cal.com. Existing bookings and pricing were not changed."});
 }
 return reply({configured:true,verified:true,syncEnabled:false,username:"bookleprokahn",message:"Account access verified. Booking synchronization remains disabled."});
 } catch { return reply({error:"Connection check failed; try again later."},502); }
});
