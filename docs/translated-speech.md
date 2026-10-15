# Escuchar la traducción y leer a tu ritmo

Implementación: 15 de octubre de 2026 · VoiceToRead 1.0 · esquema V8 sin cambios.

## Para quién

Estas opciones apoyan a personas con discapacidad auditiva o baja visión, personas que todavía no dominan el idioma de una conversación y niños que practican con acompañamiento adulto. Escuchar la traducción complementa el texto; los controles, los estados de pausa y la protección también se comunican visualmente y con etiquetas accesibles. No depender del sonido o del color como única señal. No es una evaluación médica ni una garantía de traducción correcta.

## Escuchar una traducción

1. Pulsa Detener: en dispositivos compatibles comienza la traducción automáticamente. Revisa progreso o reintenta si falta preparar idiomas. Guarda la sesión cuando quieras conservarla.
2. Abre **Sesiones → sesión → Audio y subtítulos** o abre el lector desde Traducción.
3. En Escuchar elige audio original o voz traducida; en Leer elige original, traducción o Ambos.
4. Usa el único botón central Reproducir/Pausar/Continuar. Anterior y Siguiente seleccionan sin sonido. A mi ritmo reproduce un párrafo; Continua recorre los siguientes. Ambos audios usan controles del mismo tamaño.
5. Opciones permite cambiar velocidad y lectura. Guarda las correcciones antes de escucharlas.

Inglés original → voz española; español original → voz inglesa. La selección del idioma de interfaz no cambia esta dirección. En **Ambos** se lee únicamente la traducción, nunca el texto bilingüe concatenado. **Escuchar original** reproduce el archivo grabado; **Escuchar traducción** usa una voz generada por Apple. Funciona con traducciones guardadas aunque la sesión no tenga grabación de audio. No crea un doblaje, archivo exportable de voz sintética ni una imitación del hablante.

Generar nuevas traducciones conserva los requisitos existentes: SDK compatible, iOS/iPadOS 18+ y modelos de Apple preparados. Leer una traducción ya guardada usa AVSpeechSynthesizer, disponible también en el mínimo iOS 17 de la app. La voz debe estar disponible en el dispositivo; si falta, se presenta un mensaje para preparar una voz en Ajustes de accesibilidad. La descarga inicial puede requerir Internet. Verificar voz, volumen y ruta de audio en el dispositivo antes de una actividad.

La reproducción permanece separada de la captura. No hay voz automática durante la transcripción en vivo ni al terminar de traducir. Editar, cambiar fuente de audio, compartir o salir pausa/detiene el sonido. Cambiar solo el idioma visible conserva el sonido. Ante interrupción, el original conserva su posición y la voz traducida requiere Play para reiniciar el párrafo. No se envía texto a un servidor del desarrollador ni se almacena audio sintetizado.

## Lector y navegación

El lector desplazable ocupa el espacio disponible. Opciones abre una hoja, no una lista que comprima la lectura. Anterior/Siguiente seleccionan silenciosamente; el usuario pulsa Play cuando está preparado. El botón circular duplicado se elimina. Al terminar permanece el párrafo completo. Ver [guía unificada](playback-unification.md).

## Favoritos y borrado

Desliza una fila de Sesiones hacia la izquierda. Aparecen dos botones circulares: amarillo para favorita/protección y rojo para eliminar. El botón de tres puntos permite abrirlos sin deslizar; también hay acciones de VoiceOver. Al proteger, el icono cambia a candado y Eliminar aparece gris y deshabilitado. Deslizar hacia la derecha oculta los controles. Un deslizamiento nunca borra directamente.

Para borrar una favorita: pulsa el candado, confirma **Quitar protección**, luego pulsa Eliminar y confirma por separado. Quitar protección conserva todos los datos. Los borradores deben guardarse antes de protegerse. La protección también se comprueba en el repositorio, incluido borrar solo audio: no depende de que un botón esté gris. Favoritos no es una copia de seguridad; exporta lo importante.

## Cómo funciona, para estudiantes

`TranslationSpeechPlayer.paragraphs` toma una `TranslationSnapshot` vigente y obtiene `translated`, que ya aplica las correcciones del usuario. Cada párrafo conserva su UUID. Una cola entrega un párrafo a `TranslationSpeechOutput`; la implementación Apple construye un `AVSpeechUtterance` con voz del idioma de destino y velocidad elegida. Cuando el delegado informa que terminó, el controlador avanza y SwiftUI resalta el siguiente UUID.

Cada reproducción tiene un token UUID. Al detener o reemplazar una lectura, el token cambia: una respuesta tardía de la frase anterior no puede avanzar la nueva cola. Los callbacks del delegado vuelven al actor principal usando una identidad de objeto, sin transferir el objeto de audio entre actores. La máquina de estados distingue reposo, hablando y pausa. Si una finalización llega justo al pausar, conserva la cola detenida hasta Continuar.

El controlador activa AVAudioSession solo cuando el usuario pide leer, y la desactiva solo si fue su propietario. Cerrar una pantalla inactiva no debe apagar audio que pertenece a otro componente. Los observadores de interrupción se retiran al cerrar. Esta separación permite probar la cola con un doble sin descargar voces ni grabar micrófono.

`SessionMediaView` mantiene los rangos de `PlaybackParagraph` y separa `selectParagraph` (sin sonido) de `togglePlayback`. Ambos tipos de voz usan `PlaybackTransport`. `SessionHistoryView` distingue revelar acciones, quitar protección y borrar: son decisiones separadas. `TranscriptRepository` sigue siendo la última barrera para proteger archivos y registros.

Referencia de API: [AVSpeechSynthesizer, Apple](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer).

## Verificación y entrega

Consultar [checkpoint de esta entrega](translated-speech-checkpoint.md). La calidad de las voces, audífonos, interrupciones reales, lectura con VoiceOver, tamaños de letra accesibles y uso por niños/personas con discapacidad requieren aceptación en iPhone/iPad. Los tests y simuladores no certifican accesibilidad universal. Los cambios locales o en GitHub no significan que una nueva versión ya esté en TestFlight/App Store.
