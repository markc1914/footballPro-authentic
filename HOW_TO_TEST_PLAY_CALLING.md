# How to Test the Play Calling System

## Current Status
✅ Game is running
✅ You're at the Main Menu

## Steps to See the Play Calling Feature:

### 1. Start a New Game
From the Main Menu:
- Select **"New Game"**
- Choose your team
- Start the game

### 2. Get to Offense
Once in the game:
- You need to have **possession of the ball** (offense)
- If the other team has the ball, you'll need to wait for them or simulate until you get possession

### 3. Look for the "CALL PLAY" Button
When you're on offense, you should see:
- The game field view in the center
- On the bottom or side panel: A big **yellow/orange "CALL PLAY"** button
- It should say "See X's & O's Diagrams" underneath

### 4. Click "CALL PLAY"
This opens the play calling screen with:
- Play types on the left
- Visual diagrams in the center
- Available plays on the right

---

## If You Don't See It

The "CALL PLAY" button only appears when:
1. ✅ You're in an active game (not main menu)
2. ✅ It's your possession (offense)
3. ✅ It's not a kickoff/special teams situation

---

## Quick Test Path

**Fastest way to test:**

1. From Main Menu → Select "New Game"
2. Pick any team (doesn't matter)
3. Game starts with kickoff
4. After receiving kickoff (or simulating it):
   - You should have 1st & 10 on your own 25-yard line
   - Look at the bottom of the screen
   - **"CALL PLAY" button should be visible**
5. Click it!
6. See the play diagrams!

---

## Alternative: Check the Code Location

The button is in `GameDayView.swift` around line 447 in the `OffensivePlaybook` struct.

If you're in the game but don't see it, the issue might be:
- Not on offense yet
- Different screen layout than expected
- Need to scroll to see it

Let me know what screen you're seeing and I can help debug!
