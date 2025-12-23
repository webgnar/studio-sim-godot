# Steam Integration Setup Guide

## Current Status
✅ Code integrated and ready
✅ SteamManager singleton created
✅ All achievement hooks in place
✅ Game runs without errors (Steam features disabled until addon installed)

⏳ **Next Step**: Install GodotSteam client addon

---

## Step 1: Download GodotSteam Client Addon

### Option A: Direct Download (Recommended)
1. Go to: https://codeberg.org/godotsteam/godotsteam/releases
2. Find the latest release (4.11 or newer)
3. Download the file named: `godotsteam-gdextension-[version].zip`
   - **Make sure it's GDExtension** (not "modules" or "server")
   - Should be around 10-15 MB

### Option B: GitHub Mirror
1. Go to: https://github.com/GodotSteam/GodotSteam/releases
2. Same files as Codeberg

### Option C: Godot Asset Library
1. In Godot Editor, click **AssetLib** tab (top center)
2. Search for "GodotSteam"
3. Download and install

---

## Step 2: Install the Addon

1. **Extract the downloaded .zip file**
   - You should get a folder called `godotsteam/`

2. **Copy to your project**
   - Copy the entire `godotsteam/` folder into your project's `addons/` directory
   - Final structure should be:
     ```
     /Users/zackgg/Godot/studio-sim-godot/addons/
     ├── godotsteam/           ← NEW (client addon)
     ├── godotsteam_server/    ← EXISTING (server addon)
     ├── GodotSteam.app/       ← EXISTING (Godot executable)
     └── mission_tools/        ← EXISTING (your tools)
     ```

3. **Restart Godot**
   - Close the Godot editor completely
   - Reopen your project

---

## Step 3: Verify Installation

1. **Run the game** (F5 or play button)

2. **Check the console output**
   - You should see one of these messages:

   ✅ **SUCCESS:**
   ```
   SteamManager: Running in editor, Steam features limited
   SteamManager: Steam initialized successfully!
   User: [Your Steam Name] (ID: [Your Steam ID])
   Online: true
   ```

   ⚠️ **PARTIAL SUCCESS** (Steam client not running):
   ```
   SteamManager: Failed to initialize Steam: [error code]
   ```
   - This is OK! Just means Steam isn't running. Launch Steam and try again.

   ❌ **NOT INSTALLED:**
   ```
   SteamManager: GodotSteam addon not installed! Steam features disabled.
   ```
   - Addon wasn't installed correctly. Go back to Step 2.

---

## Step 4: Test Achievements (Local Testing)

With the addon installed, you can test achievements locally:

1. **Make sure Steam is running** on your computer

2. **Run the game** (F5)

3. **Complete a mission**
   - You should see console output:
     ```
     SteamManager: ✓ Achievement unlocked: ACH_FIRST_MISSION
     SteamManager: Data successfully stored to Steam
     ```

4. **Check Steam overlay**
   - Press Shift+Tab in-game (may not work in editor)
   - Or check your Steam profile → Achievements
   - You'll see "New Achievement!" (generic, since it's using test App ID 480)

---

## Step 5: Configure Steamworks Backend

Once you have a Steam App ID, you need to configure achievements in Steamworks:

### 5.1 Update App ID

1. Open: `/Users/zackgg/Godot/studio-sim-godot/steam_appid.txt`
2. Replace `480` with your actual Steam App ID
3. Save the file

### 5.2 Add Achievements to Steamworks

Log in to Steamworks Partner: https://partner.steamgames.com/

Navigate to: **Your App → Stats & Achievements → Achievements**

Add each of these 14 achievements:

| API Name | Display Name | Description |
|----------|-------------|-------------|
| `ACH_FIRST_MISSION` | First Canvas | Complete your first mission |
| `ACH_FIRST_PERFECT` | Flawless Artist | Get a perfect 100% score on any mission |
| `ACH_MISSIONS_5` | Rising Star | Complete 5 missions |
| `ACH_MISSIONS_10` | Professional | Complete 10 missions |
| `ACH_MISSIONS_ALL` | Master Artist | Complete all 14 missions |
| `ACH_GRADE_S` | S-Rank Artist | Get an S rank (95%+) on any mission |
| `ACH_GRADE_S_5` | Elite Painter | Get S rank on 5 missions |
| `ACH_PERFECTIONIST` | Perfectionist | Get S rank on all missions |
| `ACH_HARD_MISSION` | Challenge Accepted | Complete a hard mission (difficulty 8+) |
| `ACH_HARD_PERFECT` | Master of Difficulty | Get S rank on a hard mission (difficulty 8+) |
| `ACH_PLAY_1HOUR` | Dedicated Artist | Play for 1 hour |
| `ACH_PLAY_10HOURS` | Studio Regular | Play for 10 hours |
| `ACH_SPEEDRUNNER` | Speed Painter | Complete any mission in under 60 seconds |
| `ACH_PAINTER` | Prolific Creator | Place 1000 total stickers |

**Important:** The "API Name" column MUST match exactly!

### 5.3 Add Statistics to Steamworks

Navigate to: **Your App → Stats & Achievements → Stats**

Add each of these 8 statistics:

| API Name | Display Name | Type | Default |
|----------|-------------|------|---------|
| `STAT_MISSIONS_COMPLETED` | Missions Completed | Int | 0 |
| `STAT_MISSIONS_PERFECT` | Perfect Missions | Int | 0 |
| `STAT_MISSIONS_S_RANK` | S-Rank Missions | Int | 0 |
| `STAT_MISSIONS_FAILED` | Failed Attempts | Int | 0 |
| `STAT_STICKERS_PLACED` | Total Stickers Placed | Int | 0 |
| `STAT_PLAYTIME_SECONDS` | Playtime (seconds) | Int | 0 |
| `STAT_BEST_SCORE` | Best Mission Score | Int | 0 |
| `STAT_TOTAL_SCORE` | Total Score | Int | 0 |

### 5.4 Publish Changes

**CRITICAL:** Click **Publish** in Steamworks!
- Achievements and stats won't work until published
- You can publish to "default" branch for testing

---

## Step 6: Create Achievement Icons

Create 64x64px icons for each achievement:

1. **Design icons** (Photoshop, GIMP, etc.)
   - Size: 64x64 pixels
   - Format: PNG or JPG
   - Transparent backgrounds recommended

2. **Upload to Steamworks**
   - Go to each achievement in Steamworks
   - Upload the corresponding icon
   - Publish changes

---

## Step 7: Disable Debug Mode (Production)

Before shipping:

1. Open: `/Users/zackgg/Godot/studio-sim-godot/scripts/SteamManager.gd`
2. Find line 27:
   ```gdscript
   var debug_mode: bool = true  # Set to false for production
   ```
3. Change to:
   ```gdscript
   var debug_mode: bool = false  # Set to false for production
   ```
4. This disables console spam in production builds

---

## Implemented Achievements Breakdown

### Mission Progression (6 achievements)
- ✅ First mission completed
- ✅ 5 missions completed
- ✅ 10 missions completed
- ✅ All 14 missions completed
- ✅ First perfect (100%) score
- ✅ First S rank (95%+)

### Advanced Progression (3 achievements)
- ✅ 5 S ranks
- ✅ All missions S rank
- ✅ Complete hard mission (difficulty 8+)

### Skill Challenges (2 achievements)
- ✅ S rank on hard mission
- ✅ Speedrunner (< 60 seconds)

### Playtime (2 achievements)
- ✅ Play for 1 hour
- ✅ Play for 10 hours

### Fun/Hidden (1 achievement)
- ✅ Place 1000 total stickers

---

## File Reference

All Steam-related files:

```
/Users/zackgg/Godot/studio-sim-godot/
├── steam_appid.txt                      (App ID config)
├── scripts/
│   ├── SteamManager.gd                 (Core Steam integration)
│   ├── MissionManager.gd               (Mission achievement hooks)
│   ├── UIManager.gd                    (Playtime tracking)
│   └── painting/
│       ├── PaintingSystem.gd           (3D sticker tracking)
│       └── PaintingSystem2D.gd         (2D sticker tracking)
└── project.godot                        (SteamManager autoload)
```

---

## Troubleshooting

### "Steam not initialized" error
- **Cause**: Steam client not running
- **Fix**: Launch Steam, then restart game

### No achievement popups
- **Cause**: Not calling `storeStats()` after unlocking
- **Fix**: Already handled in code! Check if achievements are published in Steamworks

### Achievements not appearing in Steamworks
- **Cause**: Changes not published
- **Fix**: Click "Publish" button in Steamworks Partner portal

### "Achievement not found" warnings
- **Cause**: Achievement not configured in Steamworks
- **Fix**: Add all 14 achievements to Steamworks with exact API names

### Stats not updating
- **Cause**: Stats not configured in Steamworks
- **Fix**: Add all 8 statistics to Steamworks with exact API names

---

## Testing Checklist

- [ ] Steam client is running
- [ ] GodotSteam addon installed in `addons/godotsteam/`
- [ ] Console shows "Steam initialized successfully!"
- [ ] Complete a mission → Achievement unlocked
- [ ] Place stickers → Stat increments
- [ ] Play for 60 seconds → Playtime stat updates
- [ ] All 14 achievements configured in Steamworks
- [ ] All 8 statistics configured in Steamworks
- [ ] Achievement icons uploaded
- [ ] Changes published in Steamworks
- [ ] Tested in exported build (not just editor)

---

## Production Checklist

- [ ] Replace `steam_appid.txt` with real App ID
- [ ] Set `debug_mode = false` in SteamManager.gd
- [ ] All achievements configured and published
- [ ] All statistics configured and published
- [ ] Achievement icons uploaded
- [ ] Tested achievement popups in exported build
- [ ] Verified Steam overlay works (Shift+Tab)
- [ ] Tested offline mode (no crashes)

---

## Support Resources

- **GodotSteam Docs**: https://godotsteam.com/
- **Stats/Achievements Guide**: https://godotsteam.com/tutorials/stats_achievements/
- **API Reference**: https://godotsteam.com/classes/user_stats/
- **Discord Support**: https://discord.gg/SJRSq6K
- **Steamworks Partner**: https://partner.steamgames.com/

---

**Last Updated**: 2025-12-22
**Status**: Code complete, awaiting GodotSteam addon installation
