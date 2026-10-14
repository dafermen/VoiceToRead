# Práctica de pronunciación — build 19

## Actualización build 20

Entrar desde **Practicar idioma → Practicar pronunciación**. El ejemplo, los intentos y el reconocimiento local opcional siguen el idioma de la sesión: en-US o es-ES. La comprobación se mantiene como reconocimiento de palabras, no evaluación fonética. El plan de evaluación en línea sigue pendiente. [Uso acompañado y accesible](inclusive-use.md).


## Experiencia de uso

Abre **Sessions → sesión guardada → Aprender inglés → Practicar pronunciación**. Funciona incluso si esa sesión no tiene audio guardado. La pantalla tiene tres pasos, controles con texto y símbolos, áreas táctiles cómodas y desplazamiento para letra grande u orientación horizontal.

1. **Escucha el ejemplo:** voz sintética inglesa del iPhone. Activa **Más lento** para la siguiente reproducción. En **Cambiar palabra o frase**, elige un fragmento de hasta ocho palabras o una palabra individual de tu texto.
2. **Ahora tú:** pulsa **Pronunciar** y concede permiso de micrófono si hace falta. **Terminar** detiene la grabación; a los 15 segundos se detiene sola. El indicador muestra nivel y tiempo. No se empieza a grabar por abrir la pantalla.
3. **Escucha y compara:** alterna **Escuchar mi voz** y **Escuchar ejemplo**. **Volver a grabar** elimina el intento anterior. No hay rachas, penalizaciones ni grabación automática entre ejercicios.

**¿Qué entendió el iPhone?** es opcional. Solicita permiso de reconocimiento de voz y procesa el archivo localmente solo cuando existe soporte inglés sin conexión. Presenta el texto reconocido y una comparación de palabras sin distinguir mayúsculas/puntuación. No es una evaluación de fonemas, acento, fluidez o pronunciación. Una diferencia puede provenir del ruido o del motor. Nunca se calcula una nota o porcentaje a partir de la confianza del reconocimiento. Sin modelo o permiso puedes continuar escuchando y comparando.

Las grabaciones demasiado cortas no se aceptan. El reconocimiento vacío, fallido o que tarda más de 15 segundos muestra una invitación a intentar de nuevo, no una mala calificación. El ruido no tiene un detector/calificador propio en esta versión.

## Privacidad y límites

- Intentos WAV mono PCM de 16 kHz, máximo 15 segundos, protegidos localmente y excluidos de backup. Se eliminan al volver a grabar, cambiar palabra, salir de la práctica o pasar al segundo plano. Tras un cierre inesperado, se limpian al siguiente inicio de la app.
- La práctica no utiliza **Save audio with transcript** ni **Continue in background**. Siempre es temporal y en primer plano; no modifica preferencias, sesiones, traducciones ni archivos originales.
- Una interrupción de audio o cambio de dispositivo durante una acción cancela el intento. No se reanuda el micrófono automáticamente.
- No se sube audio, no hay Azure, cuentas nuevas ni cargos de servicio. Preparar voces/modelos del sistema puede requerir una descarga mediante iOS. Si la voz no está disponible se explica cómo revisar Ajustes.
- El ejemplo es sintético, inglés estadounidense. No se promete enseñanza fonética ni una medición objetiva de pronunciación. Las frases se dividen por longitud, no por análisis gramatical; puedes elegir una palabra.
- Se conservan esquema V7, bundle `com.innovalogic.voicetoread` e iOS mínimo 17.

## Cómo está hecho — para estudiantes

`UI/PronunciationPracticeView.swift` agrupa la primera implementación en cuatro piezas:

1. **PracticeRecognition** es lógica sin interfaz: separa texto, crea fragmentos/palabras y compara secuencias. Por ejemplo, «Hello, world!» y «hello world» coinciden; «hello» y «hello world» no. La función solo compara texto, no escucha sonidos. La petición de Speech exige `requiresOnDeviceRecognition`, y antes de ejecutarla el controlador comprueba `supportsOnDeviceRecognition`. No se entrega la respuesta esperada como `contextualStrings`, evitando favorecerla artificialmente.
2. **PracticeFiles** crea un directorio temporal único con protección completa y exclusión de backup. La limpieza se limita a `PronunciationPractice`; nunca busca ni elimina archivos de sesiones. `VoiceToReadApp.init` limpia intentos abandonados del proceso anterior.
3. **PronunciationPractice** es el controlador observable, aislado en MainActor. Sus actividades son idle, permission, recording, example, playback y checking. Antes de otra acción detiene reproducción, síntesis, reconocimiento y temporizador. AVSpeechSynthesizer habla el ejemplo; AVAudioRecorder crea el intento; AVAudioPlayer permite compararlo; SFSpeechRecognizer transcribe el archivo. Un temporizador actualiza el medidor; el propio grabador impone el límite de 15 segundos.
4. **PronunciationPracticeView** dibuja controles según el estado. No duplica el audio en SwiftData ni modifica el historial. Al cambiar selección elimina el intento; al cerrar desactiva audio y observadores. El reproductor anterior de Aprender inglés se detiene antes de abrirla.

**Por qué existe generation:** pedir permiso y reconocer audio son tareas asíncronas. El usuario puede salir antes de recibir una respuesta. Cada cancelación cambia un UUID; una respuesta con el UUID viejo se ignora. Así una autorización tardía no vuelve a encender el micrófono después de cerrar la pantalla.

La lectura de reconocimiento muestra resultados finales, no parciales. Los errores se traducen a acciones comprensibles. Los botones tienen identificadores de accesibilidad para pruebas; no se crean resultados de reconocimiento simulados en la app publicada.

## Evaluación especializada futura — documentada, no activada

El usuario confirmó que no tiene Azure y autorizó terminar primero la práctica local. La evaluación de sonidos queda pendiente:

- Piloto con palabras/frases cortas y un servicio como Azure Pronunciation Assessment, usando texto de referencia y audio; revisar exactitud por fonema y fluidez donde corresponda.
- Backend autenticado con límites de uso, claves fuera de la app, tiempos máximos, presupuesto y tratamiento de errores. No incluir una clave de suscripción en el binario, repositorio o documentación.
- Consentimiento explícito antes de enviar solo el intento de práctica; explicar proveedor, retención y costo. No enviar audios de reuniones ni transcripciones completas. Actualizar política y declaraciones de privacidad antes de habilitarlo.
- Comentarios orientativos, comprensibles y respetuosos con distintos acentos. Consejos articulatorios revisados; no deducirlos de una simple palabra mal reconocida. Probar con ruido, silencios, diferentes acentos y evaluación humana antes de fijar umbrales.
- Mantener la alternativa local sin red. No mostrar una puntuación cuando el servicio no evaluó o la muestra no es adecuada.

## Verificación

Consultar el [punto de reanudación](pronunciation-checkpoint.md) y [reporte](validation-report.md) para resultados ejecutados. En iPhone queda comprobar voz instalada, calidad del micrófono, reconocimiento inglés sin conexión, permisos denegados, Bluetooth, llamadas, bloqueo, letra grande y VoiceOver. Las pruebas de simulador no validan pronunciación ni entrega a TestFlight.

Referencias: [Speech sin conexión](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition), [soporte local](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition), [grabación limitada](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/record(forduration:)), [Azure Pronunciation Assessment](https://learn.microsoft.com/en-us/azure/ai-services/speech-service/how-to-pronunciation-assessment).
