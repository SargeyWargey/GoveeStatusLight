# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GoveeStatusLight** - A macOS menu bar application that integrates Govee smart lights with Microsoft Teams status and Outlook calendar events. The app automatically changes light colors based on your availability and upcoming meetings.

## Current Status

**Phase 1 Complete** - Project foundation with MVVM architecture implemented. Ready for Microsoft Teams API integration.

## Development Setup

### Prerequisites
- **Xcode 15+** with macOS development tools
- **macOS 12.0+** (Monterey or later)
- **Swift 5.9+**

### Building the Project
```bash
# Open the Xcode project
open StatusLight/StatusLight.xcodeproj

# Or build from command line
cd StatusLight
xcodebuild -project StatusLight.xcodeproj -scheme StatusLight -configuration Debug
```

### Running the App
- Build and run in Xcode (⌘+R)
- App appears as menu bar item with lightbulb icon
- Click to show status window with Teams/meeting info

## Architecture

### MVVM Pattern
- **Models**: `TeamsStatus`, `GoveeDevice`, `CalendarEvent`, `ColorMapping`
- **ViewModels**: `StatusLightViewModel` (main coordinator)
- **Views**: `ContentView` (menu bar interface), `SettingsView` (configuration)
- **Services**: `TeamsService`, `GoveeService`, `CalendarService`

### Key Components
- **Reactive Data Flow**: Uses Combine publishers for real-time updates
- **Rate Limiting**: Built-in Govee API compliance (10 requests/minute)
- **Menu Bar Integration**: Native macOS MenuBarExtra implementation
- **Color Mapping Engine**: Priority-based lighting rules system

### Project Structure
```
StatusLight/
├── Models/              # Data structures
├── Views/               # SwiftUI interfaces  
├── ViewModels/          # Business logic coordinators
├── Services/            # API integrations
├── Utils/               # Helper utilities
└── Extensions/          # Swift extensions
```

## API Integration Status

### Microsoft Teams (Phase 2 - In Progress)
- [ ] Azure app registration
- [ ] OAuth 2.0 authentication flow
- [ ] Microsoft Graph presence API
- [ ] Real-time status monitoring

### Govee API (Phase 4 - Planned)
- [x] Rate limiting implementation
- [x] Device models and control structures
- [ ] API key authentication
- [ ] Device discovery and control

### Calendar Integration (Phase 3 - Planned)
- [ ] Microsoft Graph calendar API
- [ ] Meeting countdown logic
- [ ] Event classification system

## Testing

### Mock Data
- App currently uses mock data for Teams status and calendar events
- Random status changes every 30 seconds for testing UI reactivity
- Mock meetings show countdown functionality

### Manual Testing
1. Launch app and verify menu bar icon appears
2. Click icon to open status window
3. Verify status indicators and mock data display
4. Test Settings button (placeholder)
5. Verify Refresh and Quit buttons work

## Configuration

### API Keys (Future)
- Microsoft Graph: OAuth tokens stored in Keychain
- Govee API: User-provided key stored securely
- No hardcoded credentials in source code

## Troubleshooting

### Common Issues
- **Menu bar icon not showing**: Check macOS version compatibility (12.0+)
- **Build errors**: Ensure Xcode 15+ and proper project configuration
- **Mock data not updating**: Check timer implementation in ViewModel

### Development Notes
- Use `@MainActor` for UI updates in async contexts
- Services use protocol abstractions for testing
- All external dependencies properly abstracted