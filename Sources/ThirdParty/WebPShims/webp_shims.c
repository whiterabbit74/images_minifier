#include "webp_shims.h"
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>

typedef size_t (*WebPEncodeRGBAFn)(const uint8_t* rgba, int width, int height, int stride, float quality_factor, uint8_t** output);
typedef uint8_t* (*WebPDecodeRGBAFn)(const uint8_t* data, size_t data_size, int* width, int* height);
typedef void (*WebPFreeFn)(void* ptr);

static void* webp_handle = NULL;
static WebPEncodeRGBAFn webp_encode_rgba_fn = NULL;
static WebPDecodeRGBAFn webp_decode_rgba_fn = NULL;
static WebPFreeFn webp_free_fn = NULL;
static int webp_checked = 0;

static void load_libwebp(void) {
    if (webp_checked) return;
    webp_checked = 1;

    const char* env_path = getenv("PICS_LIBWEBP_PATH");
    const char* paths[] = {
        env_path,
        "/opt/homebrew/lib/libwebp.dylib",
        "/usr/local/lib/libwebp.dylib",
        "/usr/lib/libwebp.dylib",
        "libwebp.dylib",
        NULL
    };

    for (int i = 0; paths[i] != NULL; i++) {
        if (!paths[i] || strlen(paths[i]) == 0) continue;
        webp_handle = dlopen(paths[i], RTLD_LAZY);
        if (webp_handle) break;
    }

    if (!webp_handle) return;

    webp_encode_rgba_fn = (WebPEncodeRGBAFn)dlsym(webp_handle, "WebPEncodeRGBA");
    webp_decode_rgba_fn = (WebPDecodeRGBAFn)dlsym(webp_handle, "WebPDecodeRGBA");
    webp_free_fn = (WebPFreeFn)dlsym(webp_handle, "WebPFree");

    if (!webp_encode_rgba_fn || !webp_decode_rgba_fn || !webp_free_fn) {
        dlclose(webp_handle);
        webp_handle = NULL;
        webp_encode_rgba_fn = NULL;
        webp_decode_rgba_fn = NULL;
        webp_free_fn = NULL;
    }
}

int webp_encode_rgba(const uint8_t* rgba, int32_t width, int32_t height, int32_t stride, float quality, uint8_t** output, size_t* output_size) {
    load_libwebp();
    if (!webp_encode_rgba_fn) {
        if (output) *output = NULL;
        if (output_size) *output_size = 0;
        return 0;
    }
    size_t size = webp_encode_rgba_fn(rgba, (int)width, (int)height, (int)stride, quality, output);
    if (output_size) *output_size = size;
    return size > 0 ? 1 : 0;
}

void webp_free_buffer(uint8_t* buffer) {
    load_libwebp();
    if (webp_free_fn) {
        webp_free_fn(buffer);
    } else if (buffer) {
        free(buffer);
    }
}

int webp_decode_rgba(const uint8_t* webp_data, size_t webp_size, uint8_t** output_rgba, int32_t* width, int32_t* height, int32_t* stride) {
    load_libwebp();
    if (!webp_decode_rgba_fn) {
        if (output_rgba) *output_rgba = NULL;
        if (width) *width = 0;
        if (height) *height = 0;
        if (stride) *stride = 0;
        return 0;
    }

    int w = 0;
    int h = 0;
    uint8_t* out = webp_decode_rgba_fn(webp_data, webp_size, &w, &h);
    if (!out || w <= 0 || h <= 0) {
        if (output_rgba) *output_rgba = NULL;
        if (width) *width = 0;
        if (height) *height = 0;
        if (stride) *stride = 0;
        return 0;
    }

    if (output_rgba) *output_rgba = out;
    if (width) *width = (int32_t)w;
    if (height) *height = (int32_t)h;
    if (stride) *stride = (int32_t)(w * 4);
    return 1;
}

int webp_embedded_available(void) {
    load_libwebp();
    return webp_encode_rgba_fn && webp_decode_rgba_fn && webp_free_fn ? 1 : 0;
}
