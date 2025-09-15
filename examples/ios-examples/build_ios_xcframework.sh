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
FRAMEWORK_NAME="LibWqAec"
LIBRARY_NAME="libaec"
BUILD_DIR="build"
XCFRAMEWORK_DIR="xcframework"
IOS_PROJECT_PATH="/Users/mac/Documents/GitHub/ios_use_cpp_demo/iOSUseCppDemo1"

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

if [ ! -f "LibAecFramework_C.c" ]; then
    echo -e "${RED}❌ LibAecFramework_C.c not found${NC}"
    exit 1
fi

# Check if iOS project path exists
if [ ! -d "${IOS_PROJECT_PATH}" ]; then
    echo -e "${YELLOW}⚠️  iOS project path not found: ${IOS_PROJECT_PATH}${NC}"
    echo -e "${YELLOW}XCFramework will be built but not copied to iOS project${NC}"
fi

echo -e "${BLUE}📦 Building SpeexDSP for iOS Device (arm64)...${NC}"

# Build SpeexDSP first
SPEEX_BUILD_DIR="${BUILD_DIR}/speexdsp-ios"
mkdir -p ${SPEEX_BUILD_DIR}
cd ${SPEEX_BUILD_DIR}

# Configure and build SpeexDSP for iOS arm64
cmake /Users/mac/Documents/GitHub/aec-rs/crates/aec-rs-sys/speexdsp \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_SYSROOT=$(xcrun --sdk iphoneos --show-sdk-path) \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=12.0 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS="-arch arm64" \
    -DENABLE_FLOAT_API=ON \
    -DENABLE_FIXED_POINT=OFF

make -j$(sysctl -n hw.ncpu)

cd ../..

echo -e "${BLUE}📦 Building LibWqAec for iOS Device (arm64)...${NC}"

# iOS Device (arm64) build
IOS_DEVICE_DIR="${BUILD_DIR}/ios-device"
mkdir -p ${IOS_DEVICE_DIR}

# Compile the C wrapper for iOS device
clang -c LibAecFramework_C.c \
    -o ${IOS_DEVICE_DIR}/LibAecFramework.o \
    -arch arm64 \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -mios-version-min=12.0 \
    -std=c99 \
    -O2 \
    -I. \
    -Ilibaec-ios-aarch64

# Extract object files from the original static library
cd ${IOS_DEVICE_DIR}
ar x ../../libaec-ios-aarch64/libaec.a
cd ../..

# Create combined static library for iOS device (include SpeexDSP)
if [ -f "${SPEEX_BUILD_DIR}/libspeexdsp.a" ]; then
    echo -e "${GREEN}✅ Including SpeexDSP library${NC}"
    # Extract SpeexDSP objects
    cd ${IOS_DEVICE_DIR}
    ar x ../${SPEEX_BUILD_DIR#${BUILD_DIR}/}/libspeexdsp.a
    cd ../..
else
    echo -e "${YELLOW}⚠️  SpeexDSP library not found at expected location, searching...${NC}"
    # Look for library in build directory and include it
    SPEEX_LIB=$(find ${SPEEX_BUILD_DIR} -name "libspeexdsp.a" | head -1)
    if [ -n "$SPEEX_LIB" ]; then
        echo -e "${GREEN}✅ Found SpeexDSP library at: $SPEEX_LIB${NC}"
        cd ${IOS_DEVICE_DIR}
        ar x "$SPEEX_LIB"
        cd ../..
    else
        echo -e "${RED}❌ SpeexDSP library not found${NC}"
    fi
fi

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
cp libaec_ios.h ${IOS_DEVICE_FRAMEWORK_DIR}/Headers/libaec.h

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
    umbrella header "LibAecFramework.h"
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

# Copy XCFramework to iOS project if path exists
if [ -d "${IOS_PROJECT_PATH}" ]; then
    echo -e "${YELLOW}📁 Copying XCFramework to iOS project...${NC}"
    
    # Remove old framework if it exists
    rm -rf "${IOS_PROJECT_PATH}/${FRAMEWORK_NAME}.xcframework"
    
    # Copy new framework
    cp -R "${FRAMEWORK_NAME}.xcframework" "${IOS_PROJECT_PATH}/"
    
    if [ -d "${IOS_PROJECT_PATH}/${FRAMEWORK_NAME}.xcframework" ]; then
        echo -e "${GREEN}✅ XCFramework copied to iOS project successfully!${NC}"
        echo -e "${GREEN}📍 Location: ${IOS_PROJECT_PATH}/${FRAMEWORK_NAME}.xcframework${NC}"
    else
        echo -e "${RED}❌ Failed to copy XCFramework to iOS project${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Skipping copy to iOS project (path not found)${NC}"
fi

echo -e "${GREEN}✨ All done! Your iOS XCFramework is ready.${NC}"
