# Biblioteca e idiomas — 17 de octubre de 2026

## Para quien utiliza la aplicación

VoiceToRead busca facilitar la comprensión a personas con dificultades auditivas o baja visión, personas que todavía no dominan un idioma y niños que practican con acompañamiento adulto. Los controles conservan etiquetas accesibles, contraste y tamaño dinámico; los colores nunca sustituyen el nombre del idioma. No se promete una certificación de accesibilidad ni reconocimiento/traducción perfectos.

Sesiones abre las grabaciones guardadas, agrupadas por día y ordenadas de más recientes a antiguas. Todas/Favoritas filtra únicamente lo guardado. La búsqueda encuentra título, original corregido y traducción activa vigente. Un aviso breve permite revisar borradores; el menú de opciones abre Borradores y Eliminadas recientemente. En iPad con ancho suficiente, estas categorías aparecen en una barra lateral. No se agregan pestañas globales para la papelera.

Favoritas conserva la protección contra eliminación accidental. Deslizar o usar el botón de acciones permite proteger/eliminar. Quitar protección y eliminar requieren pasos distintos. Eliminar una sesión guardada permite recuperar durante 30 días; descartar un borrador sigue siendo definitivo y requiere confirmación. Una sesión en captura no puede descartarse desde la biblioteca.

## Idiomas sin confusión

- **Idioma de la aplicación:** menús y botones en inglés o español; no cambia la voz.
- **Idioma hablado:** inglés, español, francés o coreano. Inglés continúa como valor inicial.
- **Traducir a:** un idioma diferente al hablado. El valor inicial inglés → español se conserva.
- Cambia el par en Ajustes → Idiomas de voz y traducción o en los selectores cercanos al micrófono antes de comenzar. Al iniciar queda fijo para esa sesión.
- En Conversación elige dos participantes/idiomas arriba. Los dos botones conservan su posición y color. Si eliges el idioma del otro participante, las posiciones se intercambian. Cambiar el par borra el turno temporal para no etiquetar texto antiguo con un idioma nuevo; no modifica las sesiones.
- El modo Por botón sigue siendo inicial: tocar Hablar, hablar, tocar Terminar y reproducir. El micrófono se libera antes de sintetizar voz. Cancelar y las interrupciones invalidan resultados tardíos.
- En Texto y traducción puedes elegir otro destino. Cada destino conserva sus propias correcciones. Regresar a una traducción ya guardada no requiere traducir nuevamente. Traducir otra vez reemplaza solamente el destino seleccionado, con confirmación.
- Reproducción ofrece Original / Traducción / Ambos. Ambos escucha el original y después la traducción del mismo párrafo. Exportar ambos identifica los dos idiomas en el nombre del archivo.
- Colores iniciales: inglés azul, español verde, francés morado y coreano naranja; personalizables. Alto contraste tiene prioridad.

Reconocimiento local, traducción y voz son capacidades distintas. El sistema comprueba la disponibilidad para el idioma/par y dispositivo. Translation requiere iOS/iPadOS 18+ y un SDK compatible; puede pedir descargar modelos. La transcripción conserva su política local, sin fallback a un servidor. Preparación permite comprobar la voz de cada idioma y probar el par elegido. No instalar ni iniciar grabaciones automáticamente.

El diccionario personal existente contiene pares inglés/español: se aplica solo a ese par, nunca se inyecta una traducción española en francés o coreano. La práctica usa el idioma del original; compara lo reconocido con el texto, no califica fonemas. Las notas de expresiones guardadas se etiquetan como traducción, sin inventar el idioma de notas históricas.

## Para estudiantes de programación

`CaptureLanguage` es un catálogo de cuatro locales, con nombre, código y saludo. `InterfaceLanguage` continúa independiente. `AppSettings` guarda el par predeterminado; el selector evita origen = destino. `defaultTarget` solo interpreta datos antiguos y propone un valor inicial: la traducción real recibe un destino explícito.

`SessionLanguagePair` es una nueva tabla V11: enlaza UUID de sesión con el destino. Crear una grabación inserta sesión y par en la misma transacción. La migración añade la tabla sin modificar los modelos de esquemas anteriores. Si falta el registro, una traducción antigua conserva su dirección histórica; cambiar Ajustes no la reinterpreta.

`TranslationSnapshot` añade `targetLocale` opcional a su JSON. La ausencia significa el destino histórico español para fuente inglesa, inglés para fuente española. `TranslationLibrary` guarda snapshots por destino y un destino activo dentro del mismo `SessionTranslation.payload`. El lector admite el JSON antiguo, y el primer guardado lo convierte conservando sus datos. El cambio no añade cuentas ni sincronización remota.

`IncrementalTranslation` reutiliza resultados solo cuando coinciden UUID, texto, origen y destino. De este modo una respuesta española nunca se presenta como coreana. Guardar valida la fuente, conserva otros destinos y aplica cambios atómicamente. Si la transcripción se corrige, los destinos anteriores quedan desactualizados y necesitan actualización antes de reproducir/exportar.

`ParagraphAudioStep` recibe el destino: mantiene el audio grabado para el original y usa la voz del destino para la traducción. `PlaybackLanguagePreference` guarda roles, no idiomas concretos. `SessionLibraryView` adapta navegación a ancho disponible; `SessionHistoryView` separa borradores antes de aplicar la búsqueda o favoritas.

## Verificación y límites

Las pruebas de código cubren las doce direcciones distintas entre cuatro idiomas, persistencia/reapertura, migración V10, correcciones por destino, exportación coreana y preferencia de interfaz independiente. Las pruebas de interfaz usan contenido ficticio y no acreditan calidad lingüística ni disponibilidad de modelos reales.

Antes de publicar: probar francés/coreano en iPhone e iPad compatibles, descargar modelos, rechazar/cancelar descarga, modo avión, alarmas y permisos, voz ausente, textos extensos, Dynamic Type/VoiceOver, captura alternada y exportación. Revisar legibilidad y calidad con hablantes de ambos idiomas. La sincronización de subtítulos traducidos es aproximada y conserva todas las palabras; no es alineación fonética. Ver el informe `session-library-languages-checkpoint.md` para resultados de esta entrega.

Referencias: [Translation availability](https://developer.apple.com/documentation/translation/languageavailability), [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber), [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars).

Los selectores de idioma de Conversación, captura, Ajustes y traducción guardada usan `LanguagePickerControl`: el mismo texto azul, chevron y área de toque. Cada propietario conserva sus reglas de selección. Los nombres de idioma no se ocultan al desactivar Mostrar nombres de los botones. Ver [convenciones compartidas](home-controls.md#selectores-de-idioma-y-regreso-a-inicio).
