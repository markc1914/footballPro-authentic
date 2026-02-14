# Testing Guide - Football Pro

## Quick Test Steps

### 1. Build the Game
```bash
cd /Users/markcornelius/projects/claude/footballPro/footballPro
swift build
```

### 2. Run the Game
```bash
swift run
```

OR open in Xcode:
```bash
open /Users/markcornelius/projects/claude/footballPro/footballPro/footballPro.xcodeproj
```
Then press ⌘R

---

## What to Look For

### ✅ Main Menu
- [ ] "New Game" button works
- [ ] Team selection grid appears
- [ ] Can select a team and start franchise

### ✅ Team Management
- [ ] Roster view shows players
- [ ] Depth chart displays positions
- [ ] Finance tab shows salary cap
- [ ] Stats tab shows team ratings

### ✅ Season View
- [ ] Schedule displays all weeks
- [ ] Current week highlighted
- [ ] "Sim Week" button works
- [ ] Can navigate to Play Game

### ✅ Game Day - THE BIG TEST!
- [ ] **Retro field view appears** with green field
- [ ] **X's and O's formations** visible (yellow O's, red X's)
- [ ] **Blue line of scrimmage** shows
- [ ] **Yellow first down marker** shows
- [ ] Down & distance displays correctly
- [ ] Scoreboard shows teams and score

### ✅ Play Calling
- [ ] Offensive playbook shows when user has ball
- [ ] Defensive playbook shows when opponent has ball
- [ ] Can select plays from categories (Run, Pass, Defense)
- [ ] "Sim Drive" / "Sim Quarter" buttons work

### ✅ Play Animation - CORE FEATURE!
- [ ] **Run plays**: HB runs forward with ball
- [ ] **Pass plays**: QB drops back, WR runs route, ball flies
- [ ] **White trajectory line** shows during plays
- [ ] **Players move** during animation
- [ ] **Ball position updates** after play

### ✅ Play Results
- [ ] Compact result shows below field (yards gained)
- [ ] "1ST DOWN" badge appears when earned
- [ ] "TOUCHDOWN!" shows on scoring plays
- [ ] "TURNOVER!" shows on interceptions/fumbles

### ✅ Sound Effects
- [ ] Tackle sound on run plays
- [ ] Catch/incomplete sounds on passes
- [ ] Touchdown fanfare (ascending tones)
- [ ] Crowd cheer/boo sounds
- [ ] Menu navigation sounds

### ✅ Game Flow
- [ ] Quarters progress (1st → 2nd → Halftime → 3rd → 4th)
- [ ] Clock counts down
- [ ] Possession switches on turnovers
- [ ] Score updates correctly
- [ ] Game ends and shows final score

---

## Known Working Features

### Simulation Engine
- ✅ Play resolution with realistic outcomes
- ✅ Yards gained based on player ratings
- ✅ First downs tracked correctly
- ✅ Touchdowns scored and points added
- ✅ Field goals and extra points
- ✅ Turnovers (interceptions, fumbles)
- ✅ Punts and kickoffs

### AI Coach
- ✅ CPU calls plays based on down/distance
- ✅ Smart 4th down decisions (punt, FG, go for it)
- ✅ Clock management in late game
- ✅ Formation selection based on situation

### Field View Animations
- ✅ Formation setup on new drive
- ✅ Run play: HB moves, blockers push, defenders pursue
- ✅ Pass play: QB drops, WR runs route, ball arcs to receiver
- ✅ Tackle animation completes play
- ✅ Field resets for next play

---

## Testing Scenarios

### Test 1: Basic Game
1. Start new franchise
2. Play Game → Start Game
3. Call a run play (HB Dive, HB Stretch)
4. **Watch animation**: HB should run forward with ball
5. Call a pass play (Slant, Curl)
6. **Watch animation**: QB drops back, ball flies to WR
7. Continue playing until touchdown
8. **Listen**: Should hear touchdown fanfare

### Test 2: Computer Simulation
1. Start game
2. Click "Sim Drive" button
3. **Watch field**: Should see multiple plays animate rapidly
4. Drive should end (TD, FG, punt, or turnover)

### Test 3: Full Game Simulation
1. Start game
2. Click "Sim Game" button
3. **Watch**: Game simulates to completion
4. Game Over screen appears with final score
5. Click "Continue to Season"
6. **Check**: Game result recorded in season standings

### Test 4: Special Teams
1. Get to 4th down
2. Attempt field goal
3. **Watch**: Should see success/failure message
4. **Listen**: Rising tones (good) or descending (miss)

### Test 5: Turnover
1. Call deep pass repeatedly (higher risk)
2. Eventually should see interception
3. **Check**: "TURNOVER!" message appears
4. **Check**: Possession switches to opponent
5. **Listen**: Descending dramatic tones

---

## Performance Benchmarks

### Expected Performance:
- **Play animation**: 0.8-1.0 seconds per play
- **Field redraw**: Instant on down change
- **Full drive sim**: 5-10 seconds
- **Full game sim**: 30-60 seconds

### Frame Rates:
- **Field animations**: Should be smooth at 60fps
- **Play trajectory**: Smooth arc for passes
- **Player movement**: No stuttering or lag

---

## Debugging Tips

### If field doesn't show:
1. Check RetroFieldView is being imported
2. Verify viewModel has game data
3. Check console for errors

### If animations don't play:
1. Check viewModel.lastPlayResult is updating
2. Verify `onChange` triggers in RetroFieldView
3. Check isAnimating flag

### If sounds don't play:
1. Check system volume is up
2. Verify SoundManager.shared.isSoundEnabled = true
3. Check audio permissions in macOS Settings

### If plays seem unrealistic:
1. Check PlayResolver.swift for outcome logic
2. Verify player ratings are reasonable (50-99)
3. Check difficulty setting (affects CPU bonus)

---

## Success Criteria

The integration is successful if:
1. ✅ Field view displays with X's and O's
2. ✅ Plays animate (run/pass movement)
3. ✅ Sounds play for different events
4. ✅ Game progresses through quarters
5. ✅ Final score is recorded

---

## Next Test After Success

Once basic gameplay works:
1. **Test full season simulation** (Sim Week repeatedly)
2. **Test franchise save/load** (Save game, quit, load game)
3. **Test different teams** (ratings affect outcomes)
4. **Test playoffs** (complete regular season)
5. **Test stats tracking** (player season stats accumulate)

---

**Ready to test! Run the game and watch those X's and O's come to life! 🏈**
