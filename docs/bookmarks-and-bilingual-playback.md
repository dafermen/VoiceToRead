# Marcadores y escucha bilingüe por párrafo

> Actualización 2026-10-16: la interfaz de marcadores de frases y la reproducción inline en Traducción se retiraron. Consulta [la navegación actual](simplified-navigation.md); las referencias anteriores describen el historial de implementación.

## Cómo usarlo

Estas mejoras facilitan volver a una frase, comprender una conversación en otro idioma y practicar con tiempo propio. Están orientadas a apoyar a personas con discapacidad auditiva o baja visión, estudiantes de idiomas y niños acompañados por un adulto. Los nombres de las acciones y sus estados acompañan a los símbolos: el color y el sonido no son la única señal.

### Marcadores (Bookmarks)

- Pulsa **Guardar marcador / Save bookmark** junto a un párrafo finalizado en Captions, en una sesión guardada o en Traducción. En Audio y subtítulos está junto al progreso del párrafo.
- El botón pasa a **Quitar marcador / Remove bookmark** y muestra el símbolo relleno. Volver a pulsarlo quita solo el marcador, no el texto.
- Abre **Marcadores / Bookmarks** en las acciones de captura o en la sesión para consultar las frases guardadas. En una sesión guardada, elegir una devuelve al párrafo correspondiente.
- En la vista bilingüe se guarda el mismo párrafo original, identificado por su UUID. Marcar desde Traducción y quitar desde la sesión son operaciones sobre el mismo marcador, sin duplicados.
- Se conserva el marcador al guardar y reabrir la sesión; descartar un borrador elimina sus datos. Los marcadores de frases son distintos de las **sesiones favoritas protegidas**, que impiden el borrado accidental de una sesión completa.

### Audio y subtítulos

1. Abre Sesiones → una sesión → Audio y subtítulos.
2. Elige el idioma en el menú **Leer y escuchar / Read and listen**. El botón muestra la selección actual: English, Español o Both/Ambos. Esta única elección controla texto y audio.
3. En **Ambos**, cada párrafo reproduce primero el original y después su traducción. La dirección se adapta al idioma de captura.
4. **A mi ritmo / At my pace** termina después de esos dos pasos y conserva el párrafo en pantalla. Anterior y Siguiente seleccionan en silencio; pulsa Reproducir cuando estés preparado. **Continua** pasa al siguiente párrafo después de ambos idiomas.
5. Un solo idioma reproduce únicamente ese idioma. El original usa su fragmento grabado cuando existe; sin grabación o sin tiempos válidos para ese párrafo se usa una voz generada. La traducción usa una voz del dispositivo.

Pausar/Reanudar conserva el paso actual. Cambiar de idioma, seleccionar otra frase, editar o salir detiene el sonido. Tras una interrupción hay que pulsar Reproducir; no se reinicia solo. La velocidad se elige aparte. El modo bilingüe no presenta una duración ficticia para la voz generada.

### Escuchar desde Traducción

El selector superior elige English, Español o Ambos. Debajo de cada párrafo, **Escuchar original / Escuchar traducción / Escuchar ambos** inicia la escucha ahí mismo, sin abrir otra ventana. El botón cambia a Pausar/Reanudar, aparece Detener y el estado indica qué idioma está sonando. Cada pulsación reproduce solo ese párrafo; no continúa al siguiente. El acceso general a Audio y subtítulos sigue disponible para quien quiera usar el reproductor completo.

Las correcciones de texto se aplican a la voz generada; no modifican las palabras del archivo original grabado. Una traducción obsoleta tras editar el original no se reproduce: primero debe actualizarse. No se añade doblaje, exportación de voz sintética, servicios en línea ni un nuevo tratamiento de datos.

## Qué ocurría y cómo se corrigió

Antes, «Both» solo seleccionaba el texto visible; la fuente de audio se elegía por separado. Los botones de cada traducción abrían el reproductor sin iniciarlo. Los marcadores estaban disponibles mediante pulsación prolongada en el original en vivo, pero faltaban controles visibles en las tarjetas bilingües y los párrafos guardados. Esos comportamientos hacían difícil entender qué acción realizar.

## Explicación para estudiantes

- `ParagraphAudioStep.make` transforma párrafos con UUID estable en una lista ordenada: original A → traducción A → original B → traducción B. Cada paso tiene texto, idioma, tipo de voz y, si corresponde, rango del archivo grabado. La misma función sirve para un párrafo o muchos.
- `ParagraphPlayback` coordina dos motores existentes: `SessionPlayer` para muestras grabadas y `TranslationSpeechPlayer` para síntesis. Ambos avisan al terminar. El controlador inicia el siguiente paso **cuando termina el anterior**, no después de un tiempo estimado.
- El estado observable (`idle`, `playing`, `paused`, `completed`) actualiza botones y resaltado de SwiftUI. No hace falta un temporizador para decidir qué idioma viene después. El temporizador del audio grabado solo actualiza el progreso visible.
- Cada motor invalida su token al detenerse. Así, una respuesta tardía de una reproducción cancelada no empieza otro idioma ni otro párrafo. Los callbacks usan referencias débiles para evitar ciclos de retención. Salir elimina los observadores de interrupciones.
- En `SessionMediaView`, el selector de lectura sincroniza la fuente de escucha. La cola compartida resuelve Ambos y el original sin archivo; las rutas existentes conservan la reproducción de un solo idioma con archivo/voz.
- `SessionTranslationView` utiliza el mismo controlador con los pasos de un único UUID. No abre una hoja para reproducir un párrafo. Antes de crear pasos verifica que el snapshot traducido coincide con el original revisado.
- `TranscriptRepository.toggleBookmark(paragraphID:in:)` comprueba pertenencia a la sesión y rechaza sesiones en papelera. Reutiliza la persistencia existente; `@Query` actualiza los botones de todas las vistas. La traducción conserva el UUID original, por eso no requiere otro tipo de marcador ni migración de base de datos.

## Verificación

Consultar [el checkpoint de esta corrección](bookmarks-and-bilingual-playback-checkpoint.md) para resultados, limitaciones y distribución. Las pruebas cubren orden de idiomas, finalización real del segmento grabado, pausa, cancelación, interrupciones, reapertura de marcadores y recorridos de interfaz. La disponibilidad de voces, auriculares y alarmas debe comprobarse también en dispositivos físicos. Las pruebas no certifican accesibilidad completa ni la precisión de traducción.
