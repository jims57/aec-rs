//
//  LibAecFramework_C.c
//  Pure C implementation for iOS AEC Framework
//

#include "LibAecFramework.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

// Include the iOS-compatible header directly
#include "libaec_ios.h"

// ============================================================================
// MARK: - Stream Context Implementation (C version)
// ============================================================================

struct AecStreamContext {
    Aec *aec_instance;
    uint32_t sample_rate;
    uint32_t frame_size;
    int enable_preprocess;
};

// ============================================================================
// MARK: - Enhanced iOS Integration Functions
// ============================================================================

Aec *AecNewForRealtimeIOS(uint32_t sample_rate, bool enable_preprocess) {
    uint32_t frame_size = AecGetRecommendedFrameSize(sample_rate);
    uint32_t filter_length = AecGetRecommendedFilterLength(sample_rate);
    
    return AecNew(frame_size, filter_length, sample_rate, enable_preprocess);
}

Aec *AecNewForFileProcessing(uint32_t sample_rate, bool enable_preprocess) {
    // For file processing, we can use a larger filter length for better quality
    uint32_t frame_size = AecGetRecommendedFrameSize(sample_rate);
    uint32_t filter_length = AecGetRecommendedFilterLength(sample_rate) * 2; // Double for file processing
    
    return AecNew(frame_size, filter_length, sample_rate, enable_preprocess);
}

int AecProcessAudioFiles(Aec *aec_ptr,
                        const int16_t *rec_samples,
                        const int16_t *echo_samples,
                        int16_t *out_samples,
                        size_t num_samples) {
    if (!aec_ptr || !rec_samples || !echo_samples || !out_samples) {
        return -1; // Invalid parameters
    }
    
    // Process the audio in frame-sized chunks
    uint32_t frame_size = AecGetRecommendedFrameSize(16000); // Default frame size
    
    for (size_t i = 0; i < num_samples; i += frame_size) {
        size_t current_frame_size = (frame_size < (num_samples - i)) ? frame_size : (num_samples - i);
        
        AecCancelEcho(aec_ptr,
                     &rec_samples[i],
                     &echo_samples[i],
                     &out_samples[i],
                     current_frame_size);
    }
    
    return 0; // Success
}

uint32_t AecGetRecommendedFrameSize(uint32_t sample_rate) {
    // Frame size for 10ms at different sample rates
    switch (sample_rate) {
        case 8000:  return 80;
        case 16000: return 160;
        case 24000: return 240;
        case 32000: return 320;
        case 44100: return 441;  // ~10ms
        case 48000: return 480;
        default:    return (sample_rate / 100); // 10ms default
    }
}

uint32_t AecGetRecommendedFilterLength(uint32_t sample_rate) {
    // Filter length for 100ms at different sample rates
    switch (sample_rate) {
        case 8000:  return 800;
        case 16000: return 1600;
        case 24000: return 2400;
        case 32000: return 3200;
        case 44100: return 4410;
        case 48000: return 4800;
        default:    return (sample_rate / 10); // 100ms default
    }
}

// ============================================================================
// MARK: - Real-time Streaming API Implementation
// ============================================================================

AecStreamContext *AecCreateStreamContext(uint32_t sample_rate, bool enable_preprocess) {
    AecStreamContext *ctx = (AecStreamContext*)malloc(sizeof(AecStreamContext));
    if (!ctx) return NULL;
    
    ctx->sample_rate = sample_rate;
    ctx->enable_preprocess = enable_preprocess ? 1 : 0;
    ctx->frame_size = AecGetRecommendedFrameSize(sample_rate);
    
    uint32_t filter_length = AecGetRecommendedFilterLength(sample_rate);
    ctx->aec_instance = AecNew(ctx->frame_size, filter_length, sample_rate, enable_preprocess);
    
    if (!ctx->aec_instance) {
        free(ctx);
        return NULL;
    }
    
    return ctx;
}

int AecProcessStreamChunk(AecStreamContext *stream_ctx,
                         const int16_t *rec_chunk,
                         const int16_t *echo_chunk,
                         int16_t *out_chunk,
                         size_t chunk_size) {
    if (!stream_ctx || !stream_ctx->aec_instance || !rec_chunk || !echo_chunk || !out_chunk) {
        return -1; // Invalid parameters
    }
    
    // Process the chunk directly
    AecCancelEcho(stream_ctx->aec_instance,
                 rec_chunk,
                 echo_chunk,
                 out_chunk,
                 chunk_size);
    
    return 0; // Success
}

void AecResetStreamContext(AecStreamContext *stream_ctx) {
    if (stream_ctx && stream_ctx->aec_instance) {
        // Destroy and recreate the AEC instance to reset state
        AecDestroy(stream_ctx->aec_instance);
        
        uint32_t filter_length = AecGetRecommendedFilterLength(stream_ctx->sample_rate);
        stream_ctx->aec_instance = AecNew(stream_ctx->frame_size, 
                                         filter_length,
                                         stream_ctx->sample_rate,
                                         stream_ctx->enable_preprocess);
    }
}

void AecDestroyStreamContext(AecStreamContext *stream_ctx) {
    if (stream_ctx) {
        if (stream_ctx->aec_instance) {
            AecDestroy(stream_ctx->aec_instance);
        }
        free(stream_ctx);
    }
}

// ============================================================================
// MARK: - Utility Functions Implementation
// ============================================================================

const char *AecGetVersion(void) {
    return "aec-rs-ios-1.0.0";
}

bool AecIsSampleRateSupported(uint32_t sample_rate) {
    switch (sample_rate) {
        case 8000:
        case 16000:
        case 24000:
        case 32000:
        case 44100:
        case 48000:
            return true;
        default:
            return false;
    }
}

void AecFloatToInt16(const float *float_samples, int16_t *int16_samples, size_t num_samples) {
    for (size_t i = 0; i < num_samples; i++) {
        float sample = float_samples[i];
        // Clamp to [-1.0, 1.0] range
        if (sample > 1.0f) sample = 1.0f;
        if (sample < -1.0f) sample = -1.0f;
        // Convert to int16 range
        int16_samples[i] = (int16_t)(sample * 32767.0f);
    }
}

void AecInt16ToFloat(const int16_t *int16_samples, float *float_samples, size_t num_samples) {
    for (size_t i = 0; i < num_samples; i++) {
        float_samples[i] = (float)(int16_samples[i]) / 32767.0f;
    }
}
