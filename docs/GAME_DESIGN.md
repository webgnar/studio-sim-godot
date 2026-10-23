# Studio Sim: Game Design Document

Status: living document, first draft written 2026-10-23 from the code on `main` and the existing docs.
Anything marked **[?]** was inferred from code and needs a decision from zack. All open questions are collected at the end.

## 1. Concept

Studio Sim is a first-person art studio game for Steam, built in Godot 4. You are an artist in a studio modeled on the real Carroll art studio. You make paintings by placing stickers on a canvas, take them off the easel, ship them through a freight elevator down to your gallery, and earn money that you spend on tools, studio objects, visitors and attractions. Over time the studio grows from an empty room into a small art world: a gallery full of visitors with opinions, a hall of fame of the community's best work, a dance party, an arcade, and an assistant who paints while you are away.

The tone is deadpan and a little conspiratorial: free energy devices in the shop, a fortune teller, a government agent critic, a UFO outside the window. The art is the player's own, and the game connects it to the outside world through an online gallery, a sticker marketplace between players, and Steam.

### Pillars

1. **Your paintings are real.** Every shipped painting is exported as a PNG and a 3D GLB, uploaded to the online gallery, and can come back into the game through the hall of fame.
2. **The studio is a real place.** The space follows the real Carroll studio: smooth white drywall, white-painted wooden pillars, white cinder block only on the north-east corner wall, cool fluorescents, a frosted skylight and a moving sun. It starts empty, like the photos.
3. **Low pressure, always progressing.** No fail states besides missions; money always trickles in, and the studio fills up with the things you chose.
4. **Weird and funny around the edges.** Critics, visitors, shop descriptions and secrets reward poking around.

### Audience and platform

PC on Steam (GodotSteam, Steam Input, achievements, leaderboards), keyboard and mouse or gamepad, with gyro aiming for painting. Localized through `translations/` and `LocaleManager`. **[?]** Target price, release date and whether other platforms are planned are not recorded anywhere.

## 2. Core loop

```
 paint on the canvas  ->  press red Detach  ->  carry the painting
        ^                                            |
        |                       hang it with the nail gun, or put it in the elevator
        |                                            |
  buy tools, objects,  <-  money  <-  ship it (export + upload + critics + sale)
  visitors, upgrades                                 |
                                         painting appears in the gallery
```

1. **Paint.** Walk up to the canvas on the easel. Aim at it and place stickers from your library: cycle stickers, rotate, scale, place, undo. The canvas can be switched between square and 5x3 landscape (`CanvasFormatToggle`). Once bought, the pencil draws freehand on the canvas.
2. **Detach.** Press the red button (`PaintingConvertButton`). The canvas turns into a carryable physical painting and a fresh blank canvas appears. Detaching during a mission aborts the mission.
3. **Name and sign.** Paintings carry a title, an artist statement (`PaintingPromptDialog`) and a signature drawn on the canvas.
4. **Display or ship.**
   - Hang it on a wall with the nail gun, keep it, or throw it in the gallery trash slot where it burns.
   - Put it in the elevator, close the gate and press export. The elevator descends, the painting is exported (PNG + GLB), uploaded to the online gallery, critiqued on the CritiqueTV, and sold.
5. **Get paid** and spend it in the shop.

### Missions (commissions)

A second loop sits beside free painting. The Commissions tab in the pause menu lists missions, each with a reference image. The player recreates it on the canvas and presses Submit. The painting is scored by colour distribution (70%) and pixel match (30%); 70% passes. Missions record grade and best score, and passing pays a commission. A painting that passed a commission sells for only 25% when shipped, since the commission already paid for it.

There are 17 missions today (`resources/missions/`), all at the default reward of $75. **[?]** Are missions a core pillar, a tutorial, or a side mode? Their reward is far below a free shipped painting, see Economy.

## 3. Spaces

| Space | What happens there | How you get in |
| --- | --- | --- |
| **Studio** | The main room. Canvas and easel, red Detach button, the elevator, light switches for the fluorescents, the save computer, the mirror (change skin), boombox, sticker-folder button, intro notes. Bought props appear here. | Start |
| **Studio assistant room** | The assistant's sticker wall slowly fills with stickers; a red button transfers the wall to a finished canvas in the next room, where a convert button turns it into a carryable painting. You can talk to the assistant by voice. | Buying the studio assistant |
| **Elevator** | Ships paintings down to the gallery. The elevator CritiqueTV shows a critic's review of what you shipped. | Start |
| **Gallery** | Shipped paintings arrive here. Visitors walk between paintings and attractions and comment on them. Has the Instagram feed screen, the fortune teller, the DJ booth, the coin pusher and the trash slot in the floor. | Down the elevator **[?]** how does the player get down: stairs were sealed in a recent change |
| **Expanded gallery** | More wall space past a fog door. | The coin pusher's first scored ball reveals the fog door |
| **Hall of fame** | Community paintings hearted on the website, hung along rails and shuffled each load. Lit by baked ceiling spots under a frosted skylight. | Make a basket with the basketball to unlock the door |
| **Dance party** | The gallery transformed: house lights drop, disco lights, mirror ball and projectors (including kaleidoscope and gobo patterns built from your stickers), every visitor dances. | Buy the DJ, talk to them |
| **Lou Gnar arcade** | A stand-up cabinet running Lou Gnar, the endless skate game, with a Steam leaderboard. | Buy the Lou Gnar cabinet |
| **Outside** | The UFO "Tomlander" flies outside and fires mantis projectiles; each hit pixelates the screen more (retro shader). Shooting it with nails moves it along. | Visible through windows **[?]** is this a mini-boss with an ending or an easter egg |

## 4. Progression and unlocks

Progression today is almost entirely bought with money. There is no level gating in the shop (`ShopManager.is_locked` always returns false).

### Shop catalog (prices in code today)

| Item | Price | What it unlocks |
| --- | --- | --- |
| Trash can | $75 | Prop |
| Cardboard box | $100 | "Something useful might be inside" **[?]** |
| Monstera / Fern / Madagascar palm | $100 / $125 / $175 | Plants |
| Fan, Styrofoam cube, Phone, Psywheel | $150 each | Fan needs power (cords and outlets); phone shows "a mysterious Brazilian website"; psywheel spins when you are onto something |
| Skateboard | $175 | Rideable |
| Mirror | $220 | Skins (built-in and custom PNG skins) |
| Nail gun | $300 | Hang paintings; break windows; shoot the UFO |
| Water filter (Berkey), Cyclone | $300 each | Prop; cyclone arcade game |
| SEG, GEET | $420 each | Free energy devices (all three unlock "Brave New World") |
| Water fuel cell | $555 | Third free energy device |
| Lou Gnar cabinet | $500 | Arcade minigame |
| RF receiver | $500 | Live internet radio on the boombox |
| Gallery visitor | $500, repeatable | One more NPC visitor; each raises shipped painting value by 15% |
| Pencil | $1,000 | Freehand drawing on the canvas |
| Work lamp | $1,500 | Carryable light |
| Studio assistant | $2,000 | Passive income and the assistant room (bought with an in-world button, not the shop) |
| Custom sticker modder | $2,500 | A hidden blue button that opens your custom sticker folder |
| DJ | $7,000 | Dance party |
| Coin pusher | $12,000 | Coin pusher minigame, which also pays out money and opens the expanded gallery |
| Boombox, basketball | free | Always present |

### Non-shop unlocks

- **Hall of fame door:** score a basket.
- **Expanded gallery fog door:** first ball scored in the coin pusher.
- **Custom stickers:** PNGs dropped into `user://custom_stickers/` after buying the modder; bought marketplace stickers land in `bought_stickers/`.
- **Achievements:** exports (1, 5, 10, 20, 50), all missions, speedrun a mission, 500 canvas stickers, 100 world stickers, burn a painting, die, lock yourself in the elevator, break a window with the nail gun, meet all 14 visitors, open the hall of fame, enter the expanded gallery, max pixelation, Lou Gnar 1,000 points, 10 Instagram likes on a painting, make the assistant swear, and one per key purchase.

### Reputation

`ReputationManager` has levels (thresholds 0 to 550 points) and a +20% price multiplier per level, but nothing awards reputation and nothing reads the multiplier. **[?]** Revive reputation as the second progression track (gating shop items, mission tiers, visitor count), or remove it.

## 5. Economy

All money is in `EconomyManager` (integer dollars). Sources and sinks today:

| Source | Amount |
| --- | --- |
| Ship a painting | $275 x (1 + 0.15 per gallery visitor); 25% of that if it was a passed commission |
| Pass a mission | reward x 1.5 (all missions are $75, so $112) |
| Studio assistant | every 5 minutes: $100 + a bonus that grows by $5 per visitor each cycle, capped at $150 extra |
| Sticker marketplace | other players buying stickers you listed; credits are claimed from the server on launch and every 5 minutes |
| Coin pusher | payouts from the machine |

| Sink | |
| --- | --- |
| Shop | see the catalog above |
| Sticker marketplace | buying other players' stickers |

Notes:

- A painting is worth the same no matter what is on it. Only visitor count changes the price. `StyleTracker` can penalize repeating yourself but is switched off.
- Shipping is effectively unlimited, so the fastest income is detaching near-empty canvases and shipping them. **[?]** Should value depend on the painting (sticker count, variety, coverage, critic reaction, a hall of fame heart), and should there be a cost or cooldown to shipping?
- Reaching the DJ ($7,000) takes about 25 shipped paintings with no visitors, or roughly 12 hours of assistant income alone.

## 6. Minigames and toys

- **Lou Gnar:** one-button endless skater (ollie, tricks in the air, grind rails, stomp UFOs, collect flowers), six speed tiers, Steam leaderboard with local fallback.
- **Coin pusher:** physical coin pusher with bonus balls every 50 points and a spinning wheel.
- **Cyclone:** a light-chase reflex game.
- **Basketball:** a hoop; the first basket opens the hall of fame.
- **Skateboard:** ride around the studio.
- **Nail gun shooting:** break windows, shoot the UFO.
- **Fortune teller:** astrology readings from your birth date, time and place (set in Options).
- **World tagging:** place stickers on 3D surfaces around the world (100 for an achievement).
- **Talk to the studio assistant:** push-to-talk voice chat, answered by an AI voice.
- **Gallery visitors:** 14 named NPCs with distinct personalities who comment on paintings and attractions; dialogue is templated, or AI-written when "Generative AI" is on in Options.
- **Elevator critics:** Bum, General, Government Agent, Guy, Woman. Each critique is assembled from template pools using the painting's title, artist and statement.

## 7. Online features

All go through the `studio-sim-gallery` backend (Vercel) and work without a key on the player's side.

- **Online gallery:** every shipped painting is uploaded with the player's Steam name, title, statement and optional Instagram and Bluesky handles.
- **Hall of fame:** paintings hearted on the website are synced into the build (`hall_of_fame/README.md`). Build time only, no runtime fetch.
- **Instagram screen:** the gallery's last posts, with likes.
- **Sticker marketplace:** list your custom stickers for a price; other players buy them and you get the money next time you play.
- **Voice and AI text:** speech to text, AI replies and text to speech for the assistant; AI dialogue for visitors and the fortune teller when enabled.
- **Radio:** live internet stations through the RF receiver.

Dev rule: running the real game claims pending sticker-sale credits from the server, so disable the marketplace autoload for any test run.

## 8. Controls

| Action | Keyboard and mouse | Gamepad |
| --- | --- | --- |
| Move | WASD | Left stick |
| Look | Mouse | Right stick (gyro also steers the painting cursor) |
| Jump | Space | A |
| Crouch | C | B |
| Run | Shift | Left stick click |
| Interact, pick up, put down | E | X |
| Place sticker, use tool | Left click | Right trigger |
| Undo, secondary | Right click | Left trigger |
| Previous / next sticker | 1 / 2 or mouse wheel | LB / RB |
| Rotate sticker | R / T | D-pad left / right |
| Scale sticker | Z / X | D-pad up / down |
| Pause menu | ` (backtick) | Start |
| Back | Esc, B | B |

The pause menu has Commissions, Inventory (your paintings), Shop, Sticker Marketplace and Options tabs.

## 9. Art and lighting direction

These are standing rules from zack.

- **Keep the studio empty, like the photos.** No props unless asked for. Never commit mockups unless asked.
- **Match the real Carroll studio.** Smooth white drywall walls. White cinder block only on the north-east corner wall. White-painted wooden pillars. Keep the existing ceiling and pillars as they are.
- **Fluorescents are intentionally cool.** Only remove blue that is unintentional. Fluorescents follow their wall switches; the room goes dark when they are off.
- **Keep the sun moving.** The day and night cycle is live (`DayNightCycle.gd`): daylight fill fades at night, nights are lit by the lamps. A full day runs a few minutes, with slow midday and fast nights.
- **Baked lighting.** Lamp-only lightmap bake, daylight as a live fill, reflection probes, baked hall of fame ceiling spots. Re-bake steps: `docs/BAKED_LIGHTING.md`.
- **The skylight is never clear.** The player must not see through it from above. Frosted is fine.
- **Textures** come from texturecan.com.
- **UI and FX:** retro, low-fi touches (pixelation shader, CRT screens using `tv.tres`, pipe screensaver).

## 10. Planned features

### Idle autoplay bot (major, long term)

A screensaver-style bot that plays the game while the player is idle (in progress, PR #7, see `docs/IDLE_AUTOPLAY.md` on that branch).

- Turned on in Options > Game with an idle delay. Any input returns control on that frame.
- Plays like a real player: full pathfinding on foot, wanders and looks around, no fades or teleports.
- Paints like a player: the sticker ghost visibly moves around the canvas before each placement, then it presses Detach.
- Its behaviors grow with what the player has unlocked: transfer and convert the assistant's work, hang paintings with the nail gun, play the boombox, play minigames.
- **Long-term focus: tuning how the bot composes paintings** so they look good. That means sticker choice (palette, theme, variety), placement (composition, balance, layering, negative space), scale and rotation, and when to stop. The composition rules it learns are also candidate inputs for painting value (section 5) and could feed hints to the player.

**[?]** Should the bot's paintings earn the same as the player's, and should it ship them? Should the bot ever spend money?

### Other directions found in code or notes

- Freeform painting with a repetition penalty (`StyleTracker`, "Phase 4").
- More assistant behaviors beyond the payout timer (the assistant's own sticker wall already exists).
- Hall of fame grows with every website sync; Lou Gnar leaderboard shows only the top 10 today.

## 11. Open questions for zack

1. What is the release target: price, date, platforms?
2. Missions: core pillar, tutorial, or side mode? They pay $112 against $275 for any shipped painting.
3. Should a painting's sale price depend on what is on it (and on critics, visitors or hall of fame hearts)? Today an almost empty canvas earns the same as a finished one.
4. Should shipping have a cost or limit?
5. Reputation: bring it back as a second progression track, or delete it?
6. Should any shop items be gated by progress instead of only money?
7. How does the player get to the gallery now that the stair doorway is sealed: elevator only?
8. Is the UFO outside a boss with an outcome, or an easter egg?
9. What is in the cardboard box?
10. Is there an ending, or is the game endless by design?
11. Autoplay bot: does it earn, ship and spend like the player?
12. Is the studio assistant meant to grow (more assistants, better paintings, upgrades)?
