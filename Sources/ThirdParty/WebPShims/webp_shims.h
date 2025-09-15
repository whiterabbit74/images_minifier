#ifndef WEBP_SHIMS_H
#define WEBP_SHIMS_H

#include <stddef.h>
#include <stdint.h>

// Минимальные C-шимы для будущей интеграции libwebp.
// Пока только заглушки, чтобы собрать цель и связать.

#ifdef __cplusplus
extern "C" {
#endif

// Согласованные заголовки для вызовов из Swift (будут реализованы в C)
int webp_encode_rgba(const uint8_t* rgba, int32_t width, int32_t height, int32_t stride, float quality, uint8_t** output, size_t* output_size);
void webp_free_buffer(uint8_t* buffer);
int webp_decode_rgba(const uint8_t* webp_data, size_t webp_size, uint8_t** output_rgba, int32_t* width, int32_t* height, int32_t* stride);
int webp_embedded_available(void);

#ifdef __cplusplus
}
#endif

#endif /* WEBP_SHIMS_H */


