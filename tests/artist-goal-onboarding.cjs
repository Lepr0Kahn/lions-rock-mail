const assert=require("node:assert/strict"),fs=require("node:fs"),vm=require("node:vm");
require("../career-direction.js");
const source=fs.readFileSync("studio-member.html","utf8"),elements=new Map();
const el=id=>{if(!elements.has(id))elements.set(id,{value:"",textContent:"",disabled:false});return elements.get(id);};
let saved=null,opened=0,code=null;
const sb={from:()=>({upsert:async p=>code?{error:{code,message:"Database rejected save"}}:(saved={...p},{error:null})})};
const sandbox={el,sb,uid:"artist",isOwner:false,generation:1,window:{LionsRockDirection:globalThis.LionsRockDirection},
 usernameValue:id=>el(id).value.trim().toLowerCase(),withLoadTimeout:p=>p,load:async()=>{opened++;},renderArtistProfilePreview(){}};
vm.createContext(sandbox);
const a=source.indexOf(" function selectGoal("),b=source.indexOf(' el("artist-onboarding-goal-key").onchange',a);
vm.runInContext(source.slice(a,b),sandbox);
const c=source.indexOf(' el("artist-onboarding-form").onsubmit='),d=source.indexOf(' el("edit-career-profile").onclick',c);
vm.runInContext(source.slice(c,d),sandbox);
(async()=>{
 el("artist-onboarding-username").value="Artist_ONE";el("artist-onboarding-name").value="Artist One";el("artist-onboarding-genres").value="Soca";el("artist-onboarding-obstacle").value="time";
 await el("artist-onboarding-form").onsubmit({preventDefault(){}});assert.equal(opened,0);assert.equal(saved,null,"Missing goal bypassed setup");
 el("artist-onboarding-goal-key").value="record_single";sandbox.selectGoal("artist-onboarding");
 assert.equal(el("artist-onboarding-goal").value,globalThis.LionsRockDirection.goalOptions.record_single.label);
 await el("artist-onboarding-form").onsubmit({preventDefault(){}});
 assert.equal(opened,1);assert.equal(saved.username,"artist_one");assert.equal(saved.goal_key,"record_single");assert.equal(saved.direction_focus,"recording");assert.equal(saved.direction_obstacle,"time");
 el("artist-onboarding-goal-key").value="release_ep";sandbox.selectGoal("artist-onboarding");assert(el("artist-onboarding-goal").value.includes("EP"));
 el("artist-onboarding-goal").value="My personal release target";sandbox.selectGoal("artist-onboarding");assert.equal(el("artist-onboarding-goal").value,"My personal release target","Personal wording overwritten");
 el("artist-onboarding-goal-key").value="custom";el("artist-onboarding-goal").value="";await el("artist-onboarding-form").onsubmit({preventDefault(){}});assert.equal(opened,1,"Empty custom goal accepted");
 el("artist-onboarding-goal").value="Perform a small local set";code="23505";await el("artist-onboarding-form").onsubmit({preventDefault(){}});assert(el("artist-onboarding-status").textContent.includes("already taken"));assert.equal(opened,1);assert.equal(el("artist-onboarding-save").disabled,false);
 assert(source.includes("if(!window.LionsRockDirection.onboardingComplete(identity.data))"));assert(source.includes('identity.data?.goal_12_months||""'));
 console.log("PASS Artist onboarding: required goal/identity, preset goals, custom details, normalised username, mapped direction, duplicate-name failure and no premature entry");
})().catch(e=>{console.error(e);process.exitCode=1;});
