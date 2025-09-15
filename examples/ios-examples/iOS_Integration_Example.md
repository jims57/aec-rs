# iOS AEC Integration Guide

## Overview
This guide shows how to integrate the `LibAecFramework.xcframework` into your iOS app for acoustic echo cancellation (AEC).

## Integration Steps

### 1. Add Framework to Xcode Project
1. Drag `LibAecFramework.xcframework` into your Xcode project
2. In target settings, add it to "Frameworks, Libraries, and Embedded Content"
3. Set to "Do Not Embed" (it's a static framework)

### 2. Import Headers
```objc
#import <LibAecFramework/LibAecFramework.h>
// Or just the core API:
// #import <LibAecFramework/libaec.h>
```

### 3. Add Microphone Permission
In your `Info.plist`, add:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access for echo cancellation</string>
```

## Usage Examples

### Real-time AEC (Recommended for Live Calls)

```objc
@interface ViewController () {
    Aec *aecInstance;
    uint32_t frameSize;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize AEC for real-time processing
    uint32_t sampleRate = 16000; // 16kHz
    aecInstance = AecNewForRealtimeIOS(sampleRate, true); // Enable noise suppression
    frameSize = AecGetRecommendedFrameSize(sampleRate); // Usually 160 samples for 16kHz
    
    if (!aecInstance) {
        NSLog(@"Failed to create AEC instance");
        return;
    }
    
    NSLog(@"AEC initialized with frame size: %u", frameSize);
}

- (void)processAudioFrame:(int16_t *)microphoneData 
                speakerData:(int16_t *)speakerData 
                   outputData:(int16_t *)outputData {
    
    if (aecInstance) {
        // Process one frame of audio
        AecCancelEcho(aecInstance, 
                     microphoneData,  // Recorded audio from microphone
                     speakerData,     // Reference audio played through speaker
                     outputData,      // Output processed audio
                     frameSize);      // Frame size in samples
    }
}

- (void)dealloc {
    if (aecInstance) {
        AecDestroy(aecInstance);
        aecInstance = NULL;
    }
}

@end
```

### File Processing AEC (For Processing Recorded Files)

```objc
- (void)processAudioFiles {
    // Initialize AEC for file processing (better quality, slower)
    Aec *fileAec = AecNewForFileProcessing(16000, true);
    
    if (!fileAec) {
        NSLog(@"Failed to create file processing AEC");
        return;
    }
    
    // Assume you have audio data loaded
    size_t numSamples = 16000; // 1 second of 16kHz audio
    int16_t *recordedAudio = malloc(numSamples * sizeof(int16_t));
    int16_t *referenceAudio = malloc(numSamples * sizeof(int16_t));
    int16_t *outputAudio = malloc(numSamples * sizeof(int16_t));
    
    // Load your audio data here...
    // [self loadAudioData:recordedAudio reference:referenceAudio numSamples:numSamples];
    
    // Process the entire audio file
    int result = AecProcessAudioFiles(fileAec, 
                                     recordedAudio, 
                                     referenceAudio, 
                                     outputAudio, 
                                     numSamples);
    
    if (result == 0) {
        NSLog(@"Audio file processing successful");
        // Save or play the processed audio
    } else {
        NSLog(@"Audio file processing failed");
    }
    
    // Cleanup
    free(recordedAudio);
    free(referenceAudio);
    free(outputAudio);
    AecDestroy(fileAec);
}
```

### Streaming AEC (For Continuous Audio Processing)

```objc
@interface ViewController () {
    AecStreamContext *streamContext;
}
@end

@implementation ViewController

- (void)startStreamingAEC {
    // Create streaming context
    streamContext = AecCreateStreamContext(16000, true);
    
    if (!streamContext) {
        NSLog(@"Failed to create streaming context");
        return;
    }
    
    NSLog(@"Streaming AEC started");
}

- (void)processStreamingChunk:(int16_t *)micData 
                   speakerData:(int16_t *)spkData 
                          size:(size_t)chunkSize {
    
    if (streamContext) {
        int16_t *outputData = malloc(chunkSize * sizeof(int16_t));
        
        int result = AecProcessStreamChunk(streamContext,
                                          micData,
                                          spkData,
                                          outputData,
                                          chunkSize);
        
        if (result == 0) {
            // Use the processed audio data
            [self playProcessedAudio:outputData size:chunkSize];
        }
        
        free(outputData);
    }
}

- (void)resetAECState {
    if (streamContext) {
        AecResetStreamContext(streamContext);
        NSLog(@"AEC state reset");
    }
}

- (void)stopStreamingAEC {
    if (streamContext) {
        AecDestroyStreamContext(streamContext);
        streamContext = NULL;
        NSLog(@"Streaming AEC stopped");
    }
}

@end
```

## Utility Functions

### Audio Format Conversion
```objc
// Convert float audio to int16 (if needed)
- (void)convertFloatToInt16:(float *)floatSamples 
                    toInt16:(int16_t *)int16Samples 
                      count:(size_t)sampleCount {
    AecFloatToInt16(floatSamples, int16Samples, sampleCount);
}

// Convert int16 audio to float (if needed)
- (void)convertInt16ToFloat:(int16_t *)int16Samples 
                    toFloat:(float *)floatSamples 
                      count:(size_t)sampleCount {
    AecInt16ToFloat(int16Samples, floatSamples, sampleCount);
}
```

### Sample Rate Support Check
```objc
- (BOOL)isSampleRateSupported:(uint32_t)sampleRate {
    return AecIsSampleRateSupported(sampleRate);
}

- (uint32_t)getRecommendedFrameSize:(uint32_t)sampleRate {
    return AecGetRecommendedFrameSize(sampleRate);
}
```

## Integration with Audio Units / AVAudioEngine

### Basic AVAudioEngine Integration
```objc
@property (nonatomic, strong) AVAudioEngine *audioEngine;
@property (nonatomic, strong) AVAudioInputNode *inputNode;
@property (nonatomic, strong) AVAudioPlayerNode *playerNode;

- (void)setupAudioEngine {
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.inputNode = [self.audioEngine inputNode];
    self.playerNode = [[AVAudioPlayerNode alloc] init];
    
    [self.audioEngine attachNode:self.playerNode];
    
    // Set up audio format (16kHz, 1 channel, int16)
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                             sampleRate:16000
                                                               channels:1
                                                            interleaved:YES];
    
    // Install input tap for microphone data
    [self.inputNode installTapOnBus:0
                         bufferSize:frameSize
                             format:format
                              block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        // Process the microphone data with AEC here
        [self processInputBuffer:buffer];
    }];
}
```

## Performance Tips

1. **Frame Size**: Use recommended frame sizes (160 for 16kHz, 480 for 48kHz)
2. **Sample Rate**: 16kHz is optimal for voice, 48kHz for high-quality audio
3. **Real-time vs File**: Use real-time mode for live calls, file mode for better quality processing
4. **Memory**: Always call `AecDestroy()` to prevent memory leaks
5. **Threading**: AEC processing is CPU-intensive, consider running on a background queue

## Troubleshooting

### Common Issues
- **No AEC effect**: Ensure reference audio (speaker output) is correctly aligned with microphone input
- **Distorted audio**: Check sample rate matching between input and AEC instance
- **High CPU usage**: Reduce frame size or sample rate for real-time processing
- **Memory leaks**: Always destroy AEC instances when done

### Debugging
```objc
// Check AEC version
NSString *version = [NSString stringWithUTF8String:AecGetVersion()];
NSLog(@"AEC Version: %@", version);

// Verify sample rate support
if (!AecIsSampleRateSupported(44100)) {
    NSLog(@"44.1kHz not supported, using 16kHz instead");
}
```

## Next Steps

1. **Add Simulator Support**: Request x86_64 precompiled libraries for full simulator support
2. **Audio Session**: Configure `AVAudioSession` for optimal echo cancellation
3. **Real-time Processing**: Integrate with `AudioUnit` for lower latency
4. **Quality Testing**: Test with various audio scenarios and environments

The framework is now ready for production use in iOS apps requiring acoustic echo cancellation!
