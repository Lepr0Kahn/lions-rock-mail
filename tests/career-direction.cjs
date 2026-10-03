const assert=require("assert"),fs=require("fs"),vm=require("vm");
require(process.argv[2]||"../career-direction.js");const build=globalThis.LionsRockDirection.buildDirection;
function context(){return {progress:{stage:"discover",stage_index:2,evidenced_stage:"discover",held:false,next_action:"Start a music project.",gates:[{stage:"join",reached_now:true}]},tracks:{computed_at:"2026-10-01T22:00:00Z",signals:{profile:1,projects:0,uploads:0,masters:0,masters_collected:0,releases:0,milestones_30:0,sessions_completed:0,budget_defined:0,invoices_settled:0,bookings:0},tracks:Object.fromEntries(["creative","momentum","audience","network","business"].map((k,i)=>[k,{score:i*10,partial:false,breakdown:[{signal:"projects",available:true,units:0}]}]))}};}
let c=context(),before=JSON.stringify(c),d=build(c);assert.equal(JSON.stringify(c),before,"Input mutation");assert.equal(d.nextActions.length,5);assert.equal(new Set(d.nextActions.map(a=>a.track)).size,5);assert.equal(d.nextActions[0].title,"Start one music project");assert(d.nextActions.every(a=>a.evidence&&a.why));assert(!("scores" in d)&&!("tracks" in d)&&!("stage" in d));assert(d.risks.some(x=>x.includes("offline")));
c=context();c.tracks.signals.profile=0;assert.equal(build(c).nextActions.find(a=>a.track==="creative").title,"Complete your artist identity and goal");
c=context();c.minor=true;d=build(c);assert(d.nextActions.find(a=>a.track==="business").title.includes("guardian"));assert(!d.nextActions.find(a=>a.track==="business").title.includes("budget"));
c=context();c.progress.held=true;c.progress.stage="release";c.progress.evidenced_stage="plan";d=build(c);assert(d.stageRationale.includes("plan"));assert(d.risks.some(x=>x.includes("retained")));
c=context();c.tracks.signals.projects=1;c.tracks.tracks.network.partial=true;c.tracks.tracks.network.breakdown.push({signal:"quotes",available:false,units:null});d=build(c);assert.equal(d.evidenceQuality,"partial");assert(d.trackNotes.network.includes("not integrated"));
c=context();c.tracks.signals={};d=build(c);assert.equal(d.evidenceQuality,"thin");assert(d.nextActions.every(a=>a.title.startsWith("Check")));assert(d.nextActions.every(a=>a.evidence.includes("unavailable")));
assert.throws(()=>build({}),/required/);
const source=fs.readFileSync(process.argv[3]||"studio-member.html","utf8"),start=source.indexOf("function renderDirection("),end=source.indexOf("async function loadMilestones(target)",start);assert(start>=0&&end>start);const renderer=source.slice(start,end);
function node(){return {children:[],textContent:"",append(...v){this.children.push(...v);},replaceChildren(){this.children=[];},scrollIntoView(){this.scrolled=true;}};}
const elements=new Map();const el=id=>{if(!elements.has(id))elements.set(id,node());return elements.get(id);};let calls=[];
const sandbox={el,document:{createElement:()=>node()},window:{LionsRockDirection:globalThis.LionsRockDirection},uid:"artist",isOwner:false,isMinor:true,artistMinorIds:new Set(),milestoneGeneration:1,generation:1,shortcut:name=>calls.push(name)};vm.createContext(sandbox);vm.runInContext(renderer,sandbox);
c=context();sandbox.renderDirection({data:c.progress},{data:c.tracks},"artist",1,1);
let root=el("career-direction");assert(root.children.length>5);let rows=root.children.filter(n=>n.className==="row");assert.equal(rows.length,5);const business=rows.find(r=>r.children[0].textContent.startsWith("Business"));assert(business.children[0].textContent.includes("guardian"));business.children.at(-1).onclick();assert.equal(calls[0],"projects");
sandbox.generation=2;business.children.at(-1).onclick();assert.equal(calls.length,1,"Stale navigation allowed");
sandbox.renderDirection({error:{message:"denied"}},{data:c.tracks},"artist",1,2);assert.equal(el("career-direction").children.length,3);assert(el("career-direction").children[1].textContent.includes("Refresh"));
// Intent is explicit, and free text is displayed without pretending to interpret it.
c=context();c.profile={artist_name:"Artist",genres:"Soca",goal_12_months:"Do not release anything yet",direction_focus:"release",direction_obstacle:"time"};
before=JSON.stringify(c);d=build(c);assert.equal(JSON.stringify(c),before);assert.equal(d.nextActions[0].track,"creative","Foundation must precede preferences");assert(d.nextActions.find(a=>a.track==="momentum").why.includes("15–30"));assert(d.personalisation.goal.includes("Do not release"));assert(d.nextActions.find(a=>a.track==="audience").why.includes("before publishing"));
c.tracks.signals.projects=2;c.tracks.signals.uploads=1;c.tracks.signals.masters=1;c.tracks.signals.masters_collected=1;
d=build(c);assert(["momentum","audience"].includes(d.nextActions[0].track));assert(d.nextActions.find(a=>a.track==="audience").title.includes("readiness"));
for(const focus of Object.keys(globalThis.LionsRockDirection.focusOptions))for(const obstacle of Object.keys(globalThis.LionsRockDirection.obstacleOptions)){
 c.profile.direction_focus=focus;c.profile.direction_obstacle=obstacle;c.minor=true;d=build(c);
 assert.equal(d.nextActions.length,5);assert.equal(new Set(d.nextActions.map(a=>a.track)).size,5);assert(d.nextActions.every(a=>a.why&&a.evidence));
 assert(d.nextActions.find(a=>a.track==="business").title.includes("guardian"),"Minor guidance must route business to guardian");
 assert(!JSON.stringify(d).includes("undefined"));assert(!("scores" in d)&&!("stage" in d));
}
c=context();c.profile={direction_focus:"<script>",direction_obstacle:"unknown"};d=build(c);assert.equal(d.personalisation.chosen,false);
c=context();c.profile={direction_focus:"recording",direction_obstacle:"budget"};c.tracks.signals={};d=build(c);assert(d.nextActions.every(a=>a.title.startsWith("Check")),"Preferences cannot invent missing evidence");
c=context();c.profileUnavailable=true;d=build(c);assert.equal(d.personalisation.profileUnavailable,true);
// Owner sees exactly the same selected Artist's guidance and stale controls cannot act.
sandbox.isOwner=true;sandbox.isMinor=false;sandbox.artistMinorIds.add("artist");sandbox.generation=1;el("milestone-artist").value="artist";
c=context();c.profile={direction_focus:"business"};sandbox.renderDirection({data:c.progress},{data:c.tracks},"artist",1,1,c.profile);
root=el("career-direction");rows=root.children.filter(n=>n.className==="row");assert(rows.some(r=>r.children[0].textContent.includes("guardian")));assert.equal(el("artist-direction-preview").children.length,0);
let refresh=root.children.find(n=>n.textContent==="Refresh guidance");let refreshed=[];sandbox.loadMilestones=id=>refreshed.push(id);refresh.onclick();assert.deepEqual(refreshed,["artist"]);
el("milestone-artist").value="other";refresh.onclick();assert.equal(refreshed.length,1);
assert(source.includes('direction_focus:el("career-focus").value'));assert(source.includes('direction_obstacle:el("career-obstacle").value'));assert(source.includes('setProfileEditing(false)'));
// Untrusted profile strings are rendered as text, never HTML.
sandbox.isOwner=false;c.profile={goal_12_months:"<img src=x onerror=alert(1)>"};sandbox.renderDirection({data:c.progress},{data:c.tracks},"artist",1,1,c.profile);
assert(el("career-direction").children.some(n=>n.textContent.includes("<img src=x")));assert(!renderer.includes("innerHTML"));
console.log("PASS Direction Engine: evidence-backed five-track actions, incomplete evidence, retained stage, minor-safe guidance, input preservation, current-source rendering/error clear and stale navigation guard");

