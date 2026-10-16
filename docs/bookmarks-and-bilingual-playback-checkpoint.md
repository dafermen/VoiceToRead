# Checkpoint — marcadores y escucha bilingüe

## Alcance

Se revisaron tres informes: Bookmarks poco accesible, Both que solo cambiaba el texto visible y botones de Traducción que abrían una hoja sin reproducir. Se añadieron controles visibles de marcador, selección conjunta de texto/audio y escucha directa por párrafo con cola original→traducción.

No cambia el bundle `com.innovalogic.voicetoread`, la versión 1.0 ni el esquema V9. No se añaden servicios externos ni almacenamiento de voz sintetizada. Las grabaciones originales permanecen intactas.

## Evidencia y problemas de validación

- Orden original→traducción en EN→ES y ES→EN, cola continua, final de un párrafo bilingüe, pausa/reanudación, cancelación y callbacks tardíos cubiertos por pruebas.
- El motor de audio reproduce un segmento de un archivo CAF de prueba y su finalización real inicia la voz traducida. Un archivo inaccesible produce un estado de error visible, sin saltar silenciosamente al segundo idioma.
- Marcadores creados con UUID original desde la ruta compartida sobreviven al cierre y reapertura del almacén; quitar desde otra vista elimina el mismo marcador. Se rechazan UUID ajenos a la sesión.
- Una prueba previa de permisos de pronunciación asumía que `Task.yield()` garantizaba iniciar la solicitud. Se reemplazó la espera por una expectativa y una continuación controlada; se mantiene la comprobación de que cerrar impide una captura tardía.
- El simulador iOS 17 fallaba al resolver el scroll automático de XCTest para un menú que estaba visible. El test pulsa el centro del menú localizado por su identificador y verifica selección y resultado.
- La prueba de lectura inyecta y guarda 320 párrafos antes de emitir «New captions…». La espera inicial de 20 segundos resultó insuficiente en este Mac; el vídeo mostró que todavía se estaban procesando los párrafos iniciales. Se espera el resultado real hasta 120 segundos y se comprueba después que releer conserva la posición mientras llegan nuevos párrafos y que Volver al directo alcanza el último. No se usa esa carga sintética para medir latencia del micrófono. Se prueba el nuevo botón visible de marcador, sin depender del menú de selección de texto. El seguimiento de producción conserva su implementación previa.

## Resultado final — 16 de octubre de 2026

- **115 pruebas unitarias correctas** en iPhone 15, simulador iOS 17.2.
- Cinco recorridos de interfaz correctos en iPhone: marcador bilingüe en vivo, guardar/quitar marcador entre sesión y Traducción, reproducción directa EN→ES, geometría/pausa/navegación del reproductor y relectura con 320 párrafos seguida de Volver al directo. La ruta ES→EN también pasó en la primera ejecución de esta corrección.
- Tres recorridos correctos en iPad Air de quinta generación, iOS 17.2: escucha directa ES→EN sin grabación, reproductor bilingüe con navegación silenciosa y marcadores compartidos entre vistas.
- **Release para dispositivo compilada sin firma**, después de los cambios finales. La firma y distribución se verifican en Xcode Cloud.
- Catálogos EN/ES: 634 claves y dos permisos equivalentes; 445 claves extraídas por el compilador cubiertas. Validación de textos de App Store y `git diff --check` correctos.
- Inspección visual de tarjetas, controles y marcadores en capturas de iPhone/iPad. No constituye certificación de accesibilidad.

Resultados locales: `/private/tmp/vtr-bilingual-recovery-phone.xcresult` contiene las 115 pruebas unitarias correctas y el fallo inicial de espera de la prueba de interfaz; `/private/tmp/vtr-follow-final.xcresult` contiene esa prueba de interfaz corregida y aprobada. `/private/tmp/vtr-bilingual-final-phone.xcresult` contiene los otros cuatro recorridos aprobados y el fallo previo de espera. `/private/tmp/vtr-bilingual-cleanrunner-ipad.xcresult` contiene los tres recorridos de iPad aprobados. Release: `/private/tmp/vtr-bilingual-release-complete.log`.

En el momento de preparar el commit, la disponibilidad de esta corrección en TestFlight aún depende de la nueva ejecución de Xcode Cloud y del procesamiento de Apple.

## Límites

Las pruebas locales usan Xcode 15.2 y simuladores iOS 17.2. Las traducciones de los recorridos de interfaz son datos de prueba; no verifican el motor Translation ni sus descargas en iOS 18+. La prueba del segmento usa audio sintético y la prueba de voz registra eventos del sintetizador simulado; la interfaz también se ejecuta con las voces disponibles en el simulador.

Comprobar en iPhone/iPad físico los dos idiomas, las voces instaladas, volumen, auriculares y alarmas. Confirmar con VoiceOver y tamaños de letra habituales del usuario. La documentación mantiene el enfoque de apoyo a discapacidad auditiva/baja visión, aprendizaje de idiomas y práctica infantil acompañada; no declara certificación de accesibilidad.

## Documentación y publicación

README, CHANGELOG, guías de proyecto/junior/arquitectura, reproducción y notas para App Review se actualizan con la selección unificada. El paquete local de textos de App Store se regenera. No se envía la app a revisión ni se modifica el sitio Hostinger. Xcode Cloud debe terminar la distribución y Apple procesar la compilación antes de anunciar disponibilidad en TestFlight.

Nota del entorno: iPad ejecutaba un runner anterior y buscaba controles ya sustituidos, incluso tras compilar con `test`. Se detuvo la ejecución y se desinstaló únicamente `com.innovalogic.voicetoread.uitests.xctrunner` del simulador; la siguiente ejecución de `test` instaló el runner actual y aprobó los tres recorridos. No borrar la app ni los datos del usuario para resolver este problema de pruebas. Las ejecuciones con aquel runner no son evidencia del código nuevo.

## Capturas de QA con datos ficticios

- [Escucha directa y marcador en iPhone](qa/bilingual-playback/iphone-inline.png).
- [Both y marcador en el reproductor de iPad](qa/bilingual-playback/ipad-player.png).
- [Español→inglés y controles por párrafo en iPad](qa/bilingual-playback/ipad-inline.png).
