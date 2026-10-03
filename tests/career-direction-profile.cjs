const assert=require("node:assert/strict"),fs=require("node:fs"),vm=require("node:vm");
require("../career-direction.js");
const source=fs.readFileSync("studio-member.html","utf8");
const start=source.indexOf(" function setProfileEditing("),end=source.indexOf(" let notificationGeneration=",start);
assert(start>=0&&end>start);
function node(){
 const classes=new Set();
 return {value:"",textContent:"",children:[],disabled:false,style:{},
  classList:{toggle(k,on){if(on)classes.add(k);else classes.delete(k);},contains:k=>classes.has(k)},
  append(...v){this.children.push(...v);},replaceChildren(){this.children=[];},focus(){},addEventListener(){}};
}
const els=new Map(),el=id=>{if(!els.has(id))els.set(id,node());return els.get(id);};
let stored={username:"sample_artist",goal_key:"record_single",artist_name:"Sample Artist",genres:"Soca",goal_12_months:"Finish one song",direction_focus:"recording",direction_obstacle:"time"},fail=false,refreshes=0;
const sb={from:()=>({select(){return this},eq(){return this},maybeSingle:async()=>({data:{...stored},error:null}),
 upsert:async values=>{if(fail)return {error:{message:"Save failed"}};stored={...values};return {error:null};}})};
const sandbox={el,sb,usernameValue:id=>el(id).value.trim().toLowerCase(),window:{LionsRockDirection:globalThis.LionsRockDirection},isOwner:false,uid:"artist",generation:1,document:{createElement:node},requestAnimationFrame:f=>f(),
 withLoadTimeout:p=>p,loadMilestones:async()=>{refreshes++;},load:async()=>{},render:()=>{}};
vm.createContext(sandbox);vm.runInContext(source.slice(start,end),sandbox);
(async()=>{
 await sandbox.loadCareerProfile(1);
 assert.equal(el("career-focus").value,"recording");assert.equal(el("career-obstacle").value,"time");
 assert(el("career-profile-form").classList.contains("profile-complete"));assert(el("profile-edit-fields").classList.contains("hidden"));
 sandbox.setProfileEditing(true);el("career-focus").value="release";el("career-obstacle").value="unfinished";
 await el("career-profile-form").onsubmit({preventDefault(){}});
 assert.equal(stored.direction_focus,"release");assert.equal(stored.direction_obstacle,"unfinished");
 assert(el("profile-edit-fields").classList.contains("hidden"));assert.equal(refreshes,1);
 await sandbox.loadCareerProfile(1);assert.equal(el("career-focus").value,"release");
 sandbox.setProfileEditing(true);fail=true;el("career-focus").value="audience";
 await el("career-profile-form").onsubmit({preventDefault(){}});
 assert.equal(stored.direction_focus,"release");assert(!el("profile-edit-fields").classList.contains("hidden"));
 assert.equal(el("career-profile-status").textContent,"Save failed");assert.equal(el("save-career-profile").disabled,false);
 sandbox.isOwner=true;fail=false;await el("career-profile-form").onsubmit({preventDefault(){}});assert.equal(stored.direction_focus,"release","Owner must not edit an Artist profile");
 console.log("PASS Direction Profile: saved choices reload, optional choices preserve completion, editor closes after success, errors keep edits open, Owner write blocked");
})().catch(e=>{console.error(e);process.exitCode=1;});
