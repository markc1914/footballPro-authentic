# How to Add New Files to Xcode Project

## The Issue

The Xcode project file (`project.pbxproj`) gets corrupted when edited programmatically.

## The Solution (Choose One)

### Option 1: Use Swift Build (Works Now - No Xcode Needed) ✅

```bash
cd /Users/markcornelius/projects/claude/footballPro/footballPro
swift run
```

This works perfectly! All files compile with Swift Package Manager.

### Option 2: Manually Add Files in Xcode (1 Minute)

1. **Open the project**:
   ```bash
   open footballPro.xcodeproj
   ```

2. **Add Models files**:
   - In Xcode's left sidebar, right-click the `Models` folder
   - Choose "Add Files to 'footballPro'..."
   - Navigate to `footballPro/Models/`
   - Select these files (hold Cmd to multi-select):
     - `PlayerRole.swift`
     - `PlayRoute.swift`
   - Click "Add"

3. **Add Views files**:
   - Right-click the `Views/Game` folder
   - Choose "Add Files to 'footballPro'..."
   - Navigate to `footballPro/Views/Game/`
   - Select these files:
     - `PlayDiagramView.swift`
     - `PlayCallingView.swift`
   - Click "Add"

4. **Build**:
   - Press Cmd+B
   - Should build successfully!

## Files to Add

All 4 files exist in the filesystem and compile perfectly with `swift build`:

| File | Location | Purpose |
|------|----------|---------|
| `PlayerRole.swift` | `footballPro/Models/` | Shared player position enum |
| `PlayRoute.swift` | `footballPro/Models/` | Route definitions + PlayArtDatabase |
| `PlayDiagramView.swift` | `footballPro/Views/Game/` | Visual X's and O's diagrams |
| `PlayCallingView.swift` | `footballPro/Views/Game/` | Play calling interface |

## Verification

After adding files in Xcode, verify they're in the project:

1. Open Xcode
2. Look in left sidebar under:
   - `footballPro` → `Models` → Should see `PlayerRole.swift` and `PlayRoute.swift`
   - `footballPro` → `Views` → `Game` → Should see `PlayDiagramView.swift` and `PlayCallingView.swift`
3. Press Cmd+B to build
4. Should say "Build Succeeded"

## Current Status

✅ **Swift Build**: Works perfectly (Build complete! 0.25s)
⚠️ **Xcode Project**: Needs manual file addition (1 minute)

## Recommendation

**Use `swift run` for now!** It works immediately. Add files to Xcode when you have a spare minute.
