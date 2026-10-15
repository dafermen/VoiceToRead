# Reproducir a mi ritmo y favoritas protegidas

Fuente build 23 · 2026-10-12. Resultados y entrega: [checkpoint](pace-checkpoint.md).

## Uso

1. Abre **Sesiones → una sesión → Audio y subtítulos**.
2. Elige **A mi ritmo**. Pulsa reproducir para escuchar únicamente el párrafo elegido. El texto completo permanece visible después de terminar; puedes desplazarlo si es largo.
3. **Anterior/Siguiente** seleccionan otro párrafo sin reproducirlo. Pulsa Play cuando estés preparado. Al terminar, el mismo botón permite Escuchar de nuevo. Reiniciar párrafo está en Opciones. La lista de párrafos también selecciona en silencio.
4. **Corregir párrafo** pausa la reproducción y abre directamente su texto. Guardar conserva la corrección; Cancelar permite descartar cambios. Al volver se conserva el párrafo, sin reproducción automática.
5. **Continua** permite escuchar la grabación completa desde la posición elegida. Cambiar de modo pausa el audio. El modo se recuerda en este dispositivo.

Los rangos corresponden a párrafos reconocidos, que no siempre equivalen a una oración gramatical. Una sesión sin audio original conserva lectura/edición y puede reproducir una traducción vigente mediante voz generada. Sin tiempos guardados no se inventan rangos. Los tiempos se acotan a la duración real de una grabación incompleta.

Desde Traducción, la corrección en reproducción modifica el texto traducido si se muestran la traducción o ambos idiomas; no reescribe el original. Para corregir el original, selecciona su idioma o entra desde la sesión. Las exportaciones usan el texto corregido. El audio original nunca se modifica; los subtítulos corregidos o traducidos conservan sincronización aproximada dentro del párrafo.

## Favoritas

En el detalle toca **Añadir a favoritas y proteger**. En Sesiones, el filtro **Favoritas** reúne las sesiones protegidas sin copiarlas ni mover sus grabaciones. Al deslizar la fila hacia la izquierda aparecen dos círculos: favorita/proteger y eliminar. Eliminar queda gris y deshabilitado al proteger. El botón de opciones y las acciones de VoiceOver ofrecen acceso sin gesto.

Mientras está protegida, no se puede borrar la sesión ni su audio. Para hacerlo, toca **Favorita protegida**, confirma **Quitar protección**, y después inicia y confirma el borrado por separado. Quitar protección no borra nada. Guarda primero un borrador de recuperación para poder protegerlo.

La protección evita borrados desde VoiceToRead; no es un respaldo, bloqueo de edición ni contraseña. Eliminar la aplicación o perder el dispositivo puede eliminar las favoritas. Exporta una copia de lo importante.

## Idioma y accesibilidad

Ajustes/Settings y las otras pestañas se resuelven explícitamente con el idioma de interfaz. El TabView conserva su identidad para no recrear el coordinador ni una captura activa. El idioma hablado continúa siendo independiente. Controles con etiquetas accesibles y áreas mínimas de 44 puntos; la selección no depende solo del color porque el párrafo permanece en el lector. Validar además VoiceOver, tamaño de texto accesible y uso real con personas; los tests UI no certifican accesibilidad universal.

## Desarrollo

- `PlaybackParagraph.make`: usa UUID, texto revisado y `CaptionTiming`; devuelve un rango completo por párrafo, aunque haya varios cues SRT.
- `SessionPlayer`: `AVAudioEngine` + `AVAudioPlayerNode.scheduleSegment` programan un número limitado de muestras. Un temporizador actualiza la posición visual; no decide el corte. Cada reproducción usa un token para ignorar finalizaciones de una selección anterior.
- `ParagraphEditorView`: reutiliza Undo/Redo y descarte; el callback puede lanzar un error. Solo cierra después de guardar correctamente.
- `SessionFavorite`: tabla independiente añadida en esquema V8; V1–V7 no se redefinen. `requireUnprotected` se ejecuta antes de cualquier eliminación de archivo/modelo.
- `@Query` actualiza biblioteca y protección del reproductor. No se usa un booleano de UI como única barrera de borrado.

Voz sintetizada de traducciones y explicación inclusiva: [guía actual](translated-speech.md).
