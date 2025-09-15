//
//  ViewController_AEC_Example.m
//  iOS AEC Integration Example
//
//  This shows how to integrate AEC functionality into your existing iOS app
//

#import "ViewController_AEC_Example.h"
#import <LibAecFramework/LibAecFramework.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController () {
    // AEC-related properties
    Aec *aecInstance;
    AecStreamContext *streamContext;
    uint32_t sampleRate;
    uint32_t frameSize;
    
    // Audio-related properties
    AVAudioEngine *audioEngine;
    AVAudioInputNode *inputNode;
    AVAudioPlayerNode *playerNode;
    
    // UI properties
    BOOL isAECActive;
}

@property (nonatomic, strong) UIButton *noiseReductionButton;
@property (nonatomic, strong) UIButton *aecButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *versionLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize AEC settings
    sampleRate = 16000; // 16kHz for voice processing
    frameSize = AecGetRecommendedFrameSize(sampleRate);
    isAECActive = NO;
    
    [self setupUI];
    [self initializeAEC];
    [self setupAudioEngine];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // AEC version label
    self.versionLabel = [[UILabel alloc] init];
    self.versionLabel.text = [NSString stringWithFormat:@"AEC Version: %s", AecGetVersion()];
    self.versionLabel.font = [UIFont systemFontOfSize:14];
    self.versionLabel.textColor = [UIColor systemGrayColor];
    self.versionLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.versionLabel];
    
    // Status label
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"AEC Ready";
    self.statusLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.statusLabel.textColor = [UIColor systemBlueColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
    
    // Original noise reduction button
    self.noiseReductionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.noiseReductionButton setTitle:@"降噪C++" forState:UIControlStateNormal];
    [self.noiseReductionButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    self.noiseReductionButton.titleLabel.font = [UIFont systemFontOfSize:18];
    self.noiseReductionButton.layer.borderWidth = 1.0;
    self.noiseReductionButton.layer.borderColor = [UIColor systemBlueColor].CGColor;
    self.noiseReductionButton.layer.cornerRadius = 8.0;
    [self.noiseReductionButton addTarget:self 
                                  action:@selector(noiseReductionButtonTapped:) 
                        forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.noiseReductionButton];
    
    // New AEC button
    self.aecButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.aecButton setTitle:@"回声消除 (AEC)" forState:UIControlStateNormal];
    [self.aecButton setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
    self.aecButton.titleLabel.font = [UIFont systemFontOfSize:18];
    self.aecButton.layer.borderWidth = 1.0;
    self.aecButton.layer.borderColor = [UIColor systemGreenColor].CGColor;
    self.aecButton.layer.cornerRadius = 8.0;
    [self.aecButton addTarget:self 
                       action:@selector(aecButtonTapped:) 
             forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.aecButton];
    
    // Setup constraints
    [self setupConstraints];
}

- (void)setupConstraints {
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.noiseReductionButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.aecButton.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        // Version label at top
        [self.versionLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.versionLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        
        // Status label
        [self.statusLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.versionLabel.bottomAnchor constant:20],
        
        // Original noise reduction button
        [self.noiseReductionButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.noiseReductionButton.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-40],
        [self.noiseReductionButton.widthAnchor constraintEqualToConstant:200],
        [self.noiseReductionButton.heightAnchor constraintEqualToConstant:50],
        
        // New AEC button
        [self.aecButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.aecButton.topAnchor constraintEqualToAnchor:self.noiseReductionButton.bottomAnchor constant:20],
        [self.aecButton.widthAnchor constraintEqualToConstant:200],
        [self.aecButton.heightAnchor constraintEqualToConstant:50]
    ]];
}

- (void)initializeAEC {
    // Check if sample rate is supported
    if (!AecIsSampleRateSupported(sampleRate)) {
        NSLog(@"Sample rate %u not supported, falling back to 16kHz", sampleRate);
        sampleRate = 16000;
        frameSize = AecGetRecommendedFrameSize(sampleRate);
    }
    
    // Initialize AEC instance for real-time processing
    aecInstance = AecNewForRealtimeIOS(sampleRate, true); // Enable noise suppression
    
    if (aecInstance) {
        NSLog(@"AEC initialized successfully - Sample Rate: %u, Frame Size: %u", sampleRate, frameSize);
        self.statusLabel.text = [NSString stringWithFormat:@"AEC Ready (%ukHz)", sampleRate/1000];
    } else {
        NSLog(@"Failed to initialize AEC");
        self.statusLabel.text = @"AEC Initialization Failed";
        self.statusLabel.textColor = [UIColor systemRedColor];
    }
    
    // Create streaming context for continuous processing
    streamContext = AecCreateStreamContext(sampleRate, true);
    if (!streamContext) {
        NSLog(@"Failed to create streaming context");
    }
}

- (void)setupAudioEngine {
    self.audioEngine = [[AVAudioEngine alloc] init];
    self.inputNode = [self.audioEngine inputNode];
    self.playerNode = [[AVAudioPlayerNode alloc] init];
    
    [self.audioEngine attachNode:self.playerNode];
    
    // Configure audio format for AEC
    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatInt16
                                                             sampleRate:sampleRate
                                                               channels:1
                                                            interleaved:YES];
    
    if (format) {
        NSLog(@"Audio format configured: %@ Hz, %d channels", @(format.sampleRate), format.channelCount);
    }
}

- (void)noiseReductionButtonTapped:(UIButton *)sender {
    NSLog(@"降噪C++ button tapped!");
    
    // Demonstrate AEC file processing functionality
    [self demonstrateFileProcessing];
}

- (void)aecButtonTapped:(UIButton *)sender {
    if (!isAECActive) {
        [self startAECProcessing];
        isAECActive = YES;
        [self.aecButton setTitle:@"停止 AEC" forState:UIControlStateNormal];
        [self.aecButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        self.aecButton.layer.borderColor = [UIColor systemRedColor].CGColor;
        self.statusLabel.text = @"AEC Active";
        self.statusLabel.textColor = [UIColor systemGreenColor];
    } else {
        [self stopAECProcessing];
        isAECActive = NO;
        [self.aecButton setTitle:@"回声消除 (AEC)" forState:UIControlStateNormal];
        [self.aecButton setTitleColor:[UIColor systemGreenColor] forState:UIControlStateNormal];
        self.aecButton.layer.borderColor = [UIColor systemGreenColor].CGColor;
        self.statusLabel.text = @"AEC Stopped";
        self.statusLabel.textColor = [UIColor systemOrangeColor];
    }
}

- (void)demonstrateFileProcessing {
    if (!aecInstance) {
        NSLog(@"AEC not initialized");
        return;
    }
    
    // Create sample audio data for demonstration
    size_t numSamples = frameSize * 10; // 10 frames worth of data
    int16_t *recordedAudio = calloc(numSamples, sizeof(int16_t));
    int16_t *referenceAudio = calloc(numSamples, sizeof(int16_t));
    int16_t *outputAudio = calloc(numSamples, sizeof(int16_t));
    
    // Generate some test audio data
    for (size_t i = 0; i < numSamples; i++) {
        recordedAudio[i] = (int16_t)(sin(2.0 * M_PI * 440.0 * i / sampleRate) * 16000); // 440Hz tone
        referenceAudio[i] = (int16_t)(sin(2.0 * M_PI * 880.0 * i / sampleRate) * 8000); // 880Hz reference
    }
    
    // Process with AEC
    int result = AecProcessAudioFiles(aecInstance, recordedAudio, referenceAudio, outputAudio, numSamples);
    
    if (result == 0) {
        NSLog(@"File processing demo successful - processed %zu samples", numSamples);
        
        // Show some stats
        dispatch_async(dispatch_get_main_queue(), ^{
            self.statusLabel.text = [NSString stringWithFormat:@"Processed %zu samples", numSamples];
        });
    } else {
        NSLog(@"File processing demo failed");
    }
    
    // Cleanup
    free(recordedAudio);
    free(referenceAudio);
    free(outputAudio);
}

- (void)startAECProcessing {
    if (!streamContext) {
        NSLog(@"Stream context not available");
        return;
    }
    
    // Reset the streaming context
    AecResetStreamContext(streamContext);
    
    NSLog(@"AEC real-time processing started");
    
    // In a real implementation, you would start your audio capture/playback here
    // and call processAudioFrame:speakerData:outputData: for each audio frame
    
    // Simulate some processing for demonstration
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self simulateRealtimeProcessing];
    });
}

- (void)stopAECProcessing {
    NSLog(@"AEC real-time processing stopped");
    
    // In a real implementation, you would stop your audio capture/playback here
}

- (void)simulateRealtimeProcessing {
    // This simulates real-time AEC processing for demonstration
    for (int frame = 0; frame < 100 && isAECActive; frame++) {
        int16_t *micData = calloc(frameSize, sizeof(int16_t));
        int16_t *speakerData = calloc(frameSize, sizeof(int16_t));
        int16_t *outputData = calloc(frameSize, sizeof(int16_t));
        
        // Generate test audio for this frame
        for (uint32_t i = 0; i < frameSize; i++) {
            micData[i] = (int16_t)(sin(2.0 * M_PI * 440.0 * (frame * frameSize + i) / sampleRate) * 16000);
            speakerData[i] = (int16_t)(sin(2.0 * M_PI * 880.0 * (frame * frameSize + i) / sampleRate) * 8000);
        }
        
        // Process with streaming AEC
        int result = AecProcessStreamChunk(streamContext, micData, speakerData, outputData, frameSize);
        
        if (result == 0 && frame % 20 == 0) { // Log every 20th frame
            NSLog(@"Processed frame %d successfully", frame);
        }
        
        free(micData);
        free(speakerData);
        free(outputData);
        
        // Simulate frame timing (10ms for 16kHz)
        usleep(10000); // 10ms
    }
}

- (void)processAudioFrame:(int16_t *)microphoneData 
               speakerData:(int16_t *)speakerData 
                outputData:(int16_t *)outputData {
    // This method would be called by your audio processing pipeline
    if (aecInstance && isAECActive) {
        AecCancelEcho(aecInstance, microphoneData, speakerData, outputData, frameSize);
    }
}

- (void)dealloc {
    // Cleanup AEC resources
    if (aecInstance) {
        AecDestroy(aecInstance);
        aecInstance = NULL;
    }
    
    if (streamContext) {
        AecDestroyStreamContext(streamContext);
        streamContext = NULL;
    }
    
    // Stop audio engine
    if (self.audioEngine.isRunning) {
        [self.audioEngine stop];
    }
}

@end
