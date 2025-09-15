/* iOS-compatible version of libaec.h */

#ifndef libaec_ios_h
#define libaec_ios_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Forward declaration
typedef struct Aec Aec;

// Core AEC functions
Aec *AecNew(size_t frame_size,
            int32_t filter_length,
            uint32_t sample_rate,
            bool enable_preprocess);

void AecCancelEcho(Aec *aec_ptr,
                   const int16_t *rec_buffer,
                   const int16_t *echo_buffer,
                   int16_t *out_buffer,
                   size_t buffer_length);

void AecDestroy(Aec *aec_ptr);

#ifdef __cplusplus
}
#endif

#endif /* libaec_ios_h */
