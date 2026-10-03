/* Optional authenticator setup. Enforcement is deliberately separate. */
function installAdminSecurity(sb, content, requireOwner, toast) {
 let generation=0, pending=null;
 const current=n=>n===generation;
 const withTimeout=async(promise,label,ms=12000)=>{let timer;const timeout=new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(label+" took too long. Refresh to retry.")),ms);});try{return await Promise.race([promise,timeout]);}finally{clearTimeout(timer);}};
 function leave(){generation++;pending=null;}
 async function show(){
  const n=++generation;pending=null;
  content.innerHTML='<div class="empty">Checking security…</div>';
  try {
   if(!await requireOwner()||!current(n))return;
   const [f,a,s]=await withTimeout(Promise.all([sb.auth.mfa.listFactors(),sb.auth.mfa.getAuthenticatorAssuranceLevel(),sb.rpc('owner_mfa_status')]),"Security check");
   if(!current(n))return;if(f.error)throw f.error;if(a.error)throw a.error;if(s.error)throw s.error;
   const factors=f.data.totp||[],required=!!s.data?.required,aal2=a.data.currentLevel==='aal2';
   content.innerHTML='<h2>Admin Security</h2><p>Enroll a primary and a separate backup authenticator before enabling Owner MFA enforcement. Enforcement remains off until you explicitly enable it after verifying this session.</p><p id="mfa-status" role="status" aria-live="polite"></p><div id="mfa-actions"></div><div id="mfa-setup"></div>';
   content.querySelector('#mfa-status').textContent='Enforcement: '+(required?'ON':'OFF')+' · Verified authenticators: '+factors.length+' · Session: '+(aal2?'MFA verified (aal2)':'password/sign-in only (aal1)')+'.';
   const actions=content.querySelector('#mfa-actions');
   if(factors.length){factors.forEach(f=>{const b=document.createElement('button');b.className='btn';b.textContent='Verify '+(f.friendly_name||'authenticator');b.onclick=()=>codeForm(f.id,n,false);actions.appendChild(b);});}
   else {const b=document.createElement('button');b.className='btn primary';b.textContent='Set up authenticator';b.onclick=()=>enroll(n,b);actions.appendChild(b);}
   if(factors.length&&aal2){const backup=document.createElement('button');backup.className='btn';backup.textContent=factors.length<2?'Add backup authenticator':'Add another authenticator';backup.onclick=()=>enroll(n,backup);actions.appendChild(backup);}
   if(aal2&&factors.length>=2&&!required){const enable=document.createElement('button');enable.className='btn primary';enable.textContent='Enable Owner MFA enforcement';enable.onclick=async()=>{if(!confirm('Enable Owner MFA enforcement? Future Owner management sessions will require a verified authenticator. Confirm that your primary and backup authenticators are stored separately before continuing.'))return;enable.disabled=true;try{const r=await sb.rpc('configure_owner_mfa',{enable:true});if(r.error)throw r.error;toast('Owner MFA enforcement enabled.');await show();}catch(e){enable.disabled=false;toast(e.message||'Could not enable MFA enforcement.',true);}};actions.appendChild(enable);}
   if(aal2&&required){const disable=document.createElement('button');disable.className='btn red';disable.textContent='Disable Owner MFA enforcement';disable.onclick=async()=>{if(!confirm('Disable Owner MFA enforcement? Authenticator factors will remain enrolled, but management sessions will no longer require MFA.'))return;disable.disabled=true;try{const r=await sb.rpc('configure_owner_mfa',{enable:false});if(r.error)throw r.error;toast('Owner MFA enforcement disabled.');await show();}catch(e){disable.disabled=false;toast(e.message||'Could not disable MFA enforcement.',true);}};actions.appendChild(disable);}
   if(!required&&factors.length<2){const readiness=document.createElement('p');readiness.textContent='Before enforcement can be enabled: verify '+(factors.length?'one separate backup authenticator.':'a primary authenticator and one separate backup authenticator.');actions.appendChild(readiness);}
   const note=document.createElement('p');note.textContent='Recovery: keep the backup authenticator on a separate device or securely stored separately. A password reset does not remove MFA. If every authenticator is lost, there is no email-only bypass.';actions.appendChild(note);
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
