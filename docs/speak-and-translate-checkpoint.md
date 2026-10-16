# Entrega: Conversación bilingüe — 2026-10-16

## Implementación actual

Dos toques por turno en ambos sentidos, Por botón inicial, Automático en Opciones, tarjetas compartidas, reproducción/detención, edición y escritura separadas. No cambia idioma global ni guarda sesiones. [Guía vigente](speak-and-translate.md).

- iPhone 15 / iOS 17.2: **133 pruebas unitarias y 2 de interfaz aprobadas**, `/private/tmp/vtr-two-way-tests.xcresult`.
- iPad Air 5 / iOS 17.2: **1 prueba de interfaz aprobada**, `/private/tmp/vtr-two-way-ipad.xcresult`.
- Release para simulador, sin firma: **BUILD SUCCEEDED**, `/private/tmp/vtr-two-way-release.log`. Dos advertencias preexistentes de aislamiento/concurrencia en `CaptionViewModel` y `SessionTranslationView`; no errores nuevos.
- Capturas revisadas: [iPhone](qa/speak-and-translate/two-way-iphone.png) e [iPad](qa/speak-and-translate/two-way-ipad.png). Textos traducidos ficticios de DEBUG.
- Localización extraída: 472 claves del compilador cubiertas. Metadatos App Store, 10 páginas del sitio/ZIP y `git diff --check` aprobados. Paquete de textos App Store regenerado; web preparada localmente, sin publicar Hostinger.
- Localización inicial: 724 claves EN/ES + 2 permisos; sin diferencias de placeholders.
- Los dobles de captura, traducción y voz usados por las pruebas son exclusivos de DEBUG. Hace falta verificar reconocimiento/Apple Translation/voz reales en ambos sentidos en dispositivos compatibles.
- Para la próxima compilación: verificar distribución y procesamiento en TestFlight por separado. Una compilación local correcta no acredita disponibilidad. No cambiar certificados por advertencias Swift sin evidencia de un fallo de firma.

## Aceptación física pendiente

1. Español → terminar → voz inglesa; inglés → terminar → voz española. Confirmar que no hace falta cambiar Ajustes ni dar un tercer toque.
2. Detener/repetir, escribir en ambos idiomas, cancelar una corrección y reintentar tras fallo de traducción.
3. Probar descarga inicial, permisos, ruido, silencio, límite manual, auriculares, alarma/llamada y salida al fondo. Nunca debe reiniciarse el micrófono ni hablar una respuesta cancelada.
4. iPhone/iPad, ambos idiomas de interfaz, orientación, letra grande y VoiceOver. El color debe acompañar etiquetas, no sustituirlas.

## Registro histórico — flujo anterior, sustituido por el descrito arriba

# Entrega: Hablar y traducir — 2026-10-16

## Ampliación: controles claros y modos separados

- Flecha circular compartida para volver a texto en vivo en lector original y bilingüe; nombre accesible conservado.
- Guardar audio, Reducir ruido y Segundo plano con nombre/estado visible. Acceso duplicado a preferencias eliminado en pantalla normal, conservado en pantalla completa.
- Automático y Por botón separados. Por botón no finaliza al detectar una pausa ni reproduce traducciones hasta Play; mantiene límites de duración y cancelación. El modo se recuerda, el mensaje no.
- Primera pasada iPhone 15 / iOS 17.2: **10 pruebas específicas + 4 de interfaz aprobadas**, `/private/tmp/vtr-controls-tests.xcresult`. Cubre silencio hasta Play, edición, interrupciones/cancelación, recorrido automático, flecha bilingüe y preferencias con sesión pausada.
- Pasada final tras persistir el modo: **10 pruebas específicas + 2 de interfaz aprobadas**, `/private/tmp/vtr-controls-final.xcresult`. Comprueba reapertura sin mensaje, conservación de Por botón y relectura original estable mientras llegan subtítulos; la flecha retoma seguimiento.
- Release para dispositivo sin firma: **BUILD SUCCEEDED**, `/private/tmp/vtr-controls-release.log`. Mantiene las dos advertencias de concurrencia preexistentes indicadas abajo; sin errores nuevos.
- Localización: **695 claves + 2 permisos**, **485 claves extraídas** cubiertas. Metadatos App Store y `git diff --check` sin errores.
- Capturas revisadas: [controles](qa/speak-and-translate/capture-controls-iphone.png) y [conversación por botón](qa/speak-and-translate/by-button-iphone.png). El mensaje inglés mostrado es una respuesta ficticia de DEBUG; no ilustra calidad de Apple Translation.

Para la aceptación física, comprobar ambos modos con voz española real; en Por botón, esperar tras traducir sin sonido y después pulsar Reproducir en inglés. Reabrir conserva el modo pero limpia el texto. Probar el regreso al texto en vivo en Original/Ambos y etiquetas de controles con letra grande y VoiceOver. La nueva distribución a TestFlight se verifica aparte de estas pruebas locales.

## Evidencia de la implementación anterior

## Alcance

Modo temporal español → inglés: captura explícita, cierre por pausa estimada o botón, traducción seguida de voz, edición/escritura, repetir y cancelar. Acceso inicial en Captions, Ajustes e inicio sencillo. No modifica idioma global, grabaciones o sesiones existentes. Guía: [Hablar y traducir](speak-and-translate.md).

## Evidencia local

- Primera ejecución iPhone 15 / iOS 17.2: **125 pruebas unitarias + 1 de interfaz aprobadas** (`/private/tmp/vtr-conversation-tests.xcresult`).
- iPad Air 5 / iOS 17.2: **8 pruebas específicas + 1 de interfaz aprobadas** (`/private/tmp/vtr-conversation-final.xcresult`). Incluye cierre automático por pausa, revisión final, finalización fallida, interrupciones, cancelar durante arranque, respuestas tardías/duplicadas y dispositivo no compatible.
- Pasada final iPhone 15 tras los ajustes visuales: **8 pruebas específicas + 1 de interfaz aprobadas** (`/private/tmp/vtr-conversation-verified.xcresult`). [Captura revisada](qa/speak-and-translate/iphone.png), con traducción ficticia de prueba.
- Compilación Release final para dispositivo, sin firma: **BUILD SUCCEEDED** (`/private/tmp/vtr-conversation-release-final.log`).
- Localización EN/ES: **685 claves + 2 permisos**, placeholders coincidentes y **484 claves extraídas por el compilador cubiertas**.
- Comprobación de metadatos App Store y `git diff --check`: sin errores. El paquete local `build/app-store/VoiceToRead-AppStore-1.0.zip` se regenera con las notas de revisión.

## Límites de la validación y próxima compilación

El Mac usa Xcode 15.2. No ejecuta el framework moderno de Translation: la prueba UI utiliza una respuesta ficticia únicamente en DEBUG. Las pruebas unitarias sustituyen micrófono y salida de voz para verificar orden y cancelación. La compilación de Xcode Cloud con SDK moderno y la prueba física con Apple Translation siguen siendo necesarias. No declarar disponible en TestFlight hasta verificar distribución y procesamiento de Apple.

La primera compilación local mantiene dos advertencias preexistentes de aislamiento/concurrencia en `CaptionViewModel.swift:61` y `SessionTranslationView.swift:188`. No son errores de esta función. No modificar certificados ni perfiles por estas advertencias.

## Aceptación en dispositivos físicos

1. Abrir Hablar y traducir en iPhone/iPad con modelos españoles e inglés disponibles; permitir micrófono/Speech cuando se solicite.
2. Decir «Un vaso de agua, por favor», pausar y comprobar texto español, traducción y voz inglesa. Confirmar que la voz del teléfono no se transcribe de nuevo.
3. Probar espera de cinco segundos, finalización manual en ruido, silencio sin voz y límite de un minuto.
4. Corregir el texto, traducir, repetir y cancelar; probar llamada/alarma, auriculares, salida al fondo y cierre durante una descarga. No debe hablar un resultado antiguo ni reabrir el micrófono solo.
5. Comprobar español e inglés de interfaz, VoiceOver, tamaño de texto grande y desplazamiento. Confirmar que no se crean sesiones ni archivos de grabación y que el idioma global conserva su valor.

No se ha publicado la web de Hostinger ni enviado la app a App Review en este cambio.
