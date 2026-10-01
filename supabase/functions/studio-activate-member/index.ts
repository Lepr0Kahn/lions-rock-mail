import "jsr:@supabase/functions-js/edge-runtime.d.ts";
const APP_ORIGIN="https://lions-rock-mail.vercel.app";
Deno.serve(async(req)=>{
  const origin=req.headers.get("origin");
  const headers={
    "Access-Control-Allow-Origin":origin===APP_ORIGIN?origin:APP_ORIGIN,
    "Access-Control-Allow-Headers":"authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods":"POST, OPTIONS",
    "Vary":"Origin",
    "Content-Type":"application/json"
  };
  if(req.method==="OPTIONS")return new Response("ok",{headers});
  return new Response(JSON.stringify({
    error:"Legacy application activation is closed. Create a private invite from Access Administration."
  }),{status:410,headers});
});