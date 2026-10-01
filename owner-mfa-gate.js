async function ownerMfaGate(sb,showGateSection,resume,isCurrent){
 const status=await sb.rpc('owner_mfa_status');if(!isCurrent())return false;
 if(status.error)throw Error('Could not check management security. Retry sign-in.');
 if(!status.data.required||status.data.allowed)return true;
 showGateSection('mfa-view');
 const root=document.getElementById('mfa-factors'),out=document.getElementById('mfa-status');root.replaceChildren();out.textContent='Verify your primary or backup authenticator to open management.';
 const factors=await sb.auth.mfa.listFactors();if(!isCurrent())return false;if(factors.error)throw factors.error;
 const verified=factors.data.totp||[];
 verified.forEach(f=>{const form=document.createElement('form'),label=document.createElement('label'),input=document.createElement('input'),button=document.createElement('button');label.textContent=f.friendly_name||'Authenticator';input.inputMode='numeric';input.autocomplete='one-time-code';input.maxLength=6;input.required=true;input.setAttribute('aria-label','Six-digit authenticator code');button.textContent='Verify';button.className='login-button';form.append(label,input,button);root.appendChild(form);
 form.onsubmit=async e=>{e.preventDefault();if(!isCurrent())return;if(!/^[0-9]{6}$/.test(input.value)){out.textContent='Enter a six-digit code.';return;}button.disabled=true;
 try{const c=await sb.auth.mfa.challenge({factorId:f.id});if(!isCurrent())return;if(c.error)throw c.error;const v=await sb.auth.mfa.verify({factorId:f.id,challengeId:c.data.id,code:input.value});input.value='';if(!isCurrent())return;if(v.error)throw v.error;await resume();}catch(error){if(isCurrent()){input.value='';out.textContent=error.message||'Verification failed. Try the next code.';}}finally{if(isCurrent())button.disabled=false;}};});
 if(!verified.length)out.textContent='No verified authenticator is available. Contact the Supabase project administrator for verified recovery. Password reset does not bypass MFA.';
 return false;
}
