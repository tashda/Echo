/* ===== helpers ===== */
const $=(s,r=document)=>r.querySelector(s), $$=(s,r=document)=>[...r.querySelectorAll(s)];
function h(tag,attrs,...kids){const e=document.createElement(tag);for(const k in (attrs||{})){const v=attrs[k];if(k==='class')e.className=v;else if(k==='text')e.textContent=v;else if(k.startsWith('on'))e.addEventListener(k.slice(2),v);else if(v!==false&&v!=null)e.setAttribute(k,v===true?'':v)}
 for(const c of kids.flat()){if(c==null||c===false)continue;e.append(c.nodeType?c:document.createTextNode(c))}return e}
function ic(id){const s=document.createElementNS('http://www.w3.org/2000/svg','svg');s.setAttribute('class','ic');const u=document.createElementNS('http://www.w3.org/2000/svg','use');u.setAttribute('href','#i-'+id);s.append(u);return s}

/* ===== sidebar for mocks ===== */
function sidebar(active){
  const it=(id,icon,label,badge)=>`<div class="si${active===id?' on':''}"><svg class="ic"><use href="#i-${icon}"/></svg>${label}${badge?`<span class="b">${badge}</span>`:''}</div>`;
  return `<div class="proj"><svg class="ic"><use href="#i-branch"/></svg>Echo<small>dev ▾</small></div>
  <div class="grp">Work</div>${it('desk','desk','Desk',4)}${it('tickets','list','Tickets')}${it('board','board','Board')}${it('previews','eye','Previews',1)}
  <div class="grp">Reference</div>${it('specs','doc','Specs')}${it('decisions','flag','Decisions')}
  <div class="grp">Machine</div>${it('agents','cpu','Agents')}${it('log','log','Log')}
  <div class="sync">Synced with GitHub · 2 min ago</div>`;
}
$$('[data-sb]').forEach(e=>{e.innerHTML=sidebar(e.dataset.sb)});

/* ===== statuses and flow ===== */
const ALL='question sketch proposal tweak bug theme', PIPE='question sketch proposal tweak bug';
const LANES=['Intake','Exploring','Building','Landed','Off'];
const STAT=[
['Draft','you',0,ALL,'Writing it. Stays on this Mac until you submit.','You press Submit for check','not on GitHub yet'],
['Checking','agent',0,PIPE,'An agent compares it with open tickets and the Spec and writes its questions.','Hatch on submit, the agent finishes','status:checking'],
['Needs answers','you',0,PIPE,'Hatch has questions before work can start.','The agent, with hatch ask','status:needs-answers'],
['Ready','app',0,PIPE,'Complete, waiting for a free agent.','Hatch, when everything is answered','status:ready'],
['Preparing','agent',1,'question sketch proposal','The agent is making the reply, variants or specimens.','The agent, with hatch take','status:preparing'],
['Your call','you',1,'question sketch proposal','Options are ready to judge, or a reply waits for you.','The agent, with hatch offer','status:your-call'],
['Revising','agent',1,'sketch proposal','You sent it back. Old options stay, new ones are added.','You, with Send back','status:revising'],
['Accepted','app',2,'proposal','You chose. Waiting for a build slot or for claimed files.','You, with Accept','status:accepted'],
['Building','agent',2,'proposal tweak bug','Implementing in its own workspace.','The agent, with hatch take and plan','status:building'],
['To verify','you',2,'proposal tweak bug','In a Preview, waiting for you on your Mac.','Hatch, after build, tests and match check pass','status:to-verify'],
['Fixing','agent',2,'proposal tweak bug','You marked Needs work in a Preview.','You, with Needs work','status:fixing'],
['Merged','app',3,'proposal tweak bug','Merged into dev. Design system tagged if needed.','Hatch, when you press Merge','status:merged'],
['Done','done',3,ALL,'Spec and Decisions updated. Issue closed.','Hatch, after the agent records the change','closed (completed)'],
['Blocked','app',4,ALL,'Waiting on another ticket or on claimed files. Shows which.','Hatch','status:blocked'],
['Parked','off',4,ALL,'You paused it. It leaves the Desk.','You','status:parked'],
['Dropped','off',4,ALL,'Will not be done. Kept for history.','You','closed (not planned)'],
];
const TYPES=[['all','All'],['question','Question'],['sketch','Sketch'],['proposal','Proposal'],['tweak','Tweak'],['bug','Bug'],['theme','Theme']];
(function flow(){
  const lanes=$('#lanes');LANES.forEach((n,i)=>{const l=h('div',{class:'lane'},h('h4',{text:n}));STAT.filter(s=>s[2]===i).forEach(s=>l.append(h('span',{class:'chip '+s[1],'data-t':s[3]},s[0])));lanes.append(l)});
  const pb=$('#pathBtns');
  const set=t=>{$$('button',pb).forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.t===t)));$$('.lane .chip').forEach(c=>c.classList.toggle('dim',t!=='all'&&!c.dataset.t.split(' ').includes(t)))};
  TYPES.forEach(([k,n])=>pb.append(h('button',{type:'button','data-t':k,'aria-pressed':String(k==='all'),onclick:()=>set(k)},n)));
  const tb=$('#statusTable');tb.append(h('tr',{},...['Status','Turn','Meaning','Moved by','GitHub'].map(x=>h('th',{text:x}))));
  const turn={you:'You',agent:'Agent',app:'Hatch',done:'Finished',off:'Paused'};
  STAT.forEach(s=>tb.append(h('tr',{},h('td',{},h('span',{class:'chip '+s[1]},s[0])),h('td',{text:turn[s[1]]}),h('td',{text:s[4]}),h('td',{text:s[5]}),h('td',{},h('code',{text:s[6]})))));
})();

/* ===== state: decisions and notes ===== */
let db=null,uid=null,dbReady=false;
const decisions={}, notes=[];       // decisions[id]={choice,rec,at}; notes:{id,item,kind,text,status,reply,at}
const optName=(d,k)=>{const o=d.opts.find(x=>x.k===k);return o?o.n:k};
const banner=$('#dbBanner');
function showBanner(t,warn){banner.textContent=t;banner.classList.add('show');banner.classList.toggle('warn',!!warn)}

/* ===== render decision cards ===== */
function wireSvg(key){
  const r=WIRES[key];if(!r)return null;
  const s=document.createElementNS('http://www.w3.org/2000/svg','svg');s.setAttribute('viewBox','0 0 100 64');s.setAttribute('class','wire');s.setAttribute('role','img');s.setAttribute('aria-label','Layout sketch');
  r.forEach(([x,y,w,hh,c])=>{const e=document.createElementNS('http://www.w3.org/2000/svg','rect');e.setAttribute('x',x);e.setAttribute('y',y);e.setAttribute('width',w);e.setAttribute('height',hh);e.setAttribute('rx',2);if(c)e.setAttribute('class',c);s.append(e)});return s;
}
const writeQ={};
function queue(key,fn){writeQ[key]=(writeQ[key]||Promise.resolve()).then(fn).catch(e=>showBanner('Could not save: '+(e&&e.message||e),true))}
function choose(d,k){
  const v={choice:k,rec:k===d.rec,at:Date.now(),by:uid};
  decisions[d.id]=v;refreshCard(d.id);refreshProgress();
  if(db)queue('d'+d.id,()=>db.doc('decisions/'+d.id).set(v));
}
function addNote(item,kind,text){
  const n={item,kind,text,status:'open',at:Date.now(),by:uid};
  if(db){queue('n'+Math.random(),async()=>{await db.collection('notes').add(n)})}else{n.id='local'+Math.random();notes.push(n);refreshAllNotes()}
}
function delNote(id){if(db&&!String(id).startsWith('local'))queue('x'+id,()=>db.doc('notes/'+id).delete());else{const i=notes.findIndex(n=>n.id===id);if(i>=0)notes.splice(i,1);refreshAllNotes()}}
function noteEl(n){
  const el=h('div',{class:'nt '+n.kind},
    h('div',{class:'meta'},h('b',{text:n.kind==='question'?'Question':'Note'}),
      n.kind==='question'?h('span',{class:'chip '+(n.status==='answered'?'done':'you'),text:n.status==='answered'?'Answered':'Open'}):null,
      h('span',{text:new Date(n.at).toLocaleString([], {month:'short',day:'numeric',hour:'2-digit',minute:'2-digit'})}),
      n.status!=='answered'?h('button',{class:'x',type:'button',onclick:()=>delNote(n.id)},'Delete'):null),
    h('div',{text:n.text}));
  if(n.reply)el.append(h('div',{class:'reply'},h('b',{text:'Hatch design reply: '}),document.createTextNode(n.reply)));
  return el;
}
function buildCard(d){
  const card=h('article',{class:'dec',id:'dec-'+d.id,'data-id':d.id});
  const state=h('span',{class:'state'});
  card.append(h('div',{class:'top'},h('span',{class:'tag',text:d.id}),h('h4',{text:d.title}),state));
  if(d.q)card.append(h('p',{class:'qtext',text:d.q}));
  const opts=h('div',{class:'opts',role:'radiogroup','aria-label':d.title});
  d.opts.forEach(o=>{
    const inp=h('input',{type:'radio',name:'r-'+d.id,value:o.k,onchange:()=>choose(d,o.k)});
    const lab=h('label',{class:'opt','data-k':o.k},inp,wireSvg(o.w),
      h('div',{class:'nm'},h('span',{class:'k',text:o.k}),o.n,o.k===d.rec?h('span',{class:'star',text:'★ Recommended'}):null),
      o.d?h('div',{class:'ds',text:o.d}):null);
    opts.append(lab);
  });
  card.append(opts);
  card.append(h('div',{class:'why'},h('b',{text:'I recommend '+optName(d,d.rec)+'. '}),d.why));
  const compose=h('div',{class:'compose',hidden:true});
  const ta=h('textarea',{'aria-label':'Your note or question about '+d.title,placeholder:'Write here…'});
  let kind='note';
  const save=h('button',{class:'btn pri sm',type:'button',onclick:()=>{const t=ta.value.trim();if(!t)return;addNote(d.id,kind,t);ta.value='';compose.hidden=true}},'Save');
  compose.append(ta,h('div',{class:'row'},save,h('button',{class:'btn sm',type:'button',onclick:()=>{compose.hidden=true}},'Cancel')));
  const open=k=>{kind=k;save.textContent=k==='question'?'Send question':'Save note';ta.placeholder=k==='question'?'What do you want to know before deciding?':'Context, preference, or something I should consider…';compose.hidden=false;ta.focus()};
  card.append(h('div',{class:'acts'},
    h('button',{class:'btn pri sm','data-role':'userec',type:'button',onclick:()=>choose(d,d.rec)},'Use recommendation'),
    h('button',{class:'btn sm',type:'button',onclick:()=>open('note')},'Add note'),
    h('button',{class:'btn sm',type:'button',onclick:()=>open('question')},'Ask a question')));
  card.append(compose,h('div',{class:'nts','data-role':'notes'}));
  card._state=state;return card;
}
const cards={};
function refreshCard(id){
  const d=DECISIONS.find(x=>x.id===id),card=cards[id];if(!card)return;
  const v=decisions[id];
  $$('.opt',card).forEach(l=>{const on=v&&v.choice===l.dataset.k;l.classList.toggle('on',!!on);$('input',l).checked=!!on});
  card.classList.toggle('decided',!!v);
  const mine=notes.filter(n=>n.item===id),openQ=mine.filter(n=>n.kind==='question'&&n.status!=='answered').length;
  const st=card._state;st.className='state';
  if(openQ){st.textContent=openQ+' open question'+(openQ>1?'s':'')+(v?' · decided':'');st.classList.add('q')}
  else if(v){st.textContent=v.choice===d.rec?'Decided · my recommendation':'Decided · Option '+v.choice;st.classList.add('ok')}
  else st.textContent='Undecided';
  const ub=$('[data-role=userec]',card);ub.disabled=!!(v&&v.choice===d.rec);
  const box=$('[data-role=notes]',card);box.replaceChildren(...mine.map(noteEl));
  applyFilter();
}
function refreshAllNotes(){
  DECISIONS.forEach(d=>refreshCard(d.id));
  const box=$('#allNotes');box.replaceChildren(...[...notes].sort((a,b)=>b.at-a.at).map(n=>{
    const e=noteEl(n);const d=DECISIONS.find(x=>x.id===n.item);
    e.querySelector('.meta').prepend(d?h('a',{href:'#dec-'+d.id,text:d.id+' '+d.title}):h('span',{class:'tag',text:'General'}));return e}));
  if(!notes.length)box.append(h('p',{class:'muted',text:'Nothing yet.'}));
  refreshProgress();
}
function refreshProgress(){
  const total=DECISIONS.length,done=DECISIONS.filter(d=>decisions[d.id]).length;
  $('#meterFill').style.width=(100*done/total)+'%';
  $$('#tocLinks a').forEach(a=>{const s=a.dataset.sec;if(!s)return;const ds=DECISIONS.filter(d=>d.sec===s),n=ds.filter(d=>decisions[d.id]).length;const el=$('.n',a);el.textContent=n+'/'+ds.length;el.classList.toggle('full',n===ds.length)});
  $('#tocTotal').textContent=done+' of '+total+' decided';
  refreshReview();
}
let onlyOpen=false;
function applyFilter(){$$('.dec').forEach(c=>{c.hidden=onlyOpen&&c.classList.contains('decided')&&!/open question/.test(c._state.textContent)})}

/* ===== build page ===== */
$$('.decs').forEach(box=>{DECISIONS.filter(d=>d.sec===box.dataset.sec).forEach(d=>{const c=buildCard(d);cards[d.id]=c;box.append(c)})});
(function toc(){
  const t=$('#tocLinks');t.append(h('div',{class:'muted',id:'tocTotal',style:'font-size:12px;margin:0 8px 6px'}));
  $$('section.sec').forEach(s=>{const sec=s.id.replace('s-','');const has=DECISIONS.some(d=>d.sec===sec);
    t.append(h('a',{href:'#'+s.id,'data-sec':has?sec:null},h('span',{text:s.dataset.title}),has?h('span',{class:'n'}):null))});
})();
$('#btnFilter').addEventListener('click',e=>{onlyOpen=!onlyOpen;e.currentTarget.setAttribute('aria-pressed',String(onlyOpen));e.currentTarget.textContent=onlyOpen?'Show all decisions':'Show only open decisions';applyFilter()});
let confirmTimer=null;
$('#btnAllRec').addEventListener('click',e=>{
  const b=e.currentTarget,open=DECISIONS.filter(d=>!decisions[d.id]);
  if(!open.length){b.textContent='Nothing left to decide';setTimeout(()=>b.textContent='Use all recommendations',2000);return}
  if(!b.dataset.arm){b.dataset.arm='1';b.textContent='Confirm: set '+open.length+' undecided';clearTimeout(confirmTimer);confirmTimer=setTimeout(()=>{delete b.dataset.arm;b.textContent='Use all recommendations'},4000);return}
  clearTimeout(confirmTimer);delete b.dataset.arm;b.textContent='Use all recommendations';open.forEach(d=>choose(d,d.rec));
});
$('#generalNote').addEventListener('click',()=>{const t=$('#generalText');if(t.value.trim()){addNote('general','note',t.value.trim());t.value=''}});
$('#generalAsk').addEventListener('click',()=>{const t=$('#generalText');if(t.value.trim()){addNote('general','question',t.value.trim());t.value=''}});
DECISIONS.forEach(d=>refreshCard(d.id));refreshAllNotes();

/* ===== database ===== */
(async function connect(){
  try{
    if(!window.claude||!claude.use){showBanner('Saving is not available here. Your picks stay on this page until you leave it.',true);return}
    db=await claude.use('db');
    if(!db){showBanner('Saving needs a signed-in view. Your picks stay on this page until you leave it.',true);return}
    try{const u=await claude.use('user');uid=u?await u.id():null}catch(_){}
    const err=e=>showBanner('Live updates stopped ('+(e&&e.code||'error')+'). Reload the page.',true);
    db.collection('decisions').onSnapshot(snap=>{
      for(const k in decisions)delete decisions[k];
      snap.docs.forEach(x=>{decisions[x.id]=x.data()});
      DECISIONS.forEach(d=>refreshCard(d.id));refreshProgress();
    },err);
    db.collection('notes').orderBy('at').onSnapshot(snap=>{
      notes.length=0;snap.docs.forEach(x=>notes.push({id:x.id,...x.data()}));refreshAllNotes();
    },err);
  }catch(e){showBanner('Saving is not available here. Your picks stay on this page until you leave it.',true)}
})();

/* ===== Proposal stage prototype ===== */
const S={mode:'side',app:'light',corner:10,scen:'rest',red:false,flip:0,cmp:'B',opa:50,wipe:50,padB:16,iconB:28,L:true,R:true,n5:false,sel:'A',verdict:{},q1:'',q2:'',shown:false};
const SCENS=[['rest','Rest'],['hover','Hover'],['error','Error'],['long','Long text'],['many','Many items']];
const OPTS={T:{name:'Echo today',pad:10,gap:8,ic:20,fs:12},A:{name:'Option A · Quiet',pad:12,gap:10,ic:22,fs:12.5},B:{name:'Option B · Roomy'},C:{name:'Option C · Balanced',pad:14,gap:12,ic:24,fs:12.5},D:{name:'Option D · Large',pad:18,gap:15,ic:30,fs:13},E:{name:'Option E · Airy',pad:20,gap:17,ic:32,fs:13.5}};
const optionKeys=()=>S.n5?['A','B','C','D','E']:['A','B'];
const optv=k=>k==='B'?{name:OPTS.B.name,pad:S.padB,gap:Math.round(S.padB*0.85),ic:S.iconB,fs:13}:OPTS[k];
function toast(k,scen,opts){
  const o=optv(k),red=opts&&opts.red;
  const t={rest:['Connection restored','Prod-EU is reachable again.',''],hover:['Connection restored','Prod-EU is reachable again.','hov'],error:['Query failed','Timed out after 30 s.','err'],long:['Export finished','4,812 rows written to "Quarterly revenue by region and product line.csv" in your Downloads folder.',''],many:['Connection restored','Prod-EU is reachable again.','']}[scen];
  const cls=['tst',k==='T'?'':k,'r'+S.corner,t[2]].filter(Boolean).join(' ');
  const el=document.createElement('div');el.className=cls;
  const z=(opts&&opts.compact)?(opts.compact===true?0.72:opts.compact):1;el.style.cssText=`--pad:${o.pad*z}px;--gap:${o.gap*z}px;--ic:${o.ic*z}px;--fs:${o.fs*z}px`;
  el.innerHTML=`<div class="i"></div><div class="b"><b></b><span></span><div class="act"><u>${scen==='error'?'Retry':'View'}</u><u>Dismiss</u></div></div><div class="cl">✕</div>`;
  el.querySelector('b').textContent=t[0];el.querySelector('span').textContent=t[1];
  if(red&&scen==='rest'){
    el.insertAdjacentHTML('beforeend',`<span class="rl" style="inset:${o.pad}px;border:1px dashed #E5484D"></span><span class="rl lb" style="left:3px;top:${Math.max(0,o.pad/2-6)}px">${o.pad}</span><span class="rl lb" style="left:${o.pad+o.ic+o.gap/2-7}px;top:${o.pad+o.ic+3}px">${o.gap}</span>`);
  }
  if(scen==='many'){const w=document.createElement('div');w.style.cssText='display:grid;gap:8px;width:min(100%,250px)';const a=el.cloneNode(true),b=el.cloneNode(true);b.querySelector('b').textContent='Sync complete';b.querySelector('span').textContent='3 changes pulled.';a.querySelector('b').textContent='Backup saved';a.querySelector('span').textContent='Prod-EU at 12:04.';w.append(el,a,b);return w}
  return el;
}
function est(k,scen){const o=optv(k);const lines=scen==='long'?3:2;return 2*o.pad+Math.max(o.ic,lines*(o.fs+3))+(scen==='hover'||scen==='error'?20:0)+(scen==='many'?2*(2*o.pad+o.fs*2+8):0)}
function slot(k,scen,opts){const s=document.createElement('div');s.className='slot';s.append(toast(k,scen,opts));return s}
function colHead(k){
  const d=optv(k);const x=document.createElement('div');x.className='xh';
  x.innerHTML=`<span></span>${k==='T'?'<span class="badge ok">Matches Echo · checked 2 days ago</span>':''}`;x.firstChild.textContent=d.name;
  if(k!=='T'){const p=document.createElement('span');p.className='pick';['Pick','Maybe','No'].forEach(v=>{const b=document.createElement('button');b.type='button';b.textContent=v;b.setAttribute('aria-pressed',String((S.verdict[k]||'')===v));b.onclick=()=>{S.verdict[k]=(S.verdict[k]||'')===v?'':v;draw()};p.append(b)});x.append(p)}
  return x;
}
function centre(){
  const el=$('#stg');if(!el)return;el.dataset.app=S.app;el.replaceChildren();
  const strip=h('div',{class:'scen'},...SCENS.map(([k,n])=>h('button',{type:'button','aria-pressed':String(S.scen===k),onclick:()=>{S.scen=k;draw()}},n)),h('button',{type:'button',disabled:true,title:'Not applicable: a toast has no empty state.',style:'opacity:.5;border-style:dashed'},'Empty · n/a'));
  el.append(strip);
  const sc=S.scen;
  if(S.mode==='side'){
    if(S.n5){
      const g=h('div',{class:'cols c2'});['T',S.sel].forEach(k=>{const c=h('div',{});c.append(colHead(k),slot(k,sc,{red:S.red,compact:0.9}));g.append(c)});el.append(g);
      const fs=h('div',{style:'display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:6px;margin-top:4px'});
      optionKeys().forEach(k=>{const b=h('button',{type:'button','aria-pressed':String(S.sel===k),title:optv(k).name,style:'border:1.5px solid '+(S.sel===k?'var(--sacc)':'var(--sl)')+';background:var(--card);color:var(--st);border-radius:8px;padding:5px 4px;font-size:10px;display:grid;gap:3px;justify-items:center;min-width:0',onclick:()=>{S.sel=k;draw()}},h('span',{text:optv(k).name.split(' ·')[0]}));b.append(toast(k,sc==='many'?'rest':sc,{compact:0.42}));fs.append(b)});
      el.append(fs,h('div',{style:'font-size:10.5px;color:var(--sm)'},'Four or more options: two shown large, the rest in the filmstrip. Arrow keys move through it.'));
    }else{
      const g=h('div',{class:'cols c3'});['T','A','B'].forEach(k=>{const c=h('div',{});c.append(colHead(k),slot(k,sc,{red:S.red,compact:0.86}));g.append(c)});el.append(g);
    }
  }else if(S.mode==='matrix'){
    const mk=['T','A','B'].concat(S.n5&&!['A','B'].includes(S.sel)?[S.sel]:[]);
    const m=h('div',{class:'matrix',style:'grid-template-columns:76px repeat('+mk.length+',minmax(0,1fr))'},h('span'),...mk.map(k=>h('span',{class:'h',text:optv(k).name.split(' ·')[0]})));
    SCENS.forEach(([sk,sn])=>{m.append(h('span',{class:'h',text:sn}));mk.forEach(k=>{const diff=k!=='T'&&Math.abs(est(k,sk)-est('T',sk))>14;const cell=h('div',{class:diff?'df':''});cell.append(toast(k,sk,{compact:true}));m.append(cell)})});
    el.append(m,h('div',{style:'font-size:10.5px;color:var(--sm)'},'Outlined: height differs from Echo today by more than 14pt in that scenario.'));
  }else{
    const cmp=h('div',{class:'xh'},h('span',{text:S.mode==='flip'?'Flip':S.mode==='overlay'?'Overlay':'Wipe'}),
      h('span',{class:'badge',text:'Echo today vs'}),
      (()=>{const s=h('span',{class:'scen'});optionKeys().forEach(k=>s.append(h('button',{type:'button','aria-pressed':String(S.cmp===k),onclick:()=>{S.cmp=k;draw()}},'Option '+k)));return s})());
    el.append(cmp);
    if(S.mode==='flip'){
      const cur=S.flip?S.cmp:'T';
      el.append(h('div',{class:'xh'},h('b',{text:'Showing: '+optv(cur).name}),h('button',{type:'button',class:'btn sm',onclick:()=>{S.flip=S.flip?0:1;draw()}},'Flip (Space)')),slot(cur,sc,{red:S.red}));
    }else{
      const ctl=h('div',{class:'rngrow'},S.mode==='overlay'?'Option opacity':'Reveal',h('input',{type:'range',min:0,max:100,value:S.mode==='overlay'?S.opa:S.wipe,'aria-label':S.mode==='overlay'?'Option opacity':'Wipe position',oninput:e=>{S[S.mode==='overlay'?'opa':'wipe']=+e.target.value;layers()}}));
      const ov=h('div',{class:'ovl',id:'ovl',style:'min-height:'+(sc==='many'?300:210)+'px'});
      ['T',S.cmp].forEach((k,i)=>{const L=h('div',{class:'layer','data-i':i,style:'position:absolute;inset:0;display:grid;justify-items:center;align-content:start;padding:14px 10px'});L.append(toast(k,sc,{red:S.red&&i===1}));ov.append(L)});
      el.append(ctl,ov);layers();
    }
  }
}
function layers(){const ov=$('#ovl');if(!ov)return;const top=$('[data-i="1"]',ov);if(!top)return;
  if(S.mode==='overlay'){top.style.opacity=S.opa/100;top.style.clipPath='none'}else{top.style.opacity=1;top.style.clipPath=`inset(0 ${100-S.wipe}% 0 0)`}}
function draw(){
  const m=$('#stageMount');if(!m)return;
  const seg=(items,cur,fn)=>{const s=h('span',{class:'seg'});items.forEach(([k,n])=>s.append(h('button',{type:'button','aria-pressed':String(cur===k),onclick:()=>fn(k)},n)));return s};
  const bar=h('div',{class:'bar'},
    h('b',{style:'font-family:var(--f-head);font-size:13px',text:'#151 Toast spacing'}),
    seg([['side','Side by side'],['overlay','Overlay'],['flip','Flip'],['wipe','Wipe'],['matrix','Matrix']],S.mode,k=>{S.mode=k;draw()}),
    h('span',{class:'sp'}),
    seg([['light','Light'],['dark','Dark'],['contrast','Contrast']],S.app,k=>{S.app=k;draw()}),
    seg([[10,'Corners 10'],[26,'Corners 26']],S.corner,k=>{S.corner=k;draw()}),
    h('button',{type:'button',class:'mb','aria-pressed':String(S.red),style:S.red?'background:var(--accent);color:var(--accent-ink)':'',onclick:()=>{S.red=!S.red;draw()}},'Redlines'),
    h('button',{type:'button',class:'mb','aria-pressed':String(S.L),onclick:()=>{S.L=!S.L;draw()}},S.L?'Hide controls':'Controls'),
    h('button',{type:'button',class:'mb','aria-pressed':String(S.R),onclick:()=>{S.R=!S.R;draw()}},S.R?'Hide decision':'Decision'));
  const ctl=h('div',{class:'ctl'});
  if(S.L){
    ctl.append(h('h6',{text:'Decision controls'}),
      h('div',{class:'optrow'},h('div',{class:'ln'},h('b',{text:'Padding, Option B'}),h('span',{id:'padv',text:S.padB+' pt'})),
        h('input',{type:'range',min:10,max:22,value:S.padB,'aria-label':'Padding on Option B',oninput:e=>{S.padB=+e.target.value;$('#padv').textContent=S.padB+' pt';centre()}}),
        h('div',{class:'muted',style:'font-size:10.5px'},'★ Hatch recommends 16 pt')),
      h('div',{class:'optrow'},h('div',{class:'ln'},h('b',{text:'Icon size, Option B'})),
        seg([[22,'Small'],[28,'Medium'],[34,'Large']],S.iconB,k=>{S.iconB=k;draw()}),
        h('div',{class:'muted',style:'font-size:10.5px'},'★ Hatch recommends Medium')),
      h('div',{style:'display:flex;gap:6px;margin:8px 0'},h('button',{type:'button',class:'mb',onclick:()=>{S.padB=16;S.iconB=28;draw()}},'Recommended preset'),h('button',{type:'button',class:'mb',onclick:()=>{S.padB=20;S.iconB=34;draw()}},'Reset')),
      h('h6',{text:'Playground ▸ (folded)',style:'margin-top:12px'}),h('div',{class:'muted',style:'font-size:10.5px;margin-bottom:6px'},'Knobs without a question, like dismiss time, live here.'),h('button',{type:'button',class:'mb',onclick:()=>{S.n5=!S.n5;if(!S.n5&&!['A','B'].includes(S.cmp))S.cmp='B';draw()}},S.n5?'Demo: back to 2 options':'Demo: 5 options'));
  }
  const dcn=h('div',{class:'dcn'});
  if(S.R){
    const rc=(name,key,rec,why)=>h('div',{class:'dcard'},h('b',{text:name}),
      ...[['T','Echo today'],['A','Option A'],['B','Option B']].map(([k,n])=>h('label',{},h('input',{type:'radio',name:'p'+key,checked:S[key]===k,onchange:()=>{S[key]=k}}),n+(k===rec?' ★':''))),
      h('div',{class:'rc',text:'I recommend '+(rec==='B'?'Option B':'Option A')}),h('div',{class:'muted',text:why}));
    dcn.append(h('h6',{text:'Your decision'}),rc('Which spacing?','q1','B','Matches the 12pt rhythm from #118 and keeps the error toast readable at Large text.'),rc('Which icon size?','q2','A','The icon should not outweigh the title.'),
      h('div',{style:'display:grid;gap:6px'},h('button',{type:'button',class:'mb pri',onclick:()=>{S.shown=!S.shown;draw()}},'Accept…'),h('button',{type:'button',class:'mb'},'Send back…'),h('button',{type:'button',class:'mb'},'Ask Hatch')),
      ...(S.shown?[h('div',{class:'dcard',style:'margin-top:8px'},h('b',{text:'Accept sheet (prototype)'}),h('div',{class:'muted',text:'Would list your choices, the repos and branches that change, the tests that run and a token estimate.'}))]:[]));
  }
  const stg=h('div',{class:'stg',id:'stg'});
  const wrap=h('div',{class:'stagewrap'+(S.L?'':' noL')+(S.R?'':' noR')},ctl,stg,dcn);
  const win=h('div',{class:'win',tabindex:'0','aria-label':'Proposal stage prototype. Space flips, keys 1 to 5 change compare mode, L and D change appearance, R toggles redlines, S changes scenario.'},
    h('div',{class:'tb'},h('i'),h('i'),h('i'),h('span',{class:'tt',text:'Hatch Stage · #151 · rev 2'})),bar,wrap);
  win.addEventListener('keydown',e=>{
    if(['INPUT','TEXTAREA'].includes(e.target.tagName)&&e.target.type!=='radio')return;
    const k=e.key;let used=true;
    if(k===' '){S.mode='flip';S.flip=S.flip?0:1}
    else if('12345'.includes(k)&&k.length===1){S.mode=['side','overlay','flip','wipe','matrix'][+k-1]}
    else if(k==='l'||k==='L')S.app='light';else if(k==='d'||k==='D')S.app='dark';
    else if(k==='r'||k==='R')S.red=!S.red;
    else if(k==='ArrowRight'||k==='ArrowLeft'){const ks=optionKeys();const i=ks.indexOf(S.sel);S.sel=ks[(i+(k==='ArrowRight'?1:ks.length-1))%ks.length]}
    else if(k==='s'||k==='S'){const i=SCENS.findIndex(x=>x[0]===S.scen);S.scen=SCENS[(i+1)%SCENS.length][0]}
    else used=false;
    if(used){e.preventDefault();draw();const w=$('#stageMount .win');if(w)w.focus()}
  });
  m.replaceChildren(win);centre();
}
draw();
document.querySelectorAll('.opt').forEach(l=>l.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();$('input',l).click()}}));

/* ===== for your review (live) ===== */
function refreshReview(){
  const box=$('#rv-open');if(!box)return;
  const open=DECISIONS.filter(d=>!decisions[d.id]);
  box.replaceChildren();
  if(!open.length){box.append(h('div',{class:'rvi'},h('b',{text:'Every decision is answered.'})))}
  else{
    box.append(h('div',{class:'muted',style:'margin-bottom:6px',text:open.length+' decision'+(open.length>1?'s':'')+' waiting for your answer'}));
    open.slice(0,12).forEach(d=>box.append(h('div',{class:'rvi'},h('span',{class:'tag',text:d.id}),
      h('div',{style:'flex:1;min-width:0'},h('a',{href:'#dec-'+d.id,text:d.title}),h('div',{class:'muted',style:'font-size:13px',text:'I recommend '+optName(d,d.rec)})),
      h('button',{class:'btn sm',type:'button',onclick:()=>choose(d,d.rec)},'Use recommendation'))));
    if(open.length>12)box.append(h('div',{class:'muted',text:'…and '+(open.length-12)+' more. Use "Show only open decisions" in the left menu to see them all.'}));
  }
  const rb=$('#rv-replies');rb.replaceChildren();
  const rep=notes.filter(n=>n.reply),wait=notes.filter(n=>!n.reply&&n.kind==='question');
  if(!rep.length&&!wait.length)rb.append(h('p',{class:'muted',text:'No replies yet.'}));
  rep.forEach(n=>{const d=DECISIONS.find(x=>x.id===n.item);rb.append(h('div',{class:'rvi'},h('span',{class:'tag',text:n.item}),h('div',{style:'flex:1;min-width:0'},h('a',{href:'#dec-'+n.item,text:d?d.title:'General note'}),h('div',{class:'muted',style:'font-size:13px',text:n.reply.length>150?n.reply.slice(0,150)+'…':n.reply}))))});
  wait.forEach(n=>rb.append(h('div',{class:'rvi'},h('span',{class:'tag',text:n.item}),h('div',{style:'flex:1'},h('span',{class:'chip you',text:'Waiting for my reply'})))));
}
refreshReview();
