const fs=require('node:fs'),path=require('node:path');
const source=process.argv[2]||'.',out=process.argv[3]||'/tmp/lions-rock-preview';fs.mkdirSync(out,{recursive:true});
const files=['studio.html','studio-member.html','studio-bookings.html','invoice-v2-embedded.html','mail-v5-1-embedded.html','studio-hub.html','studio-admin.html'];
for(const file of files){let html=fs.readFileSync(path.join(source,file),'utf8');
html=html.replace(/<script src="https:\/\/cdn.jsdelivr.net\/npm\/@supabase\/supabase-js@2"><\/script>/g,'<script src="/fixture-sdk.js"></script>');
html=html.replace(/<script src="https:\/\/accounts.google.com\/gsi\/client"[^>]*><\/script>/g,'');
html=html.replace(/<script src="\/invoice-sync.js[^"]*"><\/script>/g,'<script src="/fixture-generator.js"></script>');
html=html.replace(/if\("serviceWorker" in navigator\)\{navigator.serviceWorker.register\("\/sw.js"\).catch\(\(\)=>\{\}\);\}/g,'');
html=html.replace('<head>','<head><meta http-equiv="Content-Security-Policy" content="connect-src \'self\'; form-action \'none\'">');
html=html.replace('<body>','<body><div style="padding:8px;background:#b91c1c;color:white;font:14px sans-serif">SAMPLE PREVIEW — no live account, bookings, payments or email sending</div>');
let closingBody=html.lastIndexOf('</body>');
if(closingBody<0)closingBody=html.length;
html=html.slice(0,closingBody)+'<script>document.addEventListener("DOMContentLoaded",()=>{for(const b of document.querySelectorAll("button"))if(/send|sign in|connect gmail/i.test(b.textContent))b.disabled=true;});</script>'+html.slice(closingBody);
fs.writeFileSync(path.join(out,file),html);}
fs.copyFileSync(path.join(__dirname,'fixture-sdk.js'),path.join(out,'fixture-sdk.js'));
fs.copyFileSync(path.join(__dirname,'fixture-generator.js'),path.join(out,'fixture-generator.js'));
fs.copyFileSync(path.join(out,'studio.html'),path.join(out,'index.html'));
console.log('Built isolated sample preview: '+out);
