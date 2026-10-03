(function(){
"use strict";

const URL="https://xsvczfqvscnvmngwcmtp.supabase.co";
const KEY="sb_publishable_ZQGFWpZzlDsWBRclrySAyg_CYWqvU40";
let client=null,settings=null,enabled=false,wasEnabled=false,authListenerBound=false;
function esc(s){return String(s==null?"":s).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));}
function q(root,sel){try{return root&&root.querySelector(sel)}catch(_){return null}}
function qa(root,sel){try{return [...root.querySelectorAll(sel)]}catch(_){return[]}}
function validColor(v,fallback){return /^#[0-9a-f]{6}$/i.test(String(v||""))?String(v):fallback;}
function ensureClient(){
  if(!client&&window.supabase)client=window.supabase.createClient(URL,KEY,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:false}});
  return client;
}
async function loadSettings(){
  try{
    const sb=ensureClient();if(!sb)return null;
    const s=await sb.auth.getSession();const uid=s.data?.session?.user?.id;if(!uid)return null;
    const r=await sb.from("business_settings").select("*").eq("user_id",uid).maybeSingle();
    if(!r.error&&r.data)settings=r.data;
  }catch(e){console.warn("Business settings:",e);}
  return settings;
}
async function saveColors(accent,header){
  try{
    const sb=ensureClient();if(!sb)return;
    const s=await sb.auth.getSession();const uid=s.data?.session?.user?.id;if(!uid)return;
    accent=validColor(accent,"#C24D2C");header=validColor(header,"#111111");
    const r=await sb.from("business_settings").update({invoice_accent_color:accent,invoice_header_color:header,updated_at:new Date().toISOString()}).eq("user_id",uid);
    if(r.error)throw r.error;
    settings=Object.assign({},settings||{},{invoice_accent_color:accent,invoice_header_color:header});
  }catch(e){console.warn("Save business colors:",e);}
}
async function saveEmailBranding(footer,logo){
  try{
    const sb=ensureClient();if(!sb)return;
    const s=await sb.auth.getSession();const uid=s.data?.session?.user?.id;if(!uid)return;
    const payload={email_footer:String(footer||"").trim(),updated_at:new Date().toISOString()};
    if(typeof logo==="string")payload.logo_data=logo;
    const r=await sb.from("business_settings").update(payload).eq("user_id",uid);
    if(r.error)throw r.error;
    settings=Object.assign({},settings||{},payload);
  }catch(e){console.warn("Save business email branding:",e);throw e;}
}
function addStyle(doc,id,css){
  if(!doc||doc.getElementById(id))return;
  const s=doc.createElement("style");s.id=id;s.textContent=css;doc.head.appendChild(s);
}
function applyInvoiceColors(win){
  if(!win||!win.document)return;
  const doc=win.document;
  const accent=validColor((win.STORE?.settings?.invoice_accent_color)||settings?.invoice_accent_color,"#C24D2C");
  const header=validColor((win.STORE?.settings?.invoice_header_color)||settings?.invoice_header_color,"#111111");
  qa(doc,"#preview .preview-header").forEach(x=>x.style.borderBottomColor=accent);
  qa(doc,"#preview .doc-type,#preview .total-final .amount").forEach(x=>x.style.color=accent);
  qa(doc,"#preview .preview-table th,#preview .total-final").forEach(x=>x.style.backgroundColor=header);
  qa(doc,"#preview .deposit-note").forEach(x=>{x.style.color=accent;x.style.borderColor=accent;});
  qa(doc,"#preview .terms").forEach(x=>x.style.borderLeftColor=accent);
}
function installDocs(frame){
  const win=frame?.contentWindow,doc=frame?.contentDocument;if(!win||!doc||doc.documentElement.dataset.businessNeutral==="1")return;
  doc.documentElement.dataset.businessNeutral="1";
  addStyle(doc,"business-neutral-doc-style",`
    .business-color-row{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:11px}
    .business-color-swatch{display:grid;grid-template-columns:54px 1fr;gap:10px;align-items:center}
    .business-color-swatch input[type=color]{width:54px;height:38px;padding:2px}
    .service-field-head{display:grid;grid-template-columns:1.1fr 1.6fr 100px 38px;gap:7px;margin:0 0 7px;padding:0 2px;font-size:.62rem;letter-spacing:.12em;text-transform:uppercase;color:var(--muted);font-weight:700}
    @media(max-width:600px){.business-color-row{grid-template-columns:1fr}.service-field-head{display:none}}
  `);
  const serviceList=doc.getElementById("service-settings-list");
  if(serviceList&&!doc.getElementById("service-field-head")){
    const h=doc.createElement("div");h.id="service-field-head";h.className="service-field-head";
    h.innerHTML="<span>Service Name</span><span>Description</span><span>Price</span><span></span>";
    serviceList.parentNode.insertBefore(h,serviceList);
    const note=doc.createElement("div");note.className="mini";note.style.marginBottom="8px";note.textContent="Name each service, add an optional description, then set the price.";
    h.parentNode.insertBefore(note,h);
  }
  const logoInput=doc.getElementById("set-logo-file"),logoField=logoInput?.closest(".field");
  if(logoField&&!doc.getElementById("business-email-footer")){
    const logoHint=logoField.querySelector(".mini");if(logoHint)logoHint.textContent="Your logo is used on both invoices and Business emails. Leave blank for no logo.";
    const field=doc.createElement("div");field.className="field";field.innerHTML='<label for="business-email-footer">Email Footer (Optional)</label><textarea id="business-email-footer" rows="3" maxlength="1200" placeholder="e.g. Thank you for your business · phone · website"></textarea><div class="mini" style="margin-top:6px;">Appears at the bottom of Business emails. Leave blank for no footer.</div>';
    logoField.parentNode.insertBefore(field,logoField.nextSibling);
    const footer=doc.getElementById("business-email-footer");footer.value=settings?.email_footer||"";
    footer.addEventListener("input",()=>{const st=doc.getElementById("settings-save-status");if(st){st.textContent="Unsaved changes";st.className="settings-save-status dirty";}});
    doc.getElementById("save-settings-btn")?.addEventListener("click",()=>setTimeout(async()=>{
      try{
        const logo=win.STORE?.settings?.logo_data||"";
        await saveEmailBranding(footer.value,logo);
        const st=doc.getElementById("settings-save-status");if(st){st.textContent="Saved ✓";st.className="settings-save-status saved";}
        const mail=document.getElementById("mail-frame");if(mail?.contentWindow&&enabled){try{mail.contentWindow.renderPreview?.();}catch(_){}}
      }catch(_){
        const st=doc.getElementById("settings-save-status");if(st){st.textContent="Could not save email branding";st.className="settings-save-status dirty";}
      }
    },70));
  }
  const currency=doc.getElementById("set-currency");
  if(currency&&!doc.getElementById("business-color-row")){
    const row=doc.createElement("div");row.id="business-color-row";row.className="business-color-row";
    const accent=validColor(settings?.invoice_accent_color,"#C24D2C");
    const header=validColor(settings?.invoice_header_color,"#111111");
    row.innerHTML='<div class="field"><label>Invoice Accent Color</label><div class="business-color-swatch"><input id="business-accent-color" type="color" value="'+accent+'"><span class="mini">Headings, rules and highlights</span></div></div>'+
      '<div class="field"><label>Invoice Header Color</label><div class="business-color-swatch"><input id="business-header-color" type="color" value="'+header+'"><span class="mini">Table and total blocks</span></div></div>';
    const anchor=currency.closest(".field-row");anchor?.parentNode?.insertBefore(row,anchor);
    const ac=doc.getElementById("business-accent-color"),hc=doc.getElementById("business-header-color");
    function localApply(){
      if(win.STORE?.settings){win.STORE.settings.invoice_accent_color=ac.value;win.STORE.settings.invoice_header_color=hc.value;}
      applyInvoiceColors(win);
      const st=doc.getElementById("settings-save-status");if(st){st.textContent="Unsaved changes";st.className="settings-save-status dirty";}
    }
    ac?.addEventListener("input",localApply);hc?.addEventListener("input",localApply);
    doc.getElementById("save-settings-btn")?.addEventListener("click",()=>setTimeout(async()=>{
      if(win.STORE?.settings){win.STORE.settings.invoice_accent_color=ac.value;win.STORE.settings.invoice_header_color=hc.value;try{win.saveStore?.();}catch(_){}}
      await saveColors(ac.value,hc.value);applyInvoiceColors(win);
      const st=doc.getElementById("settings-save-status");if(st){st.textContent="Saved ✓";st.className="settings-save-status saved";}
    },40));
  }
  const rename=[["Client Name / Artist","Client Name"],["Project / Song","Work / Reference"],["— No project —","— No work reference —"]];
  qa(doc,"label,option,.panel-title,.section-label").forEach(el=>{rename.forEach(([a,b])=>{if(el.textContent.trim()===a)el.textContent=b;});});
  if(win.STORE?.settings){
    win.STORE.settings.invoice_accent_color=validColor(settings?.invoice_accent_color,"#C24D2C");
    win.STORE.settings.invoice_header_color=validColor(settings?.invoice_header_color,"#111111");
  }
  if(typeof win.renderPreview==="function"&&!win.renderPreview.__businessWrapped){
    const orig=win.renderPreview;
    const wrapped=function(){const r=orig.apply(win,arguments);applyInvoiceColors(win);return r;};
    wrapped.__businessWrapped=true;win.renderPreview=wrapped;
  }
  try{win.renderPreview?.();}catch(_){}
}
function neutralEmailHtml(win){
  const d=win.document;
  const val=id=>d.getElementById(id)?.value||"";
  const accent=validColor(val("accent-color")||settings?.invoice_accent_color,"#C24D2C");
  const subject=val("subject"),greeting=val("greeting"),body=val("body"),signoff=val("signoff");
  const sender=val("senderName"),title=val("senderTitle");
  const business=(settings?.business_name||sender||"").trim();
  const logo=String(settings?.logo_data||"").trim(),footer=String(settings?.email_footer||"").trim();
  const paragraphs=esc(body).split(/\n{2,}/).map(x=>'<p style="margin:0 0 16px;font-size:16px;line-height:1.65;color:#222">'+x.replace(/\n/g,"<br>")+"</p>").join("");
  return '<!doctype html><html><body style="margin:0;padding:0;background:#f5f5f5;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Arial,sans-serif;color:#222">'+
    '<table role="presentation" width="100%" cellspacing="0" cellpadding="0"><tr><td align="center" style="padding:28px 12px">'+
    '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:620px;background:#fff;border:1px solid #e7e7e7">'+
    '<tr><td style="height:5px;background:'+accent+'"></td></tr>'+
    '<tr><td style="padding:32px">'+
    (logo?'<div style="margin-bottom:18px"><img src="'+esc(logo)+'" alt="'+esc(business||"Business")+' logo" style="display:block;max-width:120px;max-height:72px;width:auto;height:auto"></div>':'')+
    (business?'<div style="font-size:12px;font-weight:700;letter-spacing:.12em;text-transform:uppercase;color:#555;margin-bottom:22px">'+esc(business)+'</div>':'')+
    (subject?'<div style="font-family:Georgia,serif;font-size:28px;line-height:1.2;margin-bottom:20px;color:#111">'+esc(subject)+'</div>':'')+
    (greeting?'<div style="font-size:16px;line-height:1.6;margin-bottom:16px">'+esc(greeting)+'</div>':'')+
    paragraphs+
    (signoff?'<div style="font-size:16px;line-height:1.6;margin-top:20px">'+esc(signoff)+'</div>':'')+
    (sender?'<div style="font-weight:700;margin-top:14px">'+esc(sender)+'</div>':'')+
    (title?'<div style="font-size:13px;color:#777;margin-top:3px">'+esc(title)+'</div>':'')+
    (footer?'<div style="margin-top:28px;padding-top:16px;border-top:1px solid #e7e7e7;font-size:11px;line-height:1.55;color:#777">'+esc(footer).replace(/\n/g,"<br>")+'</div>':'')+
    '</td></tr></table></td></tr></table></body></html>';
}
function neutralMailPreview(win){
  const d=win.document,root=d.getElementById("preview-root");if(!root)return;
  const val=id=>d.getElementById(id)?.value||"";
  const accent=validColor(val("accent-color")||settings?.invoice_accent_color,"#C24D2C");
  const business=(settings?.business_name||val("senderName")||"").trim(),logo=String(settings?.logo_data||"").trim(),footer=String(settings?.email_footer||"").trim();
  root.innerHTML='<div class="ep"><div class="ep-box"><div class="ep-accent" style="background:'+accent+'"></div>'+
    (logo?'<div style="padding:18px 22px 4px"><img src="'+esc(logo)+'" alt="'+esc(business||"Business")+' logo" style="max-width:92px;max-height:58px;width:auto;height:auto"></div>':'')+
    '<div style="padding:22px 22px 8px;font-size:10px;letter-spacing:.18em;text-transform:uppercase;color:#666">'+esc(business)+'</div>'+
    '<div class="ep-subject">'+esc(val("subject"))+'</div><div class="ep-greet">'+esc(val("greeting"))+'</div>'+
    '<div class="ep-body"><p>'+esc(val("body")).replace(/\n/g,"<br>")+'</p></div>'+
    '<div class="ep-sign"><p>'+esc(val("signoff"))+'</p><div class="ep-sign-name">'+esc(val("senderName"))+'</div><div class="ep-sign-title">'+esc(val("senderTitle"))+'</div></div>'+
    (footer?'<div style="margin:0 22px 22px;padding-top:12px;border-top:1px solid #ddd;font-size:10px;line-height:1.5;color:#777">'+esc(footer).replace(/\n/g,"<br>")+'</div>':'')+
    '</div></div>';
}
function installMail(frame){
  const win=frame?.contentWindow,doc=frame?.contentDocument;if(!win||!doc||doc.documentElement.dataset.businessNeutral==="1")return;
  doc.documentElement.dataset.businessNeutral="1";
  addStyle(doc,"business-neutral-mail-style",`
    .business-neutral-hidden{display:none!important}
  `);
  const tpl=doc.getElementById("template-select");
  if(tpl){
    [...tpl.options].forEach(o=>{if(!["blank","custom"].includes(o.value))o.remove();});
    tpl.value="blank";
  }
  qa(doc,"label").forEach(el=>{if(el.textContent.trim()==="Studio Client")el.textContent="Client";});
  const clientHint=q(doc,"#studio-client-select")?.closest(".field")?.querySelector(".panel-hint");
  if(clientHint)clientHint.textContent="Selecting a client fills the recipient email and first name from your client directory.";
  const music=doc.getElementById("music-input");if(music)music.accept="*/*";
  const musicBtn=doc.getElementById("music-btn");if(musicBtn)musicBtn.textContent="＋ Add attachments";
  const empty=q(doc,"#tracks-empty");if(empty){
    const last=empty.lastElementChild;if(last)last.textContent="Attach PDFs, images, documents, or other files · up to 20 MB total";
  }
  const logoBtn=doc.getElementById("logo-replace-btn");const logoPanel=logoBtn?.closest(".panel");if(logoPanel){const title=logoPanel.querySelector(".panel-title");if(title)title.textContent="Business Email Logo";const hint=logoPanel.querySelector(".panel-hint");if(hint)hint.textContent="Managed in Business Settings. This logo appears at the top of Business emails.";if(logoBtn)logoBtn.classList.add("business-neutral-hidden");doc.getElementById("logo-reset-btn")?.classList.add("business-neutral-hidden");const thumb=doc.getElementById("logo-thumb");if(thumb&&settings?.logo_data)thumb.src=settings.logo_data;}
  const sigBtn=doc.getElementById("sig-replace-btn");const sigPanel=sigBtn?.closest(".panel");if(sigPanel)sigPanel.classList.add("business-neutral-hidden");
  const sender=doc.getElementById("senderName"),title=doc.getElementById("senderTitle");
  if(sender)sender.value=settings?.business_name||"";
  if(title)title.value="";
  const ac=doc.getElementById("accent-color"),hx=doc.getElementById("accent-hex"),color=validColor(settings?.invoice_accent_color,"#C24D2C");
  if(ac)ac.value=color;if(hx)hx.value=color;
  ["subject","preheader","greeting","body","signoff"].forEach(id=>{const e=doc.getElementById(id);if(e&&!e.dataset.businessInitial){e.dataset.businessInitial="1";if(!e.value)e.value="";}});
  if(typeof win.buildEmailHtml==="function")win.buildEmailHtml=function(){return neutralEmailHtml(win);};
  if(typeof win.renderPreview==="function")win.renderPreview=function(){return neutralMailPreview(win);};
  try{win.renderPreview();}catch(_){}
}
function replaceTextNodes(root,replacements){
  if(!root)return;
  const walker=root.ownerDocument.createTreeWalker(root,NodeFilter.SHOW_TEXT);
  let n;while((n=walker.nextNode())){let t=n.nodeValue;let changed=false;for(const [a,b] of replacements){if(t.includes(a)){t=t.split(a).join(b);changed=true;}}if(changed)n.nodeValue=t;}
}
function installHub(frame){
  const doc=frame?.contentDocument;if(!doc||doc.documentElement.dataset.businessNeutral==="1")return;
  doc.documentElement.dataset.businessNeutral="1";
  const reps=[
    ["Name / Artist","Client Name"],
    ["Project / Song Name","Work / Reference"],
    ["Project / Song","Work / Reference"],
    ["Songs, productions and studio work tied to the client and billing trail.","Work records, notes and billing documents tied to the client."],
    ["Every client, their projects, documents and account activity in one place.","Every client, their work, documents and account activity in one place."],
    ["Projects","Work"],
    ["Project Notes","Work Notes"],
    ["No projects yet.","No work records yet."],
    ["+ Project","+ Work"],
    ["No project","No work reference"]
  ];
  const apply=()=>replaceTextNodes(doc.body,reps);apply();
  const ob=new MutationObserver(()=>apply());ob.observe(doc.body,{subtree:true,childList:true});
}
function applyShellNeutral(){
  if(!enabled)return;
  const nav=document.querySelector('#nav button[data-app="hub"][data-view="projects"]');if(nav)nav.textContent="Work";
  const search=document.getElementById("global-search");if(search)search.placeholder="Search clients, work, documents…";
}
async function apply(opts){
  const next=!!opts?.enabled;
  if(!next&&wasEnabled){location.reload();return;}
  enabled=next;if(!enabled)return;
  wasEnabled=true;
  await loadSettings();
  applyShellNeutral();
  installDocs(document.getElementById("docs-frame"));
  installMail(document.getElementById("mail-frame"));
  installHub(document.getElementById("hub-frame"));
}
function onFrameLoad(id,type){
  const frame=document.getElementById(id);if(!frame)return;
  frame.addEventListener("load",()=>{if(!enabled)return;setTimeout(()=>{if(type==="docs")installDocs(frame);if(type==="mail")installMail(frame);if(type==="hub")installHub(frame);},80);});
}
onFrameLoad("docs-frame","docs");onFrameLoad("mail-frame","mail");onFrameLoad("hub-frame","hub");
window.LionsRockBusinessTools={apply};
async function selfStart(){
  try{
    const sb=ensureClient();if(!sb)return;
    if(!authListenerBound){
      authListenerBound=true;
      sb.auth.onAuthStateChange(()=>setTimeout(selfStart,120));
    }
    const s=await sb.auth.getSession();const user=s.data?.session?.user;if(!user)return;
    const m=await sb.from("app_memberships").select("role,access_status,business_tools_enabled").eq("user_id",user.id).maybeSingle();
    const mode=localStorage.getItem("lions-rock-access-mode")||"business_tools";
    await apply({enabled:!m.error&&m.data?.role!=="owner"&&m.data?.access_status==="active"&&m.data?.business_tools_enabled===true&&mode==="business_tools"});
  }catch(e){console.warn("Business neutral startup:",e);}
}
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",()=>setTimeout(selfStart,120));else setTimeout(selfStart,120);
})();