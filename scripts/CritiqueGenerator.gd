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
	"woman": ["evocative", "luminous", "arresting", "provocative", "nuanced", "masterful", "striking", "delicate", "visceral", "sumptuous", "austere", "compelling", "incandescent", "restrained"],
}

const ART_TERMS := {
	"bum": ["colors", "shapes", "lines", "vibes", "whole thing", "look of it", "feel", "energy", "texture", "mess", "brushwork", "mood"],
	"general": ["composition", "formation", "positioning", "layout", "structure", "execution", "deployment", "framework", "approach", "offensive", "perimeter", "terrain"],
	"govtpig": ["content", "materials", "subject matter", "presentation", "submission", "exhibit", "piece", "installation", "display", "output", "deliverable", "visual asset"],
	"guy": ["colors", "shapes", "vibe", "style", "look", "whole thing", "details", "background", "feeling", "idea", "composition", "palette"],
	"woman": ["palette", "composition", "brushwork", "chiaroscuro", "negative space", "gesture", "tonality", "form", "texture", "spatial dynamics", "mark-making", "chromatic range"],
}

const OPENERS := {
	"bum": [
		"Alright, alright, let me take a look here.",
		"You want my honest opinion? Fine.",
		"I've seen a lot of things in my time, and this... this is one of them.",
		"Hold on, let me finish this drink first... okay, okay, I'm looking.",
		"You know, I used to know a painter. He owed me forty bucks. Anyway.",
		"Most people walk right past me. But this painting? I stopped.",
		"Listen, I ain't no critic. But I got eyes, and I got opinions.",
		"I've slept under better canvases than this. I've also slept under worse.",
		"Back when I had a gallery membership — yeah, I had one — I saw stuff like this.",
		"People think I don't notice things. I notice everything. Especially this.",
	],
	"general": [
		"At ease. I've completed my assessment.",
		"I've reviewed the intelligence on this piece. Here's my briefing.",
		"This painting has been brought to my attention. I've analyzed it thoroughly.",
		"Stand down, soldier. Let a real strategist evaluate this.",
		"I've seen battlefields with better composition. And worse. Let me elaborate.",
		"After careful reconnaissance of this work, I'm prepared to deliver my report.",
		"Every great campaign begins with observation. I've observed.",
		"This piece crossed my desk, and I don't let anything cross my desk without a full review.",
		"I've commanded thousands of troops. Reviewing a painting should be simple. Should be.",
		"War is hell. Art criticism is worse. Nevertheless, I proceed.",
	],
	"govtpig": [
		"This submission has been received and processed by our department.",
		"For the record, this review is being conducted per Section 4, Article 12 of the Cultural Assessment Protocol.",
		"Let me pull up the relevant guidelines here... yes, I have some notes.",
		"The department has allocated exactly four minutes for this evaluation.",
		"Before I begin, I want to note that all opinions expressed are those of this office.",
		"I've been assigned to review this piece. My supervisor will receive a copy of this assessment.",
		"Per the taxpayer's interest, I am obligated to provide the following critique.",
		"This has been flagged for review. Let's see what we're dealing with.",
		"The committee has reviewed the preliminary filing. Here are our findings.",
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
		"I've spent considerable time with this piece, and I have thoughts.",
		"There's something here that demands a closer reading.",
		"In the current landscape of contemporary practice, this work occupies an interesting position.",
		"I was immediately drawn to this piece upon entering the gallery.",
		"Let me preface this by saying I don't give praise lightly.",
		"Having curated three biennials and written for every major art journal, I know what I'm looking at.",
		"This piece stopped me in my tracks — and that rarely happens anymore.",
		"One encounters a great deal of mediocrity in this field. Let's see where this falls.",
		"I've been writing about emerging artists for twenty years. This caught my attention.",
		"The gallery lighting does this piece no favors, and yet, it persists.",
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
		"'{title}' — an astute choice. The title itself does significant work.",
		"The decision to title this '{title}' reveals a certain self-awareness in the practice.",
		"'{title}.' There's a tension between the title and the work that I find {adj}.",
		"One could argue '{title}' is doing too much. Or not enough. That ambiguity is the point.",
		"The title '{title}' functions almost as a separate work — a textual companion to the visual.",
		"'{title}' — it resists easy categorization, which is precisely what good titling should do.",
		"I find '{title}' to be a {adj} declaration of intent.",
		"'{title}.' Say it aloud. There's a musicality to it that complements the {term}.",
		"'{title}' — the kind of title that lingers in the mind long after you've left the gallery.",
		"They've called it '{title}.' I would have accepted nothing less than exactly this.",
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
		"The {term} demonstrates a {adj} command of the medium.",
		"What strikes me most is how the {term} creates a {adj} dialogue with the viewer.",
		"There's a {adj} interplay in the {term} that recalls the best of the post-minimalists.",
		"The {term} operates on a {adj} register — simultaneously intimate and monumental.",
		"I find the {term} to be the most {adj} element of the composition.",
		"The artist's handling of {term} reveals a {adj} sensibility that cannot be taught.",
		"One sees in the {term} a {adj} negotiation between intention and accident.",
		"The {term} achieves something {adj} — it makes the familiar feel utterly foreign.",
		"There's a {adj} materiality to the {term} that rewards sustained looking.",
		"The {term} here is doing {adj} work, pushing against the boundaries of the format.",
		"The relationship between {term} and {term2} is {adj} — almost confrontational in its intimacy.",
		"Consider how the {term2} amplifies the {term}. The result is nothing short of {adj}.",
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
		"{artist} is an emerging voice worth tracking closely.",
		"I see in {artist}'s work a maturity that belies their position in the field.",
		"{artist} joins a lineage of practitioners who understand that form is content.",
		"Mark my words — {artist} will be in every major collection within a decade.",
		"What {artist} brings to the discourse is rare: genuine conviction.",
		"{artist} operates with an assurance that most artists spend careers trying to cultivate.",
		"I'll be writing about {artist} in my next column. This work demands wider attention.",
		"{artist} has found their voice. The question now is what they'll do with it.",
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
		"The artist writes '{statement}' — a rare moment of genuine artistic transparency.",
		"'{statement}.' This kind of intentionality is what separates craft from practice.",
		"The statement '{statement}' adds a discursive layer that enriches the visual experience.",
		"'{statement}' — there's an intellectual rigor here that the work itself bears out.",
		"Reading '{statement},' one understands that this is an artist in full command of their thesis.",
		"'{statement}.' Few artists can articulate their position this clearly. Fewer still can embody it.",
		"The framing of '{statement}' positions the work within a broader critical conversation.",
		"'{statement}' — a statement that does what the best statements do: it raises more questions.",
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
		"The absence of an artist statement is itself a statement — one I find {adj}.",
		"No statement accompanies this work. The piece must do its own critical labor, and it does.",
		"I note the deliberate refusal to provide contextual framing. A {adj} choice.",
		"Without a statement, the work exists in pure visual space. This is either courageous or naive.",
		"The lack of textual mediation forces the viewer into direct confrontation with the {term}. {adj}.",
		"No statement. The work resists the tyranny of explanation. I find that {adj}.",
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
		"This is a work that demands — and rewards — repeated engagement.",
		"In the final analysis, this is {adj} work from an artist with genuine vision.",
		"I'll be thinking about this piece for some time. That is the highest compliment I offer.",
		"Rarely does one encounter work this {adj} in a space like this. {artist} has my attention.",
		"This is the kind of work that shifts the conversation. I mean that.",
		"I leave this piece feeling something I can't quite name. That is the work doing its job.",
		"Final thoughts: {adj}, {adj2}, and absolutely necessary. Do not miss this.",
		"{artist} has created something that transcends the gallery wall. A significant achievement.",
		"This work enters the discourse at exactly the right moment. {adj} and urgent.",
		"I close my notebook. The critique is finished. The painting, however, is just beginning.",
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
