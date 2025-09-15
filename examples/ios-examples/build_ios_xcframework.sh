#!/bin/bash

# Exit on any error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Building aec-rs iOS XCFramework...${NC}"

# Configuration
FRAMEWORK_NAME="LibAecFramework"
LIBRARY_NAME="libaec"
BUILD_DIR="build"
XCFRAMEWORK_DIR="xcframework"

# Clean previous builds
echo -e "${YELLOW}🧹 Cleaning previous builds...${NC}"
rm -rf ${BUILD_DIR}
rm -rf ${XCFRAMEWORK_DIR}
rm -rf ${FRAMEWORK_NAME}.xcframework

# Create build directories
mkdir -p ${BUILD_DIR}
mkdir -p ${XCFRAMEWORK_DIR}

# Verify source files exist
if [ ! -f "libaec-ios-aarch64/libaec.a" ]; then
    echo -e "${RED}❌ libaec.a not found in libaec-ios-aarch64/${NC}"
    exit 1
fi

if [ ! -f "libaec-ios-aarch64/libaec.h" ]; then
    echo -e "${RED}❌ libaec.h not found in libaec-ios-aarch64/${NC}"
    exit 1
fi

if [ ! -f "LibAecFramework.h" ]; then
    echo -e "${RED}❌ LibAecFramework.h not found${NC}"
    exit 1
fi

if [ ! -f "LibAecFramework.cpp" ]; then
    echo -e "${RED}❌ LibAecFramework.cpp not found${NC}"
    exit 1
fi

echo -e "${BLUE}📦 Building for iOS Device (arm64)...${NC}"

# iOS Device (arm64) build
IOS_DEVICE_DIR="${BUILD_DIR}/ios-device"
mkdir -p ${IOS_DEVICE_DIR}

# Compile the C++ wrapper for iOS device
clang++ -c LibAecFramework.cpp \
    -o ${IOS_DEVICE_DIR}/LibAecFramework.o \
    -arch arm64 \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -mios-version-min=12.0 \
    -stdlib=libc++ \
    -std=c++17 \
    -O2 \
    -I. \
    -Ilibaec-ios-aarch64

# Extract object files from the original static library
cd ${IOS_DEVICE_DIR}
ar x ../../libaec-ios-aarch64/libaec.a
cd ../..

# Create combined static library for iOS device
ar rcs ${IOS_DEVICE_DIR}/lib${FRAMEWORK_NAME}.a \
    ${IOS_DEVICE_DIR}/*.o

# Note: Creating device-only XCFramework since we only have arm64 precompiled library
# For simulator support, you would need x86_64 and arm64 simulator-specific libraries

echo -e "${YELLOW}🏗️  Creating Framework structures...${NC}"

# Create Framework structure for iOS Device
IOS_DEVICE_FRAMEWORK_DIR="${XCFRAMEWORK_DIR}/ios-device/${FRAMEWORK_NAME}.framework"
mkdir -p ${IOS_DEVICE_FRAMEWORK_DIR}/Headers
mkdir -p ${IOS_DEVICE_FRAMEWORK_DIR}/Modules

# Copy static library and rename
cp ${IOS_DEVICE_DIR}/lib${FRAMEWORK_NAME}.a ${IOS_DEVICE_FRAMEWORK_DIR}/${FRAMEWORK_NAME}

# Copy headers to framework headers folder
cp LibAecFramework.h ${IOS_DEVICE_FRAMEWORK_DIR}/Headers/
cp libaec-ios-aarch64/libaec.h ${IOS_DEVICE_FRAMEWORK_DIR}/Headers/

# Create Info.plist for iOS Device
cat > ${IOS_DEVICE_FRAMEWORK_DIR}/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.aecrs.${FRAMEWORK_NAME}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${FRAMEWORK_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>12.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>iPhoneOS</string>
    </array>
</dict>
</plist>
EOF

# Create module.modulemap for iOS Device
cat > ${IOS_DEVICE_FRAMEWORK_DIR}/Modules/module.modulemap << EOF
framework module ${FRAMEWORK_NAME} {
    umbrella header "${FRAMEWORK_NAME}.h"
    export *
    module * { export * }
    
    explicit module libaec {
        header "libaec.h"
        export *
    }
}
EOF

# Note: Simulator framework creation skipped - only device framework for now

echo -e "${YELLOW}🔨 Creating XCFramework...${NC}"

# Create XCFramework (device-only for now)
xcodebuild -create-xcframework \
    -framework ${IOS_DEVICE_FRAMEWORK_DIR} \
    -output ${FRAMEWORK_NAME}.xcframework

# Verify the XCFramework
echo -e "${YELLOW}🔍 Verifying XCFramework...${NC}"
if [ -d "${FRAMEWORK_NAME}.xcframework" ]; then
    echo -e "${GREEN}✅ XCFramework created successfully!${NC}"
    echo -e "${GREEN}📍 Location: $(pwd)/${FRAMEWORK_NAME}.xcframework${NC}"
    
    # Show framework info
    echo -e "${BLUE}📋 Framework contents:${NC}"
    find ${FRAMEWORK_NAME}.xcframework -name "*.h" -o -name "Info.plist" -o -name "module.modulemap" | head -10
    
    # Show architectures
    echo -e "${BLUE}🏗️  Supported architectures:${NC}"
    echo "iOS Device: $(lipo -info ${FRAMEWORK_NAME}.xcframework/ios-arm64/${FRAMEWORK_NAME}.framework/${FRAMEWORK_NAME} 2>/dev/null | cut -d: -f3-)"
    echo -e "${YELLOW}Note: Simulator support not included (requires additional precompiled libraries)${NC}"
    
    # Show size
    echo -e "${BLUE}📏 XCFramework size:${NC}"
    du -sh ${FRAMEWORK_NAME}.xcframework
    
    echo -e "${GREEN}🎉 Build completed successfully!${NC}"
    echo -e "${GREEN}🚀 Ready to integrate into iOS project!${NC}"
    echo ""
    echo -e "${YELLOW}📖 Usage Instructions:${NC}"
    echo "1. Drag ${FRAMEWORK_NAME}.xcframework into your Xcode project"
    echo "2. Add to 'Frameworks, Libraries, and Embedded Content'"
    echo "3. Import with: #import <${FRAMEWORK_NAME}/${FRAMEWORK_NAME}.h>"
    echo "4. Use AEC functions for real-time or file processing"
    echo ""
    echo -e "${BLUE}🔧 Example integration:${NC}"
    echo "// Real-time mode"
    echo "Aec *aec = AecNewForRealtimeIOS(16000, true);"
    echo "AecCancelEcho(aec, micBuffer, speakerBuffer, outputBuffer, frameSize);"
    echo "AecDestroy(aec);"
    echo ""
    echo "// File processing mode"
    echo "Aec *aec = AecNewForFileProcessing(16000, true);"
    echo "AecProcessAudioFiles(aec, recordedData, echoData, outputData, numSamples);"
    echo "AecDestroy(aec);"
    
else
    echo -e "${RED}❌ XCFramework creation failed!${NC}"
    exit 1
fi

# Clean intermediate files
echo -e "${YELLOW}🧹 Cleaning up intermediate files...${NC}"
rm -rf ${BUILD_DIR}
rm -rf ${XCFRAMEWORK_DIR}

echo -e "${GREEN}✨ All done! Your iOS XCFramework is ready.${NC}"
