(function(root){
"use strict";
const trackOrder=["creative","momentum","audience","network","business"];
function buildDirection(context){
 const progress=context?.progress,tracks=context?.tracks;
 if(!progress||!tracks?.tracks||!Array.isArray(progress.gates)||!trackOrder.every(k=>tracks.tracks[k]))throw Error("Current stage and all five tracks are required.");
 const signals=tracks.signals||{},known=k=>typeof signals[k]==="number"&&Number.isFinite(signals[k])&&signals[k]>=0;
 const count=k=>known(k)?signals[k]:null,evidence=(k,label)=>known(k)?label+": "+signals[k]+" on record.":label+": evidence unavailable; ask the studio to check the record.";
 const action=(track,title,why,k,label,destination,effort="low")=>({track,title,why,evidence:evidence(k,label),destination,effort,horizon:"This week"});
 const actions=[];
 if(count("profile")===0)actions.push(action("creative","Complete your artist identity and goal","A clear identity and goal help you choose the next project.","profile","Complete career profile","profile"));
 else if(count("projects")===0)actions.push(action("creative","Start one music project","Use a project to organise material and the next piece of work.","projects","Projects","projects"));
 else if(count("uploads")===0)actions.push(action("creative","Add material to your project","A reference, lyric or demo gives the studio something concrete to review.","uploads","Registered material","projects"));
 else actions.push(action("creative","Review your latest project material","Choose one improvement with the studio before adding more work.","uploads","Registered material","projects","medium"));
 actions.push(action("momentum","Choose one small project task","Record a real result this week; opening the app alone does not count as progress.","milestones_30","Eligible milestones in the last 30 days","projects"));
 actions.push(count("masters_collected")===0?action("audience","Review your delivery and release checklist","If a delivery is available, review it; otherwise agree on what is needed before release.","masters_collected","Delivery downloads initiated","projects"):action("audience","Review your next release plan","Mark a project Released only after it is actually published.","releases","Projects marked Released","projects","medium"));
 actions.push(action("network","Discuss the next collaboration with the studio","Agree on the people and work needed; past scheduled sessions do not prove attendance.","sessions_completed","Past confirmed sessions (attendance unverified)","bookings"));
 const minor=!!context.minor;
 actions.push(minor?action("business","Review the project plan with your guardian","Management and your guardian handle financial approvals; your workspace keeps amounts private.","budget_defined","Projects with an explicit budget","projects"):count("budget_defined")===0?action("business","Review an optional project budget","Record a plan only when you have one; a budget is separate from a charge.","budget_defined","Projects with an explicit budget","projects"):action("business","Check the project plan and linked records","Ask the studio to reconcile any invoice record that looks wrong; recorded settlement is not processor verification.","invoices_settled","Linked invoices with full payment recorded","projects"));
 for(const a of actions){const relevant={creative:["profile","projects","uploads"],momentum:["milestones_30"],audience:["masters_collected","releases"],network:["sessions_completed"],business:["budget_defined","invoices_settled"]}[a.track];if(!relevant.every(known)){a.title="Check "+a.track+" records with the studio";a.why="Evidence is incomplete; check the records before deciding the next piece of work.";a.evidence="One or more required "+a.track+" signals are unavailable.";a.destination="projects";}}
 const score=k=>{const v=tracks.tracks[k].score;return typeof v==="number"&&Number.isFinite(v)?v:Infinity;};
 actions.sort((a,b)=>score(a.track)-score(b.track)||trackOrder.indexOf(a.track)-trackOrder.indexOf(b.track));
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
 return {mode:"rules",headline:progress.next_action||actions[0].title,stageRationale:progress.held?"Your previously reached "+progress.stage+" stage is retained. The next action follows current evidence at "+progress.evidenced_stage+".":"Your recorded stage is "+progress.stage+". The next action comes from the server's current evidence gates.",nextActions:actions,trackNotes:notes,risks:risks.slice(0,2),evidenceQuality:supported<3||["projects","uploads","masters","releases","masters_collected","profile"].filter(k=>known(k)&&signals[k]>0).length<2?"thin":trackOrder.some(k=>tracks.tracks[k].partial)?"partial":"recorded",computedAt:tracks.computed_at||null,notes:["Rule-based guidance; no AI provider is connected.","Suggestions do not approve work, change stages or scores, publish music, record payments or award rewards."]};
}
root.LionsRockDirection={buildDirection};
})(typeof window!=="undefined"?window:globalThis);
