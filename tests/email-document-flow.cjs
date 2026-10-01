const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(process.argv[2] || 'invoice-v2-embedded.html', 'utf8');
const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/g)];
const script = scripts.at(-1)[1];
async function check(type, paid, fail) {
  let handler, posted, rendered, captured;
  const button = {textContent:'Email client',disabled:false,addEventListener(_, fn){handler=fn;}};
  const fields = {'email-client-btn':button,'client-email':{value:'draft@example.com'},'client-name':{value:'Draft Client'},preview:{scrollWidth:600,scrollHeight:900}};
  const document = {body:{inert:false},readyState:'complete',getElementById:id=>fields[id] || null};
  const doc = {id:'fixture',type,paid,doc_number:type==='quote'?'QUO-0042':'INV-0042',client_name:'Final Client',client_email:'final@example.com',total:350,deposit_pct:50,items:[{name:'Full Mix',qty:1,price:350}]};
  class PDF {constructor(){this.internal={pageSize:{getWidth:()=>595,getHeight:()=>842}};}addPage(){}addImage(){}output(){return 'data:application/pdf;base64,JVBERi0=';}}
  const window = {addEventListener(){},saveDoc:()=>doc,
    async finalizeStudioDocument(d){assert.equal(document.body.inert,true);if(fail)throw Error('sync unavailable');return d;},
    loadDocIntoGenerator(d){rendered=d;},toast(){},
    async html2canvas(){assert.equal(rendered,doc);assert.equal(document.body.inert,true);captured=true;return {width:600,height:900,toDataURL:()=> 'data:image/jpeg;base64,AA=='};},
    jspdf:{jsPDF:PDF},parent:{postMessage(data){posted=data;}}};
  vm.runInNewContext(script,{window,document,location:{origin:'https://example.com'},requestAnimationFrame:fn=>fn(),console:{error(){}}});
  await handler();
  assert.equal(document.body.inert,false);assert.equal(button.disabled,false);assert.equal(button.textContent,'Email client');
  if(fail){assert.equal(posted,undefined);assert.equal(captured,undefined);return;}
  const kind=type==='quote'?'Quotation':paid?'Receipt':'Invoice';
  assert.equal(posted.email,'final@example.com');assert.equal(posted.name,'Final Client');
  assert.equal(posted.documentNumber,doc.doc_number);assert.equal(posted.documentType,type);
  assert.equal(posted.subject,"Lion's Rock "+kind+' '+doc.doc_number);
  assert.equal(posted.attachment.name,'Lions-Rock-'+kind+'-'+doc.doc_number+'.pdf');
  assert.equal(posted.attachment.mime,'application/pdf');assert.equal(posted.attachment.base64,'JVBERi0=');
  assert.equal(rendered.total,350);assert.equal(rendered.deposit_pct,50);
}
(async()=>{await check('invoice',false,false);await check('quote',false,false);await check('invoice',true,false);await check('invoice',false,true);console.log('PASS finalized recipient, preview inputs, PDF metadata, invoice/quote/receipt drafts and failure recovery');})().catch(e=>{console.error(e);process.exitCode=1;});
