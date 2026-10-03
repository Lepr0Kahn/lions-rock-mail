(function(root){
"use strict";
const trackOrder=["creative","momentum","audience","network","business"];
const focusOptions={
 general:"Build my artist foundation",songwriting:"Develop my songwriting",recording:"Finish a recording",
 release:"Prepare a release",audience:"Build my audience",collaboration:"Find collaborators",business:"Organise my artist business"
};
const obstacleOptions={
 none:"No specific obstacle",consistency:"Staying consistent",unfinished:"Finishing work",confidence:"Confidence",
 time:"Limited time",budget:"Limited budget",collaborators:"Finding collaborators"
};
const clean=(v,max=3000)=>typeof v==="string"?v.trim().slice(0,max):"";
const option=(options,key,fallback)=>Object.prototype.hasOwnProperty.call(options,key)?key:fallback;
function buildDirection(context){
 const progress=context?.progress,tracks=context?.tracks;
 if(!progress||!tracks?.tracks||!Array.isArray(progress.gates)||!trackOrder.every(k=>tracks.tracks[k]))throw Error("Current stage and all five tracks are required.");
 const signals=tracks.signals||{},known=k=>typeof signals[k]==="number"&&Number.isFinite(signals[k])&&signals[k]>=0;
 const count=k=>known(k)?signals[k]:null;
 const evidence=(k,label)=>known(k)?label+": "+signals[k]+" on record.":label+": evidence unavailable; ask the studio to check the record.";
 const action=(track,title,why,k,label,destination,effort="low")=>({track,title,why,evidence:evidence(k,label),destination,effort,horizon:"This week"});
 const profile=context.profile||{},focus=option(focusOptions,profile.direction_focus,"general"),obstacle=option(obstacleOptions,profile.direction_obstacle,"none");
 const focusChosen=focus!=="general",obstacleChosen=obstacle!=="none",goal=clean(profile.goal_12_months),artistName=clean(profile.artist_name,200),genres=clean(profile.genres,500);
 const actions=[];
 if(count("profile")===0)actions.push(action("creative","Complete your artist identity and goal","A clear identity and goal help you choose the next project.","profile","Complete career profile","profile"));
 else if(count("projects")===0)actions.push(action("creative","Start one music project","Use a project to organise material and the next piece of work.","projects","Projects","projects"));
 else if(count("uploads")===0)actions.push(action("creative","Add material to your project","A reference, lyric or demo gives the studio something concrete to review.","uploads","Registered material","projects"));
 else if(count("masters")===0)actions.push(action("creative","Agree on the next recording or production step","Review the registered material with the studio and decide what is needed for a delivery.","masters","Master / MP3 deliveries","projects","medium"));
 else actions.push(action("creative","Review your latest project material","Choose one improvement with the studio before adding more work.","uploads","Registered material","projects","medium"));
 actions.push(count("milestones_30")===0?
  action("momentum","Choose one small project task","Record a real result this week; opening the app alone does not count as progress.","milestones_30","Eligible milestones in the last 30 days","projects"):
  action("momentum","Continue with one concrete project result","Build on recent recorded progress by choosing the next task you can complete.","milestones_30","Eligible milestones in the last 30 days","projects"));
 actions.push(count("masters")===0?
  action("audience","Outline who the next song is for","Write down the intended listener and message while the music is being developed.","masters","Master / MP3 deliveries","projects"):
  count("masters_collected")===0?
  action("audience","Review your delivery and release checklist","If a delivery is available, review it; otherwise agree on what is needed before release.","masters_collected","Delivery downloads initiated","projects"):
  action("audience","Review your next release plan","Mark a project Released only after it is actually published.","releases","Projects marked Released","projects","medium"));
 actions.push(count("bookings")===0?
  action("network","Discuss what support your project needs","Ask the studio who and what would help; arrange a session only when it fits the project.","bookings","Confirmed bookings","bookings"):
  action("network","Prepare the next studio conversation","Bring one clear question and agree on the next task; confirmed bookings alone do not establish attendance.","bookings","Confirmed bookings","bookings"));
 const minor=!!context.minor;
 actions.push(minor?
  action("business","Review the project plan with your guardian","Management and your guardian handle financial approvals; your workspace keeps amounts private.","budget_defined","Projects with an explicit budget","projects"):
  count("budget_defined")===0?
  action("business","Review an optional project budget","Record a plan only when you have one; a budget is separate from a charge.","budget_defined","Projects with an explicit budget","projects"):
  action("business","Check the project plan and linked records","Ask the studio to reconcile any invoice record that looks wrong; recorded settlement is not processor verification.","invoices_settled","Linked invoices with full payment recorded","projects"));
 const byTrack=Object.fromEntries(actions.map(a=>[a.track,a]));
 const personalise=(track,title,why,source)=>{
  const a=byTrack[track];a.title=title;a.why=why;a.evidence+=" "+source;
 };
 const focusEvidence="Artist-selected focus: "+focusOptions[focus]+".";
 // Selected choices are evidence of intent, never evidence that work was completed.
 if(focusChosen&&count("profile")>0){
  if(focus==="songwriting"){
   personalise("creative",count("projects")===0?"Start a songwriting project":count("uploads")===0?"Add a lyric or rough song idea":"Choose one section of a song to refine","Choose one song and work on its message, structure or lyric before starting another.",focusEvidence);
  }else if(focus==="recording"){
   personalise("creative",count("projects")===0?"Start a recording project":count("uploads")===0?"Add a demo or recording reference":count("masters")===0?"Agree on one step toward a finished recording":"Review a delivery before starting another recording","Use the project record to agree on what needs recording, production or review; the studio judges musical quality.",focusEvidence);
  }else if(focus==="release"){
   if(count("projects")===0||count("uploads")===0||count("masters")===0){
    byTrack.creative.why+=" This is the preparation step for your release focus.";byTrack.creative.evidence+=" "+focusEvidence;
    personalise("audience","Draft a release checklist","Outline artwork, credits, rights and a proposed date; confirm delivery readiness with the studio before publishing.",focusEvidence);
   }else{
    personalise("audience",count("masters_collected")===0?"Collect and review a delivery before release":"Check the next release's readiness","Review the audio, credits, artwork and rights with the studio before committing to publication.",focusEvidence);
   }
  }else if(focus==="audience"){
   personalise("audience",count("releases")>0?"Plan one listener feedback activity":"Define the listeners you want to reach",count("releases")>0?"Choose one published project and plan a small feedback or sharing activity; audience response is not measured here.":"Write a short description of the intended listeners and what you want the music to communicate.",focusEvidence);
  }else if(focus==="collaboration"){
   personalise("network","Write a clear collaboration brief","Describe the role, song or project, contribution and permissions you need; ask the studio for suitable introductions.",focusEvidence);
   byTrack.network.destination="projects";
  }else if(focus==="business"){
   personalise("business",minor?"Review project responsibilities with your guardian":"List project responsibilities and permissions",minor?"Ask your guardian and the studio to review responsibilities, credits and approvals.":"List contributors, credits and permissions and discuss any gaps with the studio.",focusEvidence);
  }
 }
 const obstacleEvidence="Artist-selected obstacle: "+obstacleOptions[obstacle]+".";
 if(obstacleChosen){
  if(obstacle==="consistency")personalise("momentum","Choose a repeatable weekly work slot","Choose one manageable work slot and one concrete task. Record the result when it is completed.",obstacleEvidence);
  if(obstacle==="unfinished")personalise("momentum","Define what finished means for one task","Pick one piece of work, agree on a clear finish point with the studio and defer extra projects until that task is done.",obstacleEvidence);
  if(obstacle==="time")personalise("momentum","Choose a task that fits a short work slot","Break one project task into a 15–30 minute step; a small completed result is more useful than an oversized plan.",obstacleEvidence);
  if(obstacle==="confidence")personalise("momentum","Arrange feedback on one small piece of work","Choose a lyric, demo or project question to review privately with the studio; agree on one improvement.",obstacleEvidence);
  if(obstacle==="budget")personalise("business",minor?"Review a manageable plan with your guardian":"Plan the next step within your available budget",minor?"Ask your guardian and the studio to choose a manageable preparation step before any financial commitment.":"Ask the studio what you can prepare with what you already have and agree on costs before booking paid work.",obstacleEvidence);
  if(obstacle==="collaborators"){personalise("network","Define the collaborator you need","Describe the missing role and the contribution you want, then discuss suitable introductions with the studio.",obstacleEvidence);byTrack.network.destination="projects";}
  if(["time","consistency","confidence"].includes(obstacle))byTrack.momentum.effort="low";
 }
 const relevant={creative:["profile","projects","uploads","masters"],momentum:["milestones_30"],audience:["masters","masters_collected","releases"],network:["bookings"],business:["budget_defined","invoices_settled"]};
 for(const a of actions){
  if(!relevant[a.track].every(known)){
   a.title="Check "+a.track+" records with the studio";a.why="Evidence is incomplete; check the records before deciding the next piece of work.";a.evidence="One or more required "+a.track+" signals are unavailable.";a.destination="projects";
  }
 }
 const score=k=>{const v=tracks.tracks[k].score;return typeof v==="number"&&Number.isFinite(v)?v:Infinity;};
 const focusTrack={songwriting:"creative",recording:"creative",release:"audience",audience:"audience",collaboration:"network",business:"business"}[focus];
 const obstacleTrack={consistency:"momentum",unfinished:"momentum",time:"momentum",confidence:"momentum",budget:"business",collaborators:"network"}[obstacle];
 // Foundation work and unavailable evidence take precedence over preferences.
 const rank=a=>a.title.startsWith("Check ")?3:a.track==="creative"&&(count("profile")===0||count("projects")===0||count("uploads")===0)?0:a.track===obstacleTrack?1:a.track===focusTrack?1:2;
 actions.sort((a,b)=>rank(a)-rank(b)||score(a.track)-score(b.track)||trackOrder.indexOf(a.track)-trackOrder.indexOf(b.track));
 const notes={},risks=[];
 for(const k of trackOrder){
  const parts=tracks.tracks[k].breakdown||[];
  notes[k]=parts.filter(p=>p.available===true).map(p=>p.signal+": "+p.units+" on record").join("; ")||"Track evidence is unavailable.";
  if(parts.some(p=>p.available!==true))notes[k]+=". Some signals are not integrated; do not treat missing evidence as zero activity.";
 }
 if(progress.held)risks.push("A previously reached stage is retained; current evidence supports "+progress.evidenced_stage+". Review changed or removed records with the studio.");
 if(count("milestones_30")===0)risks.push("No eligible recent milestones are recorded. This does not establish that no work happened offline.");
 if(trackOrder.some(k=>tracks.tracks[k].partial))risks.push("Some track evidence is incomplete. The studio should check missing records before drawing conclusions.");
 const supported=Object.keys(signals).filter(known).length;
 const nextGate=clean(progress.next_action,500);
 return {
  mode:"rules",headline:focusChosen||obstacleChosen?actions[0].title:nextGate||actions[0].title,
  stageRationale:(progress.held?"Your previously reached "+progress.stage+" stage is retained. Current evidence supports "+progress.evidenced_stage+".":"Your recorded stage is "+progress.stage+".")+(nextGate?" The next evidence step is: "+nextGate:" Review the next evidence gate with the studio."),
  nextActions:actions,trackNotes:notes,risks:risks.slice(0,2),
  evidenceQuality:supported<3||["projects","uploads","masters","releases","masters_collected","profile"].filter(k=>known(k)&&signals[k]>0).length<2?"thin":trackOrder.some(k=>tracks.tracks[k].partial)?"partial":"recorded",
  computedAt:tracks.computed_at||null,
  personalisation:{artistName,genres,goal,focus:focusOptions[focus],obstacle:obstacleOptions[obstacle],chosen:focusChosen||obstacleChosen,profileUnavailable:!!context.profileUnavailable},
  notes:["Guidance uses your selected focus, obstacle and recorded progress.","Suggestions do not approve work, change stages or scores, publish music, record payments or award rewards."]
 };
}
root.LionsRockDirection={buildDirection,focusOptions,obstacleOptions};
})(typeof window!=="undefined"?window:globalThis);
