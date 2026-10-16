# Entrega: simplificación de navegación — 2026-10-16

Cambios implementados: [guía de usuario y arquitectura](simplified-navigation.md).

## Validación de esta entrega

- iPhone 15 / iOS 17.2: **130 pruebas unitarias aprobadas** y cinco recorridos UI aprobados en `/private/tmp/vtr-simplification-final.xcresult`: conversación por botón, preparación, lector bilingüe, retirada de marcadores/Favoritos y reproducción bilingüe sin grabación.
- Edición/guardado/reapertura/descarte/exportación SRT aprobados en la versión final, sin instrumentación (`/private/tmp/vtr-editor-dismissal.xcresult`). Los intentos anteriores fallaban al reabrir después de guardar: se ampliaron las áreas táctiles, se separó la identidad de cada presentación del UUID persistido y la prueba ahora espera que el editor desaparezca y el botón sea interactivo antes de tocarlo; ver el texto actualizado detrás de una hoja no confirma que haya terminado de cerrarse.
- iPad Air 5 / iOS 17.2: prueba de espacio de lectura en ambas orientaciones aprobada (`/private/tmp/vtr-simplification-ipad.xcresult`). La prueba de navegación inicialmente esperaba Cancelar en un popover; se adaptó para cerrarlo tocando fuera y pasó (`/private/tmp/vtr-simplification-ipad-final.xcresult`).
- Release final sin firma aprobada, incluida la identidad independiente del editor (`/private/tmp/vtr-simplification-release-editor.log`).
- Catálogos: **698 claves + 2 permisos**; **464 claves extraídas** cubiertas. Metadatos App Store, enlaces locales de documentación y `git diff --check` sin errores.
- Web estática: 10 páginas bilingües y ZIP local regenerados y validados. No se publicó Hostinger ni se envió App Review.
- Capturas revisadas: [Texto y traducción](qa/simplified-navigation/text-and-translation-iphone.png) y [reproductor único](qa/simplified-navigation/unified-playback-iphone.png), además del [inicio en iPad](qa/simplified-navigation/home-ipad.png) y la [corrección guardada](qa/simplified-navigation/corrected-playback-iphone.png). Usan datos de prueba; el SDK local iOS 17 no ejecuta Apple Translation moderno.

La primera compilación de comprobación detectó un observador `scenePhase` retirado por error del lector bilingüe; se restauró antes de estas pruebas. No se distribuyó esa versión. Permanecen las dos advertencias previas de concurrencia en CaptionViewModel y el cierre de la hoja de traducción.

## Compatibilidad

Se conserva el esquema y los datos de marcadores/notas anteriores. Favoritos de sesiones completas, correcciones, grabaciones y expresiones de práctica conservan su función. La web de Hostinger y la publicación App Store no se actualizan automáticamente con este commit.
