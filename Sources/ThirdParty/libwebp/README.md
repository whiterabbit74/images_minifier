# libwebp (vendor)

Поместите исходники libwebp (Google) сюда для сборки под macOS arm64.

Минимальный набор:
- `src/` (из репозитория libwebp)
- `README`, `COPYING`/`LICENSE`

Сборка через SPM:
- Файлы C будут собраны как часть цели `WebPShims` (добавим include и линковку).
- Обёртки в `Sources/ThirdParty/WebPShims/webp_shims.c/.h` вызывают функции libwebp:
  - `WebPEncodeRGBA` для кодирования
  - `WebPFree` для освобождения буфера

Требования: arm64 (Apple Silicon), без внешних сетевых зависимостей.
