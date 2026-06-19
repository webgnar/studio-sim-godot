class_name VisitorDialogueGenerator

## Generates NPC dialogue lines locally from template pools.
## Used for painting reactions and shop-attraction reactions.
## Templates use {title}, {artist}, {adj}, {item} substitution.

const ADJECTIVES := {
	"casual": ["cool", "chill", "nice", "solid", "decent", "sick", "dope", "legit", "smooth", "tight", "fresh", "rad"],
	"pretentious": ["derivative", "sublime", "seminal", "pedestrian", "transcendent", "reductive", "liminal", "paradigmatic", "deconstructed", "post-ironic", "neo-formalist", "auratic"],
	"confused": ["confusing", "weird", "strange", "trippy", "wild", "random", "wonky", "backwards", "inside-out", "upside-down", "abstract", "baffling"],
	"enthusiastic": ["incredible", "amazing", "gorgeous", "brilliant", "stunning", "phenomenal", "glorious", "magnificent", "breathtaking", "mind-blowing", "spectacular", "legendary"],
	"snob": ["pedestrian", "provincial", "amateur", "gauche", "uninspired", "derivative", "trite", "overwrought", "jejune", "banal", "insipid", "middling"],
	"offended": ["offensive", "tasteless", "inappropriate", "outrageous", "disrespectful", "shocking", "disgraceful", "appalling", "unacceptable", "vulgar", "brazen", "reckless"],
	"exasperated": ["exhausting", "predictable", "tiresome", "tedious", "expected", "formulaic", "recycled", "stale", "overworked", "labored", "desperate", "obvious"],
	"streetwise": ["hard", "real", "raw", "fire", "legit", "solid", "heavy", "true", "clutch", "next-level", "on point", "certified"],
	"spiritual": ["transcendent", "awakened", "luminous", "sacred", "resonant", "channeled", "elemental", "alive", "vibrant", "intentional", "blessed", "ancient"],
	"fabulous": ["fabulous", "divine", "iconic", "sickening", "gorgeous", "exquisite", "flawless", "stunning", "immaculate", "legendary", "resplendent", "impeccable"],
	"conspiracist": ["suspicious", "planted", "encoded", "classified", "redacted", "buried", "orchestrated", "deliberate", "staged", "manufactured", "compromised", "weaponized"],
	"agent": ["noted", "catalogued", "flagged", "unremarkable", "standard-issue", "cleared", "declassified", "redacted", "archived", "documented", "benign", "surveilled"],
	"disinfo": ["verified", "debunked", "confirmed", "official", "corrected", "clarified", "approved", "sanctioned", "compliant", "regulated", "authorized", "routine"],
	"canio": ["tragic", "beautiful", "broken", "magnificent", "sorrowful", "divine", "aching", "eternal", "theatrical", "passionate", "devastating", "operatic"],
	"kylie": ["cute", "major", "iconic", "obsessed", "so good", "literally perfect", "insane", "unreal", "serving", "giving", "everything", "that girl"],
	"washington": ["noble", "virtuous", "principled", "resolute", "steadfast", "commanding", "dignified", "just", "republican", "patriotic", "honorable", "stalwart"],
}

const PAINTING_LINES := {
	"casual": [
		"'{title}' is pretty cool. {artist} definitely has a style.",
		"I could see this in someone's apartment. It's {adj}.",
		"Not bad. The whole '{title}' thing works.",
		"Yeah this is {adj}. I dig it.",
		"{artist} really went for it with this one.",
		"My roommate would love '{title}.' It's very {adj}.",
		"I've been looking at this for a minute now. It's {adj}, honestly.",
		"'{title}' — that's a {adj} name for a {adj} painting.",
		"I don't know much about art but '{title}' is doing something for me.",
		"Kinda reminds me of something I saw online. {adj} either way.",
	],
	"pretentious": [
		"'{title}' is clearly a meditation on the post-digital condition. Quite {adj}.",
		"One can see {artist}'s influences here — filtered through a {adj} lens, of course.",
		"The spatial dynamics in '{title}' recall early Richter, wouldn't you say? Very {adj}.",
		"I find '{title}' to be {adj} in its refusal to engage with bourgeois aesthetics.",
		"{artist} is doing something genuinely {adj} here. The discourse needs this.",
		"There's a {adj} quality to '{title}' that most viewers will completely miss.",
		"'{title}' interrogates the relationship between surface and meaning. {adj}.",
		"What {artist} achieves here is nothing short of {adj}. A landmark work.",
		"The gestural vocabulary in '{title}' is {adj}. One is reminded of Twombly.",
		"I've written about less {adj} work than '{title}' for Art Forum.",
	],
	"confused": [
		"Is '{title}' supposed to look like that? I genuinely can't tell.",
		"I've been staring at '{title}' for five minutes and I'm more confused than when I started.",
		"Okay so... '{title}'... what am I looking at exactly?",
		"I think '{title}' might be upside down? No? That's how it's supposed to be?",
		"This is {adj}. And I don't know if that's a compliment.",
		"Did {artist} mean to do that? Because it's very {adj}.",
		"'{title}.' Right. Okay. I'm going to pretend I understand this.",
		"Every time I think I get '{title},' I lose it again. It's so {adj}.",
		"My brain is doing something {adj} trying to process this.",
		"I asked someone what '{title}' means and they just shrugged. That tracks.",
	],
	"enthusiastic": [
		"Oh my god, '{title}'! I LOVE this! It's so {adj}!",
		"{artist} is AMAZING! Everything about '{title}' is just — wow!",
		"This is the most {adj} thing I've seen all week! '{title}' is everything!",
		"I literally gasped when I saw '{title}.' So {adj}!",
		"{artist} really outdid themselves! This is {adj} on another level!",
		"I want to buy '{title}' and look at it every single day! It's {adj}!",
		"'{title}' just made my entire day! {artist} is a genius!",
		"Okay I'm OBSESSED with how {adj} this is! '{title}' forever!",
		"I'm telling everyone I know about '{title}.' This is {adj} perfection!",
		"The energy of '{title}'! The vision! So {adj}! I can't even!",
	],
	"snob": [
		"'{title}'? How {adj}. I suppose {artist} tried.",
		"One would hope {artist} has moved beyond this {adj} phase.",
		"I've seen {adj} work from first-year students. '{title}' reminds me of that.",
		"'{title}' is the kind of {adj} work that gives emerging artists a bad name.",
		"How {adj}. {artist} clearly hasn't studied the masters.",
		"I'd call '{title}' {adj}, but that would be giving it too much credit.",
		"Every gallery has its filler. '{title}' is {adj} filler at best.",
		"I'm sure {artist} has their admirers. People also enjoy fast food. Both are {adj}.",
		"'{title}' aspires to relevance but lands somewhere {adj}.",
		"If '{title}' is the best {artist} can do, perhaps a career change is in order.",
	],
	"offended": [
		"'{title}'? Are you serious right now? This is {adj}!",
		"I can't believe {artist} had the nerve to display something this {adj}.",
		"'{title}' is genuinely {adj}. Who approved this for the gallery?",
		"This is {adj} on so many levels. Does {artist} even care?",
		"I want to speak to whoever hung '{title}' on this wall. {adj}!",
		"'{title}' — what a {adj} title for a {adj} painting.",
		"{artist} should be ashamed. This is the most {adj} thing I've ever seen here.",
		"My children could see '{title}'! This is completely {adj}!",
		"I'm writing a letter about '{title}.' This is beyond {adj}.",
		"How is '{title}' even allowed? It's {adj} and everyone knows it.",
	],
	"exasperated": [
		"'{title}.' Of course. How {adj}. How terribly, predictably {adj}.",
		"Another {adj} painting from another artist who thinks they're breaking new ground.",
		"{artist} calls this '{title}'? I've seen this exact thing a thousand times. So {adj}.",
		"Let me guess — '{title}' is supposed to make me feel something? It's {adj}.",
		"'{title}' is {adj}. I'm shocked. Shocked, I tell you.",
		"I walked in and the first thing I see is '{title}.' {adj}. Naturally.",
		"Every gallery, every time — something {adj} like '{title}.' Without fail.",
		"{artist}, if you're listening — '{title}' is {adj}. Please try harder.",
		"They want me to be impressed by '{title}'? It's {adj} at best.",
		"I'm so tired. '{title}' is {adj}. The art world is {adj}. I need coffee.",
	],
	"streetwise": [
		"'{title}' hits different. {artist} got something real going on.",
		"Yo, '{title}' is {adj}. Whoever made this gets it.",
		"Real talk — '{title}' is {adj}. {artist} ain't playing.",
		"This right here? '{title}'? That's {adj}. Straight up.",
		"{artist} put their whole soul into '{title}.' That's {adj}.",
		"'{title}' got that energy you can't fake. {adj} through and through.",
		"I seen a lot of stuff on the streets. '{title}' is {adj}. Respect.",
		"'{title}' is the kind of {adj} work that makes you stop and think.",
		"Nah, '{title}' goes hard. {artist} knows what they're doing. {adj}.",
		"{artist} came through with '{title}' and it's {adj}. Big ups.",
	],
	"spiritual": [
		"'{title}' carries a {adj} energy. I can feel it from here.",
		"There's something {adj} about '{title}.' {artist} must have been in a deep place.",
		"The universe put '{title}' in front of me today for a reason. It's {adj}.",
		"I keep coming back to '{title}.' It's {adj} — like a prayer made visible.",
		"{artist} channeled something {adj} into this. You can tell.",
		"'{title}' speaks to the part of you that words can't reach. So {adj}.",
		"I want to meditate on '{title}.' The energy is {adj}.",
		"You can feel the intention behind '{title}.' It's {adj} and real.",
		"'{title}' is like looking into something {adj} and ancient.",
		"There's a {adj} light in '{title}.' {artist} has a gift.",
	],
	"fabulous": [
		"'{title}' is absolutely {adj}! I'm living for this!",
		"{artist}, darling — '{title}' is {adj}! You've outdone yourself!",
		"The drama! The color! '{title}' is giving {adj} and I am HERE for it!",
		"Oh honey, '{title}' is {adj}. Everything about it. Chef's kiss.",
		"{artist} said let me make '{title}' and make it {adj}. And they DID.",
		"I need '{title}' framed in gold and hung in my penthouse. {adj}!",
		"'{title}' is serving {adj} realness and I cannot look away!",
		"Darling, '{title}' is what happens when taste meets talent. {adj}!",
		"'{title}' walked so other paintings could run. {adj}! Iconic!",
		"If '{title}' were a person I would take them to dinner. {adj} and gorgeous.",
	],
	"conspiracist": [
		"'{title}' — you see the hidden symbols, right? Very {adj}.",
		"I've been researching {artist}. The connections to '{title}' go deep. {adj}.",
		"They don't want you looking too closely at '{title}.' That's how you know it's {adj}.",
		"'{title}' contains {adj} imagery that ties directly to — well, I can't say here.",
		"Notice how '{title}' was placed at exactly this height? That's {adj}. Intentional.",
		"{artist} knows something. '{title}' is {adj} evidence if you know where to look.",
		"I've got a whole board about '{title}' at home. The patterns are {adj}.",
		"'{title}' is {adj}. The real question is who funded it and why.",
		"Follow the money behind '{title}.' {artist} is either in on it or a pawn. {adj}.",
		"The timing of '{title}' appearing here? {adj}. Nothing is coincidence.",
	],
	"agent": [
		"'{title}.' Noted. Nothing unusual about this piece. Moving on.",
		"I've catalogued '{title}' by {artist}. Standard work. {adj}.",
		"This is a routine painting. '{title}' raises no concerns. Perfectly {adj}.",
		"I've been assigned to — I mean, I'm enjoying '{title}.' It's very {adj}.",
		"'{title}' has been cleared for public display. The content is {adj}.",
		"Our records show {artist} has no prior — I mean, nice painting. '{title}.' {adj}.",
		"I'm just a regular art lover. '{title}' is {adj}. End of observation.",
		"'{title}' by {artist}. Filed under: {adj}. No further action required.",
		"Nothing to see here. '{title}' is {adj}. Please continue your gallery visit.",
		"My assessment — I mean, my opinion — is that '{title}' is {adj}.",
	],
	"disinfo": [
		"'{title}' is exactly what it appears to be. There's nothing {adj} about it.",
		"I can confirm '{title}' by {artist} is {adj}. Nothing more to discuss.",
		"Any rumors about '{title}' being {adj} are completely unfounded.",
		"'{title}' has been {adj}. I mean verified. As normal art. By {artist}.",
		"Please disregard any alternative interpretations of '{title}.' It is simply {adj}.",
		"Our sources confirm '{title}' is {adj}. No further questions, please.",
		"{artist}'s '{title}' is {adj}. We have corrected any records suggesting otherwise.",
		"I assure you '{title}' is {adj}. The fact-checkers agree. All of them.",
		"There is no deeper meaning to '{title}.' It's {adj}. That is the official position.",
		"'{title}' by {artist} has been rated {adj} by independent reviewers. Case closed.",
	],
	"canio": [
		"Ah, '{title}'! It makes the heart weep with its {adj} beauty!",
		"Behind the painted smile, '{title}' hides something {adj}. I understand.",
		"Laugh, clown, laugh! But '{title}' — '{title}' makes even the clown pause.",
		"'{title}' by {artist} — a {adj} masterpiece! The tragedy! The comedy! ALL OF IT!",
		"I have performed before thousands! But '{title}' — this is the real show. {adj}!",
		"The paint cries out! '{title}' is {adj}! Like my tears! Which are also paint!",
		"Bravo, {artist}! '{title}' is as {adj} as my third act! Standing ovation!",
		"'{title}' understands suffering. It is {adj}. The audience weeps!",
	],
	"kylie": [
		"Okay '{title}' is literally so {adj} I can't even right now.",
		"Wait wait wait — '{title}' by {artist}? This is {adj}! Screenshotting this!",
		"'{title}' is giving main character energy. So {adj}. Love that for {artist}.",
		"I would literally die for '{title}.' It's {adj}. Adding to my vision board.",
		"'{title}' is so {adj} it's making me rethink my entire aesthetic.",
		"Okay but '{title}' would look SO good on my feed. {adj} vibes only.",
		"{artist} really said let me make '{title}' and be {adj} about it. Slay.",
		"I'm manifesting '{title}' energy. It's just so {adj}.",
	],
	"washington": [
		"'{title}' — a work of {adj} virtue. The Republic would be proud.",
		"In my day we had no such '{title},' yet I find it most {adj}.",
		"{artist} demonstrates the {adj} spirit of a true patriot in '{title}.'",
		"I cannot tell a lie: '{title}' is {adj}. A fine contribution to the nation.",
		"Were '{title}' a soldier, it would be most {adj}. I would commission it.",
		"The {adj} character of '{title}' reminds me of Valley Forge. We endured.",
		"'{title}' by {artist} is {adj}. Liberty itself smiles upon this work.",
		"A {adj} painting, '{title}.' The Founding Fathers would have displayed it proudly.",
	],
}

const ATTRACTION_LINES := {
	"casual": [
		"Oh nice, {item}. That's pretty {adj}.",
		"{item}? {adj}. I could see myself getting one.",
		"I was just looking at {item}. It's {adj}, right?",
		"My buddy has something like {item}. His is less {adj} though.",
		"{item} is {adj}. Simple as that.",
		"Okay but {item} is actually {adj}. Not even kidding.",
		"Didn't expect to see {item} here. {adj}.",
		"I keep walking past {item} and every time I think it's more {adj}.",
	],
	"pretentious": [
		"{item} exists in a {adj} dialogue with the surrounding space.",
		"The placement of {item} here is deeply {adj}. Intentional, clearly.",
		"One doesn't simply look at {item} — one must experience its {adj} presence.",
		"{item} challenges our preconceptions about the gallery as object. Quite {adj}.",
		"The curatorial decision to include {item} is {adj}. A statement in itself.",
		"I've seen {item} at Art Basel. Here it takes on a more {adj} dimension.",
		"{item} functions as both artifact and critique. {adj}.",
		"The {adj} juxtaposition of {item} against this wall — masterful.",
	],
	"confused": [
		"Why is {item} here? Is it art? I'm so confused.",
		"So {item} is... {adj}? I think? I have no idea what's going on.",
		"I've been staring at {item} trying to figure out if it's part of the exhibit.",
		"Is {item} for sale or is it decoration? This is {adj}.",
		"Someone please explain {item} to me. It's very {adj}.",
		"I thought {item} was a mistake at first. Now I'm not sure. {adj}.",
		"Every time I look at {item} I have more questions. So {adj}.",
		"Wait, {item} is on purpose? Okay. {adj}. Sure.",
	],
	"enthusiastic": [
		"Oh my GOD — {item}! I LOVE it! It's so {adj}!",
		"{item} is the best thing in this gallery! So {adj}!",
		"I need {item} in my life! It's {adj}! I'm obsessed!",
		"Can I take {item} home?! It's too {adj} to leave here!",
		"Look at {item}! LOOK AT IT! It's {adj}! I'm dying!",
		"'{item}' just became my favorite thing ever! {adj}!",
		"I didn't know I needed {item} until right now! So {adj}!",
		"If {item} were a person I'd give it a hug! {adj}!",
	],
	"snob": [
		"{item}? In a gallery? How {adj}.",
		"I suppose {item} appeals to a certain {adj} sensibility.",
		"They've placed {item} here as if it were {adj}. It isn't.",
		"I've seen {item} in airport gift shops. {adj} then too.",
		"{item} is the kind of {adj} object that clutters lesser galleries.",
		"How {adj} to include {item}. How terribly, utterly {adj}.",
		"One hopes {item} is temporary. It's rather {adj}.",
		"{item}. {adj}. Next.",
	],
	"offended": [
		"{item}?! Here?! This is {adj}!",
		"Who thought putting {item} in a gallery was acceptable? {adj}!",
		"I am personally offended by {item}. It's {adj} and wrong.",
		"{item} has no place here. It's {adj} and I won't stand for it.",
		"My taxes are paying for {item}?! This is {adj}!",
		"I came here for art, not {item}! This is {adj}!",
		"{item} is the most {adj} thing in this building!",
		"I'm filing a complaint about {item}. {adj}!",
	],
	"exasperated": [
		"{item}. Of course. Because that's what galleries need. {adj}.",
		"Oh good, {item}. I was worried this place had standards. {adj}.",
		"They went with {item}. How {adj}. How brave.",
		"Every gallery has a {item}. It's always {adj}. I'm always tired.",
		"{item} is here because someone thought it was {adj}. It's not.",
		"I see {item} and I just... sigh. {adj}.",
		"Another day, another {item}. {adj} as expected.",
		"{item}. {adj}. I need to sit down.",
	],
	"streetwise": [
		"{item} is {adj}. Respect.",
		"Yo, {item}? That's {adj}. I see you.",
		"{item} got that {adj} energy. For real.",
		"Real ones know {item} is {adj}.",
		"Can't front, {item} is kinda {adj}.",
		"{item} speaks for itself. {adj}.",
		"They got {item} in here? {adj}. I'm with it.",
		"Nah, {item} is {adj}. That's facts.",
	],
	"spiritual": [
		"{item} carries a {adj} frequency. I can feel it.",
		"There's something {adj} about {item}. The energy is intentional.",
		"{item} is here for a reason. The universe is {adj} like that.",
		"I want to sit near {item} and just breathe. It's {adj}.",
		"The aura around {item} is {adj}. Do you feel it?",
		"{item} resonates on a {adj} level. It's speaking to me.",
		"I see {adj} light coming from {item}. Metaphorically. Mostly.",
		"{item} brings a {adj} balance to this space.",
	],
	"fabulous": [
		"{item}? {adj}! Obviously!",
		"Oh darling, {item} is {adj}! I need one immediately!",
		"{item} is serving {adj} realness and I am living!",
		"The placement of {item}? {adj}! The gallery has taste!",
		"{item} is giving {adj} energy and I'm obsessed, darling!",
		"If {item} were a runway look it would be {adj}! Fierce!",
		"I would redecorate my entire apartment around {item}. {adj}!",
		"{item} is {adj}! Period! End of discussion!",
	],
	"conspiracist": [
		"They put {item} here to distract you. Very {adj}.",
		"{item} is {adj}. I've seen the documents. Don't ask which ones.",
		"Notice {item}? Now ask yourself why. It's {adj}. Think about it.",
		"I have photos of {item} at three other locations. All {adj}. All connected.",
		"{item} is a {adj} breadcrumb. Follow the trail.",
		"They want you to think {item} is just an object. It's {adj}. Wake up.",
		"The placement of {item} aligns with the lay lines. {adj}.",
		"{item}. {adj}. I've said too much already.",
	],
	"agent": [
		"{item}. Noted. {adj}. Carry on.",
		"I've completed my sweep of {item}. It's {adj}. No threats detected.",
		"{item} has been catalogued. Appears {adj}. Totally normal gallery object.",
		"My interest in {item} is purely aesthetic. It's {adj}. That is all.",
		"I was not examining {item} for concealed devices. It's simply {adj}.",
		"Disregard my interest in {item}. Standard {adj} gallery piece.",
		"{item} is {adj}. I've reported — I mean, I've appreciated it.",
		"Status report on {item}: {adj}. Moving to next position.",
	],
	"disinfo": [
		"{item} is a normal object. It is {adj}. There is nothing else to say.",
		"Reports that {item} is anything other than {adj} are misinformation.",
		"{item} has been independently verified as {adj}. Please move along.",
		"I can confirm {item} is {adj}. All alternative claims have been corrected.",
		"There is no story behind {item}. It is {adj}. Fact-checked and confirmed.",
		"{item}. {adj}. This has been your official briefing.",
	],
	"canio": [
		"Ah, {item}! It reminds me of the props from my greatest performance! {adj}!",
		"{item} — even objects carry drama! How {adj}! How theatrical!",
		"I weep at {item}! The beauty! The tragedy! {adj}!",
		"In my circus, {item} would be center stage! {adj}!",
		"{item} understands what it means to perform! {adj}! Bellissimo!",
		"The audience gasps at {item}! {adj}! The show must go on!",
	],
	"kylie": [
		"Okay but {item} is literally {adj}. Adding to cart.",
		"{item}! I need this in my apartment! So {adj}!",
		"{item} is giving {adj} and I'm SO here for it.",
		"Wait is {item} for sale? It's so {adj} I need it.",
		"I'm posting {item} immediately. My followers need to see this. {adj}!",
		"Obsessed with {item}. It's {adj}. Period.",
	],
	"washington": [
		"{item} — a {adj} addition to any republic's collection.",
		"In my time, we had no {item}. Yet I find it {adj}.",
		"Were {item} a cannon, it would be most {adj}. Formidable.",
		"I declare {item} to be {adj}. Let it be entered into the record.",
		"The {adj} nature of {item} would serve the Continental Army well.",
		"{item} is {adj}. The nation shall remember it.",
	],
}


static func generate_painting_line(personality: String, title: String, artist: String) -> String:
	var p := _resolve_personality(personality)
	var adj := _pick_adj(p)

	if title.strip_edges() == "":
		title = "this"
	if artist.strip_edges() == "":
		artist = "the artist"

	var vars := {"title": title, "artist": artist, "adj": adj}
	var line: String = PAINTING_LINES[p].pick_random()
	return _fill(line, vars)


static func generate_attraction_line(personality: String, item_title: String) -> String:
	var p := _resolve_personality(personality)
	var adj := _pick_adj(p)

	if item_title.strip_edges() == "":
		item_title = "this thing"

	var vars := {"item": item_title, "adj": adj}
	var line: String = ATTRACTION_LINES[p].pick_random()
	return _fill(line, vars)


static func _resolve_personality(personality: String) -> String:
	if PAINTING_LINES.has(personality):
		return personality
	return "casual"


static func _pick_adj(personality: String) -> String:
	var pool: Array = ADJECTIVES.get(personality, ADJECTIVES["casual"])
	return pool[randi() % pool.size()]


static func _fill(template: String, vars: Dictionary) -> String:
	var result := template
	for key in vars:
		result = result.replace("{" + key + "}", vars[key])
	return result
