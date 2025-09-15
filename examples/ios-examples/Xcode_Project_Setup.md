# Xcode Project Setup for LibWqAec Framework

## 🚀 Required Xcode Project Settings

### 1. Add XCFramework to Project

1. **Drag LibWqAec.xcframework** into your Xcode project navigator
2. **Target Settings** → **General** → **Frameworks, Libraries, and Embedded Content**
3. **Add LibWqAec.xcframework** and set to **"Do Not Embed"** (static framework)

### 2. Add Required System Frameworks

In **Build Phases** → **Link Binary With Libraries**, add these frameworks:

```
✅ Required Frameworks:
- AudioToolbox.framework
- AVFoundation.framework
- CoreAudio.framework
- Foundation.framework
- UIKit.framework
```

### 3. Add Audio Files to Bundle

1. **Add files from `audios/` folder** to your Xcode project
2. **Ensure they're added to the app target** (check target membership)
3. **Required files:**
   - `rec.wav`
   - `echo.wav` 
   - Other WAV files for testing

### 4. Build Settings Configuration

#### **Search Paths:**
- **Framework Search Paths**: Add `$(PROJECT_DIR)` (where LibWqAec.xcframework is located)
- **Header Search Paths**: Add `$(PROJECT_DIR)/LibWqAec.xcframework/ios-arm64/LibWqAec.framework/Headers`

#### **Linking:**
- **Other Linker Flags**: Add `-ObjC` (for static library loading)

#### **Architecture:**
- **Architectures**: `arm64` (device only)
- **Valid Architectures**: `arm64`

### 5. Code Signing & Capabilities

#### **Capabilities** (if needed):
- **Microphone Usage**: Already configured in Info.plist
- **Background App Refresh**: If using real-time processing

### 6. Deployment Target

- **iOS Deployment Target**: `12.0` or higher

## 🔧 Build Configuration

### Debug Configuration:
```
ENABLE_BITCODE = NO (for static libraries)
ONLY_ACTIVE_ARCH = YES
VALID_ARCHS = arm64
```

### Release Configuration:
```
ENABLE_BITCODE = NO
ONLY_ACTIVE_ARCH = NO
VALID_ARCHS = arm64
```

## 📱 Testing Steps

1. **Build for Device**: Select a real iOS device (not simulator)
2. **Run the app**
3. **Test File Processing**: Tap "文件AEC处理" 
4. **Test Real-time**: Tap "实时AEC处理"

## 🐛 Troubleshooting

### If you still get linking errors:

1. **Clean Build Folder**: Product → Clean Build Folder
2. **Check Framework Path**: Ensure XCFramework is in project directory
3. **Verify Target Membership**: XCFramework and audio files must be added to app target
4. **Framework Order**: Move LibWqAec to top of "Link Binary With Libraries"

### Common Issues:

- **"Framework not found"**: Check Framework Search Paths
- **"Undefined symbols"**: Add missing system frameworks
- **"Module not found"**: Verify Header Search Paths
- **"Audio files not found"**: Check bundle resource membership

## ✅ Expected Behavior After Setup

- **App launches** with AEC version displayed
- **File Processing** loads WAV files and processes them
- **Real-time Processing** shows frame-by-frame progress
- **Status updates** in Chinese
- **No crashes** or linking errors

The setup should work perfectly with the rebuilt pure C XCFramework!
