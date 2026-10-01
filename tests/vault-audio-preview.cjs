const assert=require("assert"),fs=require("fs"),crypto=require("crypto");
require(process.argv[2]||"../vault-audio-preview.js");
const {renderWatermarkedPreview,generateWatermarkedPreview}=globalThis.LionsRockAudioPreview;
function buffer(seconds,rate=8000,channels=1,value=0){const arrays=Array.from({length:channels},()=>new Float32Array(Math.round(seconds*rate)).fill(value));return {sampleRate:rate,length:arrays[0].length,numberOfChannels:channels,getChannelData:c=>arrays[c],arrays};}
const hash=b=>crypto.createHash("sha256").update(Buffer.from(b.arrays[0].buffer)).digest("hex");
async function wav(result){const bytes=Buffer.from(await result.blob.arrayBuffer());assert.equal(bytes.toString("ascii",0,4),"RIFF");assert.equal(bytes.toString("ascii",8,12),"WAVE");assert.equal(bytes.readUInt16LE(22),1);assert.equal(bytes.readUInt16LE(34),16);assert.equal(bytes.readUInt32LE(40),bytes.length-44);const rate=bytes.readUInt32LE(24);return {bytes,rate,seconds:(bytes.length-44)/2/rate,sample:t=>bytes.readInt16LE(44+Math.floor(t*rate)*2)/32768};}
(async()=>{
 const master=buffer(100),before=hash(master),tag=buffer(1,8000,1,1);
 let result=await renderWatermarkedPreview(master,{bpm:120,beatsPerBar:4,tagBuffer:tag});let audio=await wav(result);
 assert.equal(audio.seconds,90);assert.equal(result.tagEverySeconds,16);assert.equal(result.barsBetweenTags,8);assert.equal(result.tagKind,"custom");
 for(const t of [0.1,16.1,32.1,48.1,64.1,80.1])assert(Math.abs(audio.sample(t)-0.45)<0.001,"Custom tag absent at "+t);
 for(const t of [1.1,8.1,15.1,17.1,89.1])assert.equal(audio.sample(t),0,"Tag occurred outside eight-bar interval");
 assert.equal(hash(master),before,"Master mutated");
 result=await renderWatermarkedPreview(buffer(40),{bpm:60,beatsPerBar:4,tagBuffer:tag});audio=await wav(result);assert.equal(result.tagEverySeconds,32);assert.equal(audio.sample(16.1),0);assert(audio.sample(32.1)>0.44);
 result=await renderWatermarkedPreview(buffer(20),{bpm:120,beatsPerBar:3,tagBuffer:tag});audio=await wav(result);assert.equal(result.tagEverySeconds,12);assert(audio.sample(12.1)>0.44);assert.equal(audio.sample(16.1),0);
 result=await renderWatermarkedPreview(buffer(18),{bpm:120});audio=await wav(result);assert.equal(result.tagKind,"tone");assert(Math.abs(audio.sample(0.00525))>0.34);assert(Math.abs(audio.sample(16.00525))>0.34);assert.equal(audio.sample(8.00525),0);
 result=await renderWatermarkedPreview(buffer(0.5,44100,2,1),{bpm:120,tagBuffer:tag});audio=await wav(result);assert.equal(audio.rate,22050);assert.equal(audio.seconds,0.5);for(let i=44;i<audio.bytes.length;i+=2){const v=audio.bytes.readInt16LE(i);assert(v>=-32768&&v<=32767);}
 for(const opts of [{bpm:0},{bpm:401},{bpm:120,beatsPerBar:0},{bpm:120,tagBuffer:buffer(9)},{bpm:400,beatsPerBar:1,tagBuffer:buffer(2)},{bpm:120,tagBuffer:buffer(1)}])await assert.rejects(()=>renderWatermarkedPreview(master,opts));
 const controller=new AbortController();controller.abort();await assert.rejects(()=>renderWatermarkedPreview(master,{bpm:120,signal:controller.signal}),e=>e.name==="AbortError");
 const c=new AbortController();await assert.rejects(()=>renderWatermarkedPreview(master,{bpm:120,signal:c.signal,onProgress:()=>c.abort()}),e=>e.name==="AbortError");
 let closed=0,decodes=0;globalThis.AudioContext=class{async decodeAudioData(){decodes++;return decodes%2?master:tag;}async close(){closed++;}};
 result=await generateWatermarkedPreview({size:10,arrayBuffer:async()=>new ArrayBuffer(10)},{bpm:120,tagFile:{size:5,arrayBuffer:async()=>new ArrayBuffer(5)}});
 assert.equal(result.tagKind,"custom");assert.equal(decodes,2);assert.equal(closed,1);
 globalThis.AudioContext=class{async decodeAudioData(){throw Error("unsupported codec");}async close(){closed++;}};
 await assert.rejects(()=>generateWatermarkedPreview({size:10,arrayBuffer:async()=>new ArrayBuffer(10)},{bpm:120}),/prepared tagged preview/);assert.equal(closed,2);
 if(process.argv[3])fs.writeFileSync(process.argv[3],Buffer.from(await result.blob.arrayBuffer()));
 console.log("PASS preview WAV bytes/duration, custom tags at eight bars for BPM/meter changes, fallback tone, master preservation, peak limits, invalid/silent/long tags, cancellation and decoder cleanup");
})().catch(e=>{console.error(e);process.exitCode=1;});
