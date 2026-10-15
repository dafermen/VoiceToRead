# Escuchar la traducción y leer a tu ritmo

Implementación: 15 de octubre de 2026 · VoiceToRead 1.0 · esquema V8 sin cambios.

## Para quién

Estas opciones apoyan a personas con discapacidad auditiva o baja visión, personas que todavía no dominan el idioma de una conversación y niños que practican con acompañamiento adulto. Escuchar la traducción complementa el texto; los controles, los estados de pausa y la protección también se comunican visualmente y con etiquetas accesibles. No depender del sonido o del color como única señal. No es una evaluación médica ni una garantía de traducción correcta.

## Escuchar una traducción

1. Termina y guarda la sesión. Abre **Sesiones → sesión → Traducción**.
2. Traduce o actualiza los párrafos si hace falta. Selecciona el idioma traducido o **Ambos**.
3. Pulsa el altavoz **Escuchar traducción** de una tarjeta, o **Escuchar traducción completa** para recorrer los párrafos en orden.
4. Usa **Pausar traducción**, **Continuar traducción** o **Detener traducción**. El párrafo activo se resalta y se identifica con texto. Puedes elegir velocidad **Lenta / Normal / Rápida**; cambiarla detiene la lectura y se aplica al siguiente inicio explícito.
5. Para escuchar una corrección, guarda primero la edición y vuelve a tocar el altavoz.

Inglés original → voz española; español original → voz inglesa. La selección del idioma de interfaz no cambia esta dirección. En **Ambos** se lee únicamente la traducción, nunca el texto bilingüe concatenado. **Escuchar original** reproduce el archivo grabado; **Escuchar traducción** usa una voz generada por Apple. Funciona con traducciones guardadas aunque la sesión no tenga grabación de audio. No crea un doblaje, archivo exportable de voz sintética ni una imitación del hablante.

Generar nuevas traducciones conserva los requisitos existentes: SDK compatible, iOS/iPadOS 18+ y modelos de Apple preparados. Leer una traducción ya guardada usa AVSpeechSynthesizer, disponible también en el mínimo iOS 17 de la app. La voz debe estar disponible en el dispositivo; si falta, se presenta un mensaje para preparar una voz en Ajustes de accesibilidad. La descarga inicial puede requerir Internet. Verificar voz, volumen y ruta de audio en el dispositivo antes de una actividad.

La entrada está restringida a sesiones que pueden reproducirse sin captura activa. No hay voz automática durante la transcripción en vivo. Entrar al editor, abrir audio original, compartir, cambiar presentación o salir detiene la voz. Una interrupción, cambio de auriculares o salida a segundo plano también detiene la lectura y requiere un nuevo toque. No se reanuda sola después de una alarma. No se envía el texto a un servidor del desarrollador ni se agrega almacenamiento de audio sintetizado.

## Más espacio y frase anterior

En **Audio y subtítulos**, el lector desplazable ocupa el alto disponible, en lugar de estar limitado a 160 puntos. La barra de reproducción permanece accesible abajo. **Opciones de reproducción** despliega la lista de frases, edición completa, exportación y borrado de audio. Plegarlas o usar pantalla completa devuelve espacio al texto. Los párrafos largos se desplazan verticalmente.

En **A mi ritmo**, **Frase anterior** reproduce el párrafo anterior completo, **Repetir** vuelve al seleccionado y **Siguiente** avanza solo por decisión del usuario. Anterior está deshabilitado al principio y Siguiente al final. Terminar un párrafo conserva su texto en pantalla; no arranca el siguiente. La segmentación sigue los párrafos reconocidos y sus tiempos guardados, no necesariamente una sola oración gramatical.

## Favoritos y borrado

Desliza una fila de Sesiones hacia la izquierda. Aparecen dos botones circulares: amarillo para favorita/protección y rojo para eliminar. El botón de tres puntos permite abrirlos sin deslizar; también hay acciones de VoiceOver. Al proteger, el icono cambia a candado y Eliminar aparece gris y deshabilitado. Deslizar hacia la derecha oculta los controles. Un deslizamiento nunca borra directamente.

Para borrar una favorita: pulsa el candado, confirma **Quitar protección**, luego pulsa Eliminar y confirma por separado. Quitar protección conserva todos los datos. Los borradores deben guardarse antes de protegerse. La protección también se comprueba en el repositorio, incluido borrar solo audio: no depende de que un botón esté gris. Favoritos no es una copia de seguridad; exporta lo importante.

## Cómo funciona, para estudiantes

`TranslationSpeechPlayer.paragraphs` toma una `TranslationSnapshot` vigente y obtiene `translated`, que ya aplica las correcciones del usuario. Cada párrafo conserva su UUID. Una cola entrega un párrafo a `TranslationSpeechOutput`; la implementación Apple construye un `AVSpeechUtterance` con voz del idioma de destino y velocidad elegida. Cuando el delegado informa que terminó, el controlador avanza y SwiftUI resalta el siguiente UUID.

Cada reproducción tiene un token UUID. Al detener o reemplazar una lectura, el token cambia: una respuesta tardía de la frase anterior no puede avanzar la nueva cola. Los callbacks del delegado vuelven al actor principal usando una identidad de objeto, sin transferir el objeto de audio entre actores. La máquina de estados distingue reposo, hablando y pausa. Si una finalización llega justo al pausar, conserva la cola detenida hasta Continuar.

El controlador activa AVAudioSession solo cuando el usuario pide leer, y la desactiva solo si fue su propietario. Cerrar una pantalla inactiva no debe apagar audio que pertenece a otro componente. Los observadores de interrupción se retiran al cerrar. Esta separación permite probar la cola con un doble sin descargar voces ni grabar micrófono.

`SessionMediaView` mantiene los rangos de `PlaybackParagraph` y usa el mismo `playParagraph` para anterior, repetir y siguiente. `SessionHistoryView` distingue revelar acciones, quitar protección y borrar: son decisiones separadas. `TranscriptRepository` sigue siendo la última barrera para proteger archivos y registros.

Referencia de API: [AVSpeechSynthesizer, Apple](https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer).

## Verificación y entrega

Consultar [checkpoint de esta entrega](translated-speech-checkpoint.md). La calidad de las voces, audífonos, interrupciones reales, lectura con VoiceOver, tamaños de letra accesibles y uso por niños/personas con discapacidad requieren aceptación en iPhone/iPad. Los tests y simuladores no certifican accesibilidad universal. Los cambios locales o en GitHub no significan que una nueva versión ya esté en TestFlight/App Store.
