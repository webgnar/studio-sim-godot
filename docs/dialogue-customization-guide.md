# Dialogue & Critique Customization Guide

All NPC dialogue and critique text is generated locally from template pools with variable substitution. This guide covers every character, every pool, and how to add or edit lines.

---

## How It Works

Templates are plain strings with `{variable}` placeholders that get replaced at runtime. A random template is picked from each pool, a random adjective/term is selected, and the variables are substituted in.

### Available Variables

| Variable | Available In | Description |
|----------|-------------|-------------|
| `{title}` | Critiques + NPC painting lines | The painting's name |
| `{artist}` | Critiques + NPC painting lines | The player's Steam persona name |
| `{statement}` | Critiques only | The artist statement (truncated to ~120 chars) |
| `{adj}` | Critiques + NPC lines | Random adjective from the personality's pool |
| `{adj2}` | Critiques only | Second random adjective (guaranteed different from `{adj}`) |
| `{term}` | Critiques only | Random art term from the personality's pool |
| `{term2}` | Critiques only | Second random art term (guaranteed different from `{term}`) |
| `{item}` | NPC attraction lines only | The shop item/attraction title |

---

## File Locations

| File | What It Contains |
|------|-----------------|
| `scripts/CritiqueGenerator.gd` | TV critique templates (5 critic types) |
| `scripts/VisitorDialogueGenerator.gd` | NPC dialogue templates (16 personality types) |
| `scripts/GalleryVisitor.gd` | NPC idle fallback lines (used when not viewing anything) |

---

## Part 1: TV Critique System

**File:** `scripts/CritiqueGenerator.gd`

Critiques are assembled from multiple sections joined together:
**opener + title reaction + visual comment + [artist comment, ~60% chance] + statement reaction + closer**

### Critic Types

| Type | Avatar | Personality |
|------|--------|-------------|
| `bum` | `sprites/art critics/bum.png` | Street philosopher, rough but sometimes profound |
| `general` | `sprites/art critics/general.png` | Military commander, sees art as warfare |
| `govtpig` | `sprites/art critics/govtpig.png` | Government bureaucrat, obsessed with regulations |
| `guy` | `sprites/art critics/guy.png` | Average joe, relatable, casual takes |
| `woman` | `sprites/art critics/woman.png` | Art world sophisticate, proper criticism vocabulary |

### Template Pools (per critic type)

| Pool | Count | Variables | Purpose |
|------|-------|-----------|---------|
| `OPENERS` | 10 | none | Sets the critic's tone |
| `TITLE_REACTIONS` | 10 | `{title}`, `{adj}`, `{term}` | Responds to the painting's name |
| `VISUAL_COMMENTS` | 12 | `{adj}`, `{adj2}`, `{term}`, `{term2}` | Comments on the art itself |
| `ARTIST_COMMENTS` | 8 | `{artist}` | Comments about the artist (shown ~60% of the time) |
| `STATEMENT_REACTIONS` | 8 | `{statement}`, `{adj}` | Reacts to the artist statement |
| `NO_STATEMENT` | 6 | `{adj}`, `{term}` | Used when no artist statement was provided |
| `CLOSERS` | 10 | `{artist}`, `{adj}`, `{adj2}` | Final verdict |
| `ADJECTIVES` | 14 | — | Pool of personality-flavored adjectives |
| `ART_TERMS` | 12 | — | Pool of personality-flavored art terms |

### Adding a Critique Line

To add a new opener for `bum`, find the `OPENERS` dictionary in `CritiqueGenerator.gd`, locate the `"bum"` array, and add a new string:

```gdscript
"bum": [
    "Alright, alright, let me take a look here.",
    "You want my honest opinion? Fine.",
    # ... existing lines ...
    "Your new line goes here.",
],
```

You can use any variables listed in the pool's column above. Example with variables:
```gdscript
"The {term} is giving me {adj} flashbacks from my time on Fourth Street.",
```

---

## Part 2: NPC Dialogue System

**File:** `scripts/VisitorDialogueGenerator.gd`

NPCs say a single line when the player interacts with them. The line is selected based on what the NPC is looking at:
- **Viewing a painting** -> picks from `PAINTING_LINES`
- **Viewing a shop prop** -> picks from `ATTRACTION_LINES`
- **Not viewing anything** -> picks from fallback lines in `GalleryVisitor.gd`

### Personality Types

#### Random Pool (assigned to generic NPCs)

| Personality | Voice |
|-------------|-------|
| `casual` | Laid-back, everyday person |
| `pretentious` | Art-world jargon, name-drops movements |
| `confused` | Doesn't understand art, bewildered |
| `enthusiastic` | Loves everything, very excited |
| `snob` | Dismissive, nothing is good enough |
| `offended` | Finds everything inappropriate |
| `exasperated` | Tired of everything, world-weary |

#### Skin-Assigned (tied to specific NPC skins)

| Skin | Personality | Voice |
|------|-------------|-------|
| `blackguy_redshirt` | `streetwise` | Urban, real talk, respects authenticity |
| `tanguy_greenshirt` | `spiritual` | Mystic, feels energy, intention-focused |
| `blondeguy_whiteshirt` | `fabulous` | Dramatic, everything is fabulous, fierce |
| `garyskin` | `casual` | (uses casual pool) |
| `humanskin` | `enthusiastic` | (uses enthusiastic pool) |
| `skeletonskin` | `confused` | (uses confused pool) |
| `jollyrich` | `enthusiastic` | (uses enthusiastic pool) |
| `ronald` | `canio` | Theatrical clown, tragedy and comedy |
| `kylie` | `kylie` | Celebrity, social media, trendy |
| `tinfoilguy` | `conspiracist` | Paranoid, everything is connected |
| `maninblack` | `disinfo` | Men in Black, gaslights, "nothing to see here" |
| `gw` | `washington` | George Washington, founding father speak |

### Template Pools (per personality)

| Pool | Count | Variables | Purpose |
|------|-------|-----------|---------|
| `PAINTING_LINES` | 8-10 | `{title}`, `{artist}`, `{adj}` | Reaction to a specific painting |
| `ATTRACTION_LINES` | 6-8 | `{item}`, `{adj}` | Reaction to a shop prop/attraction |
| `ADJECTIVES` | 12 | — | Personality-flavored adjective pool |

### Adding an NPC Dialogue Line

To add a new painting reaction for `conspiracist`, find `PAINTING_LINES` in `VisitorDialogueGenerator.gd`, locate the `"conspiracist"` array, and add:

```gdscript
"conspiracist": [
    # ... existing lines ...
    "'{title}' — the date it appeared here matches the lunar cycle. {adj}.",
],
```

### Idle Fallback Lines

**File:** `scripts/GalleryVisitor.gd`

These are used when the NPC isn't viewing anything specific. They do NOT support variable substitution — they're plain static strings.

| Array | Personality | Count |
|-------|-------------|-------|
| `FALLBACK_LINES` | generic (all others) | 6 |
| `STREETWISE_FALLBACK_LINES` | streetwise | 6 |
| `SPIRITUAL_FALLBACK_LINES` | spiritual | 6 |
| `FABULOUS_FALLBACK_LINES` | fabulous | 6 |
| `CONSPIRACIST_FALLBACK_LINES` | conspiracist | 6 |
| `AGENT_FALLBACK_LINES` | agent | 6 |

Personalities without a dedicated fallback array (snob, offended, exasperated, canio, kylie, disinfo, washington, pretentious, confused, enthusiastic, casual) all use the generic `FALLBACK_LINES`.

To add a fallback line:
```gdscript
const STREETWISE_FALLBACK_LINES = [
    # ... existing lines ...
    "Your new idle line here.",
]
```

---

## Quick Reference: Total Line Counts

### Critiques (per critic, 5 critics total)
- Template lines: 64
- Adjectives: 14
- Art terms: 12
- **Unique combinations per critic: ~millions**

### NPC Dialogue (per personality, 16 personalities)
- Painting templates: 8-10
- Attraction templates: 6-8
- Adjectives: 12
- Idle fallbacks: 6 (shared generic for most)
- **Unique painting lines per personality: ~96-120**
- **Unique attraction lines per personality: ~72-96**

---

## Tips

- **Keep lines short for NPCs** — they appear in a dialogue box, not a scrolling TV. 1-2 sentences max.
- **Critique lines can be longer** — they scroll on a TV screen. Multiple sentences are fine.
- **Adjectives should be versatile** — they get plugged into different templates, so pick words that work in many contexts (e.g. "raw" works in "That's raw" and "raw energy" and "a raw quality").
- **Test with edge cases** — titles can be anything the player types. Make sure your template reads naturally with both short titles ("Untitled") and long titles.
- **No commas in array entries** — GDScript arrays use commas between entries but the trailing comma after the last entry is optional.
