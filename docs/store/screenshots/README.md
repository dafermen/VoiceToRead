# Capturas de VoiceToRead 1.0

12 candidatos generados y revisados visualmente el 2026-10-14 desde pantallas reales con texto ficticio propio. Revisar contra el archivo final antes de subir. La prueba de privacidad es material QA, no una captura comercial sugerida.

- iPhone 15, iOS 17.2: 1179 × 2556, vertical.
- iPad Pro 12.9 pulgadas (6.ª generación), iPadOS 17.2: 2048 × 2732, vertical.
- Idiomas de menús y contenido: en-US / es-ES.
- Orden sugerido: `02-reading`, `03-review`, `01-library`.
- Sin conversaciones privadas, micrófono activo ni traducción sintética anunciada.
- La captura de traducción en vivo queda pendiente de un dispositivo/SDK compatible y modelos reales preparados.

Estos tamaños figuran en las [especificaciones de Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) consultadas el 2026-10-14 (iPhone Dynamic Island medio e iPad 13 pulgadas, que admite 2048 × 2732). Verificar los requisitos al subir.

## Reproducir

Usar `python3 scripts/capture-store-screenshots.py --device UUID --label iphone` (iPhone 15) o `--label ipad` (iPad Pro 12.9, 6.ª generación). Cada ejecución guarda su log, xcresult y capturas en `build/store-…`. El UUID se obtiene con `xcrun simctl list devices available`.

La prueba mantiene cada pantalla estable cinco segundos y el script captura píxeles nativos con `simctl`. XCTest 15.2 guardaba el ancho del iPhone como **1178** en vez de **1179**: sus attachments sirven para QA, pero no se suben directamente. Los candidatos comerciales se entregan en JPEG, sin canal alfa y sin redimensionar. La tanda inicial se capturó en PNG nativo y se convirtió únicamente de formato a JPEG, conservando dimensiones y contenido.

Las pruebas `testStoreScreenshotsAndPrivacyEnglish` y `testStoreScreenshotsAndPrivacySpanish` recorren biblioteca, lectura, edición y enlaces de privacidad. Estos últimos no se abren automáticamente: se verifica su presencia en ambos idiomas; las URLs públicas se comprobaron por HTTPS aparte.

El argumento `--store-screenshots` solo existe en Debug y recrea una biblioteca en memoria; no toca sesiones reales. Release se inspecciona sin ese argumento ni contenido ficticio. Las capturas de privacidad se conservan en `build/.../qa` para QA, fuera del juego comercial.

Evidencia aprobada: `build/store-iphone-20261014-072025/Tests.xcresult` y `build/store-ipad-20261014-070944/Tests.xcresult`. Se validaron dimensiones y ausencia de alfa de los 12 JPEG. Ejecutar capturas de un dispositivo a la vez para evitar competencia entre sesiones de automatización.
