# Reducción de ruido — build fuente 22

## Uso

En **Ajustes → Preferencias de captura → Reducir ruido de fondo** (English: **Settings → Capture preferences → Reduce background noise**) activa el interruptor antes de iniciar. También está el icono de filtro junto al acceso rápido de audio en Subtítulos. Cambiar la preferencia no inicia el micrófono. La elección queda guardada para sesiones futuras.

Inicialmente está desactivada: el usuario puede comparar dos sesiones breves en su ambiente y decidir. Si la cambia durante la captura o una pausa, se aplica a la próxima sesión. La tarjeta muestra el valor de la sesión actual para evitar confundirlo con la preferencia futura. Pausar y Reanudar conserva el mismo tratamiento de audio.

El procesamiento intenta reducir ruido y eco. Puede afectar voces lejanas, música o sonido de altavoces; no garantiza aislar a una persona entre varias conversaciones. Está orientado a voz cercana. Para conferencias, acercar el dispositivo al ponente y comparar con el filtro apagado. La supresión de Apple no expone una intensidad ajustable, por eso no ofrecemos niveles inventados de reducción.

La cancelación de eco puede eliminar precisamente un video que suena en el altavoz del mismo iPhone. Esta opción no captura audio interno de YouTube u otras apps ni resuelve sus interrupciones de micrófono. El modo de procesamiento puede cambiar la ruta o reducir el volumen de otros sonidos; se solicita la atenuación mínima disponible, sin prometer mezcla inalterada.

## Qué se guarda

La misma señal procesada alimenta la transcripción y, si está activado Guardar audio, el archivo local. Reproducir y exportar ese archivo conserva el tratamiento. No se escribe simultáneamente una copia sin filtro. La opción funciona también sin guardar audio, para la entrada al reconocimiento.

No modifica grabaciones antiguas ni las vuelve a transcribir. Limpieza posterior con copia original/comparación sigue pendiente de otra etapa. No añade servidor, cuenta ni envío de audio. La práctica de pronunciación y el diagnóstico de micrófono conservan sus propios flujos; esta preferencia corresponde a sesiones de subtítulos.

Si el dispositivo no puede iniciar el procesamiento, aparece un error. No se activa silenciosamente una grabación sin filtro. Desactivar la preferencia; si el intento ya creó un borrador, detenerlo y guardar o descartar antes de crear una sesión nueva. El audio y texto previos se conservan.

## Para estudiantes: recorrido de los datos

1. `AppSettings.reduceBackgroundNoise` persiste un booleano en UserDefaults; ausencia significa false.
2. `SessionCoordinator.applyCapturePreferences` copia la preferencia al modelo solo antes de preparar la sesión. Es una instantánea, como Guardar audio.
3. `CaptionViewModel.start` configura el micrófono antes de iniciar Speech. La interfaz de dependencia `AudioCapturing.configureNoiseReduction` permite probarlo con dobles. La implementación predeterminada rechaza true si el capturador no lo soporta: no simula éxito.
4. `AudioCaptureService` usa `.voiceChat` cuando se habilita; apagado conserva `.measurement`. En un AVAudioEngine detenido habilita `setVoiceProcessingEnabled(true)`, comprueba su estado y después consulta el formato e instala el tap. Invertir ese orden podría usar un formato anterior al cambio de unidad de audio.
5. El control automático de ganancia se desactiva para evitar aumento automático del nivel en segmentos silenciosos. Se desactiva ducking avanzado y se solicita `.min` para otros sonidos. Esto no permite controlar la intensidad de supresión.
6. El tap entrega el mismo `CapturedAudio` al grabador y al reconocedor. `CaptureTimeline` sigue contando muestras: no se eliminan silencios ni se cambia la velocidad para limpiar ruido. No hace falta migración SwiftData (V7).
7. Al pausar se detiene el motor; al reanudar se crea otro con la misma elección. El grabador conserva su comprobación de formato: una ruta incompatible produce error, no un archivo con muestras mal interpretadas.

## Validación y límites

Resultados concretos en [informe](validation-report.md) y [checkpoint](noise-checkpoint.md). Las pruebas con dobles verifican preferencias y estados, no calidad acústica. La eficacia necesita comparación en iPhone/iPad real: voz cercana y distante, ventilador/aire acondicionado, varias personas, altavoz, auriculares, pausa/alarma/reanudación y exportación con subtítulos.

Comprobar que se oye voz en cada tramo, que el volumen sigue siendo útil con AGC desactivado, que el reconocimiento en ambos idiomas continúa y que los subtítulos no se desincronizan. No usar un resultado de simulador para afirmar eliminación de ruido o mejora de precisión.

## Fuentes de Apple

- [Procesamiento de voz: supresión, eco y atenuación de otros sonidos](https://developer.apple.com/videos/play/wwdc2023/10235/).
- [Activar procesamiento en AVAudioIONode](https://developer.apple.com/documentation/avfaudio/avaudioionode/setvoiceprocessingenabled(_:)).
