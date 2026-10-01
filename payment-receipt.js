(function(root){
 'use strict';
 function draft(entry,doc){
  if(!entry||!doc||entry.document_id!==doc.id||entry.user_id!==doc.user_id||doc.doc_type!=='invoice'||!['payment','refund','correction'].includes(entry.kind)||!entry.receipt_number)throw Error('A recorded payment, refund or correction is required.');
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(doc.client_email||''))throw Error('Save a valid invoice recipient email before preparing this receipt.');
  if(!Number.isFinite(Number(entry.amount))||Number(entry.amount)===0)throw Error('Invalid recorded amount.');
  const label=entry.kind==='refund'?'Recorded refund':entry.kind==='correction'?'Payment correction':'Payment receipt';
  const lines=['Lions Rock Media Facility',label,'Entry: '+entry.receipt_number,'Invoice: '+doc.doc_number,'Client: '+(doc.client_name||''),'Currency: '+doc.currency,'Amount: '+Math.abs(Number(entry.amount)).toFixed(2),'Date: '+entry.payment_date,'Method: '+entry.method,'Reference: '+(entry.reference||''),'Notes: '+(entry.notes||''),'','This confirms a studio record; it is not payment-processor verification.'];
  const text=lines.join('\n');const bytes=new TextEncoder().encode(text);let binary='';bytes.forEach(b=>binary+=String.fromCharCode(b));
  return {name:doc.client_name||'Client',email:doc.client_email,subject:label+' — '+entry.receipt_number,greeting:'Hello,',body:text+'\n\nA copy of this record is attached for your files.',signoff:'Lions Rock Studio',documentNumber:entry.receipt_number,documentType:label,attachment:{name:String(entry.receipt_number).replace(/[^A-Za-z0-9_-]/g,'_')+'.txt',mime:'text/plain;charset=utf-8',base64:btoa(binary),size:bytes.length}};
 }
 root.LionsRockReceipt={draft};
})(typeof window==='undefined'?globalThis:window);
