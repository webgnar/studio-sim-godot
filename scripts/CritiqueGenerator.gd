class_name CritiqueGenerator

## Assembles procedural art critiques from template pools.
## Each critique is built from: opener + title reaction + visual comment
## + statement reaction (or no-statement remark) + closer.
## Variables like {title}, {artist}, {adj}, {term} are substituted in,
## giving millions of unique combinations per critic type.

const ADJECTIVES := {
	"bum": ["raw", "honest", "wild", "gnarly", "rough", "heavy", "scrappy", "gritty", "real", "bold", "messy", "chaotic", "unhinged", "tender"],
	"general": ["disciplined", "strategic", "bold", "decisive", "commanding", "precise", "relentless", "formidable", "calculated", "aggressive", "measured", "tactical", "audacious", "fortified"],
	"govtpig": ["concerning", "notable", "questionable", "irregular", "significant", "unprecedented", "problematic", "compliant", "unregulated", "flagged", "pending", "documented", "non-standard", "alarming"],
	"guy": ["cool", "weird", "nice", "interesting", "different", "solid", "neat", "funky", "pretty good", "kind of wild", "alright", "something else", "lowkey amazing", "fire"],
	"woman": ["beautiful", "powerful", "moving", "stunning", "bold", "rich", "tender", "fierce", "soulful", "gorgeous", "sharp", "deep", "touching", "electric"],
}

const ART_TERMS := {
	"bum": ["colors", "shapes", "lines", "vibes", "whole thing", "look of it", "feel", "energy", "texture", "mess", "brushwork", "mood"],
	"general": ["composition", "formation", "positioning", "layout", "structure", "execution", "deployment", "framework", "approach", "offensive", "perimeter", "terrain"],
	"govtpig": ["content", "materials", "subject matter", "presentation", "submission", "exhibit", "piece", "installation", "display", "output", "deliverable", "visual asset"],
	"guy": ["colors", "shapes", "vibe", "style", "look", "whole thing", "details", "background", "feeling", "idea", "composition", "palette"],
	"woman": ["colors", "brushwork", "composition", "layers", "feeling", "movement", "light", "texture", "depth", "spirit", "energy", "whole mood"],
}

const OPENERS := {
	"bum": [
		"Alright, alright, let me take a look here.",
		"You want my honest opinion? Fine.",
		"I've seen a lot of things in my time, and this... this is one of them.",
		"Hold on, let me finish this drink first... okay, okay, I'm looking. And I'm seeing..... A whole lot of nothing. Haha, just kidding. There's something here, and it looks like Pac Man ate a rainbow, and then digested it, and then threw it up on the wall. But you know what? I kind of like that.",
		"You know, I used to know a painter. He owed me forty bucks. He used to post up at the beach and peddle his 'automatic drawings' he called them. Anyway.",
		"Most people walk right past me. But this painting? I stopped. Not that this painting is anything like me, but still. Men are visual beings, we like to respond visually to things.",
		"Listen, I ain't no critic. But I got eyes, and I got opinions. Just like everyone's got an asshole. But hey, here we are.",
		"I've slept under better canvases than this. I've also slept under worse. Thats not to say I wouldnt sleep with this canavas though.",
		"Back when I worked at the gallery — yeah, I had one — I saw stuff like this. People made stuff like this all the time.",
		"People think I don't notice things. I notice everything. Especially this.",
	],
	"general": [
		"At ease. I've completed my assessment.",
		"I've reviewed the intelligence on this piece. Here's my briefing.",
		"This painting has been brought to my attention. I've analyzed it thorough the lens of the infastructure that supports it.",
		"Stand down, soldier. Let a real strategist evaluate this.",
		"I've seen battlefields with better composition. And worse. Let me elaborate.",
		"After careful reconnaissance of this work, I'm prepared to deliver my report.",
		"Every great campaign begins with observation. I've observed.",
		"This piece crossed my desk, and I don't let anything cross my desk without a full review.",
		"I've commanded thousands of troops. Reviewing a painting should be simple. Should be.",
		"War is hell. Art criticism is worse. Nevertheless, I proceed.",
	],
	"govtpig": [
		"This submission has been received and processed by our department for social and economic good.",
		"For the record, this review is being conducted per Section 4, Article 12 of the Cultural Assessment Protocol.",
		"Let me pull up the relevant guidelines here... yes, I have some notes.",
		"The department has allocated exactly four minutes for this evaluation.",
		"Before I begin, I want to note that all opinions expressed are those of this office.",
		"I've been assigned to review this piece. My supervisor will receive a copy of this assessment.",
		"Per the taxpayer's interest, I am obligated to provide the following critique.",
		"The funding for this piece has been flagged for review. Let's see what we're dealing with.",
		"The committee has assinged me to review the preliminary filing. Here are our findings.",
		"I want to be clear that this critique does not constitute an endorsement or official position.",
	],
	"guy": [
		"Okay, so, I'm looking at this thing.",
		"Alright, I'm not really an art person, but here goes.",
		"My wife dragged me to this gallery, so I might as well say something.",
		"Honestly? I've been staring at this for like five minutes now.",
		"So my buddy told me to check this place out.",
		"I don't usually have opinions about art, but this one got me.",
		"Okay so I was just getting a coffee and I saw this.",
		"Not gonna lie, I almost walked right past this.",
		"I took a picture of this for my Instagram. Let me tell you why.",
		"Look, I failed art class in high school, so take this with a grain of salt.",
	],
	"woman": [
		"Alright now, let me look at this. I been walking through this gallery and this one right here made me stop.",
		"Mmhmm. Okay. I see what's happening here. Let me tell you something.",
		"Now I don't just hand out compliments, baby. But this one caught my eye.",
		"Chile, I walked in here not expecting much. But then I saw this.",
		"I've been looking at art my whole life. My mama had paintings all through the house. So trust me when I say I know what I'm looking at.",
		"Now hold on. Let me get a good look at this before I say anything. Okay. Okay, I'm ready.",
		"I wasn't gonna say nothing, but this painting right here won't let me walk past it.",
		"Let me tell you, I've seen a lot of art in my day. A LOT. And this one? This one got something.",
		"My grandmother always said, if it makes you feel something, it's doing its job. Well.",
		"I had to put my purse down for this one. That's how you know it's serious.",
	],
}

const TITLE_REACTIONS := {
	"bum": [
		"'{title}'? That's what you're calling it? Bold move.",
		"'{title}' — I've slept under worse titles, I'll give you that.",
		"They went with '{title}.' Could've been worse. Could've been a lot worse.",
		"'{title}.' Huh. That actually means something to me. Don't ask what.",
		"The name '{title}' — it's got a ring to it. Like a bell in an empty church.",
		"'{title}.' Sure. Why not. I've heard crazier things shouted at 3 AM.",
		"'{title}' — sounds like something my ex would name her cat.",
		"You call this '{title}'? I'd call it something else, but your title works too.",
		"'{title}.' That's the kind of name that sticks in your head whether you want it to or not.",
		"'{title}' — I once wrote that on a wall. Different context, but still.",
	],
	"general": [
		"The operation has been designated '{title}.' A strong codename.",
		"'{title}' — I've seen operations named with less thought. This has purpose.",
		"They've titled this '{title}.' In the field, we'd call that a mission statement.",
		"'{title}.' Every great campaign needs a name. This one earns it.",
		"The designation '{title}' suggests the artist knew exactly what theater they were entering.",
		"'{title}' — bold nomenclature. I've greenlit missions on less conviction.",
		"I've classified this under '{title}.' The name alone tells me the artist means business.",
		"'{title}.' Short, direct, no wasted syllables. I respect operational efficiency.",
		"'{title}' — a name that would look good on a medal. Or a warning sign.",
		"They call it '{title}.' I'd have called it Operation {title}. Same thing, more authority.",
	],
	"govtpig": [
		"The piece is titled '{title},' which has been noted in our records.",
		"'{title}' — we'll need to verify this doesn't conflict with any existing registered works.",
		"The title '{title}' has been cross-referenced with our database. No flags at this time.",
		"'{title}.' I'll need the artist to submit a Title Justification Form, but we can proceed for now.",
		"Our office has catalogued this as '{title}.' The paperwork is in order.",
		"'{title}' — the committee had questions about the title, but they've been tabled for now.",
		"We've reviewed the title '{title}' and found it within acceptable parameters.",
		"'{title}.' Per regulation, all titles must be between one and forty characters. This complies.",
		"The working title '{title}' has been approved by our Naming Standards Division. Provisionally.",
		"'{title}.' Our office has seen worse. We've also seen better. This falls within the median.",
	],
	"guy": [
		"'{title}.' Huh. That's a cool name actually.",
		"So it's called '{title}'? I probably would've called it something different, but sure.",
		"'{title}' — my kid could've come up with that. Actually no, that's way better than what my kid would say.",
		"Wait, '{title}'? I thought it was going to be called something artsy. This is way more normal.",
		"'{title}.' I had to read it twice but now I kind of get it.",
		"They named it '{title}' and honestly that's half the reason I stopped to look.",
		"'{title}.' Okay. Okay. I can work with that.",
		"The title '{title}' made me think of something but I can't remember what.",
		"'{title}' — I'd name my band that if I had a band.",
		"'{title}.' Not what I expected. But honestly? Better.",
	],
	"woman": [
		"'{title}.' Now that's a name. Say it again. '{title}.' Mmhmm. That sits right.",
		"They called it '{title}' and you know what? That's exactly what it needed to be called.",
		"'{title}' — baby, that title alone got me in my feelings.",
		"Now '{title}' is a {adj} name for a painting. It tells you just enough without telling you too much.",
		"'{title}.' I said it out loud and the lady next to me looked over. That's how you know the title works.",
		"'{title}' — I'm gonna be thinking about that name all week. It's {adj}.",
		"They went and named this '{title}' and I just — yes. That's the one.",
		"'{title}.' My mama would've had something to say about a name like that. Something good.",
		"'{title}' — now see, that title got {adj} energy to it. You feel that?",
		"'{title}.' Chile, the name alone is doing work. And then you look at the painting on top of that.",
	],
}

const VISUAL_COMMENTS := {
	"bum": [
		"The {term} here? {adj}. Absolutely {adj}.",
		"I've seen {term} like this before. In a dream, maybe. Or a dumpster. Hard to tell sometimes.",
		"Something about the {term} reminds me of a sunset I saw from under the overpass.",
		"The {term} hits different when you've been on the streets as long as I have.",
		"You know what gets me? The {term}. It's {adj} in a way most people won't understand.",
		"This has {adj} {term} and I can't look away.",
		"The {term} is doing all the heavy lifting here, and it knows it.",
		"I'm looking at this {term} and I'm feeling things I haven't felt since I lost my apartment.",
		"There's a {adj} quality to the {term} that you only notice if you really sit with it.",
		"Most people see the {term} and think it's {adj2}. They're not wrong, but they're not right either.",
		"The {term} reminds me of this mural under the bridge on Fifth. Same {adj} energy.",
		"The {term2} next to the {term} — that contrast is {adj}. Real {adj}.",
	],
	"general": [
		"The {term} shows excellent tactical awareness. This is a {adj} maneuver.",
		"From a strategic standpoint, the {term} is {adj}. The artist controls the visual battlefield.",
		"I note the {term} operates on multiple flanks — a {adj} approach to spatial dominance.",
		"The {term} here would make any field commander take notice. It's {adj} and decisive.",
		"This {term} reminds me of the advance at dawn. {adj}. Unrelenting.",
		"The artist has deployed their {term} with {adj} precision.",
		"I see {adj} {term} executed with the discipline of a well-trained unit.",
		"The {term} creates a perimeter that the eye cannot escape. {adj} containment.",
		"Every element of {term} has been positioned like troops on a ridge. {adj} and deliberate.",
		"The {term} holds the high ground while the {term2} covers the flanks. A {adj} coordination.",
		"There's a {adj} offensive in the {term} that reveals the artist's strategic depth.",
		"The {term2} supports the {term} like artillery supports infantry. {adj} and effective.",
	],
	"govtpig": [
		"The {term} has been evaluated per standard criteria and found to be {adj}.",
		"Our analysts have flagged the {term} as {adj}. Further review may be warranted.",
		"The {term} falls within {adj} parameters, though the department reserves the right to reassess.",
		"From a compliance standpoint, the {term} is {adj}. No violations detected at this time.",
		"The {term} presents a {adj} case study for our Cultural Impact Assessment team.",
		"Budget allocation for {term} of this nature would be classified as {adj}.",
		"We've benchmarked the {term} against similar submissions. It is notably {adj}.",
		"The {term} raises some {adj} questions that the subcommittee will need to address.",
		"Per our guidelines, {term} of this caliber is considered {adj}.",
		"The department's position on the {term} is that it is {adj} and within scope.",
		"The {term} has been compared against the {term2}. Both are {adj} in different respects.",
		"Our focus group rated the {term} as {adj}. The {term2} was rated similarly.",
	],
	"guy": [
		"The {term} is pretty {adj}. Like, I keep looking at it.",
		"I don't know much about {term} but this one's {adj} for sure.",
		"My buddy would say the {term} is {adj}. I think I agree.",
		"The {term} reminds me of this thing I saw online once. Really {adj}.",
		"Okay the {term} is actually {adj}. I didn't expect that.",
		"I showed my friend the {term} and she said it was {adj}. She's right.",
		"Something about the {term} is just {adj}. I can't explain it better than that.",
		"The {term}? {adj}. Yeah. That's my take.",
		"I keep going back to the {term}. It's {adj} in a way that sticks with you.",
		"Not gonna lie, the {term} is {adj} and I'm kind of into it.",
		"The {term} and the {term2} together? That's {adj}. Really {adj}.",
		"I was looking at the {term2} first but then the {term} grabbed me. So {adj}.",
	],
	"woman": [
		"Now the {term} in this? {adj}. That's the only word for it. {adj}.",
		"Look at that {term}. You see how they did that? That's {adj} right there.",
		"The {term} got me. I'm not even gonna lie, that {term} is {adj}.",
		"Baby, the {term} in this painting is doing all the heavy lifting and it knows it. {adj}.",
		"What gets me is the {term}. It's {adj} in a way that sneaks up on you.",
		"You can tell somebody put their whole heart into that {term}. It's {adj} and it's real.",
		"The {term} alone is worth the trip. That is {adj} work, honey.",
		"I keep looking at the {term} and finding something new. That's how you know it's {adj}.",
		"Chile, the {term} and the {term2} together? That's {adj}. That's church right there.",
		"See how the {term2} plays off the {term}? That's not an accident. That's {adj} on purpose.",
		"The {term} is speaking to me. Saying something {adj}. I'm listening.",
		"Honey, the {term} in this is so {adj} I wanna call my sister and tell her about it.",
	],
}

const ARTIST_COMMENTS := {
	"bum": [
		"{artist} — never heard of 'em, but I respect the hustle.",
		"So {artist} made this? Tell 'em I said it's not bad. Coming from me, that's high praise.",
		"If {artist} is listening — you got something. Don't let anybody take it from you.",
		"{artist} paints like someone who's been through it. I can tell.",
		"I'd buy {artist} a drink for this. If I could afford drinks.",
		"{artist} has that hunger you can't fake. I know hunger.",
		"Tell {artist} the guy on bench number four gives this a thumbs up.",
		"You can tell {artist} actually cares. That's rare. Real rare.",
	],
	"general": [
		"{artist} has the makings of a fine officer. This work shows leadership.",
		"I'd want {artist} in my unit. This level of commitment is what wins wars.",
		"{artist} operates like a seasoned commander — every choice is intentional.",
		"If {artist} ever tires of art, there's a place for them in strategic planning.",
		"{artist} understands that execution is everything. Theory without execution is just talk.",
		"I've seen officers with less vision than {artist} shows here.",
		"{artist} has earned my respect. That doesn't come easy.",
		"The discipline {artist} brings to the canvas would serve them well on the battlefield.",
	],
	"govtpig": [
		"{artist} is now on file with our department. Standard procedure.",
		"We've opened a cultural profile for {artist}. Purely administrative.",
		"{artist} should be aware that this submission has been permanently archived.",
		"Our records show this is {artist}'s first review by this office. We'll be watching.",
		"{artist} will receive a formal acknowledgment of this review within six to eight weeks.",
		"The department has no prior complaints regarding {artist}. That's noted positively.",
		"{artist} is advised to retain copies of all materials submitted for future audits.",
		"We appreciate {artist}'s compliance with the submission process.",
	],
	"guy": [
		"{artist} seems cool. I'd probably follow them on Instagram.",
		"I wonder if {artist} does commissions. My apartment could use something like this.",
		"I told my wife about {artist} and she wants to check out more of their stuff.",
		"{artist} is onto something here. Like, for real.",
		"If I saw {artist} at a party I'd definitely ask about this piece.",
		"{artist} is the kind of artist I can actually relate to.",
		"Shoutout to {artist}. This is genuinely good.",
		"I'm adding {artist} to my list of artists I actually know by name. Short list.",
	],
	"woman": [
		"{artist} got something special. I'm telling you right now, remember that name.",
		"Now {artist} — that's somebody who knows what they're doing. You can feel it.",
		"I'm gonna keep my eye on {artist}. They got a gift and they know how to use it.",
		"{artist} painted this like they had something to prove. And baby, they proved it.",
		"If {artist} is in the room right now, I need you to know — you did that.",
		"My cousin paints too but she ain't doing what {artist} is doing. Not even close.",
		"{artist} got the kind of talent you can't teach. You either got it or you don't. They got it.",
		"I'm telling everybody at church about {artist} this Sunday. This needs to be seen.",
	],
}

const STATEMENT_REACTIONS := {
	"bum": [
		"The artist says '{statement}' — yeah, I've thought that too, at 3 AM under a bridge.",
		"'{statement}' — deep. Deeper than most people on the street are willing to go.",
		"They wrote '{statement}' and honestly? That hit me somewhere I didn't expect.",
		"'{statement}.' I've scrawled worse on bathroom walls. But this actually means something.",
		"The statement — '{statement}' — sounds like something you'd hear at a campfire that got too real.",
		"'{statement}.' You know what, I felt that. I felt that in my bones.",
		"They say '{statement}' and I'm sitting here nodding like I'm in church.",
		"'{statement}' — I said something similar once but nobody was around to hear it.",
	],
	"general": [
		"The artist's statement — '{statement}' — reads like a mission briefing. I approve.",
		"'{statement}.' That's the kind of clarity of purpose I demand from my officers.",
		"The intent behind '{statement}' shows strategic thinking. This artist has a plan.",
		"'{statement}' — a declaration of war against mediocrity. I can respect that.",
		"Reading '{statement},' I'm reminded that the best campaigns begin with clear objectives.",
		"'{statement}.' Direct. No ambiguity. The artist knows their target and is locked on.",
		"The statement '{statement}' carries the weight of a field command. No hesitation.",
		"'{statement}' — this is what we call a clear directive. The artist leaves nothing to chance.",
	],
	"govtpig": [
		"The artist states '{statement},' which has been entered into the public record.",
		"'{statement}' — our legal team will need to review this for compliance.",
		"The statement '{statement}' has been cross-checked against our guidelines. It's... within bounds.",
		"'{statement}.' We'll file this alongside the work for our annual Cultural Audit.",
		"The artist's claim of '{statement}' will require supporting documentation.",
		"'{statement}' — bold words. The department has noted them for the permanent record.",
		"Regarding '{statement}' — we have neither the budget nor the mandate to verify this.",
		"'{statement}.' Interesting. Our department will take this under advisement.",
	],
	"guy": [
		"They said '{statement}' and honestly? Same.",
		"'{statement}' — I had to read it a couple times but now I get it. I think.",
		"The artist wrote '{statement}' and that's actually a pretty cool way to put it.",
		"'{statement}.' That's deeper than anything I've said today, and I've been talking a lot.",
		"When they say '{statement},' I'm like, yeah, I've been there. Sort of.",
		"'{statement}' — my buddy would call that profound. I'd call it relatable.",
		"The whole '{statement}' thing really ties it together for me.",
		"'{statement}.' You know what? That actually makes me see the painting differently.",
	],
	"woman": [
		"The artist said '{statement}' and baby, I felt that in my chest.",
		"'{statement}' — now see, that right there is somebody being honest. I respect that.",
		"They wrote '{statement}' and I had to read it twice because it hit different the second time.",
		"'{statement}.' Chile, if that ain't the truth. The painting says it and the words confirm it.",
		"'{statement}' — my grandmother would've nodded at that. That's real talk right there.",
		"When they say '{statement},' you know they meant every brushstroke. That's conviction.",
		"'{statement}.' Mmhmm. That's not just an artist statement, that's a testimony.",
		"'{statement}' — and you can see it in the work too. They're not just talking, they're living it.",
	],
}

const NO_STATEMENT := {
	"bum": [
		"No artist statement. Smart. Let the work speak for itself. That's street wisdom.",
		"They didn't write a statement. Good. Words are overrated when you've got paint.",
		"No explanation, no excuse, no statement. Just the painting. I respect that.",
		"The lack of a statement says more than most statements I've read.",
		"Some people talk. Some people paint. This artist paints.",
		"No statement needed. The canvas says everything the artist didn't.",
	],
	"general": [
		"No statement of purpose provided. In the military, we call that operational security.",
		"The absence of a statement suggests confidence. You don't explain a well-executed mission.",
		"No statement. The work stands on its own. A silent warrior needs no introduction.",
		"I note the lack of an artist statement. Sometimes the strongest message is no message at all.",
		"No mission briefing attached. The painting is its own intelligence report.",
		"The artist operates without a stated objective. Bold, but effective.",
	],
	"govtpig": [
		"No artist statement was provided. This has been flagged as an incomplete submission.",
		"The absence of a statement complicates our documentation process. We'll proceed regardless.",
		"For the record, the artist declined to provide a statement. Form 7-B will reflect this.",
		"No statement. The department strongly recommends one for future submissions.",
		"Our office typically requires an artist statement. We'll waive it this time.",
		"Without a statement, our Cultural Assessment team has had to work overtime. Noted.",
	],
	"guy": [
		"They didn't write anything about it, which honestly? Might be for the best.",
		"No artist statement. That's cool. I never read those anyway.",
		"There's no description or anything. Just the painting. I kind of like that.",
		"No statement. Sometimes you just gotta let the thing be the thing.",
		"I looked for an explanation but there wasn't one. Makes it more mysterious, I guess.",
		"No words. Just vibes. I can respect that.",
	],
	"woman": [
		"No artist statement. You know what? Good. Let the painting do the talking.",
		"They didn't write nothing down and honestly? The painting said everything it needed to say.",
		"No statement. That's bold. But the {term} speaks for itself, so I ain't mad.",
		"Some people write a whole essay. This artist let the work stand on its own. That's {adj}.",
		"No words, just paint. My mama always said actions speak louder. This is {adj}.",
		"They didn't explain it. I respect that. If you gotta explain it, maybe it ain't that {adj}.",
	],
}

const CLOSERS := {
	"bum": [
		"Overall? I'd hang this in my spot under the bridge. Highest honor I can give.",
		"Final word: this painting has more soul than most people I've met. And I've met a lot.",
		"Look, I've seen art in alleys, in shelters, in dumpsters. This belongs somewhere better.",
		"If I had a wall, I'd put this on it. But I don't. So I'll just remember it.",
		"Anyway, that's my two cents. Which is about all I have. Literally.",
		"Not bad, {artist}. Not bad at all. Now if you'll excuse me, I got a bench to get back to.",
		"This one's going to stick with me. Not many things do anymore.",
		"I've seen enough. This is the real deal. Now spare some change?",
		"Bottom line: this painting doesn't pretend to be something it's not. Neither do I.",
		"Tell you what — this painting and me have something in common. We're both {adj} and misunderstood.",
	],
	"general": [
		"Final assessment: this piece is combat-ready. Deploy it.",
		"Mission report: the painting exceeds expectations. Recommend for advancement.",
		"In summary, this work has earned a commendation. Carry on, {artist}.",
		"This painting would rally troops. It's got that {adj} quality that inspires action.",
		"End of briefing. This piece has my endorsement. That is not given lightly.",
		"Verdict: the artist has won this engagement. I'll be watching the next one closely.",
		"I've seen enough. This painting is a force multiplier. High marks all around.",
		"Dismissed. But take this with you: this painting has earned its place in the ranks.",
		"After thorough review, I'm awarding this piece a field promotion. Outstanding work.",
		"The campaign is over. This painting won. Debrief complete.",
	],
	"govtpig": [
		"This concludes our review. The file will remain open for 90 days.",
		"In summary, this work meets the minimum requirements for cultural significance. Barely.",
		"The department will continue to monitor {artist}'s output. Standard procedure.",
		"This review is now closed. Any appeals must be filed within 30 business days.",
		"Final note: the painting is approved for public display. Conditionally.",
		"Our assessment is complete. {artist} may collect their Certificate of Review at the front desk.",
		"To summarize: {adj}, within bounds, and duly recorded. Next submission, please.",
		"This case is closed pending further review. The painting may remain on the wall. For now.",
		"End of report. The taxpayers can rest easy knowing their cultural institutions are being monitored.",
		"We've concluded our evaluation. The department thanks {artist} for their cooperation.",
	],
	"guy": [
		"So yeah. That's what I think. Take it or leave it.",
		"Anyway, I should probably go find my wife. But this was cool.",
		"Final thoughts: I'd put this in my living room. My wife would probably hate it. Worth it.",
		"In conclusion, or whatever: thumbs up from me. For what that's worth.",
		"That's all I got. I'm gonna go get a pretzel now. But yeah, good painting.",
		"So there you go. I actually have an opinion about art now. Who knew?",
		"Bottom line: this is {adj}. I'm glad I stopped to look.",
		"I'm sending a picture of this to my group chat. They're not gonna get it, but still.",
		"Honestly? This was better than most stuff I see on my feed. And I scroll a lot.",
		"Look, if {artist} ever reads this — keep going. This is good.",
	],
	"woman": [
		"Bottom line? This is {adj}. I don't say that lightly. Come see this painting.",
		"I'm walking away from this one changed. And that's what good art is supposed to do.",
		"Listen, {artist} did that. Period. This painting is {adj} and I won't hear otherwise.",
		"I'm gonna be thinking about this all week. That's the highest praise I got, baby.",
		"If you walk past this painting without stopping, I don't know what to tell you. It's {adj}.",
		"This right here? This is the one. {adj}, {adj2}, and everything in between.",
		"{artist} put something {adj} into the world today. And the world is better for it.",
		"I came in here expecting nothing and I'm leaving with a whole testimony. {adj}.",
		"Go see this painting. Bring your mama. Bring your kids. It's that {adj}.",
		"I got nothing else to say except — {adj}. {artist}, you did your thing.",
	],
}


static func generate(critic_type: String, title: String, artist: String, statement: String) -> String:
	if not OPENERS.has(critic_type):
		critic_type = "guy"

	var adj_pool: Array = ADJECTIVES[critic_type].duplicate()
	var adj := _pick_remove(adj_pool)
	var adj2 := _pick_remove(adj_pool)

	var term_pool: Array = ART_TERMS[critic_type].duplicate()
	var term := _pick_remove(term_pool)
	var term2 := _pick_remove(term_pool)

	if title.strip_edges() == "":
		title = "Untitled"
	if artist.strip_edges() == "":
		artist = "the artist"

	var short_statement := statement
	if short_statement.length() > 120:
		var period := short_statement.find(".", 20)
		if period > 0 and period < 120:
			short_statement = short_statement.left(period + 1)
		else:
			short_statement = short_statement.left(117) + "..."

	var vars := {
		"title": title,
		"artist": artist,
		"statement": short_statement,
		"adj": adj,
		"adj2": adj2,
		"term": term,
		"term2": term2,
	}

	var parts: PackedStringArray = []
	parts.append(_fill(_pick(OPENERS, critic_type), vars))
	parts.append(_fill(_pick(TITLE_REACTIONS, critic_type), vars))
	parts.append(_fill(_pick(VISUAL_COMMENTS, critic_type), vars))

	if randf() > 0.4:
		parts.append(_fill(_pick(ARTIST_COMMENTS, critic_type), vars))

	if statement.strip_edges() != "":
		parts.append(_fill(_pick(STATEMENT_REACTIONS, critic_type), vars))
	else:
		parts.append(_fill(_pick(NO_STATEMENT, critic_type), vars))

	parts.append(_fill(_pick(CLOSERS, critic_type), vars))
	return " ".join(parts)


static func _fill(template: String, vars: Dictionary) -> String:
	var result := template
	for key in vars:
		result = result.replace("{" + key + "}", vars[key])
	return result


static func _pick(pool: Dictionary, critic_type: String) -> String:
	var entries: Array = pool[critic_type]
	return entries[randi() % entries.size()]


static func _pick_remove(pool: Array) -> String:
	var idx := randi() % pool.size()
	var val: String = pool[idx]
	pool.remove_at(idx)
	return val
