/* Prepare drafts from current records; never send automatically. */
async function studioNoticeEmail(sb,kind,id){
 const tables={booking:'studio_bookings',delivery:'artist_project_files',vault:'studio_instrumental_requests'};
 if(!tables[kind]||! /^[0-9a-f-]{36}$/i.test(id||''))throw Error('Invalid notice record.');
 const source=await sb.from(tables[kind]).select('*').eq('id',id).single();if(source.error)throw Error('Could not load the notice record.');const row=source.data;
 if(kind==='booking'&&row.status!=='confirmed')throw Error('Confirm the booking before preparing its email.');
 if(kind==='delivery'&&(!['master','mp3_delivery'].includes(row.kind)||(row.expires_at&&new Date(row.expires_at)<=new Date())))throw Error('Reissue this delivery before preparing its email.');
 if(kind==='vault'&&!['approved','released'].includes(row.status))throw Error('Approve this vault request first.');
 const membership=await sb.from('app_memberships').select('user_id,email,business_name,is_minor,access_status,deleted_at').eq('user_id',row.user_id).single();if(membership.error||membership.data.deleted_at||membership.data.access_status!=='active')throw Error('An active recipient account is required.');
 const m=membership.data;let name=m.business_name||'Artist',email=m.email;
 if(m.is_minor){const g=await sb.rpc('guardian_management');if(g.error)throw Error('Could not load guardian recipient.');const contact=(g.data.contacts||[]).find(c=>c.artist_id===row.user_id);if(!contact)throw Error('Save the guardian contact before preparing this notice.');name=contact.guardian_name;email=contact.guardian_email;}
 if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email||''))throw Error('Save a valid recipient email first.');
 let subject,body;
 if(kind==='booking'){const time=v=>new Intl.DateTimeFormat('en-BB',{timeZone:'America/Barbados',dateStyle:'full',timeStyle:'short'}).format(new Date(v));subject='Studio booking confirmed — '+row.service_name;body='Your studio booking is confirmed.\n\nService: '+row.service_name+' — '+row.variant_name+'\nStarts: '+time(row.starts_at)+'\nEnds: '+time(row.ends_at)+'\nTimes are in Barbados.\n\nOpen Lions Rock Studio to review the booking. Any invoice or guardian approval is handled separately.';}
 if(kind==='delivery'){subject='Your studio delivery is ready';body='Your '+(row.kind==='master'?'master':'MP3 delivery')+' is ready in Lions Rock Studio.\n\nFile: '+row.filename+(row.expires_at?'\nDownload access expires: '+new Intl.DateTimeFormat('en-BB',{timeZone:'America/Barbados',dateStyle:'full',timeStyle:'short'}).format(new Date(row.expires_at))+' (Barbados).':'')+'\n\nSign in to the Artist workspace and open the project to access it. This email does not attach the audio or provide a public download link.';}
 if(kind==='vault'){const exclusive=row.licence_kind==='exclusive';subject=(row.status==='released'?'Instrumental released — ':'Instrumental request approved — ')+row.title_snapshot;body=(row.status==='released'?'The studio has released your licensed master. Sign in to the Artist workspace and open the vault.':'The studio has approved your instrumental request and prepared an invoice. Master access requires full recorded payment, any required guardian approval, and studio release.')+'\n\nInstrumental: '+row.title_snapshot+'\nLicence: '+(exclusive?'Exclusive':'Nonexclusive lease')+(exclusive?'\nExisting nonexclusive licences remain valid under their original agreed terms. Download expiry does not terminate those licences.':'');}
 body+='\n\nOpen Studio: https://lions-rock-mail.vercel.app/studio';
 return{name,email,attachment:null,subject,greeting:'Hello '+name+',',body,signoff:'Lions Rock Studio',documentType:'studio notice'};
}
