# Incremental Game Implementation Plan
## Studio Sim → Art Production Game

**Last Updated**: 2026-01-08

---

## Core Philosophy

Art production as a capital process. FPS painting remains the highest marginal value activity. Start simple, add complexity only when earned.

**Key Loop**: Paint missions → Earn money → Gain reputation → Buy upgrades → Passive income + strategic choices

---

## Phase 0: Basic Economy ✅ COMPLETE

**Status**: Implemented and working

**What we built**:
- `scripts/economy/EconomyManager.gd` - Money tracking
- `scripts/economy/ReputationManager.gd` - Reputation levels and price multipliers
- `scripts/economy/StyleTracker.gd` - Repetition detection (currently DISABLED because missions enforce variety)
- `scripts/MoneyReputationHUD.gd` - Top-right money/reputation display
- Modified `MissionManager.gd` - Economy integration on mission completion
- Modified `WorldStateManager.gd` - Save/load economic state

**Current Formula**:
```
Payout = $100 (base) × 1.5 (commission bonus) × reputation_multiplier × repetition_penalty
Reputation Multiplier = 1.0 + (reputation_level × 0.2)
Reputation Gain = (match_percentage / 100) × 2.0 points
```

**Reputation Levels**:
- Thresholds: [0, 10, 30, 60, 100, 150, 210, 280, 360, 450, 550]
- Level 0 = 1.0x price, Level 1 = 1.2x, Level 5 = 2.0x, Level 10 = 3.0x

**What works**:
- Complete mission → earn $150 (at level 0)
- Money counter shows in top-right with green flash animation
- Reputation increases and shows level progression
- Money and reputation persist across saves

**Note**: Repetition penalty system exists but is disabled (returns 1.0 always) because mission variety already prevents repetition. May be useful for Phase 4 freeform painting.

---

## Phase 1: Studio Assistant ✅ IMPLEMENTED

**Status**: Code complete, needs scene setup in Godot editor

### Design: Passive Income Generator

The Studio Assistant is an NPC that paints and sells work independently while you focus on high-value commissions.

### Implementation Plan

**Purchase**:
- Cost: $1,200
- Unlocked at: Reputation Level 1 (10 points)
- One-time purchase

**Mechanics**:
- Generates passive income every 5 minutes: $30-50
- Produces low-value work (not tracked as "your" paintings)
- Trade-off: Your paintings earn -10% reputation while assistant is active (you're "less focused")

**Visual Representation**:
1. **Purchase UI**: Button on computer/phone in studio
2. **Physical Room**: Small separate room with NPC at easel
3. **NPC Model**: Simple character placing stickers on canvas
4. **Animation Cycle**:
   - Canvas starts blank
   - Over 5 minutes, stickers randomly appear
   - Canvas completes → money notification
   - Canvas clears, cycle repeats
5. **Status Bar**: Shows time until next payout, total earnings from assistant

**Code Structure**:
```
scripts/economy/AutomationManager.gd (NEW - autoload)
- var studio_assistant_active: bool = false
- var assistant_timer: float = 0.0
- const ASSISTANT_INTERVAL = 300.0  # 5 minutes
- const ASSISTANT_PAYOUT = 40  # Base $40
- func purchase_studio_assistant() -> bool
- func _process(delta): tick timer, emit payout signal

scripts/economy/StudioAssistantNPC.gd (NEW - attached to NPC scene)
- Listens to AutomationManager signals
- Animates painting progress visually
- Shows canvas filling with stickers over time

scenes/upgrades/StudioAssistantRoom.tscn (NEW)
- Small room attached to main studio
- NPC at easel with canvas
- Status panel on wall showing earnings
```

**Balance Formula**:
```
With Assistant Active:
- Manual painting reputation: (match_percentage / 100) × 2.0 × 0.9 (-10% penalty)
- Assistant payout: $40 every 5 minutes = $480/hour passive
- Manual painting: ~$150/mission, ~5 min = $1,800/hour active

Result: Assistant adds 27% more $/hour but reduces reputation growth
Strategic choice: Grind reputation early, buy assistant later for income boost
```

**UI Requirements**:
1. Purchase button (computer/phone UI)
2. Room door/entrance (interactable to view progress)
3. Status panel in assistant room showing:
   - Time until next painting: 3:45
   - Paintings completed: 12
   - Total earned: $480
4. HUD indicator showing assistant is active (small icon)

**Integration with Existing Systems**:
- AutomationManager registered as autoload in project.godot
- Hooks into EconomyManager.add_money()
- Modifies ReputationManager.add_reputation() calls to apply 0.9x multiplier
- Saves assistant_active state in WorldStateManager
- Ticks in _process(), only when game is actively running (no offline progress)

### What Was Actually Implemented

**New Files Created**:
1. `scripts/economy/AutomationManager.gd` - Core automation system
   - Tracks studio_assistant_active state
   - Timer-based passive income ($40 every 5 minutes)
   - Reputation penalty multiplier (0.9x when active)
   - Save/load support
   - Signals: assistant_purchased, assistant_payout, assistant_progress

2. `scripts/components/StudioAssistantPurchaseButton.gd` - Purchase interaction
   - Extends InteractionComponent
   - Checks money ($1,200) and reputation (Level 1) requirements
   - Updates interaction text based on affordability
   - Disables after purchase

3. `scripts/components/StudioAssistantStatusPanel.gd` - Progress display
   - Shows countdown timer to next painting
   - ASCII progress bar
   - Total session earnings tracker
   - Updates every frame for live countdown

**Modified Files**:
- `project.godot` - Registered AutomationManager as autoload
- `scripts/economy/ReputationManager.gd` - Applies 0.9x penalty when assistant active
- `scripts/WorldStateManager.gd` - Saves/loads automation state

**Scene Setup Needed** (do this in Godot editor):
1. Add a purchase button object with StudioAssistantPurchaseButton component (e.g., computer or button)
2. Create status panel in assistant room:
   - Add Label3D node
   - Attach StudioAssistantStatusPanel script
   - Assign label reference in inspector
3. Test that the key system unlocks the assistant room door
4. (Optional) Add NPC model and canvas for visual feedback

**Testing Checklist**:
- [ ] Reach reputation level 1 (10 points)
- [ ] Earn $1,200
- [ ] Purchase assistant via button
- [ ] See passive income every 5 minutes
- [ ] Verify reputation gain reduced to 90%
- [ ] Check status panel shows countdown
- [ ] Save/load preserves assistant state and timer

---

## Phase 2: Print Machine (FUTURE)

**Not designed yet. Wait until Phase 1 feels good.**

Ideas:
- Cost: $1,000
- After completing a painting, generate 2 extra prints at $30 each
- Increases market saturation (if repetition penalty re-enabled)
- Visual: Physical printing machine in studio

---

## Phase 3: Marketing Campaign (FUTURE)

**Not designed yet. Wait until Phase 2 feels good.**

Ideas:
- Cost: $750 (consumable, can buy multiple times)
- Next 5 paintings earn +30% price
- Visual: Poster appears on wall showing "5 paintings remaining"

---

## Phase 4: Freeform Painting & Sales (FUTURE)

**Not designed yet. Far future feature.**

Ideas:
- Paint without active mission
- Sell paintings from gallery/computer
- Lower reputation gain than commissions
- This is where repetition penalty could be re-enabled

---

## Phase 5: Prestige System (FUTURE)

**Not designed yet. Far future feature.**

Reset mechanic at reputation 10,000+:
- Resets: Money, reputation, automation
- Keeps: Lifetime earnings, prestige points
- Permanent bonuses: +10% reputation gain, +5% base prices per prestige

---

## Technical Reference

### Autoload Registration Order
```
WorldStateManager="*res://scripts/WorldStateManager.gd"
EconomyManager="*res://scripts/economy/EconomyManager.gd"
ReputationManager="*res://scripts/economy/ReputationManager.gd"
StyleTracker="*res://scripts/economy/StyleTracker.gd"
AutomationManager="*res://scripts/economy/AutomationManager.gd"  # Phase 1 ✅
```

### Key Files Modified in Phase 0
- `scripts/MissionManager.gd` (lines 151-186, 309-340)
- `scripts/WorldStateManager.gd` (lines 92, 260-261, 563-608)
- `scenes/world.tscn` (line 493 - added MoneyReputationHUD)
- `project.godot` (autoload registration)

### Signal Flow
```
MissionManager.complete_mission()
  → EconomyManager.add_money()
    → money_changed signal
      → MoneyReputationHUD._on_money_changed()
  → ReputationManager.add_reputation()
    → reputation_changed signal
    → level_up signal (if threshold crossed)
      → MoneyReputationHUD animations
```

---

## Design Principles

1. **FPS painting is highest marginal value** - Automation never replaces manual work
2. **Session-based only** - No idle/offline progress
3. **Reputation compounds slowly** - Early fast, late slow
4. **Automation has trade-offs** - Strategic choices, not convenience
5. **Start minimal** - Only add features if previous phase feels good

---

## Current State

**Phase 0** ✅ COMPLETE:
- ✅ Paint missions and earn money
- ✅ Reputation levels affect payout (1.2x-3.0x)
- ✅ HUD shows money and reputation
- ✅ Economy persists across saves

**Phase 1** ✅ CODE COMPLETE:
- ✅ AutomationManager system implemented
- ✅ Purchase button component created
- ✅ Status panel display created
- ✅ Reputation penalty integration (0.9x)
- ✅ Save/load support
- ⏳ Scene setup in Godot editor (user needs to place objects)

**Next Actions for User**:
1. In Godot editor, add purchase button:
   - Create a Node3D (e.g., computer, button, or sign)
   - Add child node: StudioAssistantPurchaseButton (extends InteractionComponent)
   - Place near front of studio or on desk
2. In assistant room, add status panel:
   - Create Node3D
   - Add Label3D child
   - Attach StudioAssistantStatusPanel script
   - Assign label reference in inspector
3. Test the full loop:
   - Earn reputation level 1 + $1,200
   - Purchase assistant
   - Wait 5 minutes, see $40 passive income
   - Complete a mission, verify reputation gain is 10% lower

**Questions to Answer in Testing**:
- Does $40 every 5 minutes feel rewarding?
- Is the -10% reputation penalty noticeable?
- Does the assistant room feel worthwhile to visit?
- Should payout amount or interval be adjusted?

---

## Future Considerations

- **Three upgrades total** (assistant, print machine, marketing) before considering more complex systems
- **Trend system** only if upgrades feel shallow
- **Market simulation** only if game needs more depth
- **Prestige** only if players reach reputation cap and want more progression

**Current philosophy**: Ship small, test feel, iterate based on what's fun.
