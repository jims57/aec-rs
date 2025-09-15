//
//  LibAecFramework.cpp
//  Enhanced AEC iOS Framework Implementation
//

#include "LibAecFramework.h"
#include "libaec.h"
#include <cstring>
#include <cmath>
#include <algorithm>

// ============================================================================
// MARK: - Stream Context Implementation
// ============================================================================

struct AecStreamContext {
    Aec *aec_instance;
    uint32_t sample_rate;
    uint32_t frame_size;
    bool enable_preprocess;
    
    AecStreamContext(uint32_t sr, bool preprocess) 
        : sample_rate(sr), enable_preprocess(preprocess) {
        frame_size = AecGetRecommendedFrameSize(sr);
        uint32_t filter_length = AecGetRecommendedFilterLength(sr);
        aec_instance = AecNew(frame_size, filter_length, sr, preprocess);
    }
    
    ~AecStreamContext() {
        if (aec_instance) {
            AecDestroy(aec_instance);
        }
    }
};

// ============================================================================
// MARK: - Enhanced iOS Integration Functions
// ============================================================================

extern "C" Aec *AecNewForRealtimeIOS(uint32_t sample_rate, bool enable_preprocess) {
    uint32_t frame_size = AecGetRecommendedFrameSize(sample_rate);
    uint32_t filter_length = AecGetRecommendedFilterLength(sample_rate);
    
    return AecNew(frame_size, filter_length, sample_rate, enable_preprocess);
}

extern "C" Aec *AecNewForFileProcessing(uint32_t sample_rate, bool enable_preprocess) {
    // For file processing, we can use a larger filter length for better quality
    uint32_t frame_size = AecGetRecommendedFrameSize(sample_rate);
    uint32_t filter_length = AecGetRecommendedFilterLength(sample_rate) * 2; // Double for file processing
    
    return AecNew(frame_size, filter_length, sample_rate, enable_preprocess);
}

extern "C" int AecProcessAudioFiles(Aec *aec_ptr,
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
        size_t current_frame_size = std::min(static_cast<size_t>(frame_size), num_samples - i);
        
        AecCancelEcho(aec_ptr,
                     &rec_samples[i],
                     &echo_samples[i],
                     &out_samples[i],
                     current_frame_size);
    }
    
    return 0; // Success
}

extern "C" uint32_t AecGetRecommendedFrameSize(uint32_t sample_rate) {
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

extern "C" uint32_t AecGetRecommendedFilterLength(uint32_t sample_rate) {
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

extern "C" AecStreamContext *AecCreateStreamContext(uint32_t sample_rate, bool enable_preprocess) {
    return new AecStreamContext(sample_rate, enable_preprocess);
}

extern "C" int AecProcessStreamChunk(AecStreamContext *stream_ctx,
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

extern "C" void AecResetStreamContext(AecStreamContext *stream_ctx) {
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

extern "C" void AecDestroyStreamContext(AecStreamContext *stream_ctx) {
    if (stream_ctx) {
        delete stream_ctx;
    }
}

// ============================================================================
// MARK: - Utility Functions Implementation
// ============================================================================

extern "C" const char *AecGetVersion(void) {
    return "aec-rs-ios-1.0.0";
}

extern "C" bool AecIsSampleRateSupported(uint32_t sample_rate) {
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

extern "C" void AecFloatToInt16(const float *float_samples, int16_t *int16_samples, size_t num_samples) {
    for (size_t i = 0; i < num_samples; i++) {
        float sample = float_samples[i];
        // Clamp to [-1.0, 1.0] range
        sample = std::max(-1.0f, std::min(1.0f, sample));
        // Convert to int16 range
        int16_samples[i] = static_cast<int16_t>(sample * 32767.0f);
    }
}

extern "C" void AecInt16ToFloat(const int16_t *int16_samples, float *float_samples, size_t num_samples) {
    for (size_t i = 0; i < num_samples; i++) {
        float_samples[i] = static_cast<float>(int16_samples[i]) / 32767.0f;
    }
}
