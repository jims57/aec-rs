//
//  LibAecFramework.h
//  Enhanced AEC iOS Framework
//
//  Based on aec-rs library with real-time and non-real-time modes
//  Created for iOS integration
//

#ifndef LibAecFramework_h
#define LibAecFramework_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declaration for AEC context
typedef struct Aec Aec;

// ============================================================================
// MARK: - Core AEC Functions (from original libaec.h)
// ============================================================================

/**
 * Create a new AEC instance
 * @param frame_size Number of samples per frame (typically 160 for 16kHz, 10ms)
 * @param filter_length Length of the adaptive filter (typically 1600 for 16kHz, 100ms)
 * @param sample_rate Sample rate in Hz (e.g., 16000, 44100, 48000)
 * @param enable_preprocess Enable noise suppression preprocessing
 * @return Pointer to AEC instance, NULL on failure
 */
Aec *AecNew(uintptr_t frame_size,
            int32_t filter_length,
            uint32_t sample_rate,
            bool enable_preprocess);

/**
 * Process acoustic echo cancellation on audio buffers
 * @param aec_ptr AEC instance pointer
 * @param rec_buffer Recorded audio buffer (microphone input)
 * @param echo_buffer Reference audio buffer (speaker output)
 * @param out_buffer Output buffer for processed audio
 * @param buffer_length Length of all buffers (must be equal to frame_size)
 */
void AecCancelEcho(Aec *aec_ptr,
                   const int16_t *rec_buffer,
                   const int16_t *echo_buffer,
                   int16_t *out_buffer,
                   uintptr_t buffer_length);

/**
 * Destroy AEC instance and free resources
 * @param aec_ptr AEC instance pointer to destroy
 */
void AecDestroy(Aec *aec_ptr);

// ============================================================================
// MARK: - Enhanced iOS Integration Functions
// ============================================================================

/**
 * Create AEC instance with recommended settings for iOS real-time processing
 * @param sample_rate Sample rate (16000, 44100, or 48000 recommended)
 * @param enable_preprocess Enable noise suppression
 * @return Pointer to AEC instance, NULL on failure
 */
Aec *AecNewForRealtimeIOS(uint32_t sample_rate, bool enable_preprocess);

/**
 * Create AEC instance optimized for file processing (non-real-time)
 * @param sample_rate Sample rate of the audio files
 * @param enable_preprocess Enable noise suppression
 * @return Pointer to AEC instance, NULL on failure
 */
Aec *AecNewForFileProcessing(uint32_t sample_rate, bool enable_preprocess);

/**
 * Process entire audio files for echo cancellation (non-real-time mode)
 * @param aec_ptr AEC instance pointer
 * @param rec_samples Recorded audio samples (microphone input)
 * @param echo_samples Reference audio samples (speaker output)
 * @param out_samples Output buffer for processed audio (must be pre-allocated)
 * @param num_samples Total number of samples in each buffer
 * @return 0 on success, negative on error
 */
int AecProcessAudioFiles(Aec *aec_ptr,
                        const int16_t *rec_samples,
                        const int16_t *echo_samples,
                        int16_t *out_samples,
                        size_t num_samples);

/**
 * Get recommended frame size for given sample rate
 * @param sample_rate Sample rate in Hz
 * @return Recommended frame size in samples
 */
uint32_t AecGetRecommendedFrameSize(uint32_t sample_rate);

/**
 * Get recommended filter length for given sample rate
 * @param sample_rate Sample rate in Hz
 * @return Recommended filter length in samples
 */
uint32_t AecGetRecommendedFilterLength(uint32_t sample_rate);

// ============================================================================
// MARK: - Real-time Streaming API for iOS
// ============================================================================

/**
 * Real-time streaming context for continuous audio processing
 */
typedef struct AecStreamContext AecStreamContext;

/**
 * Create streaming context for real-time audio processing
 * @param sample_rate Audio sample rate
 * @param enable_preprocess Enable noise suppression
 * @return Streaming context pointer, NULL on failure
 */
AecStreamContext *AecCreateStreamContext(uint32_t sample_rate, bool enable_preprocess);

/**
 * Process real-time audio chunk in streaming mode
 * @param stream_ctx Streaming context pointer
 * @param rec_chunk Recorded audio chunk from microphone
 * @param echo_chunk Reference audio chunk from speaker
 * @param out_chunk Output processed audio chunk
 * @param chunk_size Size of audio chunks in samples
 * @return 0 on success, negative on error
 */
int AecProcessStreamChunk(AecStreamContext *stream_ctx,
                         const int16_t *rec_chunk,
                         const int16_t *echo_chunk,
                         int16_t *out_chunk,
                         size_t chunk_size);

/**
 * Reset streaming context state (useful for new call sessions)
 * @param stream_ctx Streaming context pointer
 */
void AecResetStreamContext(AecStreamContext *stream_ctx);

/**
 * Destroy streaming context and free resources
 * @param stream_ctx Streaming context pointer
 */
void AecDestroyStreamContext(AecStreamContext *stream_ctx);

// ============================================================================
// MARK: - Utility Functions
// ============================================================================

/**
 * Get the library version string
 * @return Version string
 */
const char *AecGetVersion(void);

/**
 * Check if the given sample rate is supported
 * @param sample_rate Sample rate to check
 * @return true if supported, false otherwise
 */
bool AecIsSampleRateSupported(uint32_t sample_rate);

/**
 * Convert float audio samples to int16
 * @param float_samples Input float samples (-1.0 to 1.0)
 * @param int16_samples Output int16 samples
 * @param num_samples Number of samples to convert
 */
void AecFloatToInt16(const float *float_samples, int16_t *int16_samples, size_t num_samples);

/**
 * Convert int16 audio samples to float
 * @param int16_samples Input int16 samples
 * @param float_samples Output float samples (-1.0 to 1.0)
 * @param num_samples Number of samples to convert
 */
void AecInt16ToFloat(const int16_t *int16_samples, float *float_samples, size_t num_samples);

#ifdef __cplusplus
}
#endif

#endif /* LibAecFramework_h */
