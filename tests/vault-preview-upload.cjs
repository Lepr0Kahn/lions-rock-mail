const fs=require("fs"),vm=require("vm"),assert=require("assert");
const h=fs.readFileSync(process.argv[2]||"studio-member.html","utf8");
const helpers=h.slice(h.indexOf("function resetVaultPreview(){"),h.indexOf('el("vault-generate-preview").onclick='));
const save=h.slice(h.indexOf('el("vault-form").onsubmit=async e=>{'),h.indexOf("let paymentGeneration=",h.indexOf('el("vault-form").onsubmit=async e=>{')));
assert(helpers.includes("generateVaultPreview"));assert(save.includes('vaultPreviewSource!==master'));
async function fixture(options={}){
 const nodes=new Map(),uploads=[],writes=[];const el=id=>{if(!nodes.has(id))nodes.set(id,{value:"",checked:false,disabled:false,files:[],textContent:"",classList:{add(){},remove(){}},pause(){},removeAttribute(){},load(){}});return nodes.get(id);};
 const master=new Blob(["original-master"],{type:"audio/wav"});master.name="clean.wav";
 el("vault-master").files=[master];el("vault-auto-preview").checked=true;el("vault-bpm").value="120";el("vault-beats-per-bar").value="4";el("vault-published").checked=true;el("vault-title").value="Test beat";el("vault-price").value="150";el("vault-currency").value="BBD";
 const fakeFile=class extends Blob{constructor(parts,name,opts){super(parts,opts);this.name=name;}};
 const c={el,uid:"owner",isOwner:true,vaultEditGeneration:0,vaultPreviewGeneration:0,vaultPreviewAbort:null,vaultPreviewFile:null,vaultPreviewSource:null,vaultPreviewUrl:null,vaultExistingMaster:null,File:fakeFile,AbortController,DOMException,Error,Number,URL:{createObjectURL:()=>"blob:test",revokeObjectURL(){}},crypto:{randomUUID:()=>"random"},newVaultItem(){},loadVault:async()=>{}};
 c.window={LionsRockAudioPreview:{generateWatermarkedPreview:async(file,settings)=>{assert.equal(file,master);assert.equal(settings.bpm,120);assert.equal(settings.beatsPerBar,4);if(options.duringGenerate)options.duringGenerate(c);return {blob:new Blob(["mixed-custom-tag"],{type:"audio/wav"}),seconds:90,tagKind:"custom",tagEverySeconds:16};}}};
 c.sb={from:()=>({insert:values=>({select:()=>({single:async()=>{writes.push(values);return {data:{id:"beat"}};}})}),update:values=>({eq:()=>({select:()=>({single:async()=>{writes.push(values);return {data:{id:"beat"}};}})})})}),storage:{from:()=>({upload:async(path,file)=>{uploads.push({path,file});if(options.duringUpload)options.duringUpload(c,uploads.length);return {};}})}};
 vm.createContext(c);vm.runInContext(helpers+"\n"+save,c);await el("vault-form").onsubmit({preventDefault(){}});return {c,el,uploads,writes,master};
}
(async()=>{
 let t=await fixture();assert.equal(t.uploads.length,2);assert(t.uploads[0].path.includes("/master/"));assert.equal(t.uploads[0].file,t.master);assert(t.uploads[1].path.includes("/preview/"));assert.equal(await t.uploads[1].file.text(),"mixed-custom-tag");assert.equal(t.uploads[1].file.type,"audio/wav");assert.equal(t.writes.at(-1).published,true);
 t=await fixture({duringGenerate:c=>c.uid="other"});assert.equal(t.writes.length,0);assert.equal(t.uploads.length,0);
 t=await fixture({duringGenerate:c=>c.vaultEditGeneration++});assert.equal(t.writes.length,0);
 t=await fixture({duringUpload:(c,n)=>{if(n===1)c.isOwner=false;}});assert.equal(t.uploads.length,1);assert.equal(t.writes.length,1);assert.equal(t.writes[0].published,false);
 console.log("PASS current vault save: original master/separate mixed preview, automatic generation, publish handoff, account/editor changes and revoked Owner upload abort");
})().catch(e=>{console.error(e);process.exitCode=1;});
