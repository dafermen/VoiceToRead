# Una experiencia más fácil de entender y recuperar

Actualización: 2026-10-17. VoiceToRead ofrece apoyo a personas con dificultades auditivas, baja visión, movilidad reducida o distintos ritmos de lectura, personas que aprenden otro idioma y niños acompañados por un adulto. Las preferencias describen necesidades, no exigen indicar diagnósticos. La disponibilidad técnica no equivale a certificar accesibilidad universal.

## Cómo usar las mejoras

1. **Modo sencillo**: Ajustes → Accesibilidad y facilidad de uso. Inicio ofrece seis acciones con el mismo estilo y altura mínima: Conversación, Escuchar ahora, Mis sesiones, Practicar idioma, Escribir y hablar y Preparar VoiceToRead. Todas conservan icono y nombre; la altura crece cuando el tamaño de letra lo requiere. Dentro de captura se ocultan las herramientas secundarias en Acciones. El micrófono solo se inicia por acción explícita. Volver a Inicio requiere pausar o detener para no esconder una captura activa. El cambio de modo se bloquea mientras captura/finaliza.
2. **Mostrar nombres de los botones**: conserva los iconos y añade etiquetas cortas a las herramientas de Inicio, además de los controles de grabación y transporte. Las herramientas se distribuyen en una cuadrícula adaptable; al desactivarlo vuelven a una fila compacta. El modo sencillo también muestra esos nombres. Las etiquetas accesibles existen aunque los nombres visuales estén ocultos.
3. **Estado de grabación**: texto y símbolo identifican escucha/grabación, pausa y finalización. La pausa muestra Micrófono apagado y Reanudar grabación. La vibración de aviso es opcional en Ajustes. VoiceOver recibe el anuncio de pausa, no cada actualización del texto. Nunca se reanuda el micrófono solo.
4. **Lectura enfocada**: Ajustes o Audio y subtítulos → Opciones. Oculta selectores secundarios y activa A mi ritmo: Anterior/Siguiente seleccionan sin sonido y reinician el desplazamiento del párrafo; Play empieza la escucha. Original y traducción conservan orden, etiquetas y tamaño de letra. El idioma visible se cambia en Opciones. El texto de reproducción respeta la ampliación de letra del sistema. Con tamaños de accesibilidad, captura y reproducción permiten desplazar toda la pantalla y el transporte se organiza verticalmente para evitar superposiciones. Elegir Continua desactiva Lectura enfocada.
5. **Acceso alternativo**: las acciones de sesión también están disponibles con botón y acciones de accesibilidad, sin exigir deslizar. Los controles son botones nativos etiquetados. Teclado: Comando+R inicia/pausa captura, Comando+punto detiene; Comando+flecha izquierda/derecha selecciona párrafo; Comando+Intro dice una respuesta. La aceptación con VoiceOver, Control por voz, Control por botón y Acceso total con teclado se debe realizar en el dispositivo.
6. **Preparación y demostración**: el aviso inicial y Ajustes llevan a Preparar VoiceToRead/Preparación sin conexión. Las acciones solicitan permiso de micrófono o reconocimiento, instalan recursos cuando están disponibles y prueban traducción con una palabra de ejemplo. No se graba en esta pantalla. La traducción es opcional; puede requerir Internet para descargar idiomas. El resultado de prueba no promete que un recurso nunca vaya a ser eliminado por iOS. La demostración explica cuatro pasos con texto fijo sin usar micrófono, voz ni datos personales.
7. **Eliminados recientemente**: quitar una sesión guardada la oculta de la biblioteca y ofrece Deshacer. Durante 30 días se puede restaurar con su audio, correcciones y traducciones. El plazo no se reinicia por eliminar repetidamente. Eliminar definitivamente pide confirmación; la limpieza por plazo se ejecuta al abrir/volver a la app. Descartar borradores y eliminar solo audio siguen siendo definitivos y se explican por separado. Favoritas protegidas no se pueden enviar a la papelera. Esto no sustituye exportar una copia ni evita pérdida al desinstalar la app.
8. **Escribir y hablar**: disponible desde Inicio sencillo o Subtítulos → Acciones de sesión. Permite comunicarse sin usar la propia voz y no ocupa un acceso en Ajustes. Escribe texto, elige idioma de voz y velocidad; pulsa Decir respuesta. No traduce el texto ni guarda grabaciones. Pausa/Reanudar/Detener controlan la voz; salir borra el texto. En segundo plano se interrumpe la voz. Antes de usarla hay que pausar/detener captura para evitar grabar la propia respuesta. Puede requerir una voz instalada.

## Para estudiantes: responsabilidades y datos

`AppSettings` persiste elecciones de presentación en UserDefaults, separadas del idioma histórico de cada sesión. `SimpleHomeView` utiliza el mismo coordinador y las mismas pantallas, sin duplicar lógica de grabación. `NamedCircleControl` y `AccessibleControlLabelStyle` centralizan icono/nombre; no se usan textos de usuario como claves de traducción. `PlaybackTextCard` usa ScaledMetric para adaptar la letra del lector guardado al sistema.

`WrittenResponseView` conserva el texto en `@State` y reutiliza `TranslationSpeechPlayer` como motor de síntesis. Este motor también puede leer texto escrito: no implica llamar a un traductor. El estado observable controla si se puede editar, cambiar voz o pulsar Pausa. Salir desmonta la vista, cancela la cola y elimina el texto en memoria. Una interrupción exige una nueva acción, nunca reproduce de repente al volver.

La migración V8→V9 agrega `SessionTrash`, una tabla con UUID de sesión y fecha. No modifica clases de esquemas anteriores ni duplica archivos. `moveToTrash` exige sesión finalizada y publicada, sin protección. `restore` elimina el marcador; `delete` elimina marcador y derivados mediante la ruta de borrado existente. El historial filtra por UUID de marcadores, y la selección de práctica hace lo mismo. El repositorio rechaza guardar una traducción que llega tarde sobre una sesión en papelera.

La expiración usa un reloj inyectable en `purgeExpiredTrash(now:)`: los tests pueden avanzar 29/30 días sin esperar ni cambiar la hora del dispositivo. No hay tarea en segundo plano que borre mientras la app está cerrada. Los errores de limpieza se muestran y no se sustituye una base dañada por otra vacía.

## Aceptación con personas y tecnologías de apoyo

Probar con necesidades diferentes, sin pedir información médica. Ofrecer tareas concretas y observar dónde se detienen: iniciar una sesión, descubrir que fue interrumpida, reanudar, guardar, encontrarla, leer en ambos idiomas, escuchar una frase, recuperarla tras eliminar y escribir una respuesta. Preguntar qué esperaban que hiciera cada botón.

- VoiceOver: nombres/estado, orden del foco, volver atrás, idioma de lectura, permisos, editar y compartir; confirmar que captions nuevos no roban foco continuamente.
- Control por voz y Control por botón: todas las acciones sin gestos de precisión, cancelar diálogos, abrir opciones y recuperar una sesión.
- Baja visión: letra máxima, alto contraste, colores sin depender de ellos, reglas, iPhone pequeño, iPad, orientación y teclado abierto.
- Audición y lectura: estado visible sin sonidos, interrupciones con vibración opcional, comprensión de Original/Traducción y navegación que no inicia audio inesperadamente.
- Voz real: inglés/español, auriculares, ruta de audio, alarmas, bloqueo y ausencia de voz instalada.

Registrar dispositivo, versión, recorrido y resultado en el [checkpoint](accessible-experience-checkpoint.md). No marcar etiquetas de accesibilidad de App Store como verificadas solo por contar con controles nativos o pruebas automáticas.

## Marcadores visibles y reproducción bilingüe

[Guía de uso y desarrollo](bookmarks-and-bilingual-playback.md): un selector para leer y escuchar, original seguido de traducción, escucha directa en cada párrafo y marcadores compartidos por UUID. Incluye explicación paso a paso para estudiantes y límites de las pruebas.
