/* LOOK AND FEEL: renders the option mockups and adds the decisions */
(function(){
const TURN={you:'lk-t-you',agent:'lk-t-agent',app:'lk-t-app',done:'lk-t-done',off:'lk-t-off'};
const ROWS=[
 ['#151','Do we need a dark-only mode?','Draft','you','dash',0,1],
 ['#146','Should tabs restore after a crash?','Needs answers','you','q',0,1],
 ['#142','Sidebar density options','Your call','you','three',1,2],
 ['#141','Query tab empty state','Preparing','agent','half',1,2],
 ['#144','Connection test hangs on bad host','Building','agent','half',2,3],
 ['#143','Results grid loses scroll position','To verify','you','three',2,3],
 ['#148','Align icon sizes in the inspector','Merged','done','check',3,4],
 ['#149','Export to CSV drops the last row','Blocked','off','pause',4,5]];
function glyph(kind){
  const c='currentColor',r=5.5;
  const ring=`<circle cx="7" cy="7" r="${r}" fill="none" stroke="${c}" stroke-width="1.4"${kind==='dash'?' stroke-dasharray="2.2 2"':''}/>`;
  const fillHalf=`<path d="M7 1.5a5.5 5.5 0 0 0 0 11z" fill="${c}"/>`;
  const fillThree=`<path d="M7 1.5a5.5 5.5 0 1 1-5.5 5.5H7z" fill="${c}"/>`;
  let inner='';
  if(kind==='half')inner=fillHalf;
  if(kind==='three')inner=fillThree;
  if(kind==='q')inner=`<text x="7" y="10" text-anchor="middle" font-size="8.5" font-weight="700" fill="${c}" font-family="system-ui">?</text>`;
  if(kind==='check')return `<svg class="lk-gl" viewBox="0 0 14 14"><circle cx="7" cy="7" r="6.5" fill="${c}"/><path d="M4 7.2l2.2 2.2L10 5.2" fill="none" stroke="#fff" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  if(kind==='pause')return `<svg class="lk-gl" viewBox="0 0 14 14">${ring}<path d="M5.4 4.8v4.4M8.6 4.8v4.4" stroke="${c}" stroke-width="1.5" stroke-linecap="round"/></svg>`;
  return `<svg class="lk-gl" viewBox="0 0 14 14">${ring}${inner}</svg>`;
}
const STYLES=[
 {k:'A',name:'A · Dot and plain text',sub:'Only a coloured dot. The text stays quiet. Like the unread dot in Mail.',
  f:r=>`<span class="lk-st ${TURN[r[3]]}"><span class="lk-dot"></span><span class="lk-name-ink">${r[2]}</span></span>`,
  swift:'Label { Text(status.name) } icon: { Circle().fill(turn).frame(width: 7, height: 7) }'},
 {k:'B',name:'B · Quiet tag',sub:'Still a tag, but flat: a square-cornered tint, no dot, smaller text.',
  f:r=>`<span class="lk-cap ${TURN[r[3]]}">${r[2]}</span>`,
  swift:'Text(status.name).font(.caption).padding(.horizontal, 6).background(turn.opacity(0.12), in: .rect(cornerRadius: 5))'},
 {k:'C',name:'C · Phase glyph and name',sub:'A round symbol that fills as the ticket moves along, coloured by turn. The name is normal text. Like Reminders and Xcode.',rec:true,
  f:r=>`<span class="lk-st"><span class="${TURN[r[3]]}" style="display:inline-flex">${glyph(r[4])}</span><span class="lk-name-ink">${r[2]}</span></span>`,
  swift:'Label(status.name, systemImage: status.symbol).symbolRenderingMode(.monochrome).tint(turn)  // circle.dashed, questionmark.circle, circle.lefthalf.filled, checkmark.circle.fill, pause.circle'},
 {k:'D',name:'D · Phase meter and name',sub:'Five small segments show how far along the phase is. Good for scanning a column, but it is not a system control.',
  f:r=>`<span class="lk-st ${TURN[r[3]]}"><span class="lk-seg">${[1,2,3,4,5].map(i=>`<i class="${i<=r[6]?'on':''}"></i>`).join('')}</span><span class="lk-name-ink">${r[2]}</span></span>`,
  swift:'HStack(spacing: 2) { ForEach(1...5) { Capsule().fill($0 <= phase ? turn : .quaternary).frame(width: 9, height: 4) } }'}];
const chips=document.getElementById('lkChips');
STYLES.forEach(s=>{
  const e=document.createElement('div');e.className='lk-opt'+(s.rec?' rec':'');
  e.innerHTML=`<h4>${s.name}${s.rec?' <span class="chip app" style="margin-left:6px">recommended</span>':''}</h4><div class="sub">${s.sub}</div><div class="lk-tbl">${ROWS.map(r=>`<div class="lk-tr"><span class="n">${r[0]}</span><span class="t">${r[1]}</span>${s.f(r)}</div>`).join('')}</div><div class="swift">${s.swift}</div>`;
  chips.append(e)});

/* project in the sidebar */
const proj=document.getElementById('lkProj');
const mono=(t,c,s)=>`<span class="lk-mono${s?' s':''}" style="background:${c}">${t}</span>`;
const nav=`<div class="sec">Work</div><div class="row">Desk<span class="cnt">5</span></div><div class="row">Tickets</div><div class="row">Board</div>`;
const PV=[
 {n:'A · Pop-up button (today)',sub:'A small menu button above the list. Works, but looks like a filter and not like where you are.',
  h:`<div class="lk-sb"><div class="lk-pop"><span>All projects</span><span>⌃</span></div>${nav}</div>`,sw:'Picker("Project") with .menu'},
 {n:'B · Project card',sub:'A tinted card with the project tile, name and branch, built like Echo\'s server card. It opens to a list with counts. The branch and sync state are always in view.',rec:true,
  h:`<div class="lk-sb"><div class="lk-card open">${mono('E','#2B59C3')}<div style="flex:1;min-width:0"><b>Echo</b><small>branch hatch · 3 repos</small></div><span class="lk-more">⌃</span></div><div class="lk-menu"><div class="row">All projects<span class="cnt">14</span></div><div class="row sel">${mono('E','#2B59C3',1)}Echo<span class="cnt">11</span></div><div class="row">${mono('H','#0B6E80',1)}Hatch<span class="cnt">3</span></div><div class="row" style="color:var(--accent)">Add project…</div></div>${nav}</div>`,sw:'DisclosureGroup in a rounded card (HXProjectCard); the list is a Menu or an inline expansion'},
 {n:'C · Projects as a sidebar section',sub:'Each project is a row in the source list with its count. No click to switch, and the filter is always visible. Best with two or three projects.',
  h:`<div class="lk-sb"><div class="sec" style="padding-top:2px">Projects</div><div class="row">All<span class="cnt">14</span></div><div class="row sel">${mono('E','#2B59C3',1)}Echo<span class="cnt">11</span></div><div class="row">${mono('H','#0B6E80',1)}Hatch<span class="cnt">3</span></div>${nav}</div>`,sw:'Section("Projects") in the sidebar List, selection filters every screen'},
 {n:'D · Title menu in the toolbar',sub:'The project is the window title, as the scheme is in Xcode. The sidebar loses the picker and gets the room back.',
  h:`<div class="lk-tbar">${mono('E','#2B59C3',1)}<b>Echo</b><span style="color:var(--muted)">▾</span><span style="margin-left:auto;color:var(--muted)">Desk</span></div><div class="lk-sb" style="margin-top:-2px">${nav}</div>`,sw:'ToolbarItem(placement: .navigation) { Menu { ... } }'}];
PV.forEach(p=>{const e=document.createElement('div');e.className='lk-opt'+(p.rec?' rec':'');
  e.innerHTML=`<h4>${p.n}${p.rec?' <span class="chip app" style="margin-left:6px">recommended</span>':''}</h4><div class="sub">${p.sub}</div>${p.h}<div class="swift">${p.sw}</div>`;proj.append(e)});

/* dock */
const dk=document.getElementById('lkDock');
const TABS=[['Overview'],['Options',3],['Thread',5],['Work'],['History']];
function mk(type,tabs,extra){
  const wrap=document.createElement('div');wrap.className='lk-stage';
  const box=document.createElement('div');
  box.className=type==='dock'?'lk-dock':type==='seg'?'lk-segc':type==='ico'?'lk-dock lk-ico':'lk-ul';
  tabs.forEach((t,i)=>{const b=document.createElement('button');b.type='button';b.setAttribute('aria-pressed',i===0?'true':'false');
    const ic={Overview:'◧',Options:'◫',Thread:'◌',Work:'⚙',History:'↺'}[t[0]]||'';
    b.innerHTML=(type==='ico'?`<span>${ic}</span><span class="lbl">${t[0]}</span>`:t[0])+((type==='dock'&&t[1])?` <small>${t[1]}</small>`:'');
    b.addEventListener('click',()=>{[...box.children].forEach(x=>x.setAttribute('aria-pressed','false'));b.setAttribute('aria-pressed','true');
      pane.textContent=t[0]+' content appears here.'});box.append(b)});
  wrap.append(box);
  const pane=document.createElement('div');pane.style.cssText='font-size:12px;color:var(--muted)';pane.textContent='Overview content appears here.';wrap.append(pane);
  if(extra)wrap.append(extra);return wrap}
const more=document.createElement('div');more.className='lk-more';more.innerHTML='With 6 or more sections the dock becomes a pull-down:<span class="lk-segc"><button type="button" aria-pressed="true">Overview ⌄</button></span>';
const DV=[
 {n:'A · Text dock',sub:'Echo\'s dock with words. A glass capsule; the current section is an accent fill with accent text (a fill, because glass on glass is not used); counts sit next to the name. Up to five slots.',rec:true,
  e:()=>mk('dock',TABS,more),sw:'HXDock(items:selection:) { GlassEffectContainer + capsule .glassEffect(.regular); selected slot: Capsule().fill(accent.opacity(0.16)) }'},
 {n:'B · System segmented control (today)',sub:'The native control. Familiar and free, but it is flat, has no counts, and looks different from the rest of the Echo family.',
  e:()=>mk('seg',TABS),sw:'Picker(selection:) { ... }.pickerStyle(.segmented)'},
 {n:'C · Dock that opens the current one',sub:'Others show only an icon; the current one shows icon and name. Compact, like Safari\'s sidebar tabs. Needs an icon for every section.',
  e:()=>mk('ico',TABS),sw:'HXDock with .labelStyle: selected .titleAndIcon, others .iconOnly'},
 {n:'D · Underlined tabs',sub:'Familiar from the web. Not a Mac pattern, shown so you can rule it out.',
  e:()=>mk('ul',TABS),sw:'Custom HStack of Buttons with an underline; no native equivalent'}];
DV.forEach(p=>{const e=document.createElement('div');e.className='lk-opt'+(p.rec?' rec':'');
  e.innerHTML=`<h4>${p.n}${p.rec?' <span class="chip app" style="margin-left:6px">recommended</span>':''}</h4><div class="sub">${p.sub}</div>`;
  e.append(p.e());const sw=document.createElement('div');sw.className='swift';sw.textContent=p.sw;e.append(sw);dk.append(e)});
})();


/* buttons */
(function(){
const I={open:'<path d="M3 8h9M8 4l4 4-4 4"/>',park:'<path d="M5 3v10M11 3v10"/>',ask:'<path d="M8 2l1.5 4.5L14 8l-4.5 1.5L8 14l-1.5-4.5L2 8l4.5-1.5z"/>',more:'<path d="M3 8h.01M8 8h.01M13 8h.01"/>',drop:'<path d="M4 4l8 8M12 4l-8 8"/>'};
const ic=k=>`<svg viewBox="0 0 16 16">${I[k]}</svg>`;
const ACT=[['Open','open',1],['Park','park'],['Ask','ask'],['More','more']];
const VS=[
 {n:'A · Glass capsules, as on the Echo server page',sub:'Icon and label. One prominent capsule first, the rest quiet glass. "More" is a menu capsule with Drop inside. The row wraps when it is narrow.',rec:true,
  f:()=>ACT.map(a=>`<span class="lk-b glass${a[2]?' pro':''}">${ic(a[1])}${a[0]}${a[1]==='more'?' <span style="opacity:.6">⌄</span>':''}</span>`).join(''),
  sw:'.buttonStyle(.glassProminent) for the first; .buttonStyle(.glass) for the rest; Menu { } .menuStyle(.button) .menuIndicator(.hidden); .controlSize(.large)'},
 {n:'B · Bordered rectangles (today)',sub:'The standard AppKit-looking button. Familiar, but flat, and it does not match the Echo server page.',
  f:()=>ACT.map(a=>`<span class="lk-b bord${a[2]?' pro':''}">${a[0]}${a[1]==='more'?' ⌄':''}</span>`).join(''),sw:'.buttonStyle(.bordered) and .borderedProminent'},
 {n:'C · Icon-only glass',sub:'Compact, like the toolbar. Fine when the icon is universal; here Park and Ask need a tooltip to be understood.',
  f:()=>ACT.map(a=>`<span class="lk-b icon${a[2]?' pro':''}" title="${a[0]}">${ic(a[1])}</span>`).join(''),sw:'Button { Image(systemName:) }.buttonStyle(.glass) with .help("Park")'},
 {n:'D · Text links',sub:'Quiet and light. Nothing says these are buttons, and the main action does not stand out.',
  f:()=>ACT.map(a=>`<span class="lk-b txt${a[2]?' pro':''}">${a[0]}</span>`).join(''),sw:'.buttonStyle(.link)'}];
const host=document.getElementById('lkBtns');
VS.forEach(v=>{const e=document.createElement('div');e.className='lk-opt'+(v.rec?' rec':'');
 e.innerHTML=`<h4>${v.n}${v.rec?' <span class="chip app" style="margin-left:6px">recommended</span>':''}</h4><div class="sub">${v.sub}</div>
 <div class="lk-bcard stage"><div class="hd">#151 Notification toast spacing<small>Your turn: judge 3 options.</small></div><div class="lk-brow">${v.f()}</div></div><div class="swift">${v.sw}</div>`;host.append(e)});
})();

DECISIONS.push(
{id:'LK1',sec:'lookchips',title:'How should a status look?',
 q:'You do not like the chips. The status appears in the Tickets table, the Board cards, the Desk and the ticket header, so one choice here sets the look everywhere. The colour must still show whose turn it is.',
 opts:[
  {k:'A',n:'Dot and plain text',d:'The quietest. A coloured dot, the name in normal text. Easy to build, but the colour is small, so a column of amber rows is harder to find at a glance.'},
  {k:'B',n:'Quiet tag',d:'A flat, small tint behind the name. Closest to today, just less heavy. Still a coloured box.'},
  {k:'C',n:'Phase glyph and name',d:'A round symbol that fills as the ticket moves from Draft to Done (dashed, question mark, half, three quarters, check, pause), coloured by turn, followed by the name in normal text. Uses SF Symbols, so it matches Reminders and Xcode.'},
  {k:'D',n:'Phase meter and name',d:'Five small segments instead of a symbol. Shows progress in one look, but it is a custom control.'}],
 rec:'C',why:'It says two things without a box: how far along the ticket is (the shape) and whose turn it is (the colour). It is the pattern Apple uses for task status, it needs no custom drawing beyond SF Symbols, and in a dense table plain text with a small coloured symbol is calmer than any tag. The same glyph works in the Board cards and the ticket header.'},
{id:'LK2',sec:'lookproj',title:'How should the project appear in the sidebar?',
 q:'You asked for the project to look better and not be just a switcher. The sidebar is the first thing you see, and the project decides which tickets, repositories and branch you work in.',
 opts:[
  {k:'A',n:'Pop-up button (today)',d:'Small and neutral. Nothing about it says which project you are in.'},
  {k:'B',n:'Project card',d:'A rounded, tinted card at the top: a tile with the project\'s letter and colour, the name, and a line with the branch and repository count. Click it and a list opens with all projects, their ticket counts, All projects, and Add project. Same family as Echo\'s server card.'},
  {k:'C',n:'Projects as a sidebar section',d:'Every project is a row with its count, above Work. One click to switch, always visible. Takes more height with many projects.'},
  {k:'D',n:'Title menu in the toolbar',d:'The project name sits in the toolbar like the scheme in Xcode. Frees the sidebar, but is easy to miss.'}],
 rec:'B',why:'It makes the project part of the window\'s identity: a colour and letter you learn to recognise, with the branch visible so you know where a preview will build. It scales from two projects to ten, which a section does not. And it reuses the pattern from the Echo server card, so the two apps feel related. Option C is the better choice only if you will always have two or three projects.'},
{id:'LK3',sec:'lookdock',title:'Should the Echo dock, with text, be our section switcher?',
 q:'Echo\'s dock is an icon capsule. For Hatch the sections have names (Overview, Options, Thread, Work, History), so the labels are text. It would replace the system segmented control for switching sections inside one pane: ticket tabs, project settings sections, and the Specs and Decisions sub-views. View modes in the toolbar (List / Board) stay with the system segmented control.',
 opts:[
  {k:'A',n:'Text dock, up to five slots',d:'Glass capsule with equal slots, current in accent colour with a soft fill, counts after the name, hover grows slightly. Six or more sections become a pull-down menu, as in Echo\'s TabSectionPicker. Right-click a slot for its actions.'},
  {k:'B',n:'Keep the system segmented control',d:'Native and free. Looks plain next to the Echo dock, and has no room for counts.'},
  {k:'C',n:'Icon for others, icon and name for the current',d:'Compact, but every section needs a good icon, and names are hidden for most.'},
  {k:'D',n:'Underlined tabs',d:'Web style. Not recommended on the Mac.'}],
 rec:'A',why:'It gives Hatch and Echo one recognisable control, uses the same glass-for-controls rule, and fits counts such as "Thread 5" that segmented controls cannot show well. The limit of five slots with a pull-down above that is already Echo\'s rule, so it is proven. It is one small component (HXDock) written once and used everywhere, which also saves work later.'},
{id:'LK4',sec:'lookrules',title:'Which design principles does Hatch follow?',
 q:'Echo already has written principles (native first, glass for controls and never content, no glass on glass, tokens, motion explains change, accessibility). Hatch should feel like the same family.',
 opts:[
  {k:'A',n:'Adopt Echo\'s principles, plus Hatch\'s own',d:'Copy the six rules above into Hatch\'s DESIGN.md. Add the Hatch rules: colour means whose turn it is, one prominent action per screen, status is a glyph and a name, every suggestion shows its recommendation and reason.'},
  {k:'B',n:'Write a separate set for Hatch',d:'Free to differ, but two sets will drift apart.'},
  {k:'C',n:'No written rules, decide per screen',d:'Fast now, expensive later: every new screen reopens the same questions.'}],
 rec:'A',why:'Echo\'s rules are already tested against a real app and answer most questions in advance. Adding only the Hatch-specific ones keeps the document short enough for an agent to read in full every time, which costs fewer tokens than discussing each screen.'},
{id:'LK5',sec:'lookrules',title:'What may use colour?',
 q:'Today colour is used for turns (amber you, teal agent, slate Hatch, green finished, grey paused), and ticket types are neutral. A strict rule prevents the app from becoming colourful by accident.',
 opts:[
  {k:'A',n:'Colour only for turn and for real problems',d:'Amber, teal, slate, green and grey mean turn. Red means something is broken or failed. The system accent colour is for selection and the one prominent button. Types, areas and projects are neutral (a project has its own tile colour, only in the project card).'},
  {k:'B',n:'Also colour the ticket types',d:'Six more colours. Easier to tell types apart, but then colour no longer means one thing.'},
  {k:'C',n:'Almost monochrome, only amber for you',d:'Very calm. Agents and finished work become hard to tell apart.'}],
 rec:'A',why:'When colour has one meaning you can scan the Desk and see what needs you without reading. Types are already told apart by their symbol and name, so colouring them adds noise and not information. The project tile is the one deliberate exception, because it helps you know where you are.'},
{id:'LK6',sec:'lookrules',title:'Adopt the component map as the rule?',
 q:'The table above says which element to use for each job: Table for records, List with sections for the Desk, the text dock for sections, a pull-down for six or more, the system segmented control for view modes in the toolbar, ContentUnavailableView for empty states, and so on.',
 opts:[
  {k:'A',n:'Adopt it. Agents must use it and extend it',d:'Anything not on the map gets the nearest native control and a new row in the map, in the same change. You review the map and not each screen.'},
  {k:'B',n:'Use it as a guide only',d:'Agents may choose differently when it seems better. More variety, more rework.'},
  {k:'C',n:'Decide each new element with you',d:'Most control, and the most tokens spent.'}],
 rec:'A',why:'This is the part that saves the most effort. Most "make it look better" requests are really "use a different element here". With one agreed map, a new screen is assembled from known parts and arrives looking right the first time. When you do want a change, you change one row and every screen follows.'},
{id:'LK7',sec:'lookrules',title:'Where may glass and cards be used?',
 q:'Echo uses Liquid Glass for floating controls and keeps content opaque. Cards (a bordered, filled box) separate objects but become heavy if used everywhere.',
 opts:[
  {k:'A',n:'Glass only for floating controls; cards only for grouped facts',d:'Glass: the dock, toasts, the Ask panel header, the Stage toolbar. Content (lists, tables, text) is on plain window background. Cards: the details card, the turn banner, board cards, proposal options. No card inside a card.'},
  {k:'B',n:'No glass at all',d:'Simpler and fully flat. Looks less like Echo.'},
  {k:'C',n:'Glass and cards wherever they look good',d:'Quickly becomes inconsistent.'}],
 rec:'A',why:'It is the same rule that Echo already works by, and it keeps text readable. It also gives a clear test for a new element: is it a control that floats over content (glass), a group of facts (card), or content (plain)?'},
{id:'LK8',sec:'lookrules',title:'Text and density',
 q:'Sizes affect how native the app feels. Mac apps use the system text styles and a fairly tight row height.',
 opts:[
  {k:'A',n:'System font and text styles only',d:'San Francisco everywhere, from the system text styles (body 13, caption 11, title 3 for headings). Monospaced only for ticket numbers and code. Table rows at the standard Mac height. Sizes never typed as numbers in views.'},
  {k:'B',n:'A custom display font for headings',d:'More character, less native, and one more thing to keep in step with the Echo family.'},
  {k:'C',n:'Larger, airier by default',d:'Friendly, but you see fewer tickets at once.'}],
 rec:'A',why:'It is the most Mac-like result and it follows the user\'s system settings. It also leaves nothing to decide per screen. A Tickets table showing the standard number of rows is what makes the app useful as a working tool.'},
{id:'LK9',sec:'lookrules',title:'How do we keep new screens on track and spend few tokens?',
 q:'The goal is that you stop adjusting element by element. Three things can enforce the rules: a tokens file, a written DESIGN.md that agents read first, and automatic screenshots on every build.',
 opts:[
  {k:'A',n:'Tokens file, DESIGN.md, and screenshots, reviewed in one pass',d:'One Swift file (HX) holds spacing, radii, colours and motion; the shared components (HXDock, HXStatus, HXProjectCard, HXToast) live next to it. DESIGN.md holds the principles and the component map, and CLAUDE.md points to it. CI already renders every screen in light and dark; you review the set once per round, and your comments become changes to the rules or tokens, not to single screens.'},
  {k:'B',n:'DESIGN.md only',d:'Cheaper to set up, but nothing stops a literal number or colour from slipping in.'},
  {k:'C',n:'Review every screen as it is built',d:'Highest control, highest cost.'}],
 rec:'A',why:'Rules in a document are followed only when they are also in the code. Tokens and shared components make the right thing the easy thing, and the screenshots let you judge the whole app in minutes. Then "I do not like the pills" becomes one edit in HXStatus that changes every screen, and that is the cheapest way to iterate.'}
);

DECISIONS.push(
{id:'LK10',sec:'lookbuttons',title:'What do buttons like Park, Drop and Open look like?',
 q:'You prefer the buttons on Echo\'s server page and the Activity Monitor over the plain bordered ones. On those pages every action is a glass capsule with an icon and a label, the first one is prominent, and the others are quiet.',
 opts:[
  {k:'A',n:'Glass capsules with icon and label',d:'Exactly the Echo server page: one prominent capsule first (Open, Submit for check, Accept), then quiet glass capsules (Park, Ask), and a "More" capsule menu holding the rare ones such as Drop. Large control size on pages, regular in sheets.'},
  {k:'B',n:'Keep bordered rectangles',d:'What the app has now.'},
  {k:'C',n:'Icon-only glass',d:'Smallest. Needs tooltips and clear icons, so it suits the toolbar more than a ticket page.'},
  {k:'D',n:'Text links',d:'Lightest. The main action does not stand out.'}],
 rec:'A',why:'It is the style you already chose for Echo, so Hatch and Echo look related. The icon and the word together make each button understandable without a tooltip, and one prominent button at the front shows what to do next. It is also the least custom: the system provides both glass styles, so the only thing we write is the rule for which button gets which style.'},
{id:'LK11',sec:'lookbuttons',title:'Adopt the "which buttons where" table as the rule?',
 q:'The table above sets the style for each place: pages, rows and cards, sheets, the toolbar, and risky actions. Without it every new screen would reopen the question.',
 opts:[
  {k:'A',n:'Adopt it',d:'One prominent button per screen, always first. Quiet glass for other actions. Rare or risky actions in a "More" menu, with a confirmation sheet for destructive ones. Small bordered buttons only inside rows, cards and toasts. Toolbar stays icon-only with tooltips. Sheets: a default button that is never silently disabled.'},
  {k:'B',n:'Adopt it, but Drop is always visible',d:'Drop sits next to Park as a red glass capsule. Faster, easier to hit by mistake.'},
  {k:'C',n:'Decide per screen',d:'No rule.'}],
 rec:'A',why:'Dropping a ticket takes it off the Desk and the Board, so it should not sit one click from Open. Putting it in the More menu, with a confirmation, costs a second when you mean it and avoids a mistaken drop when you do not. Fixing the table once is also the cheapest way to keep every new screen consistent.'}
);
