# Hablar y traducir: español a inglés

## Para comunicarse en situaciones cotidianas

Este modo ayuda a pedir algo en una tienda, formular una pregunta o comunicarse cuando todavía no se domina el inglés. También permite escribir en lugar de hablar, como apoyo para personas con dificultades del habla o de audición. El texto visible y el tamaño configurable apoyan la lectura; niños pueden practicar acompañados por un adulto. No garantiza traducción exacta ni sustituye interpretación profesional o servicios de accesibilidad.

## Uso

1. Desde **Subtítulos/Captions**, antes de empezar una sesión, pulsa el **icono de conversación**, junto al selector de subtítulos en vivo, para abrir **Hablar y traducir / Speak and translate**. También está en **Ajustes → Accesibilidad y facilidad de uso** y en el inicio del modo sencillo. Se deshabilita mientras haya otra captura activa o una traducción automática de sesión.
2. Elige **Automático** o **Por botón**. La app recuerda el modo elegido al cerrar y volver a abrir, pero no conserva el mensaje. La elección inicial es Automático; cambiarla no inicia el micrófono.
3. **Automático:** pulsa **Hablar en español**, di una frase y haz una pausa de unos **3 segundos**. Con texto estable y volumen bajo, termina la captura, traduce y reproduce en inglés. Puedes elegir **5 segundos** o pulsar **Terminé de hablar** si hay ruido. La pausa es una estimación, no una comprensión del final de un párrafo.
4. **Por botón:** pulsa **Hablar en español** una vez, habla y pulsa **Terminé de hablar**. Aparecen el español y la traducción inglesa **sin reproducir sonido**. Cuando estés preparado, pulsa **Reproducir en inglés**. No necesitas mantener presionado el micrófono; esto facilita el uso a personas con dificultades motoras y permite leer a su propio ritmo.
5. En el primer uso, permite micrófono y reconocimiento si iOS lo solicita. Esta intervención usa español sin modificar el idioma predeterminado de las grabaciones. El micrófono queda apagado al traducir y reproducir. **Reproducir en inglés** también sirve para volver a escuchar; **Cancelar** detiene la operación. Otra intervención siempre requiere pulsar de nuevo **Hablar en español**.
6. Puedes escribir o corregir el español cuando no haya una operación activa. En Automático aparece **Traducir y decir en voz alta**; en Por botón, **Traducir mensaje**, que espera después a **Reproducir en inglés**. Editar invalida la traducción anterior. Si la finalización del reconocimiento falla, se pide revisar el texto y no se reproduce una traducción incompleta automáticamente.

Cada intervención de voz dura como máximo un minuto. Sin texto reconocido durante 15 segundos, se detiene y permite reintentar. En modo manual también se aplica el límite de un minuto. El volumen depende de la salida de audio elegida por iOS; prueba antes de usarlo con otra persona. Salir o mandar la app al fondo cancela captura, traducción y voz. Regresar nunca inicia el micrófono automáticamente.

## Requisitos y privacidad

La traducción necesita iOS/iPadOS 18 o posterior, una compilación compatible y los modelos de Apple preparados. Reconocimiento español y voz inglesa deben estar disponibles. El primer uso puede necesitar internet para descargar recursos; comprueba el funcionamiento sin conexión en tu dispositivo antes de depender de él.

Este modo no guarda grabaciones ni sesiones. El texto permanece temporalmente en pantalla hasta otra intervención o hasta cerrar. No cambia la opción global Guardar audio. Reutiliza el reconocimiento local, Translation y las voces de Apple; no añade servicios del desarrollador, cuentas o analítica. Puede haber errores de reconocimiento y traducción: revisa las dos tarjetas.

## Para estudiantes: arquitectura y decisiones

- `SpeakTranslateModel` posee un `CaptionViewModel` independiente y un `TranslationSpeechPlayer`. No se conecta a `TranscriptRepository`: así una conversación breve no genera grabaciones, borradores ni sesiones guardadas.
- La máquina de estados sigue preparado → preparando → escuchando → finalizando → traduciendo. El estado del reproductor indica cuándo habla. La interfaz deshabilita acciones incompatibles.
- `Mode` separa cuándo terminar de escuchar de cuándo reproducir. `selectMode` solo acepta cambios mientras está listo y sin voz; `speakWhenComplete` copia la decisión al crear el trabajo. Por botón desactiva el detector de pausa y exige Play para hablar, incluso al llegar al límite de un minuto. `@AppStorage("conversationMode")` recuerda únicamente el modo.
- `ConversationPause` combina estabilidad del texto y volumen del micrófono. Su reloj usa tiempo monotónico (`systemUptime`) para evitar cambios de hora. El umbral de volumen es una heurística; el botón manual y la espera larga son alternativas necesarias.
- `capture.stop()` se espera antes de crear `TranslationJob`. Se usa el texto final revisado por el reconocedor, no el provisional. El reconocedor libera el micrófono antes de activar reproducción: esto impide que el teléfono transcriba su propia traducción.
- `TranslationRunner` comparte la preparación y ejecución de Apple Translation con el resto de la app. `IncrementalTranslation.merging` valida IDs, orden y respuestas no vacías antes de hablar. La traducción usa español como origen e inglés como destino, independientemente del idioma de los menús.
- Cancelar invalida el token y elimina el trabajo de traducción de forma síncrona, detiene la voz y corta la captura. La limpieza espera una finalización pendiente antes de reiniciar el modelo. Un callback de una traducción antigua no puede producir voz tras Cancelar, salir o volver a otra intervención.
- Se conserva el texto para corregir errores y reintentar, pero editar descarta la traducción derivada. La siguiente escucha siempre exige una pulsación nueva para que el usuario controle quién está hablando.

## Verificación

Las pruebas unitarias ejercitan pausa, finalización antes de voz, revisiones finales, respuesta duplicada, cancelación, interrupción, indisponibilidad y errores de finalización. Las pruebas de interfaz usan una traducción ficticia explícita de DEBUG: verifican traducción automática, espera antes de Play en modo Por botón, cancelación al cerrar, mensaje temporal vacío al reabrir y persistencia del modo. Las pruebas unitarias comprueban que una pausa no termine el turno manual y que editar invalide la voz anterior. No demuestra la calidad de traducción de Apple ni el reconocimiento real.

Antes de publicar, probar en iPhone/iPad físicos con modelos preparados: frase española → pausa → inglés audible, ruido ambiental, espera larga/manual, llamada/alarma, salida al fondo, auriculares y primera descarga. Confirmar que la voz inglesa no reaparece como texto español.

[Estado de validación y entrega](speak-and-translate-checkpoint.md).
