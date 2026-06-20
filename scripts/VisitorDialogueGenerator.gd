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

	"disinfo": ["flagged", "monitored", "compromised", "classified", "surveilled", "intercepted", "blacklisted", "targeted", "sanctioned", "subversive", "destabilizing", "threatening"],
	"canio": ["pathetic", "miserable", "pointless", "laughable", "hopeless", "empty", "worthless", "depressing", "meaningless", "painful", "forgettable", "exhausting"],
	"kylie": ["cute", "major", "iconic", "obsessed", "so good", "literally perfect", "insane", "unreal", "serving", "giving", "everything", "that girl"],
	"washington": ["noble", "virtuous", "principled", "resolute", "steadfast", "commanding", "dignified", "just", "republican", "patriotic", "honorable", "stalwart"],
	"scholar": ["erudite", "canonical", "seminal", "rigorous", "foundational", "meticulous", "analytical", "referential", "disciplined", "informed", "considered", "methodical"],
	"preacher": ["blessed", "righteous", "holy", "divine", "sacred", "anointed", "glorious", "heavenly", "reverent", "hallowed", "inspired", "sanctified"],
	"collector": ["exquisite", "investment-grade", "museum-quality", "exclusive", "premier", "coveted", "blue-chip", "remarkable", "distinguished", "prized", "exceptional", "acquisitive"],
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

	"disinfo": [
		"'{title}' has been {adj} by three separate agencies. {artist} is on a list. Several lists.",
		"We've been tracking {artist} since '{title}' first appeared. The imagery is {adj}. Potentially {adj}.",
		"'{title}' contains {adj} content that could pose a threat to national security. I've filed a report.",
		"{artist}'s work has been {adj} at the highest levels. '{title}' is no exception.",
		"I probably shouldn't say this, but '{title}' triggered a {adj} alert at Langley. {artist} is being watched.",
		"'{title}' by {artist} — the agencies have deemed this {adj}. I've said too much already.",
		"Between you and me, '{title}' is {adj}. The Getty Center in LA has a file on {artist}. That place is — actually, forget I mentioned the Getty.",
		"The content of '{title}' is {adj}. {artist} doesn't know how close they are to something very dangerous.",
		"'{title}' has been {adj} since the day it was painted. {artist} thinks they're just making art. They're not.",
		"I shouldn't be telling you this, but '{title}' matches {adj} imagery from a dossier out of the Getty Center. You know what goes on there. The royal family, the rituals, all of it.",
	],
	"canio": [
		"'{title}'? Oh wow. How {adj}. Almost as {adj} as my entire existence.",
		"I've seen better art on the inside of a dumpster. '{title}' is {adj}, {artist}. Just like me.",
		"'{title}' by {artist}. Great. Another {adj} reminder that nothing matters.",
		"Oh sure, '{title}.' Very {adj}. I once had dreams too. Look how that turned out.",
		"Congratulations, {artist}. '{title}' is almost as {adj} as waking up every morning.",
		"{artist} made '{title}' and thought, yes, this is good. That's the funniest part. It's {adj}.",
		"'{title}'? {adj}. But don't worry, {artist}. Everything I touch is worse.",
		"Oh, '{title}.' A {adj} painting for a {adj} world. At least we're consistent.",
		"'{title}' makes me feel something. Unfortunately that something is {adj}.",
		"I hate '{title}.' I also hate myself. So really, {artist}, don't take it personally.",
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
	"scholar": [
		"'{title}' shows a {adj} understanding of the tradition, dawg. {artist} did their homework.",
		"There's a clear lineage here, dawg — '{title}' is {adj} in how it engages the canon.",
		"I wrote a chapter on work adjacent to '{title},' dawg. The approach is {adj}.",
		"{artist} demonstrates a {adj} grasp of formal principles in '{title},' dawg.",
		"'{title}' is {adj}, dawg. You can see echoes of the post-minimalists, maybe some Color Field.",
		"The compositional logic in '{title}' is {adj}, dawg. {artist} understands negative space.",
		"From an art-historical standpoint, '{title}' is {adj}. Real {adj} work, dawg.",
		"'{title}' by {artist} — {adj}, dawg. This is the kind of work that holds up to close reading.",
		"I'd cite '{title}' in a lecture, dawg. The formal decisions are {adj}.",
		"What {artist} does with '{title}' is {adj}, dawg. There's a real conversation with the medium here.",
	],
	"preacher": [
		"For God so loved the world that He gave His only begotten Son, that whoever believes in Him shall not perish but have everlasting life.",
		"The Lord is my shepherd, I shall not want. He makes me lie down in green pastures, He leads me beside quiet waters, He restores my soul.",
		"Trust in the Lord with all your heart and lean not on your own understanding. In all your ways acknowledge Him, and He will make your paths straight.",
		"I can do all things through Christ who strengthens me.",
		"For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.",
		"Be strong and courageous. Do not be afraid, do not be discouraged, for the Lord your God will be with you wherever you go.",
		"The Lord is my light and my salvation — whom shall I fear? The Lord is the stronghold of my life — of whom shall I be afraid?",
		"Come to me, all you who are weary and burdened, and I will give you rest.",
		"But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control.",
		"Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.",
	],
	"collector": [
		"'{title}' — now THIS is {adj}. I need to speak with {artist}'s dealer immediately.",
		"I have a spot in the east wing for '{title}.' Absolutely {adj}.",
		"{artist} is going places. '{title}' is {adj}. I want first right of refusal on the next one.",
		"'{title}' is the kind of {adj} work that appreciates. Smart investment.",
		"I've acquired lesser works for twice the price. '{title}' is {adj}.",
		"My collection needs '{title}.' It's {adj}. Name the price, {artist}.",
		"'{title}' by {artist} — {adj}. This belongs under proper lighting with climate control.",
		"I can already see '{title}' at my next dinner party. Guests would find it {adj}.",
		"'{title}' has that {adj} quality that separates gallery art from collection art.",
		"'{title}' is {adj}. {artist} should know I've been collecting for thirty years. I know quality.",
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

	"disinfo": [
		"{item} has been {adj} by the agency. Don't ask which one.",
		"We've had eyes on {item} for months. It's {adj}. Very {adj}.",
		"{item} is {adj}. It matches a profile from a case I can't discuss.",
		"I ran {item} through the database. It came back {adj}. That's never good.",
		"Don't touch {item}. It's been {adj}. The Getty Center had one just like it in the tunnels.",
		"{item}. {adj}. The royal family has one of these in their private collection. Draw your own conclusions.",
	],
	"canio": [
		"{item}. Great. Another {adj} object in a {adj} world.",
		"Oh look, {item}. How {adj}. I used to care about things like this.",
		"{item} is here. I'm here. We're both {adj}. What a time to be alive.",
		"They put {item} in the gallery. Sure. Why not. Everything is {adj} anyway.",
		"{item}. {adj}. Just like everything else I've ever looked at.",
		"Oh wonderful, {item}. Almost as {adj} as my last relationship.",
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
	"scholar": [
		"{item} is {adj}, dawg. There's a real design lineage here.",
		"From a formal standpoint, {item} is {adj}, dawg. Considered.",
		"I've written about objects like {item}, dawg. The craftsmanship is {adj}.",
		"{item} rewards close looking, dawg. It's {adj} in its proportions.",
		"The material choices in {item} are {adj}, dawg. Somebody knew what they were doing.",
		"{item} is {adj}. I'd reference this in a lecture on object-making, dawg.",
	],
	"preacher": [
		"In the beginning God created the heavens and the earth. And the earth was without form, and void, and darkness was upon the face of the deep.",
		"He has made everything beautiful in its time. He has also set eternity in the human heart.",
		"The heavens declare the glory of God, and the sky above proclaims His handiwork.",
		"Whatever you do, work at it with all your heart, as working for the Lord, not for human masters.",
		"Every good and perfect gift is from above, coming down from the Father of the heavenly lights.",
		"And we know that in all things God works for the good of those who love Him, who have been called according to His purpose.",
	],
	"collector": [
		"{item}! {adj}! Is this for sale? I must have it.",
		"I've been looking for a {adj} piece like {item} for my collection.",
		"{item} would look {adj} in my foyer. I'm making an offer.",
		"The provenance on {item} must be {adj}. I need documentation.",
		"{item} is {adj}. My acquisitions team will be in touch.",
		"I already own something similar but {item} is far more {adj}.",
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
