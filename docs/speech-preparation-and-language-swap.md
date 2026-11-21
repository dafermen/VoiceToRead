# Intercambio de idiomas y preparación de voz — 2026-11-21

## Fallos reportados

El usuario no podía intercambiar los idiomas de Conversar con las flechas del
centro. También reportó que los nuevos idiomas no instalaban su modelo: aparecía
«Volver a comprobar» y el recorrido se repetía sin poder hablar.

Se identificaron tres problemas concretos en el código:

1. Las flechas de `CommunicationLanguagePair` eran una imagen decorativa, sin acción.
2. El adaptador moderno reservaba nuevos idiomas sin liberar reservas inactivas.
   Apple limita el número de reservas por aplicación/dispositivo. Las reservas
   de sesiones anteriores pueden agotar ese límite, incluso al reiniciar la app.
3. Si SpeechTranscriber no admitía el idioma, la selección pasaba directamente a
   SFSpeechRecognizer. Ese adaptador no tiene una API para instalar su modelo.
   La UI ofrecía comprobar otra vez, no una preparación mediante DictationTranscriber.
   Además, un error o descarga pendiente no tenía un reintento que iniciara/retomara
   la instalación; comprobar solo podía repetir el mismo estado.

No se recibió el NSError del iPhone: la captura y el texto «Volver a comprobar»
no permiten atribuir cada idioma a una única causa. La corrección trata los
fallos verificables anteriores; la descarga real en el teléfono requiere aceptación.

## Corrección

- Conversar tiene un botón real «Intercambiar idiomas», con área táctil de 44×44,
  VoiceOver y presentación en tamaños accesibles. Invierte exactamente los dos
  idiomas visibles y prepara el nuevo origen. Utiliza el mismo comportamiento de
  cambio explícito de los selectores; no modifica preferencias de Escuchar ni
  sesiones guardadas. Se bloquea mientras hay captura, traducción, preparación o voz.
  Otros módulos conservan su flecha indicativa cuando no reciben una acción.
- En iOS 26 con SDK compatible se selecciona, antes de grabar:
  SpeechTranscriber → DictationTranscriber → adaptador local SFSpeechRecognizer.
  Solo un idioma/dispositivo no compatible permite pasar al siguiente motor.
  Una descarga ausente permanece en su motor instalable. Los errores durante
  captura nunca provocan un cambio silencioso de motor. iOS anteriores mantienen
  el camino local previo.
- DictationTranscriber comparte la misma captura, conversión, colas, finalización,
  rango de audio y desplazamiento de sesión. Conserva subtítulos provisionales y
  puntuación automática; usa los modelos de dictado locales de Apple y admite
  su instalación con AssetInventory cuando el sistema los ofrezca. Los nombres
  y términos del vocabulario personal se pasan al contexto de dictado del idioma,
  conservando las ayudas que usaba el adaptador de compatibilidad anterior.
- `SpeechAssetReservationManager` es compartido, serializa reservas y consulta el
  límite del dispositivo. Primero reutiliza reservas equivalentes. Solo si necesita
  espacio libera la reserva inactiva menos reciente; nunca una protegida por una
  captura o descarga, aunque varias operaciones compartan el mismo idioma.
  Protege el modelo hasta finalizar/cancelar su uso. Las cancelaciones no dejan
  propietarios invisibles; una liberación rechazada termina con error en lugar
  de girar en bucle. No borra sesiones, audios, textos ni ajustes. Apple puede
  retirar posteriormente modelos que ya no estén reservados.
- Los errores muestran «Reintentar preparación del modelo de voz». El reintento
  vuelve a comprobar el idioma y realiza la instalación si falta el modelo o si
  hay una descarga pendiente. Apple consolida las solicitudes duplicadas.
  Preparar/instalar nunca abre el micrófono. Un idioma no compatible da una
  indicación de cambiar idioma/actualizar iOS y no un botón de comprobación sin salida.

No se añaden servicios remotos. Siguen siendo necesarias conexión y capacidad
para descargar modelos. El soporte de traducción no garantiza reconocimiento
local para todos los dispositivos/versiones; no se promete mantener nueve
modelos reservados simultáneamente. El adaptador antiguo sigue exigiendo
`requiresOnDeviceRecognition = true` y no puede instalar el modelo del sistema.

## Validación

Se prepararon diez regresiones nativas: una UI para intercambio alemán/español
en ambos sentidos y bloqueo durante captura; dos de reintento/descarga pendiente
sin iniciar micrófono; cinco de cuota, nueve idiomas, reservas compartidas/activas,
cancelación y liberación rechazada; dos del camino de dictado instalable y retorno
al adaptador antiguo cuando ambos motores nuevos son incompatibles.

Comprobaciones disponibles en Windows: paridad de localización, estructura y
referencias Xcode, delimitadores Swift, diff y conservación de la tubería de
audio/conversión/finalización y de los cálculos temporales. Ningún contenido
educativo, biblioteca de sesiones o dato persistido cambia.

No hay Xcode/Swift ni simulador instalados localmente. Los XCTest y la aceptación
física quedan pendientes de Mac/iPhone. Una compilación Archive exitosa en Xcode
Cloud valida producción, pero no demuestra que se hayan ejecutado estos XCTest.

Aceptación en iPhone: intercambiar el par dos veces, comprobar nombres y origen
del turno; instalar alemán, neerlandés y ruso, cerrar/reabrir y cambiar entre
idiomas; probar sin red una vez preparados; confirmar que una instalación fallida
puede reintentarse en la misma pantalla. Verificar también inglés/español,
pausa/reanudación, conservación de sesiones, tiempos de párrafo, colores y traducción.

## Fuentes de Apple

- [Reserva de modelos y sus límites](https://developer.apple.com/documentation/speech/assetinventory).
- [Límite variable por dispositivo/almacenamiento](https://developer.apple.com/documentation/speech/assetinventory/maximumreservedlocales).
- [Liberación de una reserva](https://developer.apple.com/documentation/speech/assetinventory/release(reservedlocale:)).
- [DictationTranscriber: modelos locales e idiomas descargables](https://developer.apple.com/documentation/speech/dictationtranscriber).
- [Descarga e instalación y sus reintentos](https://developer.apple.com/documentation/speech/assetinstallationrequest/downloadandinstall()).
