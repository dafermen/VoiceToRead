# Checkpoint — reproductor unificado y traducción automática

Fecha: 2026-10-15. Implementación y validación local terminadas. La disponibilidad en TestFlight depende de Xcode Cloud y del procesamiento de Apple; no se ha enviado a revisión de App Store.

## Cambios

Lector compartido para audio original y voz traducida, fuentes de audio/texto independientes, transporte del mismo tamaño, navegación silenciosa, estados explícitos, tarjetas bilingües, opciones separadas y traducción automática tras Detener. Práctica reutiliza el transporte y permite repetición explícita. No cambia la base de datos ni el bundle ID.

Guardar/Descartar conserva su significado. Traducir el borrador no lo publica. Un resultado tardío no recrea una sesión eliminada ni sobrescribe una traducción vigente corregida por el usuario. Suspender por segundo plano permite reanudar con un identificador nuevo; una autorización de descarga de idiomas no cancela el trabajo por volver la escena inactiva.

## Evidencia local

Entorno: Xcode 15.2, macOS Ventura 13.7.8, simuladores iOS/iPadOS 17.2.

- 106 pruebas unitarias, cero fallos, ejecutadas en iPhone 15 y nuevamente en iPad Air (5.ª generación). Incluyen descarte y callbacks tardíos, reintento, suspensión, protección de correcciones, intervalos de audio y estado de interrupción.
- iPhone: cuatro pruebas de interfaz finales aprobadas: igualdad de geometría del reproductor original/traducido y navegación silenciosa; traducción automática al detener; edición A mi ritmo y favoritos protegidos; traducción guardada, idiomas, reproducción y exportación. También pasaron previamente texto largo y voz traducida sin grabación en ambos sentidos.
- iPad: cuatro pruebas de interfaz aprobadas: geometría y tarjetas bilingües; desplazamiento de párrafo largo y volver al anterior; traducción al detener; guardar y reproducir expresiones de práctica con velocidad y bucle.
- Release para dispositivo iOS: compilación sin firma aprobada con el código final. Bundle `com.innovalogic.voicetoread`, versión `1.0`, familias iPhone/iPad, mínimo iOS 17. Manifiesto de privacidad presente; argumentos DEBUG de fixtures ausentes del binario.
- Localización: 571 claves EN/ES y dos permisos con las mismas interpolaciones; 401 claves extraídas por Swift cubiertas. Validación de longitudes de ficha App Store EN/ES y `git diff --check` aprobadas.
- Inspección visual de capturas de lector bilingüe en iPhone/iPad y desplazamiento de texto largo. Los controles y texto conservan área útil; las dos tarjetas usan la misma tipografía. [iPhone](qa/playback-unification/iphone-bilingual.png) · [iPad](qa/playback-unification/ipad-bilingual.png). Son datos ficticios de QA, no capturas comerciales.

Resultados locales (temporales, no se versionan): `/private/tmp/vtr-unified-tests4.xcresult`, `/private/tmp/vtr-unified-ipad.xcresult`, `/private/tmp/vtr-unified-release-verified.log`.

## Incidencias de las pruebas

El fixture inicial de Stop emitía 320 párrafos y seguía finalizando al vencer el plazo del test. Se usa el fixture corto existente de flujo de sesión para comprobar este comportamiento sin medir el reconocimiento real. Los tests antiguos de opciones/lista se ajustaron a las hojas separadas, esperando su presentación y distinguiendo sus botones Listo. XCTest no conseguía desplazar por accesibilidad los menús SwiftUI ya visibles; el test de geometría comprueba que están habilitados y toca su centro. El resultado verifica las selecciones y el cambio real de fuente.

Persisten dos advertencias locales de aislamiento/concurrencia preexistentes (`SessionTranslationView` al cerrar compartir y callback de nivel de `CaptionViewModel`). No impidieron esta compilación; no se declara aquí compatibilidad con modo de lenguaje Swift 6 estricto.

## Validación pendiente en dispositivo y distribución

La API real de traducción requiere SDK compatible e iOS/iPadOS 18+. En el simulador local antiguo se validó el flujo con `TranslationRunner` DEBUG determinista, no calidad de traducción ni descarga de modelos. Xcode Cloud debe compilar las rutas modernas. Después de actualizar TestFlight, comprobar:

1. Grabar y detener: empieza la traducción sin pulsar Traducir; la primera vez autorizar descarga si Apple la solicita. Probar inglés→español y español→inglés.
2. Guardar conserva la traducción; descartar elimina sus derivados. Pausar no inicia traducción. Una grabación nueva o segundo plano suspende y retoma; si iOS cierra el proceso, guardar el borrador y reintentar desde Traducción.
3. Oír original y traducción con igual tamaño de controles y área de lectura; Anterior/Siguiente seleccionan sin sonido. Probar A mi ritmo/Continua, fin, pausa, voces instaladas, auriculares, alarma y pantalla bloqueada.
4. VoiceOver, tamaño de letra, alto contraste, papel, orientación y párrafos extensos con personas que usan estas ayudas. Las pruebas automáticas no certifican accesibilidad universal.

La documentación de usuario, guía junior, notas de revisión y ficha EN/ES se actualizaron. Antes de enviar a App Store, regenerar/seleccionar capturas comerciales acordes con la interfaz final y completar la aceptación física. El ZIP de entrega sigue siendo material para revisar, no una publicación.
