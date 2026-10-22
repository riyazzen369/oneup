# Generates assets/content/learn.json. All summaries are original wording (no copied passages).
import json
books = [
 dict(id="wellness8", title="The Wellness 8: The Eight Dimensions to Achieving Incredible Health, Increased Wellness & Continual Well-Being",
      short="The Wellness 8", author="Jeremy Reynolds", year=2017, publisher="Wealth Builders Global LLC", isbn="9781734155716",
      note="Paperback dated 2017 by retailers; 2nd edition (ebook) 2019. Lessons based on the publisher's description only. [VERIFY] against the book.", verify=True),
 dict(id="atomic-habits", title="Atomic Habits: An Easy & Proven Way to Build Good Habits & Break Bad Ones", short="Atomic Habits",
      author="James Clear", year=2018, publisher="Avery (Penguin Random House)", isbn="9780735211292", note=None, verify=False),
 dict(id="mountain-is-you", title="The Mountain Is You: Transforming Self-Sabotage Into Self-Mastery", short="The Mountain Is You",
      author="Brianna Wiest", year=2020, publisher="Thought Catalog Books", isbn="9781949759228", note=None, verify=False),
 dict(id="better-than-before", title="Better Than Before: Mastering the Habits of Our Everyday Lives", short="Better Than Before",
      author="Gretchen Rubin", year=2015, publisher="Crown Publishers", isbn="9780804141239", note=None, verify=False),
 dict(id="body-keeps-score", title="The Body Keeps the Score: Brain, Mind, and Body in the Healing of Trauma", short="The Body Keeps the Score",
      author="Bessel van der Kolk", year=2014, publisher="Viking", isbn="9780670785933", note=None, verify=False),
 dict(id="mindset", title="Mindset: The New Psychology of Success", short="Mindset", author="Carol S. Dweck", year=2006,
      publisher="Random House", isbn="9781400062751", note=None, verify=False),
dict(id="48-laws", title="The 48 Laws of Power", short="48 Laws of Power", author="Robert Greene (with Joost Elffers)", year=1998,
     publisher="Viking", isbn="9780670881468", note="Presented for awareness, not as advice to manipulate others.", verify=False),
dict(id="power-of-now", title="The Power of Now: A Guide to Spiritual Enlightenment", short="The Power of Now", author="Eckhart Tolle", year=1999,
     publisher="New World Library", isbn="9781577311522", note="First published 1997 by Namaste Publishing (Canada). Reflective practice, not a treatment for anxiety or any condition.", verify=False),
dict(id="art-of-persuasion", title="The Art of Persuasion: Winning Without Intimidation", short="Art of Persuasion", author="Bob Burg", year=2011,
     publisher="Sound Wisdom", isbn="9780768413007", note="Previously published as 'Winning Without Intimidation'.", verify=True),
]
L = []
def add(book, id, title, dims, idea, cards, tryit, sensitive=False):
    L.append(dict(id=id, book=book, title=title, dimensions=dims, idea=idea, cards=cards, tryThis=tryit, sensitive=sensitive))

# --- The Wellness 8 (minimal; publisher description only) ---
add("wellness8","w8-more-than-health","Wellness is more than not being ill",["physical","emotional"],"The idea of total wellness",
 ["Feeling well is broader than having no illness.","The book's framing: you can be physically fit and still not feel well if other parts of life are struggling.","It invites you to look at your life as a whole, not one area at a time."],
 "Ask yourself: in which area of life do I feel most 'well' today, and which feels least?")
add("wellness8","w8-wheel","A wheel with eight spokes",["social","spiritual"],"The eight dimensions",
 ["The book names eight areas: emotional, environmental, financial, intellectual, occupational, physical, social and spiritual.","It compares them to spokes on a wheel: if one is weak, the whole ride feels bumpy.","Balance doesn't mean perfect scores; it means no spoke is forgotten."],
 "Look at your OneUP wheel and pick the one spoke you have given the least attention lately.")
add("wellness8","w8-learning","Keep learning, even when busy",["intellectual","occupational"],"Nonstop learning",
 ["The book encourages a habit of continuous learning.","Learning doesn't need long blocks of time; small, regular amounts add up.","Curiosity can be practised like any other habit."],
 "Pick one topic you are curious about and spend 10 minutes on it this week.")
add("wellness8","w8-kindness","The value of kindness",["social","emotional"],"Kindness and contribution",
 ["The book highlights kindness and contributing to others as part of being well.","Small acts count: a message, a thank-you, a moment of attention.","Kindness tends to strengthen the relationships around you."],
 "Send one short, genuine thank-you message to someone today.")

# --- Atomic Habits ---
add("atomic-habits","ah-tiny-gains","Small changes compound",["occupational","intellectual"],"The power of tiny improvements",
 ["Tiny improvements feel insignificant on any single day.","Repeated over months, they add up to a large difference, in either direction.","Look at the direction you're heading, not just today's result."],
 "Choose one habit you could make just a little better this week, and keep it small.")
add("atomic-habits","ah-systems","Systems over goals",["occupational","financial"],"Systems versus goals",
 ["Goals describe the result you want; systems are the everyday processes that get you there.","People with the same goal can get very different results because their systems differ.","Improving the process often matters more than restating the target."],
 "Write one goal, then list the daily action (the system) that would move you toward it.")
add("atomic-habits","ah-identity","Habits shape who you become",["emotional","spiritual"],"Identity-based habits",
 ["Lasting change is easier when it's tied to the kind of person you want to be.","Each time you act in line with that identity, you add evidence that it's true.","Ask 'Who do I want to become?' as well as 'What do I want to achieve?'"],
 "Complete the sentence: 'I am the kind of person who…' and do one small action that fits it.")
add("atomic-habits","ah-four-laws","Four ways to shape a habit",["physical","occupational"],"The Four Laws of Behavior Change",
 ["The book suggests making a good habit obvious, attractive, easy and satisfying.","To break a habit, flip them: make it invisible, unattractive, difficult and unsatisfying.","You don't need all four at once; one adjustment can help."],
 "Pick one habit and change just one of the four: e.g., put your water bottle where you'll see it.")
add("atomic-habits","ah-stacking","Attach new habits to old ones",["physical","intellectual"],"Habit stacking",
 ["An existing routine can act as a cue for a new one.","The pattern: after I do my current habit, I will do my new habit.","Being specific about when and where makes it easier to follow through."],
 "Write one stack: 'After I pour my morning tea, I will…' and try it tomorrow.")
add("atomic-habits","ah-environment","Design your surroundings",["environmental","physical"],"Environment design and the Two-Minute Rule",
 ["Your surroundings nudge your choices more than you might notice.","Make cues for good habits visible and remove cues for unwanted ones.","Start a new habit with a version that takes about two minutes, then grow it."],
 "Rearrange one small spot at home so a good habit is the easiest option there.")

# --- The Mountain Is You ---
add("mountain-is-you","miy-sabotage","Self-sabotage meets a hidden need",["emotional"],"There's no such thing as self-sabotage",
 ["Behaviour that holds us back often serves a need we haven't named, such as comfort or safety.","Seeing that need is more useful than blaming yourself.","Once the need is clear, you can look for a healthier way to meet it."],
 "Think of one habit that holds you back and ask: what might it be giving me?")
add("mountain-is-you","miy-triggers","Triggers as signposts",["emotional","spiritual"],"Your triggers are the guides to your freedom",
 ["Strong reactions can point to something that matters to you or still needs care.","Getting curious about a reaction, rather than only reacting, creates room to choose.","A trigger can be information, not just discomfort."],
 "Next time something irritates you, note it later in one line: what happened and what you felt.")
add("mountain-is-you","miy-eq","Building emotional intelligence",["emotional","social"],"Building emotional intelligence",
 ["Emotional intelligence includes noticing, naming and understanding your feelings.","Feelings carry useful messages, even uncomfortable ones.","Understanding your own emotions helps in understanding others too."],
 "Three times today, pause and name your feeling in one word.")
add("mountain-is-you","miy-future","Acting as your future self",["occupational","spiritual"],"Building a new future",
 ["Change becomes real through small actions, not only insight.","Imagining the person you want to become can guide everyday choices.","Progress can feel uncomfortable because it is unfamiliar, not because it is wrong."],
 "Write one small thing the future version of you would do today, and do it.")

# --- Better Than Before ---
add("better-than-before","btb-tendencies","Know how you respond to expectations",["emotional","occupational"],"The Four Tendencies",
 ["The book describes four tendencies: Upholder, Questioner, Obliger and Rebel.","They differ in how people respond to expectations from others and from themselves.","Knowing your tendency helps you choose habit strategies that suit you."],
 "Think about a promise you kept easily and one you didn't. What made the difference?")
add("better-than-before","btb-foundation","Strengthen the foundation",["physical","environmental"],"Strategy of Foundation",
 ["Some habits support many others, such as sleep, movement, eating well and decluttering.","When these basics slip, other habits tend to wobble too.","Starting with a foundation habit can make the rest easier."],
 "Choose one foundation habit (sleep, movement, food or a tidy space) to protect this week.")
add("better-than-before","btb-monitoring","What you track, you notice",["financial","physical"],"Strategy of Monitoring",
 ["Keeping track of an action makes it more visible.","Simple monitoring, like noting spending or steps, often changes behaviour on its own.","Track without judging; the aim is awareness."],
 "For three days, jot down one thing you want to understand better, e.g., small purchases.")
add("better-than-before","btb-abstainer","Abstainer or moderator?",["physical","emotional"],"Abstainers and Moderators",
 ["Some people find it easier to avoid a temptation completely (abstainers).","Others do better with a little, now and then (moderators).","Neither is better; knowing which fits you helps you set useful rules."],
 "Think of one temptation. Would 'none' or 'a little' be easier for you? Try that approach for a week.")
add("better-than-before","btb-loopholes","Spot your loopholes",["intellectual","financial"],"Strategy of Loophole-Spotting",
 ["We often invent reasons to skip a habit 'just this once'.","Common examples include 'it's a special occasion' or 'I'll make up for it tomorrow'.","Naming the loophole in advance makes it easier to notice in the moment."],
 "Write down the excuse you use most often to skip a good habit.")

# --- The Body Keeps the Score (sensitive; gentle; no therapy instructions) ---
SENS = True
add("body-keeps-score","bks-mind-body","Mind and body are connected",["emotional","physical"],"The book's central idea",
 ["The book explores how very difficult experiences can affect the body as well as the mind.","It suggests that stress can be felt physically, not only as thoughts.","Understanding this connection can make reactions feel less confusing."],
 "Be kind to yourself today: notice one thing your body needs (rest, water, a stretch) and offer it.", SENS)
add("body-keeps-score","bks-connection","Connection and feeling safe",["social","emotional"],"Relationships and safety",
 ["The book emphasises how important safe, supportive relationships are.","Feeling understood by others can be a meaningful part of healing.","Support can come from friends, family, community or professionals."],
 "Think of one person or place that feels safe to you, and consider reaching out or visiting.", SENS)
add("body-keeps-score","bks-many-paths","Many paths to recovery",["spiritual","physical"],"Approaches discussed in the book",
 ["The book discusses a range of approaches it describes as helpful for some people, including body-based and creative activities.","What helps differs from person to person.","Choosing an approach is best done with a qualified professional."],
 "If you are curious about support options, the Consult tab lists professionals you can talk to.", SENS)
add("body-keeps-score","bks-self-compassion","Reactions make sense",["emotional","spiritual"],"Understanding responses to stress",
 ["Strong reactions after difficult experiences are understandable, not a personal failing.","Seeing them this way can make room for patience with yourself.","You don't have to work through hard memories alone."],
 "Write one kind sentence to yourself, the way you would to a friend.", SENS)

# --- Mindset ---
add("mindset","ms-two-mindsets","Fixed and growth mindsets",["intellectual","emotional"],"The mindsets",
 ["The book contrasts two beliefs: that abilities are fixed, or that they can be developed.","These beliefs shape how people approach challenges.","Most people hold a mix, and it can vary from one area of life to another."],
 "Name one skill you think you 'just aren't good at'. Add the word 'yet' to the end of that thought.")
add("mindset","ms-failure","Setbacks as information",["occupational","emotional"],"Mindsets change the meaning of failure",
 ["With a fixed view, a setback can feel like a verdict on who you are.","With a growth view, it becomes information about what to try next.","The event is the same; the meaning we give it differs."],
 "Recall a recent setback and write one thing it taught you.")
add("mindset","ms-effort","Effort is how ability grows",["intellectual","physical"],"Mindsets change the meaning of effort",
 ["A fixed view can treat effort as a sign you lack talent.","A growth view treats effort as the way skills are built.","Useful effort includes trying new strategies, not just trying harder."],
 "Pick something you're learning and try one new approach to it this week.")
add("mindset","ms-praise","Praise the process",["social","intellectual"],"The danger of praise and positive labels",
 ["Praising people only for being 'smart' or 'talented' can make them avoid challenges.","Noticing effort, strategies and progress tends to encourage learning.","This applies to how we talk to ourselves, too."],
 "Today, when you appreciate someone, mention what they did, not just what they are.")
add("mindset","ms-relationships","Mindsets in relationships",["social"],"Relationships",
 ["Mindsets also show up in friendships and close relationships.","A growth view sees relationships as something people can work on together.","Disagreements become chances to understand each other, not proof something is broken."],
 "Think of a recent disagreement and ask: what could we each learn from it?")

# --- Added: Environmental & Financial (0.1.20) ---
add("wellness8","w8-surroundings","Shape your surroundings",["environmental","social"],"Environmental wellness (per publisher description)",
 ["The book links environmental wellness to the surroundings you manage day to day.","Its description includes people, media and even your own self-talk as part of that environment.","The aim is to reduce what drags you down and make room for what lifts you up."],
 "Notice one input today (a feed, a show, a conversation) that leaves you drained, and limit it for a day.")
add("wellness8","w8-clutter","Let go of what holds you back",["environmental","emotional"],"Letting go of clutter",
 ["The book encourages letting go of 'clutter' that holds you back.","Clutter can be physical things, but also commitments or habits that no longer fit.","Clearing a little space can make it easier to focus on what matters."],
 "Clear one small surface or drawer today, and notice how it feels afterwards.")
add("wellness8","w8-financial-freedom","Money as part of wellness",["financial","emotional"],"Financial wellness (per publisher description)",
 ["The book treats financial wellness as one of the eight dimensions, alongside health and relationships.","Its description stresses understanding the value of financial freedom and the tools to work toward it.","Thinking about money calmly and regularly can reduce the stress it brings."],
 "Write down one money question you have been avoiding. You don't need to solve it today.")
add("atomic-habits","ah-invisible","Make temptations invisible",["environmental","emotional"],"Inverting the 1st Law: make it invisible",
 ["Cues you see often are hard to ignore.","To weaken an unwanted habit, reduce how often you encounter its cue.","Removing a cue is often easier than resisting it again and again."],
 "Move one tempting item (snack, device, app) out of sight or off your home screen for a week.")
add("atomic-habits","ah-one-space","One space, one use",["environmental","occupational"],"Context and environment",
 ["Places become linked with the activities we do in them.","Keeping a space mostly for one activity can make that activity easier to start.","Even a particular chair or corner can work as a dedicated spot."],
 "Choose one spot at home that you will use only for one good habit, like reading.")
add("atomic-habits","ah-commitment","Decide once, in advance",["financial","occupational"],"Commitment devices",
 ["A commitment device is a choice made now that shapes your behaviour later.","It works by making the good option automatic or the unwanted option harder.","Setting things up once can save willpower every day afterwards."],
 "Think of one recurring choice, such as spending on a habit, and one way to decide it ahead of time.")
add("atomic-habits","ah-contract","Make it visible to someone else",["financial","social"],"Accountability and habit contracts",
 ["Knowing someone is aware of your commitment can make it easier to keep.","The book describes making an agreement with others about a habit and what happens if you break it.","Sharing a goal with a trusted person adds a gentle, social reason to follow through."],
 "Tell one trusted person about a small goal and ask them to check in with you next week.")
add("better-than-before","btb-convenience","Make good habits convenient",["environmental","physical"],"Strategies of Convenience and Inconvenience",
 ["We tend to do what's easy and skip what takes effort.","Making a good habit more convenient, and an unwanted one less convenient, shifts behaviour.","Small amounts of friction, like an extra step, can matter."],
 "Add one small step of friction to a habit you want less of, and remove one from a habit you want more of.")
add("better-than-before","btb-clarity","Be clear about what you value",["financial","intellectual"],"Strategy of Clarity",
 ["Habits are easier to keep when you are clear about what you want and why.","Conflicting values can leave you stuck between choices.","Being specific about the action helps, too."],
 "Write one sentence about what you want your money to do for you, in your own words.")
add("better-than-before","btb-scheduling","Put it on the calendar",["financial","occupational"],"Strategy of Scheduling",
 ["Scheduling a habit for a set time takes the daily decision out of it.","A regular slot helps a habit become routine.","This works well for tasks that are easy to postpone."],
 "Choose a short, regular time each week to look over your spending or plans.")

# --- 48 Laws of Power: awareness framing only ---
add("48-laws","p48-awareness","Recognise power games",["social","emotional"],"The book as a catalogue of power tactics",
 ["The book describes tactics people have used to gain power, drawing on historical stories.","Read for awareness, it can help you notice when someone may be steering you.","Recognising a pattern gives you a choice in how to respond."],
 "Think of a recent conversation that left you uneasy. Was there pressure, flattery or guilt you can now name?")
add("48-laws","p48-say-less","Pause before you speak",["social","occupational"],"Law 4: Always Say Less Than Necessary",
 ["The book argues that saying more than needed can weaken your position.","A wellness-friendly reading: you don't owe everyone every detail.","Speaking thoughtfully is a way of keeping healthy boundaries."],
 "In one conversation today, pause for a breath before answering a personal question.")
add("48-laws","p48-company","Notice the company you keep",["social","emotional"],"Law 10: Avoid the unhappy and unlucky",
 ["The book warns that other people's moods and habits can spread to us.","This isn't about judging people who are struggling; it's about noticing your own limits.","You can care for others while still protecting your energy."],
 "Notice who you feel lighter after spending time with this week, and make a little more room for them.")
add("48-laws","p48-plan","Think to the end",["occupational","intellectual"],"Law 29: Plan All the Way to the End",
 ["The book stresses thinking through where a plan leads before starting.","Considering the likely ending helps you avoid being swept along by short-term wins.","Used ethically, it's simply careful planning."],
 "For one goal, write down what 'done' looks like and one obstacle you might meet on the way.")

# --- The Power of Now ---
add("power-of-now","pon-present","This moment is where life happens",["spiritual","emotional"],"The present moment",
 ["The book's central idea is that life only ever happens now.","Much stress, it suggests, comes from living in thoughts about the past or future.","Bringing attention back to now is something you can practise anytime."],
 "Right now, notice three things you can hear, without labelling them good or bad.")
add("power-of-now","pon-watch-mind","You can watch your thoughts",["spiritual","intellectual"],"You are not your mind",
 ["The book invites you to notice thoughts as they arise, as if listening to them.","Observing thoughts can create a small gap between you and them.","In that gap, the book describes a sense of calm presence."],
 "For one minute, watch your thoughts like passing cars, without following any of them.")
add("power-of-now","pon-acceptance","Accept what is, then act",["spiritual","emotional"],"Surrender (acceptance)",
 ["The book uses 'surrender' to mean accepting the present moment as it is.","It doesn't mean giving up; you can still take action to change things.","Accepting first can make your action calmer and clearer."],
 "Name one situation you are resisting. Say 'this is how it is right now', then choose one small step.")
add("power-of-now","pon-inner-body","Feel alive from the inside",["spiritual","physical"],"The inner body",
 ["The book suggests bringing attention to the felt sense of aliveness in your body.","This can anchor you in the present when your mind is busy.","It is a reflective practice, not a medical treatment."],
 "Close your eyes and notice the feeling in your hands for thirty seconds.")

# --- The Art of Persuasion (Bob Burg) ---
add("art-of-persuasion","aop-win-win","Persuade without pressure",["social","occupational"],"Winning without intimidation",
 ["The book's theme is getting good outcomes with people without bullying or being bullied.","It favours making others feel good about helping you.","Influence that respects the other person tends to last longer."],
 "Before your next request, think of how it could also benefit the other person.")
add("art-of-persuasion","aop-own-emotions","Steady yourself first",["emotional","social"],"Controlling your own emotions",
 ["The book stresses staying in control of your own reactions in tense moments.","Reacting from anger usually makes persuasion harder.","Calm gives you more choices in how to respond."],
 "When you feel irritated today, take a slow breath before replying.")
add("art-of-persuasion","aop-difficult","Kindness with difficult people",["social","emotional"],"Dealing with difficult people",
 ["The book suggests that firm kindness often works better than confrontation.","Letting someone save face can calm a tense exchange.","Being kind doesn't mean giving up your position."],
 "Think of a tricky person in your life and one respectful phrase you could use with them.")
add("art-of-persuasion","aop-relationships","Influence grows from trust",["social","occupational"],"Building rapport",
 ["The book links influence to relationships built over time.","People are more open to those they know, like and trust.","Small, genuine acts of attention build that trust."],
 "Note one colleague or friend you could show genuine interest in this week.")

data = {"version": 1,
  "disclaimer": "Summary in our own words; read the book for full context. For general wellness learning, not medical or psychological advice.",
  "financialNote": "General learning only. Not financial advice.",
  "sensitiveNote": "If this brings up difficult feelings, consider speaking with a qualified professional.",
  "books": books, "lessons": L}
json.dump(data, open("assets/content/learn.json","w"), ensure_ascii=False, indent=1)
print(len(L))
