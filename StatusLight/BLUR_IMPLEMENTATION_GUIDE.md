# Apple Blur Effect Implementation Guide

## Overview
This guide explains how to implement proper native Apple blur effects for macOS SwiftUI applications, specifically for menubar popup windows.

## Implementation

### Current Implementation
The application now uses native `NSVisualEffectView` wrapped in SwiftUI through the `VisualEffectBlur` component.

**Key files modified:**
- `/StatusLight/StatusLight/StatusLightApp.swift` - Main blur implementation
- `/StatusLight/StatusLight/Views/SettingsView.swift` - Settings window blur

### Current Configuration
```swift
// MenuBar popup uses .menu material for native menubar appearance
VisualEffectBlur(material: .menu, blendingMode: .behindWindow)

// Settings window uses .sidebar material for secondary content
VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
```

## Material Options

### For MenuBar Popups
1. **`.menu`** (Current) - Most native for dropdown menus and popups
2. **`.popover`** - More pronounced blur for floating panels
3. **`.hudWindow`** - Minimal, floating HUD appearance

### For Settings Windows
1. **`.sidebar`** (Current) - Ideal for secondary content windows
2. **`.sheet`** - Modal sheet appearance
3. **`.windowBackground`** - Standard window background

## Easy Customization

### Change MenuBar Blur Style
In `StatusLightApp.swift`, line 32, replace:
```swift
VisualEffectBlur(material: .menu, blendingMode: .behindWindow)
```

With any of these alternatives:
```swift
// More pronounced blur
VisualEffectBlur(material: .popover, blendingMode: .behindWindow)

// HUD-style minimal appearance
VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

// Tooltip-style
VisualEffectBlur(material: .toolTip, blendingMode: .behindWindow)
```

### Change Settings Window Blur
In `SettingsView.swift`, line 723, replace:
```swift
VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow)
```

With alternatives like:
```swift
// Modal sheet appearance
VisualEffectBlur(material: .sheet, blendingMode: .behindWindow)

// Standard window background
VisualEffectBlur(material: .windowBackground, blendingMode: .behindWindow)

// Content area background
VisualEffectBlur(material: .contentBackground, blendingMode: .behindWindow)
```

## Advanced Options

### Layered Blur Effect
For more depth, you can layer multiple blur effects:
```swift
ZStack {
    // Base blur layer
    VisualEffectBlur(material: .menu, blendingMode: .behindWindow)
    
    // Secondary overlay for depth
    Rectangle()
        .fill(.regularMaterial.opacity(0.3))
}
```

### Adaptive Blur Based on Appearance
```swift
@Environment(\.colorScheme) var colorScheme

var material: NSVisualEffectView.Material {
    colorScheme == .dark ? .hudWindow : .menu
}

VisualEffectBlur(material: material, blendingMode: .behindWindow)
```

## Window Configuration

The settings window is configured with these properties for optimal blur integration:
```swift
newWindow.titlebarAppearsTransparent = true
newWindow.backgroundColor = NSColor.clear
newWindow.isOpaque = false
newWindow.hasShadow = true
newWindow.styleMask.insert(.fullSizeContentView)
newWindow.alphaValue = 0.98
```

## Visual Enhancements

### Current Styling Features:
- Rounded corners with `clipShape(RoundedRectangle(cornerRadius: 12))`
- Drop shadow with `shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)`
- Subtle border with `stroke(.quaternary, lineWidth: 0.5)`

### Customization Tips:
- Increase corner radius for more modern appearance
- Adjust shadow opacity and radius for different depth effects
- Change border color for different themes

## Troubleshooting

### Common Issues:
1. **Duplicate blur structs** - Ensure `VisualEffectBlur` is only defined once
2. **Import statements** - Make sure to import both `SwiftUI` and `AppKit`
3. **Window transparency** - Ensure window `backgroundColor` is clear and `isOpaque` is false

### Performance Notes:
- Native `NSVisualEffectView` is more performant than SwiftUI's `.ultraThinMaterial`
- `.behindWindow` blending mode is typically more efficient than `.withinWindow`
- Use appropriate materials for context to maintain system consistency