# Front Page Sports: Football Pro

A native macOS football management/simulation game built with Swift and SwiftUI. Inspired by the classic 1993 Sierra game, this modern recreation features stats-based simulation, full season management, and support for both keyboard/mouse and game controllers.

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

### Core Gameplay
- **8-Team League** with 2 divisions (Western & Eastern)
- **14-Game Regular Season** with full schedule generation
- **4-Team Playoffs** - Semifinals and Championship
- **Play-by-Play Simulation** with realistic outcomes
- **Full Roster Management** - 53-man rosters with depth charts

### Team Management
- **Player Ratings** (1-99 scale) for 30+ attributes
- **Salary Cap Management** with contracts and dead money
- **Depth Chart Editor** for all positions
- **Trade System** with AI evaluation
- **Free Agency** market
- **NFL-Style Draft** with scouting grades

### Simulation Engine
- **Position-Specific Ratings** that affect play outcomes
- **Situational AI Coach** - Smart play calling based on game state
- **Weather Effects** on kicking and passing
- **Injury System** with recovery times
- **Full Statistics Tracking** - Passing, rushing, receiving, defense

### Modern Features
- **Controller Support** - Xbox, PlayStation, Nintendo controllers via GameController framework
- **Keyboard Shortcuts** - Full keyboard navigation
- **SwiftData Persistence** - Multiple save slots, auto-save
- **Dark Mode** native support

## Screenshots

*Coming soon*

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9+

## Installation

### From Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/footballPro.git
cd footballPro
```

2. Open the project in Xcode:
```bash
open footballPro.xcodeproj
```

3. Build and run (⌘R)

### Using Swift Package Manager

```bash
cd footballPro
swift build
swift run
```

## Project Structure

```
footballPro/
├── footballPro/
│   ├── App/
│   │   └── FootballProApp.swift          # App entry point
│   ├── Models/
│   │   ├── Player.swift                  # Player attributes, stats, contracts
│   │   ├── Team.swift                    # Team roster, depth chart, finances
│   │   ├── Game.swift                    # Game state, score, play history
│   │   ├── Season.swift                  # Schedule, standings, playoffs
│   │   ├── Play.swift                    # Play types, formations, outcomes
│   │   └── League.swift                  # All teams, league settings
│   ├── Engine/
│   │   ├── SimulationEngine.swift        # Core game simulation logic
│   │   ├── PlayResolver.swift            # Resolves play outcomes
│   │   ├── StatCalculator.swift          # Calculates and tracks all stats
│   │   ├── AICoach.swift                 # CPU play calling AI
│   │   └── DraftEngine.swift             # Draft class generation, logic
│   ├── ViewModels/
│   │   ├── GameViewModel.swift           # Live game state management
│   │   ├── TeamViewModel.swift           # Team management
│   │   ├── SeasonViewModel.swift         # Season progression
│   │   └── LeagueViewModel.swift         # League-wide operations
│   ├── Views/
│   │   ├── MainMenu/
│   │   ├── Team/
│   │   ├── Game/
│   │   └── Components/
│   ├── Input/
│   │   ├── InputManager.swift            # Unified input handling
│   │   ├── ControllerManager.swift       # GameController integration
│   │   └── KeyboardShortcuts.swift       # Keyboard bindings
│   ├── Services/
│   │   ├── SaveGameService.swift         # Save/load game state
│   │   └── SettingsService.swift         # User preferences
│   └── Resources/
│       ├── PlaybookData.json             # Default plays/formations
│       └── TeamData.json                 # Initial team data
├── Tests/
│   ├── PlayerTests.swift
│   ├── TeamTests.swift
│   ├── GameTests.swift
│   ├── SimulationEngineTests.swift
│   └── LeagueTests.swift
└── footballPro.xcodeproj
```

## Controls

The game supports keyboard/mouse, Xbox, PlayStation, and Nintendo controllers. Button prompts automatically update based on your active input device.

### Keyboard Controls

#### General Navigation
| Action | Key |
|--------|-----|
| Navigate Up | ↑ / W |
| Navigate Down | ↓ / S |
| Navigate Left | ← / A |
| Navigate Right | → / D |
| Select/Confirm | Enter / Space |
| Back/Cancel | Escape |
| Previous Tab | Q / [ |
| Next Tab | E / ] |

#### Game Day Controls
| Action | Key |
|--------|-----|
| Call Timeout | T |
| View Play Info | I |
| Toggle Sim Speed | 1-4 |
| Skip to End of Quarter | End |
| Quick Save | ⌘S |

#### Management Screens
| Action | Key |
|--------|-----|
| Search/Filter | / |
| Sort Column | Click Header |
| Quick Stats | I |
| Trade Player | T |
| Release Player | R |
| View Details | Enter |

### Controller Controls

#### Xbox Controller
| Action | Button |
|--------|--------|
| Navigate | D-Pad / Left Stick |
| Select/Confirm | A |
| Back/Cancel | B |
| Info/Details | Y |
| Action/Special | X |
| Previous Tab | LB |
| Next Tab | RB |
| Call Timeout | LT |
| Sim Speed | RT |
| Pause Menu | Menu |
| View Options | View |

#### PlayStation Controller
| Action | Button |
|--------|--------|
| Navigate | D-Pad / Left Stick |
| Select/Confirm | ✕ (Cross) |
| Back/Cancel | ○ (Circle) |
| Info/Details | △ (Triangle) |
| Action/Special | □ (Square) |
| Previous Tab | L1 |
| Next Tab | R1 |
| Call Timeout | L2 |
| Sim Speed | R2 |
| Pause Menu | Options |
| View Options | Create |

#### Nintendo Controller
| Action | Button |
|--------|--------|
| Navigate | D-Pad / Left Stick |
| Select/Confirm | A |
| Back/Cancel | B |
| Info/Details | X |
| Action/Special | Y |
| Previous Tab | L |
| Next Tab | R |
| Call Timeout | ZL |
| Sim Speed | ZR |
| Pause Menu | + |
| View Options | - |

### Mouse Controls

| Action | Input |
|--------|-------|
| Select Item | Left Click |
| Context Menu | Right Click |
| Scroll Lists | Mouse Wheel |
| Drag (Depth Chart) | Click + Drag |

### Controller Setup

1. **Connect your controller** via Bluetooth or USB
2. **macOS will auto-detect** Xbox, PlayStation, and Nintendo controllers
3. **Button prompts** will update automatically when you use your controller
4. **Haptic feedback** is supported on compatible controllers (DualSense, etc.)
5. **Light bar** on PlayStation controllers shows your team colors during games

## Development

### Running Tests

```bash
# Run all tests
swift test

# Or in Xcode
⌘U
```

### Building for Release

```bash
# Command line
swift build -c release

# Or in Xcode: Product → Archive
```

## Packaging & Deployment

### Creating a Release Build

1. **In Xcode:**
   - Select Product → Archive
   - In the Organizer, select your archive
   - Click "Distribute App"
   - Choose "Copy App" for local distribution or "Developer ID" for notarized distribution

2. **Command Line:**
```bash
# Build release
xcodebuild -project footballPro.xcodeproj \
  -scheme footballPro \
  -configuration Release \
  -archivePath build/footballPro.xcarchive \
  archive

# Export app
xcodebuild -exportArchive \
  -archivePath build/footballPro.xcarchive \
  -exportPath build/release \
  -exportOptionsPlist ExportOptions.plist
```

### Creating a DMG Installer

```bash
# Create DMG with Applications symlink
hdiutil create -volname "Football Pro" \
  -srcfolder build/release/footballPro.app \
  -ov -format UDZO \
  footballPro-1.0.dmg
```

### Notarization (for distribution outside App Store)

```bash
# Store credentials
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

# Submit for notarization
xcrun notarytool submit footballPro-1.0.dmg \
  --keychain-profile "AC_PASSWORD" \
  --wait

# Staple the notarization ticket
xcrun stapler staple footballPro-1.0.dmg
```

### App Store Submission

1. Create an App Store Connect record
2. Archive in Xcode (Product → Archive)
3. In Organizer, click "Distribute App"
4. Select "App Store Connect"
5. Upload and submit for review

## Configuration

Settings are stored in UserDefaults and can be modified in-app:

- **Simulation Speed**: Slow / Normal / Fast / Instant
- **Difficulty**: Rookie / Normal / All-Pro / All-Madden
- **Injury Frequency**: Off / Low / Normal / High
- **Auto-Save**: Toggle and interval

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [Front Page Sports: Football Pro](https://www.myabandonware.com/game/front-page-sports-football-pro-22k) (Sierra, 1993)
- Built with Swift and SwiftUI
- Uses Apple's GameController framework for controller support

## Roadmap

- [ ] Multiple season franchise mode
- [ ] Player progression and aging
- [ ] Expanded playoffs (6/7 team format)
- [ ] Historical stats and records
- [ ] Custom team creation
- [ ] Online roster sharing
- [ ] iPad support

---

**Front Page Sports: Football Pro** - A modern recreation of a classic
