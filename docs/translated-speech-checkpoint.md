# Entrega de voz traducida y lectura accesible

Fecha: 2026-10-15. Fuente VoiceToRead 1.0 (1), bundle `com.innovalogic.voicetoread`, esquema V8 sin migraciones. No confundir el número fuente con el número asignado por Xcode Cloud a una distribución.

## Implementado

- Voz Apple para traducciones guardadas y corregidas, EN→ES y ES→EN, sin depender del audio original: párrafo o cola completa, pausa/continuar/detener, velocidad y resaltado.
- Interrupciones, cambio de ruta, salir, editar o abrir otro audio detienen la síntesis; no hay reproducción automática durante la captura.
- Visor de subtítulos sin el límite de 160 puntos; opciones secundarias plegadas y controles compactos en horizontal.
- Frase anterior en A mi ritmo, con estado deshabilitado visible al principio; se mantienen repetición y edición sin cambiar el archivo original.
- Dos círculos al deslizar a la izquierda: proteger y eliminar. Borrado deshabilitado/oculto como acción de VoiceOver al proteger; confirmaciones separadas y barrera del repositorio conservadas.
- Documentación de uso inclusivo, arquitectura junior, privacidad técnica, GitHub y borradores de App Store actualizados.

## Evidencia local

macOS Ventura 13.7.8, Xcode 15.2, simuladores iOS 17.2. No es una ejecución del SDK moderno de Translation: los escenarios UI cargan traducciones ficticias guardadas y ejercitan reproducción/edición reales.

- **102 pruebas unitarias aprobadas**, incluidas selección de traducción corregida, origen cambiado, dirección inversa, cola/pausa/continuación, interrupción, voz ausente y callbacks antiguos. También pasan las pruebas existentes de datos, protección y audio. Log `/private/tmp/vtr-speech-tests-2.log`, resultado `/private/tmp/vtr-speech-tests-2.xcresult`.
- **iPhone 15:** aprobados los seis recorridos distintos: A mi ritmo/corrección/giro, voz traducida en ambos sentidos sin grabación, párrafo largo desplazable, edición/exportación de traducción y deslizar/proteger/quitar protección/eliminar. Resultados en `vtr-speech-tests-2.xcresult` (tres UI aprobados y un fallo de selector corregido) y `vtr-speech-tests-3.xcresult` (tres UI aprobados).
- **iPad Air 5:** cinco recorridos aprobados: voz traducida en ambos sentidos, párrafo largo, protección/borrado y A mi ritmo/corrección/giro. `vtr-speech-ipad.xcresult` conserva cuatro aprobados y el primer fallo de espera; el reintento `/private/tmp/vtr-speech-ipad-rotation.xcresult` pasó en 42,559 s.
- **Release genérico iOS sin firma aprobado**, log `/private/tmp/vtr-speech-release-final.log`. Se comprobó bundle, versión 1.0, mínimo iOS 17, familias iPhone/iPad, manifiesto plist válido y ausencia de fixtures DEBUG en el ejecutable. No es una validación de firma o subida.
- Catálogos EN/ES: **542 claves** y dos permisos, sin diferencias de claves/placeholders. Longitudes del texto de App Store válidas. `git diff --check` sin errores.

Dos avisos de concurrencia ya existentes permanecen: callback de nivel en `CaptionViewModel` y cierre `onDismiss` en `SessionTranslationView`. No se cambió el motor de captura para esta entrega.

## Incidencias de validación

La primera prueba de borrado seleccionó el botón de la fila que estaba detrás del diálogo porque compartía el texto Quitar protección. Se añadieron identificadores específicos a las confirmaciones y el recorrido completo pasó en iPhone e iPad. No se eliminó ninguna confirmación para hacer pasar el test.

En iPad, el primer test de giro pulsó Opciones inmediatamente después de que XCTest notificara la orientación, cuando la hoja aún se estaba recolocando. Se añadió espera de orientación y de la animación antes del toque. El reintento pasó completo, incluida edición, anterior, giro, desplegar opciones y verificar audio protegido; no se requirió cambiar el comportamiento de producción para resolverlo.

## Capturas de control

Contenido ficticio. Son capturas de QA, no el juego comercial de App Store; no subir los attachments de XCTest directamente como capturas de tienda.

- [Sesión protegida y círculos](qa/translated-speech/protected-session.png).
- [Voz española en pausa](qa/translated-speech/translated-voice-paused.png).
- [Párrafo largo desplazado](qa/translated-speech/long-paragraph.png).
- [Voz inglesa en iPad](qa/translated-speech/ipad-translated-voice.png).

## Pendiente antes de afirmar disponibilidad

1. Confirmar compilación del commit en Xcode Cloud y distribución al grupo TestFlight correspondiente.
2. Instalar ese build en iPhone/iPad reales y validar voces/modelos, ambas direcciones, audífonos, alarma, bloqueo y modo avión después de preparar voces.
3. Revisar VoiceOver, Voice Control, letra grande, alto contraste y lectura con personas con discapacidad auditiva/baja visión, aprendices y adultos que acompañen niños. Pruebas automáticas no certifican accesibilidad universal.
4. Antes de App Store: archivo elegible, firma/privacidad, ficha y capturas finales. No se envió a revisión ni se publicó una versión pública en esta entrega.

Guía de uso y explicación de código: [voz traducida](translated-speech.md).
