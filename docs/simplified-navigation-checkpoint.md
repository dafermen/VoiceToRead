# Entrega: simplificación de navegación — 2026-10-16

Cambios implementados: [guía de usuario y arquitectura](simplified-navigation.md).

## Validación de esta entrega

- iPhone 15 / iOS 17.2: **130 pruebas unitarias aprobadas** y cinco recorridos UI aprobados en `/private/tmp/vtr-simplification-final.xcresult`: conversación por botón, preparación, lector bilingüe, retirada de marcadores/Favoritos y reproducción bilingüe sin grabación.
- Edición/guardado/reapertura/descarte/exportación SRT aprobados en la versión final, sin instrumentación (`/private/tmp/vtr-editor-dismissal.xcresult`). Los intentos anteriores fallaban al reabrir después de guardar: se ampliaron las áreas táctiles, se separó la identidad de cada presentación del UUID persistido y la prueba ahora espera que el editor desaparezca y el botón sea interactivo antes de tocarlo; ver el texto actualizado detrás de una hoja no confirma que haya terminado de cerrarse.
- iPad Air 5 / iOS 17.2: prueba de espacio de lectura en ambas orientaciones aprobada (`/private/tmp/vtr-simplification-ipad.xcresult`). La prueba de navegación inicialmente esperaba Cancelar en un popover; se adaptó para cerrarlo tocando fuera y pasó (`/private/tmp/vtr-simplification-ipad-final.xcresult`).
- Release final sin firma aprobada, incluida la identidad independiente del editor (`/private/tmp/vtr-simplification-release-editor.log`).
- Catálogos: **698 claves + 2 permisos**; **464 claves extraídas** cubiertas. Metadatos App Store, enlaces locales de documentación y `git diff --check` sin errores.
- Web estática: 10 páginas bilingües y ZIP local regenerados y validados. No se publicó Hostinger ni se envió App Review.
- Capturas revisadas: [Texto y traducción](qa/simplified-navigation/text-and-translation-iphone.png) y [reproductor único](qa/simplified-navigation/unified-playback-iphone.png), además del [inicio en iPad](qa/simplified-navigation/home-ipad.png) y la [corrección guardada](qa/simplified-navigation/corrected-playback-iphone.png). Usan datos de prueba; el SDK local iOS 17 no ejecuta Apple Translation moderno.

La primera compilación de comprobación detectó un observador `scenePhase` retirado por error del lector bilingüe; se restauró antes de estas pruebas. No se distribuyó esa versión. Permanecen las dos advertencias previas de concurrencia en CaptionViewModel y el cierre de la hoja de traducción.

## Compatibilidad

Se conserva el esquema y los datos de marcadores/notas anteriores. Favoritos de sesiones completas, correcciones, grabaciones y expresiones de práctica conservan su función. La web de Hostinger y la publicación App Store no se actualizan automáticamente con este commit.

## Reintento de distribución solicitado — 2026-10-16

El titular pidió una nueva compilación para App Store Connect/TestFlight. El código de la app sigue siendo el validado en `6717215`; este registro activa un nuevo cambio en `main` para el workflow Default.

La ejecución anterior `00b43544-37e8-4f38-9cc7-ec8587ce003f` terminó Archive iOS correctamente, sin errores y con dos advertencias, pero su estado global en GitHub seguía pendiente al solicitar el reintento. No se pudo confirmar su disponibilidad en TestFlight. No confundir el éxito de Archive con procesamiento/distribución completados: comprobar el nuevo flujo y la asignación al grupo Dev antes de anunciar disponibilidad en el iPhone.


## Guardado dentro de Escuchar

En el inicio de comunicación (Conversar/Escuchar/Entrenar), Guardado deja de ser
una pestaña global. La barra inferior contiene Inicio y Ajustes. El acceso con el
icono de reloj y el nombre Guardado se coloca a la derecha del estado de Escuchar;
el estado inicial se acorta a Listo. El nombre respeta Mostrar nombre de los
botones y el título accesible se conserva en modo solo icono. El área táctil es
de al menos 44 puntos. No se cambia el acceso Sesiones del inicio clásico.

El encabezado alinea las primeras líneas de texto cuando caben. ViewThatFits usa
una segunda línea con Guardado alineado a la derecha cuando falta ancho; los
tamaños de accesibilidad usan esa disposición directamente. No se fija una altura
que recorte los textos. El acceso permanece disponible al grabar, pausar y terminar,
igual que la pestaña anterior. El historial conserva sus restricciones existentes
de edición/reproducción mientras hay captura activa.

La navegación usa el destino HomeDestination.sessions ya existente. Volver regresa
al lector y al mismo coordinador de sesión. No hay migración ni cambios en guardado,
favoritos, búsqueda, borradores, papelera, restauración ni confirmaciones. El
accesorio de pantalla completa del lector se oculta mientras el historial está en
la ruta de Inicio, para evitar que quede encima de esa ventana.

Las pruebas UI existentes acceden ahora desde Escuchar. Se añade cobertura de texto
grande, ajuste al ancho, tamaño táctil, regreso al lector, ausencia de Guardado en
la barra inferior y acceso durante captura/pausa. Localización y comprobación de
diff verificadas en Windows; Xcode/XCTest y revisión visual en iPhone/iPad quedan
pendientes de compilación nativa. Los archivos del almacén de sesiones y del
historial no fueron modificados.
