class_name FortuneTellerGenerator

## Generates horoscope readings from the player's birth date.
## Derives zodiac sign, element, ruling planet, and personality traits,
## then assembles a multi-part reading from template pools.

const SIGNS := {
	"aries":       {"name": "Aries",       "element": "Fire",  "planet": "Mars",    "symbol": "the Ram",
		"traits": ["courage", "determination", "passion", "confidence", "boldness", "initiative"],
		"challenges": ["impatience", "impulsiveness", "restlessness", "temper", "recklessness", "stubbornness"]},
	"taurus":      {"name": "Taurus",      "element": "Earth", "planet": "Venus",   "symbol": "the Bull",
		"traits": ["reliability", "patience", "devotion", "stability", "persistence", "sensuality"],
		"challenges": ["stubbornness", "possessiveness", "resistance to change", "indulgence", "inflexibility", "materialism"]},
	"gemini":      {"name": "Gemini",      "element": "Air",   "planet": "Mercury", "symbol": "the Twins",
		"traits": ["adaptability", "curiosity", "wit", "eloquence", "versatility", "cleverness"],
		"challenges": ["inconsistency", "indecision", "nervousness", "restlessness", "superficiality", "scattered focus"]},
	"cancer":      {"name": "Cancer",      "element": "Water", "planet": "the Moon","symbol": "the Crab",
		"traits": ["intuition", "loyalty", "empathy", "tenacity", "imagination", "nurturing"],
		"challenges": ["moodiness", "sensitivity", "clinginess", "pessimism", "insecurity", "over-protectiveness"]},
	"leo":         {"name": "Leo",         "element": "Fire",  "planet": "the Sun", "symbol": "the Lion",
		"traits": ["generosity", "charisma", "creativity", "warmth", "leadership", "confidence"],
		"challenges": ["arrogance", "stubbornness", "vanity", "jealousy", "self-centeredness", "inflexibility"]},
	"virgo":       {"name": "Virgo",       "element": "Earth", "planet": "Mercury", "symbol": "the Maiden",
		"traits": ["diligence", "analytical skill", "modesty", "precision", "reliability", "practicality"],
		"challenges": ["overthinking", "criticism", "perfectionism", "worry", "shyness", "self-doubt"]},
	"libra":       {"name": "Libra",       "element": "Air",   "planet": "Venus",   "symbol": "the Scales",
		"traits": ["diplomacy", "grace", "fairness", "charm", "idealism", "harmony"],
		"challenges": ["indecision", "avoidance", "people-pleasing", "superficiality", "self-pity", "detachment"]},
	"scorpio":     {"name": "Scorpio",     "element": "Water", "planet": "Pluto",   "symbol": "the Scorpion",
		"traits": ["intensity", "passion", "resourcefulness", "bravery", "loyalty", "perception"],
		"challenges": ["jealousy", "secrecy", "obsession", "possessiveness", "manipulation", "distrust"]},
	"sagittarius": {"name": "Sagittarius", "element": "Fire",  "planet": "Jupiter", "symbol": "the Archer",
		"traits": ["optimism", "adventurousness", "honesty", "humor", "generosity", "independence"],
		"challenges": ["recklessness", "bluntness", "impatience", "overconfidence", "restlessness", "carelessness"]},
	"capricorn":   {"name": "Capricorn",   "element": "Earth", "planet": "Saturn",  "symbol": "the Sea-Goat",
		"traits": ["discipline", "ambition", "responsibility", "patience", "wisdom", "self-control"],
		"challenges": ["rigidity", "pessimism", "coldness", "workaholism", "stubbornness", "detachment"]},
	"aquarius":    {"name": "Aquarius",    "element": "Air",   "planet": "Uranus",  "symbol": "the Water-Bearer",
		"traits": ["originality", "independence", "humanitarianism", "vision", "intellect", "inventiveness"],
		"challenges": ["aloofness", "rebelliousness", "unpredictability", "emotional detachment", "stubbornness", "extremism"]},
	"pisces":      {"name": "Pisces",      "element": "Water", "planet": "Neptune", "symbol": "the Fish",
		"traits": ["compassion", "intuition", "artistic talent", "gentleness", "wisdom", "empathy"],
		"challenges": ["escapism", "over-sensitivity", "indecision", "naivety", "self-pity", "fearfulness"]},
}

# month, day pairs: sign starts on or after this date
const SIGN_DATES := [
	[1, 20, "aquarius"], [2, 19, "pisces"], [3, 21, "aries"], [4, 20, "taurus"],
	[5, 21, "gemini"], [6, 21, "cancer"], [7, 23, "leo"], [8, 23, "virgo"],
	[9, 23, "libra"], [10, 23, "scorpio"], [11, 22, "sagittarius"], [12, 22, "capricorn"],
]

const OPENINGS := [
	"Ah, {sign}... {symbol}. The stars have been expecting you.",
	"I see you, child of {planet}. The cosmos speaks through your sign, {sign}.",
	"Welcome, {sign}. The {element} within you burns bright today.",
	"The celestial wheel turns, and {sign} stands at the threshold.",
	"I feel the pull of {planet} upon your spirit, dear {sign}.",
	"The heavens have aligned for {symbol}. Listen closely.",
	"{sign}... yes. {planet} whispers your name across the void.",
	"Born under {symbol}, shaped by {element}. I see your path.",
	"The {element} signs are restless tonight, and you, {sign}, are no exception.",
	"Come closer, {sign}. The stars do not wait for the hesitant.",
	"Ah, a child of {element}. {sign}, guided by {planet}. How fitting that you've come.",
	"The constellations shift, and {symbol} emerges from the cosmic fog.",
]

const SIGN_READINGS := {
	"aries": [
		"Your {trait} has carried you far, but today the stars urge patience. Not all battles are won by charging forward.",
		"The fire in your heart burns bright, {sign}. Your {trait} will be tested soon — stand firm and it will become your greatest weapon.",
		"A new beginning calls to you. Your {trait} makes you a natural pioneer — trust it, but guard against your {challenge}.",
		"Mars stirs restlessly in your chart. Channel your {trait} toward creation, not conflict. The universe rewards builders.",
		"Your {challenge} may surface today. Recognize it, name it, and let your {trait} guide you past it.",
		"Something you started long ago is about to bear fruit. Your {trait} planted the seed — now have the patience to harvest.",
		"The Ram does not follow — it leads. Your {trait} is needed now more than ever. Step forward.",
		"A crossroads approaches. Your {challenge} will tempt you to rush the decision. Breathe. Your {trait} knows the way.",
	],
	"taurus": [
		"The earth beneath your feet is steady, but change approaches. Your {trait} will anchor you through the storm.",
		"Venus smiles upon you today. Your {trait} draws good things toward you — open your hands to receive.",
		"Beware your {challenge}, dear Bull. The stars suggest that flexibility will serve you better than force right now.",
		"Something beautiful is taking root in your life. Your {trait} nurtures it well. Trust the slow growth.",
		"The material world calls to you, but true wealth lies in your {trait}. Invest in what cannot be bought.",
		"Your {challenge} has been building quietly. Release it before it hardens into something unmovable.",
		"A gift is coming — not the kind you expect. Your {trait} will help you recognize its true value.",
		"The Bull knows when to stand and when to graze. Today calls for your {trait}, not your horns.",
	],
	"gemini": [
		"Your mind races with possibility, but {planet} asks you to choose. Your {trait} can serve one purpose well or many poorly.",
		"The Twins are in conversation today. Let your {trait} bridge the gap between what you think and what you feel.",
		"Words are your currency, Gemini. Spend your {trait} wisely — the right phrase today will echo for months.",
		"Your {challenge} clouds your vision. Step back and let your {trait} cut through the noise.",
		"Two paths diverge before you. Your {challenge} says take both. The stars say your {trait} will reveal the true one.",
		"A conversation is coming that will change your perspective. Your {trait} has prepared you — listen more than you speak.",
		"The wind shifts direction, and so do you. Your {trait} is not fickleness — it is evolution. Trust the turn.",
		"Mercury brings a message. Your {trait} will help you decode it, but beware reading too much between the lines.",
	],
	"cancer": [
		"The tides of emotion run deep today. Your {trait} is your lighthouse — let it guide you to safe harbor.",
		"Home is more than walls, dear Crab. Your {trait} creates sanctuary wherever you go.",
		"The Moon waxes in your favor. Your {trait} is amplified — use it to mend what has been broken.",
		"Your shell protects you, but today the stars ask you to open it. Your {trait} is stronger than your fear.",
		"Someone close to you needs what only your {trait} can offer. The cosmos chose you for this moment.",
		"Your {challenge} whispers old worries. Answer it with your {trait} — you have survived worse tides than this.",
		"A wave of creativity washes over you. Your {trait} channels it into something lasting and true.",
		"The Crab walks sideways, but always reaches its destination. Your {trait} guides you by an unseen path.",
	],
	"leo": [
		"The spotlight finds you today, Leo. Your {trait} deserves the stage — step into it without apology.",
		"The Sun pours its warmth through you. Your {trait} inspires others more than you know.",
		"Beware your {challenge} today. Even the Lion must share the savanna. Your {trait} shines brighter in collaboration.",
		"A creative fire ignites within you. Your {trait} is the spark — fan it into something magnificent.",
		"Someone challenges your authority. Respond with your {trait}, not your pride. The crown sits lighter when earned.",
		"Your {challenge} tempts you toward the dramatic. Choose your {trait} instead — quiet strength roars the loudest.",
		"The Lion's heart is vast. Your {trait} has room for more than you've been allowing. Expand.",
		"Royalty is not title — it is conduct. Your {trait} is your true crown. Wear it well today.",
	],
	"virgo": [
		"The details call to you, Virgo. Your {trait} untangles what others cannot see.",
		"Mercury sharpens your already keen mind. Your {trait} will solve a puzzle that has lingered too long.",
		"Your {challenge} may slow you today. Remember: progress, not perfection, is what the stars demand.",
		"A system in your life needs redesigning. Your {trait} is the architect — trust your instinct to improve.",
		"Someone underestimates you. Your {trait} will prove them wrong, quietly and without fanfare.",
		"Your {challenge} builds pressure inside. Release it through your {trait} — channel the energy into service.",
		"The Maiden sees what others overlook. Your {trait} is a gift today. Use it to heal, not to judge.",
		"Order emerges from chaos when you apply your {trait}. Today the cosmos needs your careful hand.",
	],
	"libra": [
		"The Scales seek balance, and today they find it through your {trait}. Trust the equilibrium you create.",
		"Venus graces your interactions today. Your {trait} smooths rough edges — people need your presence.",
		"A decision you've been avoiding demands attention. Your {challenge} wants delay, but your {trait} knows the answer.",
		"Beauty surrounds you today, Libra. Your {trait} helps you see it where others see only the ordinary.",
		"A relationship needs recalibration. Your {trait} is the instrument — use it with care and honesty.",
		"Your {challenge} whispers that all sides are equal. They are not. Your {trait} will reveal the truth.",
		"The Scales tip toward joy today. Your {trait} has earned this — receive it gracefully.",
		"Harmony is not the absence of conflict. Your {trait} transforms tension into music. Play on.",
	],
	"scorpio": [
		"The depths call to you, Scorpio. Your {trait} navigates waters that terrify lesser souls.",
		"Pluto stirs transformation in your chart. Your {trait} is the catalyst — do not fear the change.",
		"A secret reveals itself today. Your {trait} has always known it was there. Now act on what you see.",
		"Your {challenge} coils tightly around an old wound. Release it. Your {trait} is strong enough to heal.",
		"The Scorpion strikes only when necessary. Today calls for your {trait}, not your sting.",
		"Something dies so something better can be born. Your {trait} guides this metamorphosis. Trust the process.",
		"Your {challenge} tests your trust. Meet it with your {trait} — vulnerability is the deepest form of power.",
		"The still waters of your soul run deeper than anyone knows. Your {trait} is your anchor in those depths.",
	],
	"sagittarius": [
		"The Archer's arrow flies true today. Your {trait} sets the trajectory — aim high and release.",
		"Jupiter expands your horizons. Your {trait} propels you toward something bigger than you imagined.",
		"Your {challenge} tempts you to leap before you look. Temper it with your {trait} and the landing will be soft.",
		"A journey begins — of the mind, the heart, or the road. Your {trait} is your compass.",
		"The truth you've been seeking is closer than you think. Your {trait} will recognize it when it arrives.",
		"Your {challenge} scatters your energy across too many targets. Focus your {trait} on the one that matters most.",
		"The Archer knows that every arrow spent is a lesson learned. Your {trait} turns misses into wisdom.",
		"Freedom calls to you, Sagittarius. Your {trait} opens doors that others see as walls.",
	],
	"capricorn": [
		"The mountain does not come to you, Capricorn. But your {trait} carries you steadily to the summit.",
		"Saturn rewards your effort today. Your {trait} has not gone unnoticed by the cosmos.",
		"Your {challenge} weighs heavy. Set it down for a moment. Your {trait} is not diminished by rest.",
		"A structure you've been building is nearly complete. Your {trait} laid every stone with purpose.",
		"The Sea-Goat navigates both earth and water. Your {trait} adapts to terrain others cannot cross.",
		"Your {challenge} tells you the work is never done. The stars disagree. Enjoy what your {trait} has built.",
		"An old responsibility lifts from your shoulders. Your {trait} earned this freedom — use it wisely.",
		"The summit is lonely, but the view belongs to you. Your {trait} brought you here. Look around.",
	],
	"aquarius": [
		"The Water-Bearer pours forth ideas today. Your {trait} nourishes minds that are parched for new thinking.",
		"Uranus disrupts the expected. Your {trait} thrives in the chaos — where others see disorder, you see possibility.",
		"Your {challenge} isolates you from those who need you. Bridge the gap with your {trait}.",
		"A vision crystallizes in your mind. Your {trait} gives it form — share it before it fades.",
		"The collective calls for your {trait}. You were not born to follow the crowd, but to redirect it.",
		"Your {challenge} builds walls between heart and mind. Let your {trait} tear them down.",
		"The future arrives early for Aquarius. Your {trait} has been preparing you for this moment all along.",
		"Convention crumbles before your gaze. Your {trait} rebuilds it into something the world actually needs.",
	],
	"pisces": [
		"The cosmic ocean swells around you, Pisces. Your {trait} lets you swim where others would drown.",
		"Neptune veils the world in mystery today. Your {trait} sees through the illusion to what is real.",
		"Your {challenge} pulls you beneath the surface. Rise with your {trait} — you are stronger than the current.",
		"A dream you had recently carries a message. Your {trait} is the key to unlocking its meaning.",
		"The Fish swims in two directions at once. Your {trait} unifies the split — follow the deeper current.",
		"Your {challenge} blurs the line between self and other. Ground yourself in your {trait} before giving more.",
		"Art, music, beauty — the cosmos pours inspiration into your open hands. Your {trait} shapes it into form.",
		"The boundary between worlds is thin for you today. Your {trait} lets you walk between them safely.",
	],
}

const ELEMENT_ADVICE := {
	"Fire": [
		"The {element} within you craves action. Channel it — create something today, even if it's imperfect.",
		"Your {element} nature demands expression. Speak your truth, but let your warmth outshine your heat.",
		"The flames are high today. Direct your {element} energy toward what matters, not what merely excites.",
		"{element} purifies. Let go of something that no longer serves you — burn it clean and move forward.",
		"Your inner {element} seeks fuel. Feed it with purpose, not distraction.",
		"Other {element} signs feel your intensity today. Together you could ignite something extraordinary.",
		"Even the brightest flame needs tending. Nurture your {element} — rest is not weakness, it is fuel.",
		"The spark in you is contagious. Your {element} energy lights the way for someone who has lost theirs.",
	],
	"Earth": [
		"Ground yourself today, child of {element}. Your roots run deeper than you know.",
		"The {element} is patient. What you plant today will grow in its own time — trust the soil.",
		"Your {element} nature craves stability, but growth requires disruption. Bend before you break.",
		"Something tangible needs your attention. Your {element} hands were made for building. Build.",
		"The {element} beneath you holds ancient memory. Listen to it — your body knows what your mind forgets.",
		"Practical magic is your gift. Your {element} nature transforms the mundane into the meaningful.",
		"Other {element} signs anchor you today. Seek their steady presence if the winds blow strong.",
		"The harvest comes to those who tend the field. Your {element} patience is about to be rewarded.",
	],
	"Air": [
		"Your {element} mind moves quickly today. Catch the best idea before it drifts away.",
		"Communication is your superpower, child of {element}. Use your words to build bridges, not walls.",
		"The {element} carries whispers from far away. Your intellect decodes what others hear only as noise.",
		"Your {element} nature resists being pinned down. But landing, even briefly, can reveal treasures.",
		"A brilliant insight arrives on the wind. Your {element} mind is ready — write it down before it scatters.",
		"Connection feeds your soul. Your {element} nature thrives in the exchange of ideas. Seek conversation.",
		"Other {element} signs amplify your thinking today. Two minds of air create a cyclone of possibility.",
		"The {element} clears what is stale. Let your thoughts blow away what you've outgrown.",
	],
	"Water": [
		"The {element} runs deep in you today. Your emotions are not weakness — they are wisdom in liquid form.",
		"Trust your currents, child of {element}. Your intuition flows toward truth even when logic cannot.",
		"The {element} within you mirrors the world. Be careful whose emotions you carry — not all of them are yours.",
		"A {element} cleansing is coming. Release what you've been holding beneath the surface. Let it flow.",
		"Your {element} nature absorbs everything. Today, choose carefully what you let in.",
		"The tide turns in your favor. Your {element} patience has brought you to this shore. Rest here awhile.",
		"Other {element} signs understand your depths. Seek their company — you do not need to explain yourself.",
		"Your tears and your laughter carry equal power. Your {element} nature knows: feeling everything is your greatest strength.",
	],
}

const CLOSINGS := [
	"The stars have spoken. Go forth, {sign}, and carry this knowledge gently.",
	"The reading is complete. May {planet} guide your steps, {sign}.",
	"The cosmos watches over you, child of {element}. Return when the stars shift again.",
	"Remember: the stars incline, they do not compel. Your choices are your own, {sign}.",
	"The veil closes. What has been revealed today will unfold in its own time.",
	"Go with the blessing of {planet}, dear {sign}. The universe does not forget its children.",
	"The celestial wheel turns on. You have your reading. Now you must decide what to do with it.",
	"Until next time, {sign}. The stars will keep your secrets.",
	"The cosmic winds carry you forward. Trust your {trait}, and {symbol} will light the way.",
	"The reading fades like morning mist, but its truth lingers. Walk well, {sign}.",
]


static func generate(birth_date: String) -> String:
	var sign_key := _get_zodiac_sign(birth_date)
	if sign_key == "":
		return "The stars cannot read your birth date. The celestial record is unclear."

	var sign_data: Dictionary = SIGNS[sign_key]
	var trait_pool: Array = sign_data["traits"].duplicate()
	var challenge_pool: Array = sign_data["challenges"].duplicate()
	var sign_trait: String = trait_pool[randi() % trait_pool.size()]
	var challenge: String = challenge_pool[randi() % challenge_pool.size()]

	var vars := {
		"sign": sign_data["name"],
		"element": sign_data["element"],
		"planet": sign_data["planet"],
		"symbol": sign_data["symbol"],
		"trait": sign_trait,
		"challenge": challenge,
	}

	var parts: PackedStringArray = []
	parts.append(_fill(OPENINGS[randi() % OPENINGS.size()], vars))
	parts.append(_fill(SIGN_READINGS[sign_key][randi() % SIGN_READINGS[sign_key].size()], vars))

	var element_pool: Array = ELEMENT_ADVICE[sign_data["element"]]
	parts.append(_fill(element_pool[randi() % element_pool.size()], vars))

	parts.append(_fill(CLOSINGS[randi() % CLOSINGS.size()], vars))
	return " ".join(parts)


static func _get_zodiac_sign(birth_date: String) -> String:
	var parts := birth_date.split("-")
	if parts.size() < 3:
		parts = birth_date.split("/")
	if parts.size() < 3:
		return ""

	var month := int(parts[0]) if parts[0].length() <= 2 else int(parts[1])
	var day := int(parts[1]) if parts[0].length() <= 2 else int(parts[2])

	# Handle YYYY-MM-DD format
	if parts[0].length() == 4:
		month = int(parts[1])
		day = int(parts[2])

	if month < 1 or month > 12 or day < 1 or day > 31:
		return ""

	# Walk backwards through SIGN_DATES to find the matching sign
	for i in range(SIGN_DATES.size() - 1, -1, -1):
		var entry: Array = SIGN_DATES[i]
		if month > entry[0] or (month == entry[0] and day >= entry[1]):
			return entry[2]

	# If nothing matched (e.g., Jan 1-19), it's Capricorn
	return "capricorn"


static func _fill(template: String, vars: Dictionary) -> String:
	var result := template
	for key in vars:
		result = result.replace("{" + key + "}", vars[key])
	return result
