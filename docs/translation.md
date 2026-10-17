# Traducción y revisión — build 17

> Actualización 2026-10-16: la interfaz de marcadores de frases y la reproducción inline en Traducción se retiraron. Consulta [la navegación actual](simplified-navigation.md); las referencias anteriores describen el historial de implementación.

Actualización 2026-10-15: al Detener, la app intenta traducir automáticamente el borrador final en dispositivos compatibles. Guardar/Descartar sigue siendo explícito. Ver [flujo actual](playback-unification.md). La vista previa en vivo sigue siendo temporal.

## Actualización build 20: ambos sentidos

Elegir el idioma hablado en Settings antes de empezar. Inglés sigue siendo predeterminado. Una sesión española genera traducción inglesa, y una inglesa genera traducción española; funciona tanto en vista en vivo como guardada. Los párrafos originales, audio y tiempos permanecen intactos. `sourceLocale` opcional conserva compatibilidad con payloads antiguos (inglés implícito). El vocabulario sigue escribiéndose `English = español` y se invierte para sesiones españolas; destinos duplicados se deduplican al invertir. Ver [guía inclusiva](inclusive-use.md) y [validación](accessibility-checkpoint.md). Las secciones de builds anteriores describen el sentido inglés → español original.


## Uso

1. Guarda la sesión y abre **Sessions → tu sesión → Translate to Spanish**.
2. Pulsa **Translate to Spanish**. La primera vez, Apple puede solicitar permiso para descargar inglés y español. Se requiere iOS 18 o posterior y una compilación con el SDK de Translation.
3. La vista abre en **Español** al finalizar. El selector permite **English**, **Español** o **Both**.
4. **Edit Spanish** permite corregir, buscar/reemplazar y deshacer. Guardar modifica solo el español. **Restore translation** restaura la traducción automática dentro del borrador de edición.
5. Compartir abre **Review & share**: comprueba idioma, vigencia y formato; revisa los primeros 800 caracteres antes de **Share file**. Puedes copiar, TXT, PDF, SRT o WebVTT. Los formatos sincronizados se ofrecen solo con tiempos disponibles.
6. **Listen to original** bajo un párrafo traducido abre el audio desde ese párrafo. **Audio & subtitles** abre el reproductor completo; no genera voz española.
7. Busca en **Sessions** por título o texto inglés/español. Un resultado español vigente abre Translation; uno inglés abre el párrafo original. El español obsoleto no se indexa.

La traducción se inicia explícitamente sobre el texto inglés ya corregido. No requiere grabar audio. Puede cancelarse; un intento incompleto no reemplaza una traducción anterior. Traducir otra vez solicita confirmación porque reemplaza también las correcciones españolas.

Si editas el inglés, el snapshot español queda desactualizado: se muestra un aviso y se oculta su lectura/exportación. **Update changed paragraphs** traduce solo párrafos nuevos o modificados: conserva las correcciones españolas de párrafos cuyo UUID y texto inglés no cambiaron. Las correcciones del párrafo modificado se reemplazan. La operación completa se guarda de forma atómica; cancelarla o fallar conserva la copia anterior. Si solo se eliminaron/reordenaron párrafos, se reutiliza la traducción sin llamar a Apple. **Translate again** sobre una traducción vigente continúa siendo un reemplazo completo con confirmación.

## Diccionario personal

En **Settings → Names & translation terms**, escribe una entrada por línea: `meeting = reunión` o solo `OpenAI` para conservar un nombre. **Save vocabulary** guarda hasta 100 entradas breves y únicas en este iPhone. Se ignoran líneas vacías, destinos vacíos, fuentes de más de 80 caracteres y destinos de más de 120. Los cambios orientan nuevas solicitudes de reconocimiento; no reescriben transcripciones existentes ni garantizan que el motor reconozca cada nombre.

Al traducir, coincidencias literales de términos completos se sustituyen por el español preferido; los fragmentos restantes se traducen mediante Apple. No hay sustituciones dentro de palabras. Se priorizan términos largos cuando coinciden al mismo inicio. Esto asegura términos consistentes, pero puede afectar la concordancia o el contexto de la frase: revisa el resultado. Cambiar el diccionario no invalida automáticamente traducciones anteriores; usa **Translate again** para aplicarlo a todo el texto.

## Traducción durante la captura — actualización build 27

En Captions, el botón de bocadillo con caracteres abre **Idiomas en vivo / Live caption display**. Elige **Original**, **Traducción** o **Ambos**. Está disponible con iOS/iPadOS 18+ y SDK compatible; en sistemas anteriores se conserva el lector original. La elección se recuerda, sin cambiar el idioma hablado ni el idioma de los menús.

**Ambos** muestra cada párrafo original y debajo su traducción, desde build 27 en tarjetas con bordes redondeados, sombra suave y etiquetas de idioma. Inglés usa azul y español verde de forma predeterminada, personalizables en Ajustes → Colores por idioma e independientes del sentido de traducción, en una sola columna para iPhone/iPad y pantalla completa. En modo oscuro se adaptan los fondos; alto contraste usa blanco/negro y bordes más marcados. Se admite inglés→español y español→inglés. Cambiar la vista no pausa ni reinicia el micrófono. Original usa el lector completo anterior; Traducción y Ambos comparten el mismo panel y conservan los resultados al alternar entre ellos.

Se traducen únicamente párrafos confirmados: no es traducción palabra por palabra sin demora. En Ambos, las palabras provisionales siguen visibles en el idioma original. Si falta la traducción, se conserva el original con «Esperando traducción…», sin duplicarlo como si ya fuera el texto traducido. **Following / Follow latest** controla el seguimiento; arrastrar hacia textos anteriores lo pausa. Se respetan tamaño, negrita, interlineado, renglones, fondo y pantalla completa.

La ventana conserva los últimos 40 párrafos y procesa lotes de hasta cuatro. Los anteriores siguen en la transcripción original. La vista previa vive en memoria: se pierde al elegir Original o cerrar el panel. Para guardar/exportar la traducción, guarda la sesión y tradúcela desde Sessions. No captura audio interno de YouTube ni de otras apps.

Cambiar a segundo plano cancela la traducción en curso. La captura obedece su preferencia de Background, independiente de esta vista. Al volver se reanudan las traducciones pendientes. Un error muestra Retry sin detener el micrófono ni modificar la transcripción. Se requiere descargar idiomas inicialmente; probar latencia, batería y modo avión en un iPhone antes de depender de esta función durante una conferencia.

## Subtítulos y sincronización

Se reutilizan los UUID de párrafo y las ventanas de subtítulos ingleses. Las palabras españolas se distribuyen proporcionalmente entre esas ventanas. El resultado mantiene el reloj de la sesión, pero la correspondencia palabra a palabra es **aproximada**. La vista bilingüe coloca inglés y español en el mismo intervalo. Revisa legibilidad y tiempos antes de publicar un video.

Las sesiones antiguas sin tiempos pueden traducirse y exportarse como texto/PDF, pero no generan SRT/VTT sincronizado. Cuando hay una grabación parcial, la exportación se limita a su duración disponible. Las pausas eliminadas del audio siguen eliminadas de los subtítulos. El reloj no corresponde automáticamente a un video externo.

## Diseño para estudiantes

- `SessionTranslation`: nuevo modelo independiente en el esquema V6. V1–V5 no cambian; una migración aditiva conserva sesiones, borradores, marcadores, audio y correcciones.
- `TranslationSnapshot.source`: copia exacta de los párrafos ingleses corregidos al iniciar. Compararla con el texto actual detecta traducciones obsoletas, incluso si los UUID siguen siendo iguales.
- `generated`: español automático con los mismos UUID y orden. `edits`: diccionario de cambios del usuario. Así se puede restaurar el resultado automático sin tocar el inglés.
- `saveTranslation`: valida IDs, respuestas completas y vigencia antes de codificar JSON y guardar de forma atómica. Fallos de idioma, cancelación o descarga no producen una traducción parcialmente guardada.
- `IncrementalTranslation`: calcula diferencias por UUID + texto y mezcla resultados manteniendo solo ediciones vigentes.
- `LiveTranslationBuffer`: cola pura limitada a 40 párrafos/cuatro por lote; descarta respuestas de fuentes modificadas.
- `PersonalVocabulary`: valida entradas, escapa expresiones literales y conserva términos/espacios al traducir fragmentos. El reconocimiento usa contextualStrings (compatibilidad) o AnalysisContext (motor moderno).
- `AppleTranslationRunner`: usa `TranslationSession` de Apple, prepara idiomas y procesa párrafos completos. Reporta progreso y comprueba cancelación. El UUID del intento impide guardar una respuesta tardía después de cancelar.
- `TranslatedSubtitles`: función pura y comprobable; no llama al traductor ni al disco. Reutiliza tiempos originales y escapa texto al renderizar SRT/WebVTT.
- `SessionTranslationView`: concentra selección de idioma, edición, exportación y reproducción. La captura ofrece un único menú para Original/Traducción/Ambos. `LiveCaptionDisplay` es una preferencia de presentación; cada pareja se enlaza por UUID en `LiveTranslationBuffer`, no por posición visual.

## Compatibilidad y privacidad

La app sigue admitiendo iOS 17. En ese sistema no se generan traducciones, pero una traducción previamente guardada se puede leer, editar y compartir. `#if canImport(Translation)` permite compilar con Xcode 15.2; la rama de Apple necesita un SDK más reciente y `#available(iOS 18.0, *)` protege su ejecución.

El contenido y las traducciones se guardan localmente, sin CloudKit y excluidos del backup junto con la base existente. Eliminar la sesión elimina su traducción. La app no añade servicios de terceros, claves, cuentas ni clientes HTTP. Apple gestiona la descarga de idiomas y puede recoger métricas del uso de su API que no incluyen el contenido original o traducido, según su documentación. Compartir transmite únicamente al destino elegido por el usuario.

## Validación y límites

Consultar [el informe de validación](validation-report.md). Las pruebas con español prefijado en DEBUG verifican interfaz/persistencia/exportación, **no** la calidad ni el funcionamiento real del traductor de Apple. Es necesario probar en un iPhone iOS 18+: descarga, rechazo de descarga, cancelación, modo avión con idiomas instalados, texto extenso, cierre/reapertura y calidad inglés→español.

Fuentes oficiales:
- [Vocabulario contextual](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/contextualstrings)
- [AnalysisContext](https://developer.apple.com/documentation/speech/analysiscontext)
- [TranslationSession](https://developer.apple.com/documentation/translation/translationsession)
- [Traducción dentro de una app](https://developer.apple.com/documentation/translation/translating-text-within-your-app)
