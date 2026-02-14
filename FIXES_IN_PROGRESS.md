# Fixes In Progress

## Three Critical Issues

### 1. Kickoff Not Visible
**Problem**: Opening kickoff executes but doesn't show in UI
**Root Cause**: Kickoff runs in async Task, might complete before UI renders
**Fix**: Need to add a small delay or ensure UI updates properly

### 2. Punts Not Showing in Play-by-Play
**Problem**: AI punts on 4th down but nothing appears in play-by-play
**Root Cause**: `executePunt()` returns `Int` (net yards), not `PlayResult`
**Fix**: Change return type to `PlayResult` and update all callers

### 3. Players Not Showing on Field
**Problem**: Field view shows but no player dots visible
**Root Cause**: `setupFieldPositions()` called onAppear but game may not be loaded yet
**Fix**: Also trigger setup when game changes, not just on appear

## Changes Needed

### SimulationEngine.swift
```swift
// Change from:
func executePunt() async -> Int

// Change to:
func executePunt() async -> PlayResult
```

### GameViewModel.swift
```swift
// Update all punt calls to handle PlayResult
case .punt:
    let result = await simulationEngine.executePunt()
    lastPlayResult = result
    playByPlay.append(result)
```

### FPSFieldView.swift
```swift
// Add trigger when game loads
.onChange(of: viewModel.game) { _, _ in
    setupFieldPositions()
}
```
