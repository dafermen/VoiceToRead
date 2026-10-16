# Hablar y traducir: español a inglés

## Para comunicarse en situaciones cotidianas

Este modo ayuda a pedir algo en una tienda, formular una pregunta o comunicarse cuando todavía no se domina el inglés. También permite escribir en lugar de hablar, como apoyo para personas con dificultades del habla o de audición. El texto visible y el tamaño configurable apoyan la lectura; niños pueden practicar acompañados por un adulto. No garantiza traducción exacta ni sustituye interpretación profesional o servicios de accesibilidad.

## Uso

1. Desde **Subtítulos/Captions**, antes de empezar una sesión, abre **Hablar y traducir / Speak and translate**. También está en **Ajustes → Accesibilidad y facilidad de uso** y en el inicio del modo sencillo. Se deshabilita mientras haya otra captura activa o una traducción automática de sesión.
2. Pulsa **Hablar en español**. En el primer uso, permite micrófono y reconocimiento si iOS lo solicita. Se usa español para esta intervención, sin modificar el idioma predeterminado de las grabaciones.
3. Di una frase o un párrafo corto. Tras unos **3 segundos** sin cambios del reconocimiento y con volumen bajo, termina la captura, traduce y reproduce la traducción en inglés. Es una estimación de pausa, no una comprensión exacta de dónde termina un párrafo.
4. Puedes elegir **5 segundos** para tener más tiempo, o **Solo al pulsar Terminé de hablar**. El botón **Terminé de hablar** siempre está disponible mientras escuchamos; úsalo si el ruido evita detectar la pausa.
5. Se muestran el español y el inglés. El micrófono permanece apagado durante la traducción y la voz. **Repetir en inglés** vuelve a decir la traducción; **Cancelar** detiene la operación. Para otra intervención, pulsa de nuevo **Hablar en español**.
6. Puedes escribir o corregir el español mientras no haya operaciones activas y pulsar **Traducir y decir en voz alta**. Editar invalida la traducción anterior. Si la finalización del reconocimiento falla, se pide revisar el texto y no se reproduce automáticamente una traducción incompleta.

Cada intervención de voz dura como máximo un minuto. Sin texto reconocido durante 15 segundos, se detiene y permite reintentar. En modo manual también se aplica el límite de un minuto. El volumen depende de la salida de audio elegida por iOS; prueba antes de usarlo con otra persona. Salir o mandar la app al fondo cancela captura, traducción y voz. Regresar nunca inicia el micrófono automáticamente.

## Requisitos y privacidad

La traducción necesita iOS/iPadOS 18 o posterior, una compilación compatible y los modelos de Apple preparados. Reconocimiento español y voz inglesa deben estar disponibles. El primer uso puede necesitar internet para descargar recursos; comprueba el funcionamiento sin conexión en tu dispositivo antes de depender de él.

Este modo no guarda grabaciones ni sesiones. El texto permanece temporalmente en pantalla hasta otra intervención o hasta cerrar. No cambia la opción global Guardar audio. Reutiliza el reconocimiento local, Translation y las voces de Apple; no añade servicios del desarrollador, cuentas o analítica. Puede haber errores de reconocimiento y traducción: revisa las dos tarjetas.

## Para estudiantes: arquitectura y decisiones

- `SpeakTranslateModel` posee un `CaptionViewModel` independiente y un `TranslationSpeechPlayer`. No se conecta a `TranscriptRepository`: así una conversación breve no genera grabaciones, borradores ni sesiones guardadas.
- La máquina de estados sigue preparado → preparando → escuchando → finalizando → traduciendo. El estado del reproductor indica cuándo habla. La interfaz deshabilita acciones incompatibles.
- `ConversationPause` combina estabilidad del texto y volumen del micrófono. Su reloj usa tiempo monotónico (`systemUptime`) para evitar cambios de hora. El umbral de volumen es una heurística; el botón manual y la espera larga son alternativas necesarias.
- `capture.stop()` se espera antes de crear `TranslationJob`. Se usa el texto final revisado por el reconocedor, no el provisional. El reconocedor libera el micrófono antes de activar reproducción: esto impide que el teléfono transcriba su propia traducción.
- `TranslationRunner` comparte la preparación y ejecución de Apple Translation con el resto de la app. `IncrementalTranslation.merging` valida IDs, orden y respuestas no vacías antes de hablar. La traducción usa español como origen e inglés como destino, independientemente del idioma de los menús.
- Cancelar invalida el token y elimina el trabajo de traducción de forma síncrona, detiene la voz y corta la captura. La limpieza espera una finalización pendiente antes de reiniciar el modelo. Un callback de una traducción antigua no puede producir voz tras Cancelar, salir o volver a otra intervención.
- Se conserva el texto para corregir errores y reintentar, pero editar descarta la traducción derivada. La siguiente escucha siempre exige una pulsación nueva para que el usuario controle quién está hablando.

## Verificación

Las pruebas unitarias ejercitan pausa, finalización antes de voz, revisiones finales, respuesta duplicada, cancelación, interrupción, indisponibilidad y errores de finalización. La prueba de interfaz usa una traducción ficticia explícita de DEBUG, escribe un mensaje, espera su traducción y comprueba que cerrar no conserve la conversación. No demuestra la calidad de traducción de Apple ni el reconocimiento real.

Antes de publicar, probar en iPhone/iPad físicos con modelos preparados: frase española → pausa → inglés audible, ruido ambiental, espera larga/manual, llamada/alarma, salida al fondo, auriculares y primera descarga. Confirmar que la voz inglesa no reaparece como texto español.

[Estado de validación y entrega](speak-and-translate-checkpoint.md).
