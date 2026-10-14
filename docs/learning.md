# Aprender inglés — builds 18–19

## Actualización build 20 — Practicar idioma

El acceso visible ahora se llama **Practicar idioma**. Usa el idioma original de la sesión (inglés o español); revelar muestra el otro idioma. Ejemplos de voz y reconocimiento opcional usan la locale de esa sesión. Las expresiones antiguas siguen disponibles sin migración V7. Para niños, preferir frases breves elegidas y acompañadas por un adulto, sin puntuaciones de pronunciación. [Guía de uso inclusivo](inclusive-use.md).


## Cómo usarlo

Guarda una sesión y abre **Sessions → sesión → Aprender inglés**. No ocupa espacio extra en el lector de Captions.

1. Lee el fragmento inglés e intenta comprenderlo. Las flechas pasan al anterior/siguiente.
2. Si guardaste audio y existen tiempos, pulsa Play. El audio se detiene al terminar el fragmento. **Repeat** lo repite hasta que pulses Stop, cambies de fragmento o cierres la pantalla. Puedes elegir **0.75×** o **1×**. Este control reproduce la sesión. La nueva opción **Practicar pronunciación** abre [una práctica temporal separada](pronunciation.md), con ejemplo sintético, grabación de tu voz y comparación; no califica pronunciación.
3. **Reveal Spanish** muestra la traducción; vuelve a ocultarse al cambiar de fragmento o colección. Si falta una traducción vigente, **Translate session** abre la función existente. Generarla requiere iOS 18+ y los idiomas de Apple; leer traducciones ya guardadas funciona en iOS 17.
4. **Save expression** permite guardar todo el fragmento o una palabra/expresión contenida en él, con una nota española opcional. Si acortas el inglés, ajusta también la nota. Límite: 500 caracteres ingleses y 1000 de nota española.
5. **Saved expressions** reúne las expresiones de esta sesión, con contexto y acceso al audio del fragmento original. Cerrar/reabrir conserva la colección. **Remove from learning** retira únicamente esa expresión.

El español y los tiempos provienen de los subtítulos actuales; la alineación dentro del párrafo puede ser aproximada. Una expresión corta reproduce su fragmento de contexto, no un recorte exacto de cada palabra. El reproductor comprueba el final cada 50 ms; no es una herramienta de edición de audio de precisión.

Sin audio puedes leer y guardar expresiones. Sin tiempos no se inventan rangos. Una grabación parcial se limita a su duración real. Las expresiones conservan una copia de estudio: corregir después la transcripción o traducción no cambia esas copias automáticamente. El contexto se identifica expresamente como copia guardada. Borrar solo el audio conserva el texto de estudio; borrar la sesión elimina también sus expresiones.

El diccionario de **Settings → Names & translation terms** sigue separado: orienta reconocimiento/traducción. Guardar vocabulario de estudio no altera ese diccionario.

## Capture Preferences

Un único icono de deslizadores abre las preferencias de audio y segundo plano. Sustituye los símbolos de onda y luna que parecían botones distintos. Las opciones y sus valores permanecen iguales; la etiqueta accesible indica su estado.

## Diseño para estudiantes de programación

- `LearningUnit.make`: función pura que combina párrafos corregidos, tiempos y traducción vigente. Produce fragmentos con UUID del párrafo y rango de audio. Conserva los párrafos sin tiempos para practicar lectura y evita usar español obsoleto.
- `LearningExpression`: modelo SwiftData separado. Guarda expresión inglesa, nota española, contexto, referencia a sesión/párrafo y tiempos opcionales. Es una copia para estudiar, no una corrección de la transcripción.
- Esquema **V7**, migración aditiva V6→V7. V1–V6 permanecen intactos. El repositorio valida contenido/fuente antes de insertar, evita duplicados del mismo contexto y guarda con rollback ante errores.
- `PracticePlayer`: AVAudioPlayer independiente del reproductor general y del micrófono. Activa `enableRate` antes de preparar audio. Un Task comprueba el límite del fragmento; cancelar, cambiar de pantalla, pasar a background o recibir una interrupción detiene el bucle sin reinicio automático.
- `EnglishLearningView`: estado local para selección, español oculto, velocidad y repetición; la colección persistente vive en el repositorio. La pantalla no modifica el audio original; el botón de pronunciación abre un controlador separado que pide permiso y solo graba al tocar Pronunciar.
- Las pruebas verifican V6→V7, conservación tras reapertura, borrado independiente, rechazo de fuentes cambiadas, límites de audio, repetición y el recorrido visible. Véase [el punto de reanudación](learning-checkpoint.md) para resultados efectivos.

## Privacidad y alcance

Las expresiones usan la misma base local protegida y excluida de backup; no hay nuevas cuentas ni servicios remotos. La práctica de pronunciación solicita explícitamente los permisos existentes de micrófono y, opcionalmente, reconocimiento. Se reutiliza la traducción de Apple existente. Las copias exportadas previamente no se eliminan al borrar una sesión.

Esta primera etapa incluye escucha/repetición, traducción oculta y expresiones. La práctica local se añadió en build 19; dictado, repaso programado y evaluación especializada de sonidos quedan pendientes. Requiere comprobar en iPhone calidad del audio lento, interrupciones, accesibilidad y disponibilidad TestFlight; compilación local no confirma entrega al teléfono.

Referencia: [velocidad de AVAudioPlayer](https://developer.apple.com/documentation/avfaudio/avaudioplayer/rate).
