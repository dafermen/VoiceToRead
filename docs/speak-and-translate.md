# Conversación: español e inglés por turnos

## Para comunicarse en situaciones cotidianas

Conversación (antes Hablar y traducir) permite pedir algo, hacer una pregunta y entender la respuesta en el otro idioma. Es una ayuda para personas que no dominan el idioma, personas con dificultades auditivas o del habla y niños que practican acompañados por un adulto. Las tarjetas, el tamaño de lectura compartido y los controles etiquetados apoyan también a personas con baja visión. No garantiza traducción exacta ni sustituye interpretación profesional.

## Uso: dos toques por turno

1. Antes de empezar una grabación, abre el **icono de conversación**, junto al selector de subtítulos en vivo. También está en el inicio sencillo; Ajustes contiene preferencias, no un acceso duplicado a Conversación. No está disponible durante otra captura o traducción automática de sesión.
2. Los dos botones están en la misma fila: **español a la izquierda e inglés a la derecha**. Pulsa **Hablar en español**. Habla sin mantener pulsado el botón. Este cambia a **Terminar y reproducir en inglés**: púlsalo cuando acabes. La app finaliza el reconocimiento, traduce y reproduce en inglés automáticamente.
3. Para la respuesta, pulsa **Hablar en inglés**. Cuando la otra persona termine, pulsa el mismo botón, ahora **Terminar y reproducir en español**. Oirás la traducción española.
4. Los dos botones permanecen visibles; el turno incompatible queda deshabilitado. El estado indica el idioma que está escuchando, traduciendo o reproduciendo. Original y traducción aparecen en tarjetas con etiquetas, colores y el mismo tamaño de lectura.
5. **Reproducir** y **Corregir mensaje** comparten una fila debajo de las tarjetas. Se retira Escribir en su lugar para simplificar esta pantalla. **Detener audio** corta la voz y conserva el texto. **Reproducir en inglés/español** repite la última traducción. El siguiente turno siempre requiere una pulsación nueva; no cambia de persona automáticamente.
6. Para corregir un error, pulsa **Corregir mensaje** y después **Traducir y reproducir**. Cancelar el editor conserva el intercambio anterior. Si falla la traducción, puedes reintentar con **Traducir y reproducir** sin volver a hablar.

Cada turno conserva sus textos hasta iniciar otro, aplicar una edición o cerrar la pantalla. No hay historial de conversación guardado. El idioma del turno no cambia el idioma global de captura ni el idioma de los menús.

## Opciones y límites

El modo inicial es **Por botón**, también para quienes usaban la pantalla anterior. En **Opciones de conversación (···)** puedes elegir **Automático**: una pausa estimada de 3 o 5 segundos termina la escucha, traduce y reproduce. También puedes terminar con el botón. La app recuerda el modo, pero no el mensaje; la pausa vuelve a 3 segundos al reabrir.

En Por botón, las pausas naturales no terminan la escucha. Cada turno tiene un límite de un minuto o 4000 caracteres: al alcanzarlo se finaliza y traduce, pero hay que pulsar Reproducir para oírlo. Sin texto reconocido durante 15 segundos se detiene y permite reintentar. La detección automática es una estimación basada en texto estable y volumen bajo, no una comprensión del final de una frase.

El micrófono permanece apagado durante la traducción y la voz. No se puede iniciar otro turno mientras habla: espera o pulsa Detener audio. Salir o mandar la app al fondo cancela captura, traducción y voz. Una interrupción requiere revisar el texto o iniciar otro turno; nunca reinicia el micrófono solo.

## Requisitos y privacidad

La traducción necesita iOS/iPadOS 18 o posterior, una compilación compatible y los modelos de Apple preparados. El reconocimiento y las voces de ambos idiomas deben estar disponibles. El primer uso puede solicitar permisos y descargar recursos; prueba antes de depender de la app sin conexión. La salida y el volumen dependen del dispositivo y los auriculares elegidos.

Conversación no guarda grabaciones ni sesiones y no cambia Guardar audio. Reutiliza reconocimiento local, Apple Translation y voces de Apple; no añade cuentas, analítica ni servidores del desarrollador. Revisa los textos: el reconocimiento y la traducción pueden contener errores.

## Para estudiantes: arquitectura y decisiones

- `SpeakTranslateModel` posee un `CaptionViewModel` independiente y un `TranslationSpeechPlayer`. No usa `TranscriptRepository`: esta conversación temporal no crea sesiones ni archivos de audio.
- Estados: preparado → preparando → escuchando → finalizando → traduciendo → voz → preparado. `canEdit` exige estado preparado y reproductor inactivo. El modelo y la interfaz impiden comenzar otro micrófono durante reproducción.
- `start(language:)` captura el idioma del turno antes de iniciar el trabajo asíncrono. Configura el reconocedor con ese idioma. `IncrementalTranslation` recibe el mismo origen y `play()` utiliza `language.opposite`; por eso una respuesta inglesa produce voz española. Cambiar la dirección no modifica preferencias globales.
- `finish()` espera `capture.stop()` y utiliza el texto final revisado por el reconocedor. Solo entonces crea la traducción. Esto evita traducir un fragmento provisional o grabar la voz del teléfono.
- `Mode` decide cuándo terminar de escuchar. Ambos modos reproducen al pulsar Terminar; en automático también al detectar pausa. `speakWhenComplete` conserva la decisión del trabajo. La excepción es el límite manual de duración/caracteres, que permite revisar y pulsar Play.
- `@AppStorage("conversationTurnMode")` recuerda el modo. La clave nueva evita heredar el antiguo flujo de tres pasos; la primera apertura usa Por botón. El texto es estado temporal, no una preferencia.
- `ConversationPause` combina estabilidad del texto y nivel del micrófono, usando `systemUptime` para que cambiar el reloj no afecte la pausa. El botón manual sigue disponible en ambientes ruidosos.
- `TranslationRunner` ejecuta Apple Translation. `IncrementalTranslation.merging` valida identificadores y respuestas no vacías. Un error conserva el original para reintentar; una respuesta vieja no puede completar un trabajo nuevo.
- Cancelar invalida el token y el trabajo de forma síncrona, detiene la voz y serializa la limpieza con la finalización pendiente. Salir o ir al fondo aplica la misma cancelación.
- El editor tiene una copia local: Cancelar no altera la tarjeta. Aplicar invalida la traducción anterior y crea otra con el idioma elegido. Tarjetas compartidas y controles con texto evitan depender solo del color o de iconos desconocidos.

## Verificación

Las pruebas unitarias cubren ambos sentidos, revisión final antes de voz, bloqueo de otra captura durante reproducción, errores/reintento, callbacks antiguos, interrupciones, cancelación, pausa automática y límites manuales. Las pruebas de interfaz recorren dos turnos, detener, reabrir, cancelar una corrección y recordar el modo.

Los dobles de micrófono, traducción y voz de las pruebas UI son explícitos y solo existen en DEBUG. Verifican el flujo, no la calidad de los servicios reales. Probar físicamente español → inglés y respuesta inglesa → español, permisos/descargas, ruido, auriculares, llamada/alarma, letra grande y VoiceOver antes de dar por validada la experiencia completa.

[Estado de validación y entrega](speak-and-translate-checkpoint.md).

## Identificación por color

Botones de idioma y tarjetas comparten el color del idioma: español verde e inglés azul inicialmente. Ajustes → Colores por idioma permite cambiarlos, ver una muestra y restaurarlos. Reproducir usa el color del idioma de destino. [Detalles y accesibilidad](language-colors.md).
