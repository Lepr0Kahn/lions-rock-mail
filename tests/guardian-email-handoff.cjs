const fs=require("fs"),vm=require("vm"),assert=require("assert");
const shell=fs.readFileSync(process.argv[2]||"studio.html","utf8"),memberSource=fs.readFileSync(process.argv[3]||"studio-member.html","utf8");
const start=shell.indexOf('if(e.data.type==="lions-rock-guardian-email"){'),end=shell.indexOf('if(e.data.type==="lions-rock-email-client"){',start);
assert(start>=0&&end>start,"Current guardian handler missing");const handler=shell.slice(start,end);
function environment(){
 const posts=[],timers=[],activations=[],errors=[];
 const member={contentWindow:{}},mail={contentWindow:{postMessage:p=>posts.push(p)}};
 const data={type:"lions-rock-guardian-email",name:"Test Guardian",email:"guardian@example.invalid",documentNumber:"INV-0042",link:"https://lions-rock-mail.vercel.app/studio-guardian.html#"+"a".repeat(64),expiresAt:new Date(Date.now()+86400000).toISOString()};
 const c={URL,Date,Number,location:{origin:"https://lions-rock-mail.vercel.app"},member,mail,currentSession:{user:{id:"owner"}},currentMembership:{role:"owner",active:true},canBusiness:m=>m?.active===true,pendingClient:null,setTimeout:f=>timers.push(f),activate:x=>activations.push(x),toast:x=>errors.push(x)};
 vm.createContext(c);vm.runInContext("function handle(e){"+handler+"}",c);
 return {c,posts,timers,activations,errors,event:{source:member.contentWindow,data},flush(){timers.splice(0).forEach(f=>f());}};
}
let x=environment();x.c.handle(x.event);x.flush();assert.equal(x.posts.length,1);let p=x.posts[0];assert.equal(p.email,"guardian@example.invalid");assert.equal(p.attachment,null);assert(p.body.includes(x.event.data.link));assert(p.subject.includes("INV-0042"));assert.equal(x.activations[0],"mail");
for(const change of [
 x=>x.event.source={},
 x=>x.c.currentMembership.role="member",
 x=>x.c.currentMembership.active=false,
 x=>x.event.data.email="minor@example.invalid\nBcc:bad@example.invalid",
 x=>x.event.data.link="https://other.example/studio-guardian.html#"+"a".repeat(64),
 x=>x.event.data.link="https://lions-rock-mail.vercel.app/studio-guardian.html?token=x#"+"a".repeat(64),
 x=>x.event.data.expiresAt="bad",
 x=>x.event.data.expiresAt=new Date(Date.now()-1000).toISOString()
]){x=environment();change(x);x.c.handle(x.event);x.flush();assert.equal(x.posts.length,0);}
x=environment();x.c.handle(x.event);x.c.currentSession={user:{id:"other"}};x.flush();assert.equal(x.posts.length,0);
x=environment();x.c.handle(x.event);x.c.currentMembership.active=false;x.flush();assert.equal(x.posts.length,0);

const createStart=memberSource.indexOf('el("guardian-link-create").onclick='),copyStart=memberSource.indexOf('el("guardian-link-copy").onclick',createStart);
assert(createStart>=0&&copyStart>createStart);
const memberHandlers=memberSource.slice(createStart,copyStart);
const clear=memberSource.match(/function clearGuardianDraft\(\)\{[^\n]+\}/)[0];
async function memberCase(change){
 const nodes=new Map(),posts=[];function el(id){if(!nodes.has(id))nodes.set(id,{value:"",textContent:"",disabled:false,classList:{add(){},remove(){}}});return nodes.get(id);}
 el("payment-invoice").value="invoice";let resolve;
 const c={el,uid:"owner",isOwner:true,paymentDocs:[{id:"invoice",doc_number:"INV-0042"}],guardianDraft:null,guardianLinkGeneration:0,location:{origin:"https://lions-rock-mail.vercel.app"},window:{parent:{postMessage:p=>posts.push(p)}},Date,Error,sb:{rpc:()=>new Promise(r=>resolve=r)}};
 vm.createContext(c);vm.runInContext(clear+"\n"+memberHandlers,c);
 const pending=el("guardian-link-create").onclick();
 if(change)change(c,el);
 resolve({data:{token:"a".repeat(64),guardian_name:"Test Guardian",guardian_email:"guardian@example.invalid",expires_at:new Date(Date.now()+86400000).toISOString()}});
 await pending;el("guardian-email-draft").onclick();return {c,posts,el};
}
(async()=>{
 let v=await memberCase();assert.equal(v.posts.length,1);assert.equal(v.posts[0].email,"guardian@example.invalid");
 v.c.uid="other";v.el("guardian-email-draft").onclick();assert.equal(v.posts.length,1);assert.equal(v.c.guardianDraft,null);
 for(const mutate of [(c,e)=>{e("payment-invoice").value="another";c.clearGuardianDraft();},c=>c.uid="other",c=>c.isOwner=false]){
  v=await memberCase(mutate);assert.equal(v.posts.length,0);assert.equal(v.c.guardianDraft,null);
 }
 console.log("PASS current guardian email handoff: recipient/link/draft, invalid payload rejection, selection/account/access changes and delayed send guard");
})().catch(e=>{console.error(e);process.exitCode=1;});
