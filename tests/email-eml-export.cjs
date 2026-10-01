const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const html=fs.readFileSync(process.argv[2]||path.join(__dirname,'../mail-v5-1-embedded.html'),'utf8');
const source=html.slice(html.indexOf('function buildMimeMessage('),html.indexOf('function renderPreview('));
assert(source.includes('function buildRaw('));
const pdf=Buffer.from('%PDF-1.4\nSample invoice INV-0042\n%%EOF');
const audio=Buffer.from([0,255,128,13,10,42]);
const ctx={Date,Math,getState:()=>({to:'artist@example.com',cc:'copy@example.com',bcc:'private@example.com',subject:'Lion’s Rock — Invoice INV-0042'}),LOGO:'data:image/png;base64,aGVsbG8=',SIGNATURE:'data:image/jpeg;base64,d29ybGQ=',buildPlain:()=> 'Hi José',buildEmailHtml:()=>'<p>Invoice INV-0042 — José</p>',b64utf8:s=>Buffer.from(s).toString('base64'),b64url:s=>Buffer.from(s).toString('base64url'),wrap76:s=>s.match(/.{1,76}/g)?.join('\r\n')||'',tracks:[{name:'Invoice-INV-0042.pdf',mime:'application/pdf',base64:pdf.toString('base64')},{name:'sample.wav',mime:'audio/wav',base64:audio.toString('base64')}]};
vm.createContext(ctx);vm.runInContext(source,ctx);
const raw=ctx.buildMimeMessage();
for(const [name,bytes] of [['Invoice-INV-0042.pdf',pdf],['sample.wav',audio]]){
 const marker='Content-Disposition: attachment; filename="'+name+'"\r\n\r\n';
 const payload=raw.split(marker)[1]?.split('\r\n--')[0];assert(payload);assert.deepEqual(Buffer.from(payload.replace(/\s/g,''),'base64'),bytes);
}
assert(raw.includes('multipart/alternative'));assert(raw.includes('multipart/related'));assert(raw.includes('Cc: copy@example.com'));assert(raw.includes('Bcc: private@example.com'));
const subject=raw.match(/Subject: =\?UTF-8\?B\?(.+)\?=/)[1];assert.equal(Buffer.from(subject,'base64').toString(),ctx.getState().subject);
assert(Buffer.from(raw.match(/Content-Type: text\/html; charset=UTF-8\r\nContent-Transfer-Encoding: base64\r\n\r\n([\s\S]*?)\r\n--/)[1].replace(/\s/g,''),'base64').toString().includes('José'));
assert(Buffer.from(ctx.buildRaw(),'base64url').toString().includes('Invoice-INV-0042.pdf'));
ctx.tracks=[];assert(!ctx.buildMimeMessage().includes('Content-Disposition: attachment'));
const handler=html.split('\n').find(l=>l.startsWith('  const eml=$'));assert(handler.includes('new Blob([buildMimeMessage()]'));assert(handler.includes('document.body.appendChild(a)'));
for(const m of html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi))if(m[1].trim())new Function(m[1]);
console.log('PASS: EML PDF/audio bytes, Unicode, recipients, MIME alternatives, Gmail wrapper and empty attachments.');
