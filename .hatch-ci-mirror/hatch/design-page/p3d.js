DECISIONS.push(
{id:'S1',sec:'swift',title:'Where do Swift Proposals run?',
 q:'Your idea: open a separate application for a Swift round, so Hatch is not rebuilt for every new round.',
 opts:[
  {k:'A',n:'Inside Hatch',d:'Echo\'s specimens are compiled into Hatch. Every new round rebuilds and relaunches Hatch, as Echo Labs does today.'},
  {k:'B',n:'A separate Stage app per Proposal',d:'Hatch launches a small app that contains the stage and that round only. Prebuilt kits are reused, only the round is compiled.'},
  {k:'C',n:'One long-running Stage that loads rounds as plug-ins',d:'No relaunch at all, but compiled SwiftUI is loaded into a running app.'}],
 rec:'B',why:'Hatch is rebuilt only when Hatch itself changes, and a broken round cannot take Hatch down, which is the failure you hit with the Rebuild button today. Only the round is compiled because the stage kit, the specimens and the design system are prebuilt and cached. Option C would remove even the relaunch, but loading compiled SwiftUI into a running app is fragile, so I would measure B first and consider C only if the relaunch feels slow.'},
{id:'S2',sec:'swift',title:'What does the Stage app contain?',
 q:'The compare modes, scenarios and decision panel need to sit next to the specimens.',
 opts:[
  {k:'A',n:'The whole stage, from a shared StageKit, plus the round',d:'Everything in the prototype above runs inside the Stage app.'},
  {k:'B',n:'Specimens only',d:'Hatch captures pictures of them and draws the stage around the pictures.'}],
 rec:'A',why:'One app cannot draw live SwiftUI views from another app, so the stage and the specimens have to live in the same process. With pictures only, you would lose hover, motion, scrubbing and the exact sizes, and that is what judging a Swift round is for.'},
{id:'S3',sec:'swift',title:'How do Hatch and the Stage app talk to each other?',
 q:'Every pick, note and verdict has to end up in SQLite and, through the sync, on GitHub.',
 opts:[
  {k:'A',n:'Local API, Hatch is the only writer',d:'The Stage sends each pick and note to Hatch. If Hatch is not running, the Stage keeps them and delivers them later.'},
  {k:'B',n:'Both write to the SQLite file',d:'Shared database access.'},
  {k:'C',n:'The Stage writes files that Hatch reads',d:'JSON files in a folder.'}],
 rec:'A',why:'You set the rule that the app owns the bookkeeping. With one writer there are no lock conflicts, and every change goes through the same status rules and the sync record. Two processes writing to one SQLite file is where corrupted or half-synced state comes from.'},
{id:'S4',sec:'swift',title:'Where does the code of a Swift round live?',
 q:'Rounds are Swift packages that depend on the design system and on Echo\'s shared "today" specimens.',
 opts:[
  {k:'A',n:'A per-project specimens repo',d:'echo-specimens: the shared Echo-today views, plus one folder per round.'},
  {k:'B',n:'In the Echo repo',d:'Next to the app code.'},
  {k:'C',n:'In the private tickets repo',d:'Next to the issue.'}],
 rec:'A',why:'It keeps experiments out of Echo, which was your goal in splitting Labs out. Rounds share the Echo-today views instead of copying them, and the repo has real Swift versions and tags. An accepted round is archived into Decisions with a tag. The tickets repo is meant for text, and mixing code into it makes both harder to read.'},
{id:'S5',sec:'swift',title:'How do the Stage windows behave?',
 q:'',
 opts:[
  {k:'A',n:'One Stage window per Proposal',d:'Hatch shows its status and a Focus button. A new revision offers Reload. It closes when the ticket leaves Your call, after a confirmation.'},
  {k:'B',n:'One reusable Stage window',d:'Opening another Proposal replaces the first.'}],
 rec:'A',why:'You may want to compare two Proposals, or keep one open while writing a note in Hatch. State is stored per ticket in SQLite, so closing and reopening a Stage loses nothing.'},
{id:'S6',sec:'swift',title:'When is the Stage built and checked?',
 q:'',
 opts:[
  {k:'A',n:'Before it reaches you',d:'Hatch builds the Stage and runs it headless for the quality gate before the ticket becomes Your call. The build log is on the ticket.'},
  {k:'B',n:'The agent builds it and Hatch trusts it',d:'No check by Hatch.'},
  {k:'C',n:'When you press Open',d:'Build on demand.'}],
 rec:'A',why:'The quality gate (H19) needs the specimens to run, and a round that does not compile should go back to the agent, not to you. It also means Open is instant, because the Stage is already built.'},
{id:'S7',sec:'swift',title:'What if a Stage crashes, or Hatch is not running?',
 q:'',
 opts:[
  {k:'A',n:'Contain it',d:'Hatch shows "Stage closed unexpectedly" with Relaunch and Send crash report to agent. The Stage keeps your picks until Hatch is back.'},
  {k:'B',n:'Nothing special',d:'Whatever happens, happens.'}],
 rec:'A',why:'Separate processes only help if one failing does not lose the other\'s work. Keeping your picks in the Stage until they are delivered means a crash never costs you a judgement, and the crash report turns into an instruction for the agent.'},
);
