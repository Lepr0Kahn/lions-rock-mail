/* Optional authenticator setup. Enforcement is deliberately separate. */
function installAdminSecurity(sb, content, requireOwner, toast) {
 let generation=0, pending=null;
 const current=n=>n===generation;
 function leave(){generation++;pending=null;}
 async function show(){
  const n=++generation;pending=null;
  content.innerHTML='<div class="empty">Checking security…</div>';
  try {
   if(!await requireOwner()||!current(n))return;
   const [f,a]=await Promise.all([sb.auth.mfa.listFactors(),sb.auth.mfa.getAuthenticatorAssuranceLevel()]);
   if(!current(n))return;if(f.error)throw f.error;if(a.error)throw a.error;
   const factors=f.data.totp||[];
   content.innerHTML='<h2>Admin Security</h2><p>Use an authenticator app to verify this session. Setup is optional for now; management-wide MFA enforcement is not enabled.</p><p id="mfa-status"></p><div id="mfa-actions"></div><div id="mfa-setup"></div>';
   content.querySelector('#mfa-status').textContent=a.data.currentLevel==='aal2'?'This session has passed MFA verification.':factors.length?'An authenticator is enrolled. Verify this session below.':'No verified authenticator is enrolled.';
   const actions=content.querySelector('#mfa-actions');
   if(factors.length){factors.forEach(f=>{const b=document.createElement('button');b.className='btn';b.textContent='Verify '+(f.friendly_name||'authenticator');b.onclick=()=>codeForm(f.id,n,false);actions.appendChild(b);});}
   else {const b=document.createElement('button');b.className='btn primary';b.textContent='Set up authenticator';b.onclick=()=>enroll(n,b);actions.appendChild(b);}
   if(factors.length&&a.data.currentLevel==='aal2'){const backup=document.createElement('button');backup.className='btn';backup.textContent='Add backup authenticator';backup.onclick=()=>enroll(n,backup);actions.appendChild(backup);}
   const note=document.createElement('p');note.textContent='Recovery: enroll and verify a backup authenticator on a separate device. A password reset does not remove MFA. If every device is lost, recovery requires verified assistance from the Supabase project administrator; there is no email-only bypass.';actions.appendChild(note);
   (f.data.all||[]).filter(f=>f.status==='unverified'&&f.factor_type==='totp').forEach(f=>{const cancel=document.createElement('button');cancel.className='btn';cancel.textContent='Remove unfinished setup';cancel.onclick=async()=>{cancel.disabled=true;try{if(!await requireOwner()||!current(n))return;const r=await sb.auth.mfa.unenroll({factorId:f.id});if(r.error)throw r.error;if(current(n))await show();}catch(e){if(current(n)){cancel.disabled=false;toast(e.message||'Could not remove unfinished setup.',true);}}};actions.appendChild(cancel);});
  }catch(e){if(current(n)){content.innerHTML='<div class="empty">Could not load authenticator settings. Refresh to retry.</div>';toast(e.message||'Security settings unavailable.',true);}}
 }
 async function enroll(n,b){
  b.disabled=true;
  try{
   if(!await requireOwner()||!current(n))return;
   const r=await sb.auth.mfa.enroll({factorType:'totp',friendlyName:'Lions Rock Admin '+new Date().toISOString()});
   if(r.error)throw r.error;
   if(!current(n))return;
   pending=r.data.id;
   codeForm(r.data.id,n,true,r.data.totp);
  }catch(e){if(current(n))toast(e.message||'Could not enroll authenticator.',true);}
  finally{if(current(n))b.disabled=false;}
 }
 function codeForm(id,n,setup,totp){
  if(!current(n))return;
  const area=content.querySelector('#mfa-setup');area.replaceChildren();
  if(setup){
   const p=document.createElement('p');p.textContent='Scan this QR code in your authenticator app, then enter its six-digit code. Keep the setup key private.';area.appendChild(p);
   const img=document.createElement('img');img.alt='Authenticator enrollment QR code';img.width=200;
   img.src=totp.qr_code.startsWith('data:image/')?totp.qr_code:'data:image/svg+xml;charset=utf-8,'+encodeURIComponent(totp.qr_code);area.appendChild(img);
   const key=document.createElement('input');key.readOnly=true;key.value=totp.secret;key.setAttribute('aria-label','Private authenticator setup key');area.appendChild(key);
  }
  const form=document.createElement('form');const input=document.createElement('input');input.inputMode='numeric';input.autocomplete='one-time-code';input.pattern='[0-9]{6}';input.maxLength=6;input.required=true;input.setAttribute('aria-label','Six-digit authenticator code');
  const verify=document.createElement('button');verify.className='btn primary';verify.type='submit';verify.textContent=setup?'Verify setup':'Verify session';form.append(input,verify);area.appendChild(form);
  form.onsubmit=async e=>{e.preventDefault();if(!/^[0-9]{6}$/.test(input.value)){toast('Enter a six-digit code.',true);return;}verify.disabled=true;
   try{if(!await requireOwner()||!current(n))return;const c=await sb.auth.mfa.challenge({factorId:id});if(c.error)throw c.error;if(!current(n))return;const r=await sb.auth.mfa.verify({factorId:id,challengeId:c.data.id,code:input.value});if(r.error)throw r.error;if(!current(n))return;pending=null;input.value='';toast('Authenticator verified.');await show();}
   catch(e){if(current(n)){input.value='';toast(e.message||'Verification failed. Try the next code.',true);}}
   finally{if(current(n))verify.disabled=false;}
  };
  if(setup){const cancel=document.createElement('button');cancel.className='btn';cancel.textContent='Cancel setup';cancel.onclick=async()=>{cancel.disabled=true;try{if(!await requireOwner()||!current(n)||pending!==id)return;const r=await sb.auth.mfa.unenroll({factorId:id});if(r.error)throw r.error;if(current(n)){pending=null;await show();}}catch(e){if(current(n)){cancel.disabled=false;toast(e.message||'Could not cancel setup.',true);}}};area.appendChild(cancel);}
 }
 return {show,leave};
}
