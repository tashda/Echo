DECISIONS.push(
{id:'E8',sec:'compose',title:'The vetting agent rewrites your ticket: how does the rewrite reach you?',
 q:'From your note on E7: the agent that vets the ticket also rewrites it, and you accept it, add notes or edit it. Your free-form text stays the starting point.',
 opts:[
  {k:'A',n:'Suggested rewrite with a diff: Accept, Edit or Keep mine',d:'Hatch shows your original and the rewrite side by side, structured for the type (for a Bug: steps, expected, actual), with changed passages marked and the questions beside it. Accept publishes the rewrite to GitHub. Edit opens it for changes. Keep mine publishes your text. Your original is always kept in the history.'},
  {k:'B',n:'The agent edits the ticket directly, you review afterwards',d:'The issue on GitHub is already rewritten when you see it.'},
  {k:'C',n:'Questions only, no rewrite',d:'The agent asks, and you fix the text yourself.'}],
 rec:'A',why:'The rewrite is the same pass as the check, so it costs almost nothing extra, and it is why free-form input (E7) works: you write loosely and Hatch does the structuring. Showing it as a diff with Accept, Edit or Keep mine means the text on GitHub is always something you approved, and keeping your original in the history means a rewrite can never lose what you meant.'},
{id:'H22',sec:'proposal',title:'Testing several options at the same time',
 q:'From your note on H5. This can mean three things: (1) looking at several options side by side, (2) mixing parts of different options, such as spacing from A with the icon from B, (3) comparing all options across every state. Your picks on H2 and H5 already cover 1 and 3. The open question is mixing.',
 opts:[
  {k:'A',n:'Choose which options are shown, side by side only',d:'Checkboxes pick up to five columns. Scenarios and appearance apply to all of them at once.'},
  {k:'B',n:'Add a live Mix column, pinnable into extra columns',d:'A Mix column is drawn from your current answers to the decision questions. Pin a Mix to keep it as its own column (Mix 1, Mix 2) and try other combinations next to the original options.'},
  {k:'C',n:'One Stage window per option',d:'Open each option in its own window, as in S5.'}],
 rec:'B',why:'Your decisions are rarely "all of B". They are the spacing from one option and the placement from another, and a Mix lets you see that combination before you accept it instead of imagining it. Pinned Mixes sit next to the original options in the same scenarios and appearances, so you compare them the same way. Separate windows work, but they make state-by-state comparison harder.'},
{id:'I6',sec:'build',title:'Where do merged tickets go, and what tests them?',
 q:'From your note on I3: no full build before merge, the repo\'s CI should cover testing. Echo already has CI: "CI (Light)" runs Build & Test on every push to dev, and "CI (Full)" runs on main and on pull requests to it, both on your xcode-27 runner.',
 opts:[
  {k:'A',n:'Straight to dev',d:'Approved tickets merge to dev. CI (Light) tests them afterwards. If it fails, the ticket reopens.'},
  {k:'B',n:'A hatch integration branch checked by CI, then promoted',d:'Approved tickets merge into a hatch branch. CI runs on it. When it is green, Hatch promotes it to dev. Hatch reads the check results from GitHub and shows them on each ticket.'},
  {k:'C',n:'Full local suite before merge',d:'Hatch runs all the tests on your Mac.'}],
 rec:'B',why:'It uses the testing you already maintain, so Hatch does not duplicate it, and nothing reaches dev until CI is green. The cost is a small change to ci-light.yml so it also runs on the hatch branch. A failing ticket is named on the Board. Straight to dev is faster, but a red dev then blocks whatever else you are working on, and a full local run is the slow thing you wanted to avoid.'},
{id:'L5',sec:'projects',title:'How does the Specs section work in Hatch?',
 q:'From your note on L3: the Specs section in Echo Labs is great, because you can pick e.g. the tab bar and see what has been decided and how it looks. It is heavy to include in Hatch, so you asked for suggestions, maybe a blueprint to build it per project.',
 opts:[
  {k:'A',n:'Text only in Hatch',d:'Spec items as searchable text, linked to tickets and decisions, with reference screenshots. No live specimens.'},
  {k:'B',n:'Text in Hatch, plus a per-project Spec app launched by Hatch',d:'Hatch holds the searchable Spec text and the links. A separate Spec app per project, built like the Stage, shows each element as a live specimen. "Open in Spec app" jumps to the element. A blueprint action has an agent scaffold the Spec app for a new project from its area index, and you review it.'},
  {k:'C',n:'Live specimen pages inside Hatch',d:'As in Echo Labs today.'}],
 rec:'B',why:'It keeps the part you love, picking an element and seeing what is decided and how it looks, and keeps the heavy specimen code out of Hatch, which is the point of S1. The text layer gives search and links to tickets and decisions. The blueprint means a new project starts from a generated skeleton instead of hand-built pages. A ticket then cannot reach Done until its Spec text and Spec app pages are updated or marked unchanged, which Hatch checks in code and an agent no longer has to remember.'},
{id:'O1',sec:'order',title:'What do we build first?',
 q:'Nothing has been built yet. The order matters because the biggest assumption is S1: that a Stage app per round builds quickly.',
 opts:[
  {k:'A',n:'Foundation first',d:'SQLite, GitHub sync, projects and the hatch command, then screens, then the Stage.'},
  {k:'B',n:'Spike the Stage first, then the foundation',d:'Build one real round (the toast) as a Stage app with the specimens kit and measure the build time. Then the foundation.'},
  {k:'C',n:'Screens first with fake data',d:'Build the Desk and ticket screens against sample data.'}],
 rec:'B',why:'S1 is what the rest of the design leans on, and it is also the part you most want to try. The spike needs no GitHub and no database, only the existing toast round and the design system, so it is small. If the build time disappoints, S1 changes, and that is far cheaper to learn before the core is built on top of it.'},
);
