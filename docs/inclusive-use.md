# VoiceToRead: comprender, leer y practicar

Fuente build 20, 11 de octubre de 2026. La app acompaña conversaciones, reuniones, conferencias y clases mediante texto, traducción y práctica. Amplía sus usos más allá de aprender inglés: ayuda a acceder a lo que se dice y a repasar un idioma al ritmo de cada persona.

## Para quién y cómo usarla

| Necesidad | Propuesta práctica | Límite que debemos explicar |
| --- | --- | --- |
| Seguir un idioma que todavía no se domina | Elegir el idioma hablado, leer subtítulos y activar traducción al otro idioma | La traducción puede omitir matices; revisar datos importantes |
| Apoyo a personas sordas o con pérdida auditiva | Texto en vivo, pantalla completa, revisión y señal visual de pausa | Solo recoge lo que llega al micrófono; no identifica hablantes ni garantiza todos los sonidos |
| Apoyo a personas con baja visión | Tamaño adaptable, gesto de ampliación, negrita, interlineado, alto contraste y controles con nombres accesibles | Los colores pastel son preferencias de lectura, no un tratamiento ni garantía de accesibilidad |
| Personas que usan VoiceOver | Botones con etiquetas; anuncio cuando se pausa y control Reanudar identificable | Revisar navegación real con usuarios; no se lee automáticamente cada subtítulo nuevo |
| Niños que practican otro idioma | Un adulto elige una frase corta, escucha el ejemplo, deja pronunciar y compara sin calificaciones | Acompañamiento docente/familiar; no puntuación fonética ni diagnóstico del aprendizaje |

Para una actividad breve con niños: escoger una frase apropiada, escucharla normal o despacio, practicar una palabra, grabar un intento y comparar sin presión. Parar cuando resulte cansado. La app no introduce premios, rachas ni notas de pronunciación. Las grabaciones de práctica son temporales; guardar audio de sesiones sigue siendo una opción explícita. El adulto debe revisar qué voces/textos comparte y usar las autorizaciones correspondientes al contexto.

## Inglés o español

Antes de iniciar una sesión, abrir **Settings → Voice capture and captions → Spoken language**. **English (en-US)** es el valor inicial; **Español (es-ES)** activa reconocimiento de español. Este selector afecta al contenido hablado. Para los menús usa la sección independiente App interface → Menus and buttons (Interfaz de la aplicación → Menús y botones). No hay detección automática ni mezcla de dos idiomas en una misma sesión. Preparar el modelo para el idioma elegido y comprobar disponibilidad en el dispositivo.

La opción queda recordada. Una sesión conserva su idioma después de iniciarse, incluso al pausar, recibir una interrupción o reanudar. Para cambiarlo: detener, guardar o descartar, crear una nueva sesión y elegir el idioma. Esto evita que una sola grabación mezcle configuraciones incompatibles.

La traducción en vivo y la de sesiones guardadas usan el otro idioma: inglés → español o español → inglés. Generar traducción requiere iOS/iPadOS 18 o posterior, un binario con soporte Translation y modelos compatibles preparados. El audio original conserva su idioma; traducir subtítulos no dobla ni traduce el audio. TXT/PDF y SRT/WebVTT permiten original, traducción o ambos. Las correcciones del destino no cambian el original; sus tiempos dentro del párrafo son aproximados.

**Practicar idioma** usa el idioma original de la sesión para ejemplos de voz, palabras/frases y reconocimiento local opcional. Permite escuchar, repetir y comparar, no evaluar fonemas. La evaluación en línea permanece como trabajo futuro documentado; no requiere Azure ni cuentas en esta versión.

## Lectura y pausa

En **Aa → Fondo de lectura** o en Settings, elegir System, amarillo, azul, verde o morado claro. El texto sobre un fondo pastel permanece oscuro aunque el resto de la app use apariencia oscura. Activar **Renglones de cuaderno** si ayudan a seguir visualmente el texto; son guías decorativas del área, no subrayado semántico de cada frase. Los ajustes persisten. **Alto contraste** manda sobre papel y renglones, sin borrar sus preferencias.

Si una alarma, otra aplicación o el usuario pausa la escucha, aparece **Escucha en pausa · Micrófono apagado** con **Resume / Reanudar**. No se están capturando nuevas palabras. El aviso permanece en pantalla completa, utiliza texto e icono (no solo color), emite un anuncio de accesibilidad y solicita feedback háptico cuando el dispositivo lo admite. En segundo plano no se garantiza que se vea/escuche el aviso: revisar el estado al volver. Reanudar es siempre una decisión del usuario; no hay reinicio automático del micrófono.

## iPhone e iPad

La aplicación se configura como universal (`UIDeviceFamily` 1 y 2), con icono universal, cuatro orientaciones en iPad y las orientaciones anteriores en iPhone. Se adapta al espacio de la ventana; no exige pantalla completa de iPad. Los datos son locales a cada dispositivo: instalarla en iPad no sincroniza automáticamente las sesiones del iPhone. Descargar en TestFlight una compilación que incluya este cambio; una versión anterior continúa siendo solo iPhone.

Comprobar en iPad físico: micrófono y permisos, modelos de los dos idiomas, rotación, ventana dividida/redimensionada, teclado, sheets y menús de compartir. Soporte de proyecto y simulador no equivalen a aceptar todos los modelos físicos.

## Accesibilidad honesta

VoiceToRead ofrece apoyos de lectura y práctica; no sustituye servicios profesionales de interpretación o accesibilidad cuando son necesarios. El reconocimiento puede equivocarse por ruido, distancia o acentos. Conservar original y revisar antes de compartir. No anunciar conformidad WCAG, certificación médica ni categoría infantil sin evaluación específica. Para la próxima aceptación incluir personas que utilicen VoiceOver, baja visión o subtítulos habitualmente.

Referencias de implementación: [orientaciones UIKit](https://developer.apple.com/documentation/uikit/uiviewcontroller/supportedinterfaceorientations), [ventanas iPad y UIRequiresFullScreen](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key) y [anuncios de accesibilidad](https://developer.apple.com/documentation/uikit/uiaccessibility/notification/announcement).


## Actualización build 21

Ver [interfaz bilingüe y primera preparación](interface-and-onboarding.md). El idioma de menús es independiente del idioma hablado. Guardar audio está activado inicialmente solo en instalaciones nuevas; las elecciones anteriores se conservan. Los renglones se calculan con el texto de cada párrafo. Estado de entrega: [checkpoint](interface-checkpoint.md).
