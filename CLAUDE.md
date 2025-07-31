# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**GoveeStatusLight** - A macOS menu bar application that integrates Govee smart lights with Microsoft Teams status and Outlook calendar events. The app automatically changes light colors based on your availability and upcoming meetings.

## Current Status

**✅ Phase 1 & 2 Complete** - Working menu bar application with complete Microsoft Teams integration architecture.

**🎉 MAJOR MILESTONE**: MenuBarExtra working on macOS 15.5 with full StatusLight interface.

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

### Microsoft Teams (Phase 2 - ✅ COMPLETE)
- [x] Full Microsoft Graph service implementation
- [x] OAuth 2.0 authentication flow with ASWebAuthenticationSession
- [x] Microsoft Graph presence API integration
- [x] Real-time status monitoring with 30-second polling
- [x] Secure token storage using macOS Keychain
- [ ] Azure app registration (setup required)
- [ ] Live testing with real Teams account

### Calendar Integration (Phase 3 - ✅ ARCHITECTURE COMPLETE)
- [x] Microsoft Graph calendar API integration
- [x] Meeting countdown logic (15min, 5min, 1min)
- [x] Event classification system (meeting types)
- [ ] Live testing with real calendar data

### Govee API (Phase 4 - ✅ ARCHITECTURE COMPLETE)
- [x] Rate limiting implementation (10 req/min compliance)
- [x] Device models and control structures
- [x] Complete service layer with error handling
- [ ] API key configuration
- [ ] Device discovery and control testing

## Testing

### Mock Data
- App currently uses mock data for Teams status and calendar events
- Random status changes every 30 seconds for testing UI reactivity
- Mock meetings show countdown functionality

### Manual Testing
1. ✅ Launch app and verify menu bar icon appears (WORKING on macOS 15.5)
2. ✅ Click icon to open status window (WORKING)
3. ✅ Verify status indicators and mock data display (WORKING)
4. ✅ Test Settings button (placeholder working)
5. ✅ Verify Refresh and Quit buttons work (WORKING)

### Branch Structure
- **main**: Stable releases only
- **development**: Integration branch for features
- **feature/azure-integration**: Microsoft Graph setup and testing
- **feature/govee-integration**: Govee API setup and testing

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

## MCP Integration

### Context7 Server
Context7 MCP server is configured to provide up-to-date API documentation during development:

**Features:**
- Real-time library documentation
- Version-specific code examples
- Direct API reference integration

**Usage in Prompts:**
```
Create Teams authentication with Microsoft Graph SDK. use context7
```

**Available Libraries:**
- Microsoft Graph SDK for Swift
- SwiftUI documentation
- Govee API examples
- macOS development guides

**Configuration Location:**
`~/Library/Application Support/Claude/claude_desktop_config.json`