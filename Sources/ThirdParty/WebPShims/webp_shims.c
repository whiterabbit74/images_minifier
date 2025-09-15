#include "webp_shims.h"
#include <stdlib.h>
#include <dlfcn.h>

// Динамическая загрузка системного libwebp, чтобы не требовать линковки при отсутствии
static void* g_lib_handle = NULL;
static size_t (*g_WebPEncodeRGBA)(const uint8_t*, int, int, int, float, uint8_t**) = NULL;
static uint8_t* (*g_WebPDecodeRGBA)(const uint8_t*, size_t, int*, int*) = NULL;
static void (*g_WebPFree)(void*) = NULL;

static int ensure_libwebp_loaded(void) {
    if (g_lib_handle && g_WebPEncodeRGBA && g_WebPFree) {
        return 1;
    }
    // Try already-linked symbols (e.g., when libwebp is statically linked into the binary)
    void* enc_def = dlsym(RTLD_DEFAULT, "WebPEncodeRGBA");
    void* dec_def = dlsym(RTLD_DEFAULT, "WebPDecodeRGBA");
    void* fr_def  = dlsym(RTLD_DEFAULT, "WebPFree");
    if (enc_def && dec_def && fr_def) {
        g_lib_handle = RTLD_DEFAULT;
        g_WebPEncodeRGBA = (size_t (*)(const uint8_t*, int, int, int, float, uint8_t**))enc_def;
        g_WebPDecodeRGBA = (uint8_t* (*)(const uint8_t*, size_t, int*, int*))dec_def;
        g_WebPFree = (void (*)(void*))fr_def;
        return 1;
    }
    // 0) Environment override
    const char* env = getenv("PICS_LIBWEBP_PATH");
    if (env && env[0] != '\0') {
        void* h = dlopen(env, RTLD_LAZY);
        if (h) {
            void* enc0 = dlsym(h, "WebPEncodeRGBA");
            void* dec0 = dlsym(h, "WebPDecodeRGBA");
            void* fr0 = dlsym(h, "WebPFree");
            if (enc0 && dec0 && fr0) {
                g_lib_handle = h;
                g_WebPEncodeRGBA = (size_t (*)(const uint8_t*, int, int, int, float, uint8_t**))enc0;
                g_WebPDecodeRGBA = (uint8_t* (*)(const uint8_t*, size_t, int*, int*))dec0;
                g_WebPFree = (void (*)(void*))fr0;
                return 1;
            }
            dlclose(h);
        }
        // If override was provided but invalid, do not continue with other candidates
        return 0;
    }
    const char* candidates[] = {
        "/opt/homebrew/lib/libwebp.dylib",
        "/usr/local/lib/libwebp.dylib",
        "libwebp.dylib"
    };
    for (size_t i = 0; i < sizeof(candidates)/sizeof(candidates[0]); ++i) {
        void* h = dlopen(candidates[i], RTLD_LAZY);
        if (!h) continue;
        void* enc = dlsym(h, "WebPEncodeRGBA");
        void* dec = dlsym(h, "WebPDecodeRGBA");
        void* fr = dlsym(h, "WebPFree");
        if (enc && dec && fr) {
            g_lib_handle = h;
            g_WebPEncodeRGBA = (size_t (*)(const uint8_t*, int, int, int, float, uint8_t**))enc;
            g_WebPDecodeRGBA = (uint8_t* (*)(const uint8_t*, size_t, int*, int*))dec;
            g_WebPFree = (void (*)(void*))fr;
            return 1;
        }
        dlclose(h);
    }
    return 0;
}

// Заглушки: будут заменены на реальные вызовы libwebp после вендоринга исходников

int webp_encode_rgba(const uint8_t* rgba, int32_t width, int32_t height, int32_t stride, float quality, uint8_t** output, size_t* output_size) {
    if (!ensure_libwebp_loaded()) return 0;
    if (!rgba || width <= 0 || height <= 0 || !output || !output_size) return 0;
    size_t sz = g_WebPEncodeRGBA(rgba, (int)width, (int)height, (int)stride, quality, output);
    if (sz == 0 || *output == NULL) {
        *output_size = 0;
        return 0;
    }
    *output_size = sz;
    return 1;
}

int webp_decode_rgba(const uint8_t* webp_data, size_t webp_size, uint8_t** output_rgba, int32_t* width, int32_t* height, int32_t* stride) {
    if (!ensure_libwebp_loaded()) return 0;
    if (!g_WebPDecodeRGBA || !webp_data || webp_size == 0 || !output_rgba || !width || !height || !stride) return 0;
    int out_w = 0;
    int out_h = 0;
    uint8_t* decoded = g_WebPDecodeRGBA(webp_data, webp_size, &out_w, &out_h);
    if (!decoded || out_w <= 0 || out_h <= 0) return 0;
    *output_rgba = decoded;
    *width = (int32_t)out_w;
    *height = (int32_t)out_h;
    *stride = (int32_t)(out_w * 4);
    return 1;
}

void webp_free_buffer(uint8_t* buffer) {
    if (!buffer) return;
    if (g_WebPFree) {
        g_WebPFree(buffer);
    } else {
        free(buffer);
    }
}

int webp_embedded_available(void) {
    // Здесь "embedded" трактуем как доступность системной libwebp через dlopen
    return ensure_libwebp_loaded();
}


