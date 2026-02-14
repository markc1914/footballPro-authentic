# Fix Xcode Build Issue

## Problem
FieldPhysics.swift is not included in the Xcode project, causing build errors:
```
error: cannot find 'FieldPhysics' in scope
```

## Solution - Add File to Xcode Project

### Method 1: Drag and Drop (Easiest)
1. Open Finder and navigate to:
   `/Users/markcornelius/projects/claude/footballPro/footballPro/footballPro/Views/Game/`

2. Open `footballPro.xcodeproj` in Xcode

3. In Xcode's left sidebar (Project Navigator), expand:
   - footballPro
   - footballPro
   - Views
   - Game

4. **Drag** `FieldPhysics.swift` from Finder into the `Game` folder in Xcode

5. In the dialog that appears:
   - ✅ Check "Copy items if needed"
   - ✅ Check "footballPro" under "Add to targets"
   - Click "Finish"

6. Build the project (⌘B)

---

### Method 2: Add Files Menu
1. Open `footballPro.xcodeproj` in Xcode

2. Right-click on the `Game` folder in the left sidebar

3. Select **"Add Files to footballPro..."**

4. Navigate to:
   `footballPro/footballPro/Views/Game/`

5. Select `FieldPhysics.swift`

6. Make sure:
   - ✅ "footballPro" is checked under "Add to targets"
   - ✅ "Create groups" is selected

7. Click **"Add"**

8. Build (⌘B)

---

### Method 3: Use Swift Package Manager (Already Works)
If you just want to run the game without Xcode:

```bash
cd /Users/markcornelius/projects/claude/footballPro/footballPro
swift build
swift run
```

This already works! SPM automatically finds all Swift files.

---

## Verify It's Fixed

After adding the file, you should see:
- ✅ `FieldPhysics.swift` appears in Xcode's file list
- ✅ It has a checkmark next to "footballPro" target
- ✅ Build succeeds (⌘B)
- ✅ No "cannot find 'FieldPhysics'" errors

---

## Why This Happened

- Swift Package Manager (SPM) automatically includes all `.swift` files
- Xcode projects need files explicitly added to the project file
- When I created `FieldPhysics.swift`, SPM found it but Xcode didn't

---

## Alternative: Just Use SPM

You don't need to use Xcode! The game builds and runs fine with:

```bash
swift run
```

Xcode is optional - SPM works great for this project.
