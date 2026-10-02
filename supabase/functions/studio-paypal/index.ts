import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const ORIGIN="https://lions-rock-mail.vercel.app";
const jsonHeaders={"Content-Type":"application/json","Cache-Control":"no-store","Access-Control-Allow-Origin":ORIGIN,"Access-Control-Allow-Headers":"authorization, apikey, content-type, x-client-info","Access-Control-Allow-Methods":"POST, OPTIONS","Vary":"Origin"};
const reply=(body:any,status=200)=>new Response(JSON.stringify(body),{status,headers:jsonHeaders});
const money=(n:any)=>Number(Number(n).toFixed(2));
const mode=()=>Deno.env.get("PAYPAL_MODE")==="live"?"live":"sandbox";
const base=()=>mode()==="live"?"https://api-m.paypal.com":"https://api-m.sandbox.paypal.com";
const clientId=()=>Deno.env.get("PAYPAL_CLIENT_ID")?.trim()||"";
const secret=()=>Deno.env.get("PAYPAL_CLIENT_SECRET")?.trim()||Deno.env.get("PAYPAL_SECRET")?.trim()||"";
const webhookId=()=>Deno.env.get("PAYPAL_WEBHOOK_ID")?.trim()||"";
const chargeCurrency=()=>Deno.env.get("PAYPAL_CHARGE_CURRENCY")?.trim().toUpperCase()||"USD";
function fxRate(invoiceCurrency:string){
  const inv=invoiceCurrency.toUpperCase(),charge=chargeCurrency();
  if(inv===charge)return 1;
  if(inv==="BBD"&&charge==="USD"){
    const rate=Number(Deno.env.get("PAYPAL_FX_BBD_PER_USD"));
    if(Number.isFinite(rate)&&rate>0)return rate;
  }
  throw Error("paypal_currency_conversion_not_configured");
}
function secretKey(){
  const modern=Deno.env.get("SUPABASE_SECRET_KEYS");
  if(modern){try{const keys=JSON.parse(modern);if(keys.default)return keys.default;}catch{}}
  return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")||"";
}
async function token(){
  if(!clientId()||!secret())throw Error("paypal_not_configured");
  const auth=btoa(clientId()+":"+secret());
  const r=await fetch(base()+"/v1/oauth2/token",{method:"POST",headers:{Authorization:"Basic "+auth,"Content-Type":"application/x-www-form-urlencoded"},body:"grant_type=client_credentials",signal:AbortSignal.timeout(12000)});
  if(!r.ok)throw Error("paypal_auth_"+r.status);
  return (await r.json()).access_token;
}
async function paypal(path:string,method="GET",body?:any,requestId?:string){
  const t=await token();
  const r=await fetch(base()+path,{method,headers:{Authorization:"Bearer "+t,"Content-Type":"application/json",...(requestId?{"PayPal-Request-Id":requestId}:{}),"Prefer":"return=representation"},...(body!==undefined?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(15000)});
  let data:any={};try{data=await r.json();}catch{}
  if(!r.ok){console.error(JSON.stringify({component:"studio-paypal",stage:"paypal",path,status:r.status,name:data?.name,issue:data?.details?.[0]?.issue}));throw Error("paypal_http_"+r.status);}
  return data;
}
async function verifyWebhook(req:Request,raw:string){
  if(!webhookId())return false;
  const required={
    auth_algo:req.headers.get("paypal-auth-algo"),
    cert_url:req.headers.get("paypal-cert-url"),
    transmission_id:req.headers.get("paypal-transmission-id"),
    transmission_sig:req.headers.get("paypal-transmission-sig"),
    transmission_time:req.headers.get("paypal-transmission-time"),
    webhook_id:webhookId(),
    webhook_event:JSON.parse(raw)
  };
  if(!required.auth_algo||!required.cert_url||!required.transmission_id||!required.transmission_sig||!required.transmission_time)return false;
  const result=await paypal("/v1/notifications/verify-webhook-signature","POST",required);
  return result?.verification_status==="SUCCESS";
}
async function linkedInvoices(server:any,userId:string){
  const [bq,rq]=await Promise.all([
    server.from("studio_bookings").select("id").eq("user_id",userId),
    server.from("studio_instrumental_requests").select("invoice_id").eq("user_id",userId).not("invoice_id","is",null)
  ]);
  if(bq.error||rq.error)throw Error("invoice_links_unavailable");
  const bookingIds=(bq.data||[]).map((x:any)=>x.id);
  const requestInvoiceIds=(rq.data||[]).map((x:any)=>x.invoice_id);
  const docs:any[]=[];
  if(bookingIds.length){
    const r=await server.from("documents").select("id,doc_number,status,doc_date,due_date,currency,deposit_pct,total,amount_paid,balance_due,client_name,booking_id").in("booking_id",bookingIds).eq("doc_type","invoice");
    if(r.error)throw Error("booking_invoices_unavailable");docs.push(...(r.data||[]));
  }
  if(requestInvoiceIds.length){
    const r=await server.from("documents").select("id,doc_number,status,doc_date,due_date,currency,deposit_pct,total,amount_paid,balance_due,client_name,booking_id").in("id",requestInvoiceIds).eq("doc_type","invoice");
    if(r.error)throw Error("vault_invoices_unavailable");docs.push(...(r.data||[]));
  }
  const byId=new Map(docs.map(d=>[d.id,d]));
  return [...byId.values()].filter((d:any)=>!["draft","void"].includes(d.status)&&Number(d.balance_due)>0);
}
async function ownsInvoice(server:any,userId:string,invoiceId:string){
  const d=await server.from("documents").select("id,doc_number,status,currency,deposit_pct,total,amount_paid,balance_due,booking_id,client_name").eq("id",invoiceId).eq("doc_type","invoice").maybeSingle();
  if(d.error||!d.data)return null;
  let owned=false;
  if(d.data.booking_id){
    const b=await server.from("studio_bookings").select("id").eq("id",d.data.booking_id).eq("user_id",userId).maybeSingle();
    owned=!!b.data&&!b.error;
  }
  if(!owned){
    const r=await server.from("studio_instrumental_requests").select("id").eq("invoice_id",invoiceId).eq("user_id",userId).maybeSingle();
    owned=!!r.data&&!r.error;
  }
  return owned?d.data:null;
}
function portionAmount(d:any,portion:string){
  const total=money(d.total),paid=money(d.amount_paid),due=money(d.balance_due);
  if(portion==="deposit"){
    const target=money(total*Number(d.deposit_pct||0)/100);
    return money(Math.max(0,Math.min(due,target-paid)));
  }
  if(portion==="balance"||portion==="full")return due;
  throw Error("invalid_payment_portion");
}

Deno.serve(async req=>{
  if(req.method==="OPTIONS")return reply({ok:true});
  if(req.method!=="POST")return reply({error:"Method not allowed"},405);
  if(req.headers.get("origin")&&req.headers.get("origin")!==ORIGIN)return reply({error:"Origin not allowed"},403);

  const server=createClient(Deno.env.get("SUPABASE_URL")!,secretKey(),{auth:{persistSession:false,autoRefreshToken:false}});

  const transmission=req.headers.get("paypal-transmission-id");
  if(transmission){
    const raw=await req.text();
    if(raw.length>262144)return reply({error:"Payload too large"},413);
    try{
      if(!await verifyWebhook(req,raw))return reply({error:"Invalid PayPal signature"},401);
      const event=JSON.parse(raw),eventId=String(event.id||"");
      if(!eventId)return reply({ignored:true});
      const stored=await server.from("studio_paypal_events").insert({event_id:eventId,event_type:String(event.event_type||"unknown"),provider_resource_id:event.resource?.id?String(event.resource.id):null,payload:event});
      if(stored.error&&stored.error.code!=="23505")throw stored.error;
      if(stored.error?.code==="23505")return reply({duplicate:true});
      if(event.event_type==="PAYMENT.CAPTURE.COMPLETED"){
        const capture=event.resource,orderId=capture?.supplementary_data?.related_ids?.order_id;
        if(orderId){
          const ir=await server.from("studio_paypal_intents").select("*").eq("provider_order_id",orderId).maybeSingle();
          if(ir.data&&ir.data.status!=="captured"){
            const fee=Number(capture?.seller_receivable_breakdown?.paypal_fee?.value||0);
            const rr=await server.rpc("studio_record_paypal_capture",{paypal_intent_id:ir.data.id,capture_id:String(capture.id),captured_charge_amount:Number(capture.amount?.value),captured_charge_currency:String(capture.amount?.currency_code||""),provider_fee:fee,provider_payload:event});
            if(rr.error)throw rr.error;
          }
        }
      }
      return reply({ok:true});
    }catch(e){console.error(JSON.stringify({component:"studio-paypal",stage:"webhook",error:String(e?.message||e).slice(0,160)}));return reply({error:"PayPal webhook could not be reconciled"},503);}
  }

  const authorization=req.headers.get("authorization")||"";
  if(!authorization.startsWith("Bearer "))return reply({error:"Sign in required"},401);
  const accessToken=authorization.slice(7);
  const userResult=await server.auth.getUser(accessToken);
  const user=userResult.data.user;
  if(userResult.error||!user)return reply({error:"Sign in required"},401);

  const mr=await server.from("app_memberships").select("role,access_status,payment_status,expires_at,artist_member_enabled,is_minor,deleted_at").eq("user_id",user.id).maybeSingle();
  const m=mr.data;
  if(mr.error||!m||m.deleted_at||m.access_status!=="active"||!m.artist_member_enabled||!["paid","comped"].includes(m.payment_status)||(m.expires_at&&Date.parse(m.expires_at)<=Date.now()))return reply({error:"Active Artist access required"},403);
  if(m.is_minor)return reply({error:"Minor accounts cannot initiate payments. A guardian payment flow is required."},403);

  let body:any={};try{body=await req.json();}catch{}
  const action=body.action||"config";

  try{
    if(action==="config"){
      return reply({configured:!!(clientId()&&secret()),clientId:clientId()||null,mode:mode(),chargeCurrency:chargeCurrency()});
    }
    if(action==="list"){
      return reply({invoices:await linkedInvoices(server,user.id),configured:!!(clientId()&&secret()),mode:mode(),chargeCurrency:chargeCurrency()});
    }
    if(action==="create"){
      const invoiceId=String(body.invoiceId||""),portion=String(body.portion||"deposit");
      const d=await ownsInvoice(server,user.id,invoiceId);
      if(!d)return reply({error:"Invoice not available to this Artist"},403);
      if(["draft","void","paid"].includes(d.status)||Number(d.balance_due)<=0)return reply({error:"This invoice is not payable"},409);
      const amount=portionAmount(d,portion);
      if(amount<=0)return reply({error:portion==="deposit"?"The required deposit is already covered. Choose balance.":"Nothing remains to pay."},409);
      const rate=fxRate(d.currency),ccy=chargeCurrency(),charge=money(amount/rate);
      const existing=await server.from("studio_paypal_intents").select("*").eq("invoice_id",d.id).eq("artist_user_id",user.id).eq("portion",portion).eq("invoice_amount",amount).eq("status","created").order("created_at",{ascending:false}).limit(1).maybeSingle();
      if(existing.data?.provider_order_id)return reply({intentId:existing.data.id,orderId:existing.data.provider_order_id,amount,invoiceCurrency:d.currency,chargeAmount:existing.data.charge_amount,chargeCurrency:existing.data.charge_currency,mode:mode()});
      const created=await server.from("studio_paypal_intents").insert({invoice_id:d.id,artist_user_id:user.id,portion,invoice_amount:amount,invoice_currency:d.currency,charge_amount:charge,charge_currency:ccy,fx_rate:rate,status:"created"}).select("*").single();
      if(created.error)throw created.error;
      const i=created.data;
      let order;
      try{
        order=await paypal("/v2/checkout/orders","POST",{intent:"CAPTURE",purchase_units:[{reference_id:d.doc_number,custom_id:i.id,description:("Lions Rock "+d.doc_number).slice(0,127),amount:{currency_code:ccy,value:charge.toFixed(2)}}],application_context:{shipping_preference:"NO_SHIPPING"}},i.id);
      }catch(e){await server.from("studio_paypal_intents").update({status:"failed"}).eq("id",i.id);throw e;}
      const saved=await server.from("studio_paypal_intents").update({provider_order_id:order.id}).eq("id",i.id);
      if(saved.error)throw saved.error;
      return reply({intentId:i.id,orderId:order.id,amount,invoiceCurrency:d.currency,chargeAmount:charge,chargeCurrency:ccy,mode:mode()});
    }
    if(action==="capture"){
      const intentId=String(body.intentId||""),orderId=String(body.orderId||"");
      const ir=await server.from("studio_paypal_intents").select("*").eq("id",intentId).eq("artist_user_id",user.id).maybeSingle();
      const i=ir.data;
      if(ir.error||!i)return reply({error:"Payment intent not found"},404);
      if(i.status==="captured")return reply({ok:true,idempotent:true});
      if(!i.provider_order_id||i.provider_order_id!==orderId)return reply({error:"PayPal order mismatch"},409);
      const d=await ownsInvoice(server,user.id,i.invoice_id);
      if(!d)return reply({error:"Invoice no longer belongs to this Artist"},403);
      if(d.currency!==i.invoice_currency||Number(d.balance_due)<Number(i.invoice_amount))return reply({error:"Invoice changed. Refresh before paying."},409);
      const result=await paypal("/v2/checkout/orders/"+encodeURIComponent(orderId)+"/capture","POST",{},("cap-"+i.id).slice(0,108));
      const cap=result?.purchase_units?.[0]?.payments?.captures?.[0];
      if(!cap||cap.status!=="COMPLETED")return reply({error:"PayPal did not return a completed capture"},409);
      const custom=result?.purchase_units?.[0]?.custom_id;
      if(custom!==i.id)return reply({error:"PayPal reference mismatch"},409);
      const captured=Number(cap.amount?.value),ccy=String(cap.amount?.currency_code||"");
      if(ccy!==i.charge_currency||Math.abs(captured-Number(i.charge_amount))>0.01)return reply({error:"PayPal amount or currency mismatch"},409);
      const fee=Number(cap?.seller_receivable_breakdown?.paypal_fee?.value||0);
      const rr=await server.rpc("studio_record_paypal_capture",{paypal_intent_id:i.id,capture_id:String(cap.id),captured_charge_amount:captured,captured_charge_currency:ccy,provider_fee:fee,provider_payload:result});
      if(rr.error)throw rr.error;
      return reply({ok:true,idempotent:rr.data?.idempotent===true,receiptNumber:rr.data?.payment?.receipt_number||null});
    }
    return reply({error:"Unknown action"},400);
  }catch(e){
    const message=String(e?.message||e);
    console.error(JSON.stringify({component:"studio-paypal",stage:action,error:message.slice(0,180)}));
    if(message.includes("paypal_not_configured"))return reply({error:"PayPal sandbox is not configured yet."},503);
    if(message.includes("paypal_currency_conversion_not_configured"))return reply({error:"PayPal currency conversion is not configured for this invoice."},503);
    if(message.startsWith("paypal_http_"))return reply({error:"PayPal could not complete this step. Check the order status before retrying."},503);
    return reply({error:"PayPal payment could not be completed. Refresh and check the invoice before retrying."},503);
  }
});