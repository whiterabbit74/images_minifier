#include "webp_shims.h"
#include <stdlib.h>

// Simplified WebP shims - stub implementation for fast builds
// Real WebP functionality will be handled by system frameworks when available

// Stub implementations that return "not available" or empty results
// This allows the build to complete quickly without complex dynamic loading

int webp_encode_rgba(const uint8_t* rgba, int32_t width, int32_t height, int32_t stride, float quality, uint8_t** output, size_t* output_size) {
    // Return 0 to indicate encoding not available
    if (output) *output = NULL;
    if (output_size) *output_size = 0;
    return 0;
}

void webp_free_buffer(uint8_t* buffer) {
    // Safe to call free on any allocated buffer
    if (buffer) {
        free(buffer);
    }
}

int webp_decode_rgba(const uint8_t* webp_data, size_t webp_size, uint8_t** output_rgba, int32_t* width, int32_t* height, int32_t* stride) {
    // Return 0 to indicate decoding not available
    if (output_rgba) *output_rgba = NULL;
    if (width) *width = 0;
    if (height) *height = 0;
    if (stride) *stride = 0;
    return 0;
}

int webp_embedded_available(void) {
    // Return 0 to indicate embedded WebP not available
    // Swift code will fall back to system WebP support
    return 0;
}