# Govee API Comprehensive Reference Guide

## Overview

The Govee Developer API provides programmatic control over Govee smart lighting devices including RGBICWW floor lamps, light strips, bulbs, and other smart home devices. This document covers everything you need to know about integrating with the Govee API.

## 🔑 Authentication & Setup

### Getting API Access
1. **Download Govee Home App**: Install on your mobile device
2. **Request API Key**: Navigate to User tab → About → Request API key
3. **Approval Process**: Submit your name and reason for use (e.g., home automation, third-party integration, educational)
4. **Receive Key**: Usually delivered via email within seconds
5. **Accept Terms**: Carefully read and accept the Govee Developer API Terms of Service

### Authentication Method
- **Type**: Bearer Token Authentication
- **Header**: `Govee-API-Key: your_api_key_here`
- **Content-Type**: `application/json`

## ⚠️ Critical Rate Limits & Usage Restrictions

### Rate Limits
- **Daily Limit**: 10,000 requests per account per 24 hours
- **Per-Minute Limit**: 10 changes per minute (recently imposed)
- **Lockout Period**: 1 minute when limits exceeded
- **Error Response**: HTTP 429 with `X-RateLimit-Reset` header

### Important Usage Notes
- Rate limits apply across ALL devices on your account
- Multiple rapid state changes will trigger lockout
- Design your application to batch requests and avoid rapid polling
- Consider implementing request queuing and retry logic
- Local API available for select devices (bypasses cloud rate limits)

## 🌐 API Endpoints

### Base URL
```
https://openapi.api.govee.com
```

### Primary Control Endpoint
```
POST /router/api/v1/device/control
```

### Additional Endpoints
- **Device Discovery**: Get list of available devices
- **Device Status**: Query current device state
- **Capability Query**: Check what controls are available for specific devices

## 📝 Request Structure

### Standard Request Format
```json
{
  "requestId": "unique-uuid-here",
  "payload": {
    "sku": "device_model_number",
    "device": "device_mac_address",
    "capability": {
      "type": "capability_type",
      "instance": "instance_name", 
      "value": control_value
    }
  }
}
```

### Required Fields
- **requestId**: Unique identifier (UUID recommended)
- **sku**: Product model number
- **device**: Device MAC address or ID
- **capability**: Control specification object

## 🎛️ Device Control Capabilities

### 1. Power Control
```json
{
  "type": "devices.capabilities.on_off",
  "instance": "powerSwitch",
  "value": 1  // 1 = on, 0 = off
}
```

### 2. Color Control (RGB)
```json
{
  "type": "devices.capabilities.color_setting",
  "instance": "colorRgb",
  "value": {
    "r": 255,  // 0-255
    "g": 128,  // 0-255  
    "b": 64    // 0-255
  }
}
```

### 3. Color Temperature
```json
{
  "type": "devices.capabilities.color_setting",
  "instance": "colorTemperatureK",
  "value": 4000  // 2000-9000K
}
```

### 4. Brightness Control
```json
{
  "type": "devices.capabilities.range",
  "instance": "brightness", 
  "value": 80  // 1-100
}
```

### 5. Segmented Brightness (for devices with zones)
```json
{
  "type": "devices.capabilities.segment_color_setting",
  "instance": "segmentedBrightness",
  "value": [75, 50, 100]  // Array for each segment
}
```

### 6. Scene/Mode Selection
```json
{
  "type": "devices.capabilities.mode",
  "instance": "workMode",
  "value": "scene_name"
}
```

### 7. Dynamic Scenes
```json
{
  "type": "devices.capabilities.dynamic_scene",
  "instance": "dynamicScene", 
  "value": "energize"
}
```

### 8. Music Mode
```json
{
  "type": "devices.capabilities.music_setting",
  "instance": "musicMode",
  "value": {
    "musicMode": 1,
    "sensitivity": 5,
    "autoColor": 1
  }
}
```

### 9. Toggle Features
```json
{
  "type": "devices.capabilities.toggle",
  "instance": "oscillation",  // or "nightlight"
  "value": 1  // 1 = on, 0 = off  
}
```

## 🛜 Local API (LAN Control)

### UDP Communication
- **Port**: 4003
- **Protocol**: UDP
- **Advantage**: Bypasses cloud rate limits
- **Limitation**: Only works with select newer devices

### Local API Commands
```json
{
  "msg": {
    "cmd": "turn",
    "data": {
      "value": 1  // 1 = on, 0 = off
    }
  }
}
```

```json
{
  "msg": {
    "cmd": "brightness", 
    "data": {
      "value": 50  // 1-100
    }
  }
}
```

```json
{
  "msg": {
    "cmd": "colorwc",
    "data": {
      "color": {"r": 255, "g": 0, "b": 0},
      "colorTemInKelvin": 4000
    }
  }
}
```

## 🚫 Error Codes & Handling

### Common HTTP Status Codes
- **200**: Success
- **400**: Invalid parameters or malformed request
- **401**: Invalid or missing API key
- **404**: Device not found or not accessible
- **429**: Rate limit exceeded
- **500**: Internal server error

### Error Response Format
```json
{
  "requestId": "uuid",
  "msg": "error description",
  "code": error_code
}
```

### Rate Limit Response Headers
- `X-RateLimit-Remaining`: Requests left in current window
- `X-RateLimit-Reset`: Unix timestamp when limit resets

## 🏠 Supported Device Types

### Lighting Devices
- RGBICWW Floor Lamps (your device type)
- LED Light Strips
- Smart Bulbs  
- Light Bars
- String Lights
- Ceiling Lights

### Other Smart Devices
- Smart Plugs
- Humidifiers
- Air Purifiers
- Heaters
- Thermometers

## 💡 Best Practices for Your Application

### Rate Limit Management
1. **Implement Request Queuing**: Don't send rapid consecutive requests
2. **Batch Operations**: Group multiple changes when possible  
3. **Cache State**: Store device states locally to avoid unnecessary queries
4. **Exponential Backoff**: Implement retry logic with increasing delays
5. **Monitor Headers**: Check rate limit headers in responses

### Trigger Design Considerations
- **Debounce Triggers**: Avoid rapid-fire changes from sensitive triggers
- **State Diffing**: Only send commands when state actually needs to change
- **Priority System**: Important triggers should take precedence
- **Fallback Logic**: Handle API failures gracefully

### Security
- **Secure API Key Storage**: Never commit keys to repositories
- **Environment Variables**: Use secure environment variable storage
- **HTTPS Only**: All API calls are over HTTPS
- **Request Validation**: Validate all input parameters

## 🔧 Development Tools & Libraries

### Official Resources
- **Developer Portal**: https://developer.govee.com/
- **Postman Collection**: Available in Program Smart Lights workspace
- **Community Forum**: https://community.govee.com

### Third-Party Libraries
- **Python**: `govee-api-laggat` (PyPI)
- **Home Assistant**: Official integration available
- **Power Automate**: Microsoft connector available

## 📊 Monitoring & Debugging

### Request Logging
- Always log `requestId` for tracking
- Monitor response times and error rates
- Track rate limit usage patterns

### Testing Strategies
- Use unique `requestId` values for each request
- Test rate limit handling thoroughly
- Validate device capabilities before sending commands
- Test with actual hardware, not just API simulation

## 🎯 Example Use Cases for Your Floor Lamp

### Time-Based Triggers
```javascript
// Morning routine - warm white
{
  "type": "devices.capabilities.color_setting",
  "instance": "colorTemperatureK", 
  "value": 3000
}

// Evening - cool blue
{
  "type": "devices.capabilities.color_setting",
  "instance": "colorRgb",
  "value": {"r": 0, "g": 100, "b": 255}
}
```

### System Event Triggers
```javascript
// High CPU usage - red warning
{
  "type": "devices.capabilities.color_setting", 
  "instance": "colorRgb",
  "value": {"r": 255, "g": 0, "b": 0}
}

// Low battery - amber alert
{
  "type": "devices.capabilities.color_setting",
  "instance": "colorRgb", 
  "value": {"r": 255, "g": 191, "b": 0}
}
```

### Calendar Integration
```javascript
// Meeting in progress - do not disturb purple
{
  "type": "devices.capabilities.color_setting",
  "instance": "colorRgb",
  "value": {"r": 128, "g": 0, "b": 128}
}
```

This comprehensive guide should give you everything needed to successfully integrate with the Govee API for your smart lighting application!