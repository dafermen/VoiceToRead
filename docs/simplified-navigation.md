# Menos controles repetidos — 2026-10-16

## Recorrido de uso

- **Subtítulos:** el icono de conversación, junto a la selección de subtítulos en vivo, abre **Hablar y traducir**. Su pantalla explica Automático y Por botón. Ajustes y el inicio sencillo conservan el acceso con nombre completo. Activar Mostrar nombres de botones también identifica el acceso compacto. No inicia el micrófono al abrirlo y se deshabilita cuando otra captura/traducción ocupa el flujo.
- **Comprobar preparación:** está en Ajustes → Preparación sin conexión. Se retiró la franja permanente Antes de una reunión o clase. Los avisos necesarios de permisos, descargas o interrupciones siguen visibles en Subtítulos; retirar una sugerencia no debe ocultar un impedimento para escuchar.
- **Sesiones → Texto y traducción:** sustituye el nombre Traducir a Español/English. Sirve para leer el original y la traducción, corregir la traducción, buscar y exportar. El lápiz de la sesión sigue permitiendo corregir el original. Ya no hay reproducción ni marcadores por párrafo en esta pantalla.
- **Audio y subtítulos:** es el único reproductor de sesiones. Se puede abrir desde la sesión o desde el acceso del lector de traducción. Original, Traducción o Ambos eligen qué mostrar y escuchar. El botón central ▶ inicia/reanuda; cambia a pausa durante reproducción. A mi ritmo espera después del párrafo seleccionado y, en Ambos, después de sus dos idiomas. Anterior/Siguiente seleccionan sin empezar a sonar.
- **✓:** sustituye Listo/Done al cerrar pantallas o finalizar una acción de interfaz. Conserva el nombre accesible y un área mínima de 44 puntos. Guardar, Descartar y Cancelar conservan sus nombres y confirmaciones: cerrar una pantalla no equivale a guardar cambios.

## Marcadores y favoritos

Se retiraron los marcadores de frases del lector original, bilingüe, sesiones, traducción, reproductor, menús, acciones accesibles y selector de exportación. Compartir exporta la transcripción completa revisada. No hay un control de marcador oculto al mantener pulsado un párrafo.

**Favorita y protegida** sigue disponible para sesiones completas. También se mantienen las expresiones guardadas de práctica de idioma; son una función de aprendizaje diferente. No se borran los marcadores/notas antiguos ni se cambia el esquema: los datos heredados permanecen ligados a su sesión y se eliminan según el flujo existente de eliminación de sesiones.

La simplificación busca reducir esfuerzo visual para personas con baja visión o dificultades auditivas, usuarios que aún no dominan un idioma y niños que practican acompañados. Los iconos mantienen nombres para VoiceOver; Mostrar nombres de botones y Modo sencillo siguen ofreciendo ayudas. No se afirma certificación de accesibilidad.

## Para estudiantes: qué cambió y por qué

`SessionTranslationView` dejó de poseer un `ParagraphPlayback`: se retiraron sus tareas de reproducción, velocidades y controles por párrafo. La edición/exportación conserva sus validaciones, IDs y cancelación de traducción. El acceso a `SessionMediaView` entrega idioma y contenido revisado; allí se concentra la cola que reproduce original y traducción. No crear otro reproductor solo para reutilizar un icono.

`CaptionScreen` recibe una acción `speakAndTranslate` y un booleano que indica si se puede abrir. `LiveCaptionView` presenta la hoja usando el coordinador existente. Esta separación evita que un botón compacto cree una segunda captura sin comprobar el estado de la primera. Se eliminó la cabecera permanente de `AppRootView`; `preparationPanel` continúa reaccionando al permiso y la preparación reales.

`DoneButton` comparte representación y nombre accesible, pero recibe la acción de cada pantalla. No decide si guardar: los editores mantienen sus botones Guardar/Aplicar y la protección de cambios pendientes. El lector usa una tarjeta de texto, mientras que el reproductor comparte controles de transporte. En sus acciones inferiores, el tamaño de 44 puntos se aplica dentro de la etiqueta del botón y se define `contentShape(Rectangle())`: añadir espacio fuera de la etiqueta no garantiza ampliar el área que recibe el toque.

El editor de un párrafo usa una identidad nueva por apertura (`ParagraphEditRequest`), separada del UUID persistido de la frase. Así puede abrirse otra vez después de guardar la misma frase. Guardar actualiza el párrafo por su UUID estable y cierra la presentación; Cancelar/Descartar no sobrescriben el texto guardado.

`CaptionBookmark` y `BookmarkNote` siguen en SwiftData por compatibilidad. Quitar una función visible no autoriza destruir datos anteriores ni retirar modelos de una migración. Se retiraron vistas, consultas y parámetros usados solo para mostrar los marcadores. Las pruebas del repositorio conservan cobertura de datos históricos.

## Verificación y límites

Pruebas objetivo: abrir conversación desde el icono, volver de preparación en Ajustes sin iniciar captura, revisar/editar/compartir traducción sin reproducción inline, abrir el reproductor único, escuchar Ambos sin grabación y confirmar ausencia de marcadores sin perder Favoritos. Comprobar también preparación pendiente, pantalla horizontal, iPad, texto grande y VoiceOver.

Las pruebas de simulador usan voces/entradas o traducciones controladas; no validan precisión de reconocimiento ni calidad de Apple Translation. La compilación local no implica distribución a TestFlight. Resultados concretos: [checkpoint](simplified-navigation-checkpoint.md).

La pantalla antes llamada Hablar y traducir ahora es **Conversación**: dos toques por turno en español o inglés, sin cambiar Ajustes. Ver [guía actual](speak-and-translate.md).
