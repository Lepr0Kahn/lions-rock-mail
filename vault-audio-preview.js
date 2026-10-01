(function(root){
"use strict";
async function renderWatermarkedPreview(buffer,options={}){
 const rate=buffer.sampleRate,length=buffer.length,channels=buffer.numberOfChannels;
 if(!Number.isFinite(rate)||rate<8000||rate>192000||!Number.isInteger(length)||length<1||!Number.isInteger(channels)||channels<1||channels>8)throw Error("Unsupported decoded audio.");
 const bpm=Number(options.bpm),beatsPerBar=Number(options.beatsPerBar??4);
 if(!Number.isFinite(bpm)||bpm<20||bpm>400||!Number.isInteger(beatsPerBar)||beatsPerBar<1||beatsPerBar>12)throw Error("Enter BPM between 20 and 400 and 1–12 beats per bar.");
 const tagEverySeconds=8*beatsPerBar*60/bpm,tagBuffer=options.tagBuffer;
 let tagChannels=null,tagPeak=0;
 if(tagBuffer){
  if(!tagBuffer.length||!Number.isFinite(tagBuffer.sampleRate)||tagBuffer.numberOfChannels<1||tagBuffer.numberOfChannels>8||tagBuffer.length/tagBuffer.sampleRate>Math.min(8,tagEverySeconds))throw Error("Choose an audio tag of 8 seconds or less, shorter than the eight-bar interval.");
  tagChannels=Array.from({length:tagBuffer.numberOfChannels},(_,c)=>tagBuffer.getChannelData(c));
  for(let i=0;i<tagBuffer.length;i++){let v=0;for(const a of tagChannels)v+=Number.isFinite(a[i])?a[i]:0;tagPeak=Math.max(tagPeak,Math.abs(v/tagChannels.length));}
  if(tagPeak<0.0001)throw Error("The custom audio tag is silent.");
 }
 const outputRate=Math.min(22050,rate),frames=Math.min(Math.floor(length*outputRate/rate),90*outputRate);
 if(frames<1)throw Error("Audio is too short.");
 const source=Array.from({length:channels},(_,c)=>buffer.getChannelData(c));
 if(source.some(a=>a.length<length))throw Error("Incomplete decoded audio.");
 const bytes=new ArrayBuffer(44+frames*2),view=new DataView(bytes);
 function text(at,s){for(let i=0;i<s.length;i++)view.setUint8(at+i,s.charCodeAt(i));}
 text(0,"RIFF");view.setUint32(4,bytes.byteLength-8,true);text(8,"WAVE");text(12,"fmt ");view.setUint32(16,16,true);view.setUint16(20,1,true);view.setUint16(22,1,true);view.setUint32(24,outputRate,true);view.setUint32(28,outputRate*2,true);view.setUint16(32,2,true);view.setUint16(34,16,true);text(36,"data");view.setUint32(40,frames*2,true);
 const cancelled=()=>{if(options.signal?.aborted)throw new DOMException("Preview generation cancelled.","AbortError");};
 for(let base=0;base<frames;base+=32768){
  cancelled();const stop=Math.min(frames,base+32768);
  for(let i=base;i<stop;i++){
   const from=Math.floor(i*rate/outputRate),to=Math.min(length,Math.max(from+1,Math.floor((i+1)*rate/outputRate)));
   let sum=0;for(const a of source)for(let p=from;p<to;p++)sum+=Number.isFinite(a[p])?a[p]:0;
   const music=Math.max(-1,Math.min(1,sum/((to-from)*channels)))*(tagBuffer?0.55:0.65);
   const time=i/outputRate,tagTime=time%tagEverySeconds;let tag=0;
   if(tagBuffer){
    const p=Math.floor(tagTime*tagBuffer.sampleRate);
    if(p<tagBuffer.length){let v=0;for(const a of tagChannels)v+=Number.isFinite(a[p])?a[p]:0;
     const tagLength=tagBuffer.length/tagBuffer.sampleRate,envelope=Math.max(0,Math.min(1,tagTime/0.005,(tagLength-tagTime)/0.005));
     tag=(v/tagChannels.length)/tagPeak*0.45*envelope;}
   }else{const envelope=tagTime<0.25?Math.min(1,tagTime/0.005,(0.25-tagTime)/0.005):0;tag=0.35*Math.sin(2*Math.PI*1000*tagTime)*Math.max(0,envelope);}
   const sample=Math.max(-1,Math.min(1,music+tag));view.setInt16(44+i*2,Math.round(sample*(sample<0?32768:32767)),true);
  }
  options.onProgress?.(stop/frames);
  await new Promise(resolve=>setTimeout(resolve,0));
 }
 cancelled();
 return {blob:new Blob([bytes],{type:"audio/wav"}),seconds:frames/outputRate,sampleRate:outputRate,tagEverySeconds,barsBetweenTags:8,bpm,beatsPerBar,tagKind:tagBuffer?"custom":"tone"};
}
async function generateWatermarkedPreview(file,options={}){
 if(!file||!file.size||file.size>52428800)throw Error("Choose a complete audio file of 50 MB or less.");
 const Context=root.AudioContext||root.webkitAudioContext;if(!Context)throw Error("Audio decoding is unavailable here. Use a prepared tagged preview.");
 let context;
 try{
  context=new Context();
  if(options.signal?.aborted)throw new DOMException("Preview generation cancelled.","AbortError");
  options.onDecode?.();
  const data=await file.arrayBuffer();
  if(options.signal?.aborted)throw new DOMException("Preview generation cancelled.","AbortError");
  const decoded=await context.decodeAudioData(data);
  let tagBuffer;
  if(options.tagFile){if(!options.tagFile.size||options.tagFile.size>5242880)throw Error("Choose a custom audio tag of 5 MB or less.");tagBuffer=await context.decodeAudioData(await options.tagFile.arrayBuffer());}
  if(options.signal?.aborted)throw new DOMException("Preview generation cancelled.","AbortError");
  return await renderWatermarkedPreview(decoded,{...options,tagBuffer});
 }catch(error){if(error.name==="AbortError")throw error;throw Error("Could not generate a preview: "+(error.message||"Unsupported audio codec")+". Choose another audio file or upload a prepared tagged preview.");}
 finally{if(context)try{await context.close();}catch(_){}}
}
root.LionsRockAudioPreview={renderWatermarkedPreview,generateWatermarkedPreview};
})(typeof window!=="undefined"?window:globalThis);
