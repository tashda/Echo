DECISIONS.push(
{id:'E9',sec:'compose',title:'The agent checks whether the ticket type is right',
 q:'From your note on E8: the vetting agent should also check whether a ticket really is a Bug, a Question or something else.',
 opts:[
  {k:'A',n:'Suggest a type change with the reason, you decide',d:'Shown in the same review as the rewrite: "This reads as a Question, not a Bug: there are no steps to reproduce." Accept changes the type, Keep mine leaves it. Signals it looks for: a Bug without steps or an expected result may be a Question. A Tweak with several reasonable fixes should be a Proposal. A Question about how something should look may be a Sketch. A ticket that spans several areas may be a Theme with child tickets.'},
  {k:'B',n:'Change the type automatically',d:'The agent re-types the ticket and tells you afterwards.'},
  {k:'C',n:'Never change the type',d:'It stays as you chose it.'}],
 rec:'A',why:'The type decides the whole path: a Bug goes straight to build and a Question never does, so a wrong type wastes real work. But the agent is guessing from text and you know the intent, so the final call stays with you. Putting it in the same review as the rewrite costs no extra step, and the reason it gives makes a wrong suggestion easy to refuse.'},
{id:'V1',sec:'compose',title:'What is the vetting agent called?',
 q:'The agent that checks, questions, rewrites and re-types your tickets should feel like one consistent colleague. The name appears in the Desk ("Tally asks 2 questions"), in the ticket thread and in the rewrite review.',
 opts:[
  {k:'A',n:'Tally',d:'A tally clerk checks what comes aboard against the manifest, which is what vetting does against the Spec and other tickets. Short, friendly, reads like a first name.'},
  {k:'B',n:'Quill',d:'A pen. Fits the rewriting, but says less about checking.'},
  {k:'C',n:'Latch',d:'It holds the hatch shut until the ticket is ready. Ties to the app name, but sounds more like a gate than a colleague.'},
  {k:'D',n:'Iris',d:'A person\'s name, and also the ring that controls an opening, like a hatch. Warm, but the link to vetting is indirect.'},
  {k:'E',n:'No name, "Hatch check"',d:'Keep it as a function of the app.'}],
 rec:'A',why:'The agent does something specific: it checks a ticket against the manifest of what already exists, and asks about what is missing. "Tally" says that in one word, is easy to say in a sentence ("Tally wants to know if this replaces #118"), and works as a first name without pretending to be a person. It is also not a word that appears elsewhere in Hatch, so it stays recognisable. I would use the same name for every vetting step: questions, rewrite and type check.'},
);
