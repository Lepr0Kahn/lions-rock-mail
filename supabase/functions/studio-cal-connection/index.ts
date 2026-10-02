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
 return reply({configured:true,verified:true,syncEnabled:false,username:"bookleprokahn",message:"Account access verified. Booking synchronization remains disabled."});
 } catch { return reply({error:"Connection check failed; try again later."},502); }
});
