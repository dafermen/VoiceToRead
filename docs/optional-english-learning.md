# Aprendizaje de inglés opcional y título de Inicio — 2026-11-21

## Uso

Inicio muestra **VoiceToRead** sobre Conversar, Escuchar y Entrenar. El título de
la biblioteca principal de Entrenar se unifica con los otros dos módulos. Los
títulos de lecciones, cuentos, prácticas, reproductores y demás pantallas internas
conservan su nombre específico.

**Entrenar se oculta por defecto**, tanto en instalaciones nuevas como en las
existentes que todavía no hayan guardado la nueva opción. Para mostrarlo:

**Ajustes → Aprendizaje de inglés → Habilitar aprendizaje de inglés**.

En inglés: **Settings → English learning → Enable English learning**.

La opción muestra u oculta conjuntamente Lecciones guiadas, Mis prácticas,
Cuentos, Podcasts y Verbos y frases. Su valor se recuerda al cerrar la aplicación.
Al desactivarla también desaparecen las entradas del modo simple y del acceso
de entrenamiento en la vista anterior de conversación.

## Datos y navegación

La clave `englishLearningEnabled` es una preferencia independiente de AppSettings,
con valor inicial false. No modifica idiomas, reconocimiento, traducción,
grabaciones, bibliotecas, favoritos, marcas de realizado, progreso o preferencias
de los lectores. Desactivar no borra ni desinstala contenido. Los JSON, imágenes
y audios preparados siguen incluidos en la aplicación; no se reduce el paquete.
Al volver a habilitar aparecen los datos que ya existían.

Si se oculta mientras se está dentro de Entrenar, se cierra únicamente esa
navegación y se vuelve a Inicio. La salida utiliza los cierres existentes de
reproductores e intentos temporales. No cambia la lógica de reproducción o práctica.
Una escucha/revisión fuera del módulo conserva su identidad y no se reinicia
por activar o desactivar esta opción. El selector mantiene una selección válida
al retirar Entrenar, incluidos texto grande y cuadrícula accesible.

La raíz conserva SessionCoordinator. La selección de módulo está en la raíz para
poder identificar la navegación de Entrenar aun cuando una pantalla interna esté
abierta desde su biblioteca. La identidad de NavigationStack solo se renueva al
ocultar el aprendizaje si esa navegación está activa; no se vincula globalmente
la identidad de Inicio al valor del interruptor.

## Validación

Comprobaciones locales: paridad de catálogos, estructura/referencias del proyecto,
delimitadores Swift, diff y auditoría del alcance. Se verifica que la única
modificación de EnglishTrainingView sea el título de la biblioteca y que el
motor de conversación permanezca idéntico salvo la visibilidad de su acceso.
No cambian servicios de voz, persistencia ni recursos educativos.

Se añaden dos pruebas unitarias de preferencia: valor oculto con ajustes nuevos
y anteriores; persistencia reversible sin cambiar idiomas ni otras preferencias.
Se preparan tres pruebas UI: activación/ocultación desde Mis prácticas y retorno
al mismo entrenamiento guardado; ocultación durante Escuchar sin pausar la
captura; modo simple sin acceso hasta habilitar. La primera comprueba también
el título VoiceToRead del módulo.

Diecisiete pruebas UI anteriores que requieren Entrenar ahora lo habilitan de
forma explícita mediante `--ui-test-english-learning`, reconocido solo por las
fixtures DEBUG de pruebas. Las pruebas del nuevo valor por defecto no incluyen
ese argumento. La aplicación Release usa exclusivamente la preferencia guardada.

Windows no dispone de Xcode/simulador: los XCTest y las pruebas físicas no se
han ejecutado aquí. Una compilación Archive correcta de Xcode Cloud no implica
que se haya ejecutado XCTest.

Aceptación en iPhone/iPad: comprobar Inicio con dos opciones inicialmente;
habilitar, entrar en las cinco bibliotecas y comprobar el título; ocultar desde
una pantalla interna y volver a habilitar conservando prácticas; reiniciar la
app y comprobar la preferencia; repetir con texto accesible, modo simple y vista
anterior. Confirmar que Escuchar continúa grabando al cambiar solo esta opción.
