import b10,b7,b8,b5,b4,b6,b9
X = {
(b10,'aop-difficult',1):"\n\nSaving face matters in many settings, including workplaces and families where respect and seniority carry weight. Correcting an elder or a senior colleague privately rather than in front of others, or framing a disagreement as a shared problem ('Maybe we both missed something here'), can make it far easier for them to accept a different view. The goal is not to win the point, but to reach a better outcome while keeping the relationship intact.",
(b10,'aop-difficult',3):" It is also fine to recognise that some people will remain difficult no matter how kindly you behave. Your aim is to act in line with your own values, not to force a change in theirs.",
(b10,'aop-relationships',1):"\n\nRapport is not about pretending to agree or copying someone's opinions. It grows from honest curiosity. Asking about someone's weekend, their family or their hometown, and actually remembering the answer, signals that you see them as a person and not just a role. In a busy workplace, these small human moments are often what people remember most.",
(b10,'aop-relationships',3):" When you do slip, as everyone does, owning it quickly and sincerely tends to repair trust faster than excuses.",
(b10,'aop-win-win',2):"\n\nA useful habit is to ask open questions, ones that cannot be answered with a simple yes or no, such as 'What matters most to you here?' or 'What would a good outcome look like for you?' Then listen without interrupting. You may discover that the other person's real concern is different from what you assumed, and that a solution meeting both your needs is easier to find than it first seemed.",
(b10,'aop-win-win',4):" Persuasion that respects the other person's freedom to say no is, in the end, more persuasive than persuasion that tries to remove that freedom.",
(b10,'aop-own-emotions',3):" Seeing difficult behaviour this way can turn a moment of anger into a moment of understanding, which makes a calm reply much easier to find.",
(b7,'ms-praise',2):" It is also worth noticing that praise for effort alone, when the strategy clearly is not working, can be unhelpful; it may be kinder to praise the effort and then help the person explore a different approach.",
(b7,'ms-praise',3):" Children and adults alike tend to remember how they were spoken to after a failure. A calm 'What did you learn, and what will you try next?' can stay with someone far longer than a moment of disappointment.",
(b7,'ms-relationships',1):" Small habits support this approach: checking in regularly, expressing appreciation, and talking about problems early, before resentment builds. Neither person has to be perfect. What matters is a shared willingness to keep learning about each other.",
(b7,'ms-relationships',3):" Over a lifetime, people change, and relationships that make room for that change tend to feel more alive.",
(b8,'p48-plan',2):" Writing down the main risks and a simple response for each can make big decisions feel less frightening, because you have already thought about what you would do.",
(b8,'p48-plan',4):" A simple rule of thumb is to plan enough to feel prepared, then begin, and review the plan after the first few steps when you have real information to work with.",
(b8,'p48-say-less',2):" Thoughtful speech also includes knowing when to share. Keeping a friend's confidence, or not spreading gossip at work, is a form of restraint that builds trust rather than mystery.",
(b5,'btb-convenience',1):" It can also help to bundle the things a habit needs in one place, such as a small box with your journal and pen, so starting takes no searching.",
(b5,'btb-convenience',4):" Over time, many people find that a few well-placed changes in convenience do more than months of good intentions.",
(b4,'btb-foundation',0):" The book's idea is that strengthening these foundations first can make later changes feel less like a struggle.",
(b7,'ms-effort',2):" Asking someone more experienced for a tip, watching how others approach a problem, or breaking a skill into smaller parts are all forms of smart effort.",
(b6,'ms-two-mindsets',2):" Being kind to yourself when you notice fixed-mindset thoughts is part of growth too; criticising yourself for having them only adds pressure.",
(b6,'bks-many-paths',4):" Sharing what you learn from the book with a professional, if you are working with one, can be a useful way to explore which ideas might be relevant to you.",
(b5,'btb-abstainer',3):" You might also notice that your style shifts with stress or tiredness, which is another useful thing to learn about yourself.",
(b8,'p48-company',2):" It can also help to notice your own influence: whether you bring calm or tension to the people around you.",
(b7,'ms-failure',3):" Talking about a setback with someone you trust can also help, because putting it into words often makes the lessons clearer and the pain a little lighter.",
(b9,'pon-acceptance',2):" Many people find that once they stop arguing with the situation in their head, they have more energy for whatever needs doing.",
(b9,'pon-watch-mind',3):" Even a few moments of watching the mind during an ordinary day, such as while waiting for a kettle to boil, can be practice.",
(b9,'pon-present',2):" Some people like to choose one 'presence cue' for the day, such as every time they open a door, as a reminder to take one conscious breath.",
}
for (m,i,k),add in X.items():
    s=m.L[i]['sections'];s[k]=(s[k][0],s[k][1]+add)
L={}
_s=b10.L['aop-own-emotions']['sections'];_s[2]=(_s[2][0],_s[2][1]+" With practice, these small pauses become more natural, and you may find that conversations which once felt tense become easier to handle with a clear head.")
_s=b10.L['aop-relationships']['sections'];_s[2]=(_s[2][0],_s[2][1]+" Generosity that expects nothing back is usually the kind people remember and return.")
