# Football Rules Violations - footballPro

## Critical Issues Found

### 1. ❌ FIELD POSITION IS BROKEN
**The biggest issue**: Field position doesn't flip properly when possession changes.

#### Problem:
In football, the field is always measured from YOUR OWN goal line (0) to the opponent's goal line (100). When possession switches, the field perspective flips.

**Example:**
- Team A has ball at their 40-yard line (field position = 40)
- Team A punts
- Team B should get ball at THEIR 40-yard line (field position = 40 from their perspective)
- **Currently**: Team B gets ball at Team A's 40 (field position = 60) ❌ WRONG

#### Current Code (SimulationEngine.swift:312-316):
```swift
game.endDrive(result: .punt)
game.switchPossession()

let newYardLine = max(1, min(99, 100 - game.fieldPosition.yardLine - netPunt))
game.fieldPosition = FieldPosition(yardLine: newYardLine)
```

**Problem**: This doesn't properly flip the field from the new team's perspective.

---

### 2. ❌ CLOCK MANAGEMENT IS WRONG

#### Issues:
- **Incomplete passes**: Clock keeps running (should STOP)
- **Out of bounds**: Clock keeps running (should STOP)
- **First downs**: Clock keeps running (correct, but no pause/warning)
- **Two-minute warning**: Doesn't exist (should stop clock at 2:00 in 2nd/4th quarters)
- **Spike play**: Doesn't exist (QB should be able to throw incomplete to stop clock)

#### Current Code (SimulationEngine.swift:90):
```swift
game.clock.isRunning = true
game.clock.tick(seconds: outcome.timeElapsed)
```

**Problem**: Clock ALWAYS runs, regardless of play outcome.

---

### 3. ❌ KICKOFF/TOUCHBACK RULES BROKEN

#### Problems:
- No touchback logic (kickoffs in end zone should = ball at 25)
- Kickoff return calculation is too simple
- No onside kick option
- No squib kick option

#### Current Code (SimulationEngine.swift:201-212):
```swift
func executeKickoff() async {
    guard var game = currentGame else { return }

    let returnYards = Int.random(in: 15...35)
    let startingYardLine = 25 + returnYards  // This makes no sense

    game.isKickoff = false
    game.fieldPosition = FieldPosition(yardLine: startingYardLine)
```

**Problems**:
- `25 + returnYards` = ball starts at 40-60 yard line? Makes no sense
- Should be: Kick from 35, if lands in end zone = touchback at 25, else return from landing spot

---

### 4. ❌ PENALTY HANDLING IS INCOMPLETE

#### Issues:
- Defensive penalties don't give automatic first down
- No replay of down option
- Penalties don't consider down/distance
- No offsetting penalties
- No declined penalties logic
- Pass interference should be spot foul

#### Current Code (PlayResolver.swift:398-422):
```swift
private func resolvePenalty(isOnOffense: Bool) -> PlayOutcome {
    let penaltyType = PenaltyType.allCases.randomElement()!
    let penalty = Penalty(
        type: penaltyType,
        yards: penaltyType.yards,
        isOnOffense: isOnOffense,
        isDeclined: false
    )

    let yardEffect = isOnOffense ? -penalty.yards : penalty.yards
```

**Problems**:
- Doesn't check if penalty gives automatic first down
- Doesn't handle down replay
- Just adds/subtracts yards, doesn't properly update game state

---

### 5. ❌ TURNOVER FIELD POSITION WRONG

#### Problem:
After interception or fumble, defensive team should get ball at the SPOT OF THE TURNOVER (from their perspective), not current field position.

#### Current Code (SimulationEngine.swift:111-116):
```swift
if outcome.isTurnover {
    let driveResult: DriveResult = outcome.turnoverType == .interception ? .interception : .fumble
    game.endDrive(result: driveResult)
    game.switchPossession()
    game.downAndDistance = .firstDown(at: game.fieldPosition.yardLine) // WRONG!
    game.startDrive()
```

**Problem**: Field position is from OLD team's perspective. Should flip.

---

### 6. ❌ SAFETY RULES INCORRECT

#### Problems:
- After safety, scoring team should receive a FREE KICK (punt), not a kickoff
- Currently just gives ball at 20-yard line with normal possession

#### Current Code (SimulationEngine.swift:132-142):
```swift
if game.fieldPosition.yardLine <= 0 {
    result.scoringPlay = .safety
    game.score.addScore(points: 2, isHome: !game.isHomeTeamPossession, quarter: game.clock.quarter)
    game.endDrive(result: .safety)
    // After safety, team that scored gets the ball
    game.switchPossession()
    game.fieldPosition = FieldPosition(yardLine: 20)  // Should be FREE KICK
    game.downAndDistance = .firstDown(at: 20)
```

**Problem**: Team that gave up safety should PUNT from their own 20, not just hand ball over.

---

### 7. ❌ EXTRA POINT / 2-POINT CONVERSION RULES

#### Issues:
- After TD, extra point is automatic (no user choice in UI currently)
- No 2-point conversion animation
- After extra point/2pt, kickoff happens but not properly tracked

---

### 8. ❌ MISSED FIELD GOAL RULES

#### Problem:
Ball placement after missed FG is wrong.

#### Current Code (SimulationEngine.swift:287-290):
```swift
} else {
    // Missed FG - ball at spot of kick
    game.fieldPosition = FieldPosition(yardLine: 100 - yardLine)
    game.downAndDistance = .firstDown(at: game.fieldPosition.yardLine)
```

**Real NFL Rule**:
- If FG attempt is from OUTSIDE the 20-yard line: Ball at spot of kick
- If FG attempt is from INSIDE the 20-yard line: Ball at the 20-yard line
- Ball should flip perspective when possession changes

---

### 9. ❌ HALFTIME POSSESSION

#### Problem:
Code says "Team that kicked off first half receives" but that's WRONG.

#### Current Code (SimulationEngine.swift:351-353):
```swift
// Team that kicked off first half receives
game.possessingTeamId = game.homeTeamId
game.isKickoff = true
```

**Real NFL Rule**: Team that RECEIVED the opening kickoff, KICKS OFF in the second half.
Currently just gives it to home team.

---

### 10. ❌ NO OVERTIME RULES

#### Issues:
- Overtime exists (code mentions it) but no NFL overtime rules
- No sudden death / first score wins
- No 10-minute OT period
- No coin toss for OT possession

---

## What Works Correctly ✅

1. ✅ Down progression (1st → 2nd → 3rd → 4th)
2. ✅ First down distance (10 yards)
3. ✅ Scoring (6 for TD, 3 for FG, 1 for XP, 2 for safety)
4. ✅ Quarter progression
5. ✅ 4th down logic (punt vs FG vs go for it)
6. ✅ Red zone detection
7. ✅ Goal-to-go situations
8. ✅ Play outcome probabilities (reasonably realistic)

---

## Priority Fixes Needed

### HIGH PRIORITY (Game-Breaking):
1. **Fix field position flipping** on possession changes
2. **Fix kickoff/touchback** logic
3. **Fix clock stopping** on incomplete passes
4. **Fix turnover field position**
5. **Fix punt field position**

### MEDIUM PRIORITY (Important Rules):
6. Fix missed FG ball placement
7. Fix penalty automatic first downs
8. Add two-minute warning
9. Fix halftime possession
10. Fix safety free kick

### LOW PRIORITY (Nice to Have):
11. Add overtime rules
12. Add spike play
13. Add kneel down play
14. Add fair catch
15. Add onside kick option

---

## How Field Position SHOULD Work

### Concept:
Each team always measures from THEIR OWN goal line (0) to opponent's goal (100).

### Example Game Flow:
```
TEAM A DRIVES:
- 1st & 10 at A-25 (field position = 25, 75 yards to end zone)
- Run for 15 yards
- 1st & 10 at A-40 (field position = 40, 60 yards to end zone)
- Pass incomplete
- 2nd & 10 at A-40 (field position = 40)
- Punt 40 yards

POSSESSION CHANGES TO TEAM B:
- Punt lands at old A-80 / B-20
- Field position = 20 (Team B's perspective!)
- 1st & 10 at B-20 (80 yards to end zone)
```

### Current Bug:
After punt, code does: `100 - A's field position - punt distance`
This gives WRONG result because it doesn't properly flip perspective.

### Correct Fix:
```swift
// When possession switches, field ALWAYS flips
game.switchPossession()
game.fieldPosition.flip()  // This should flip: 100 - currentYardLine
```

---

## Testing Checklist

After fixes, verify:
- [ ] Team punts from their 40, opponent gets ball at their 40 (not 60)
- [ ] Incomplete pass stops the clock
- [ ] Out of bounds stops the clock
- [ ] Kickoff into end zone = touchback at 25
- [ ] Interception at opponent's 30 = offense now at their own 70
- [ ] Safety gives other team the ball via free kick from 20
- [ ] Missed FG from 40-yard line = opponent ball at 40
- [ ] Two-minute warning stops clock
- [ ] Defensive holding on 3rd & 15 = automatic first down
- [ ] Second half kickoff goes to team that kicked off first

---

**Bottom Line**: The game simulation logic is sophisticated, but the fundamental field position tracking is broken, making it not follow real football rules.
