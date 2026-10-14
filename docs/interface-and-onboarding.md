# Interfaz bilingüe, primera preparación y renglones — build 21

## Dos idiomas con funciones diferentes

En **Settings → App interface → Menus and buttons** elige **English** o **Español**. En español: **Ajustes → Interfaz de la aplicación → Menús y botones**. Cambia inmediatamente las etiquetas, instrucciones y avisos de la aplicación. Se recuerda al volver a abrirla. El valor inicial es inglés.

En una sección separada, **Voice capture and captions → Spoken language** / **Captura de voz y subtítulos → Idioma que se habla**, elige el idioma real de la conversación. Inglés sigue siendo el predeterminado. Una sesión iniciada mantiene su idioma incluso al pausar; termina y guarda o descarta, y crea una nueva para cambiarlo. La traducción y la práctica siguen el idioma de esa sesión, no el idioma de los menús.

Ejemplo: menús en español, conversación en inglés y traducción al español. Cambiar los menús a inglés no modifica palabras, grabaciones ni traducciones. Los nombres English/Español permanecen reconocibles en ambos menús. Los diálogos del sistema (permisos, compartir y descargas de Apple) y errores suministrados por iOS pueden seguir el idioma del sistema.

## Primera preparación

Captions muestra una tarjeta visible cuando falta acceso al micrófono, autorización de reconocimiento o un modelo local. La tarjeta ofrece la acción correspondiente: permitir, descargar cuando el motor lo admite, abrir Ajustes o revisar el estado. El texto no queda truncado en una sola línea. No se inicia el micrófono al autorizar permisos ni al instalar un modelo: hay que pulsar el botón de escucha.

Los avisos de la práctica, incluida una voz no disponible, tienen fondo destacado y texto completo. Si falta una voz, se muestran instrucciones para prepararla en Accesibilidad del dispositivo. Las voces de síntesis (escuchar ejemplos), modelos de reconocimiento (transcribir) y modelos de traducción son recursos diferentes; no prometer una descarga única que prepare los tres.

**Guardar audio** empieza activado en una instalación nueva. Se conserva cualquier elección anterior, incluido desactivado. Las instalaciones antiguas que nunca escribieron esa preferencia conservan el antiguo valor desactivado. El botón Audio on/Audio activado antes de escuchar permite revisarlo y cambiarlo. Esta preferencia no inicia la grabación. Segundo plano continúa desactivado inicialmente.

## Renglones

Las guías pertenecen a cada párrafo y se calculan desde la misma distribución TextKit que dibuja las letras. Al pausar, reanudar, cambiar el ancho, girar o modificar tamaño/interlineado, texto y líneas se recalculan juntos. No se dibuja una cuadrícula fija debajo de texto que se desplaza por separado. Se deja espacio para letras con descendentes (g, j, p, q, y). Alto contraste sigue teniendo prioridad y oculta guías decorativas.

## Aceptación en el dispositivo

1. Cambiar solo el idioma de interfaz, volver a Captions y confirmar que la captura mantiene su idioma. Repetir durante pausa; la sesión debe conservarse.
2. En instalación nueva, confirmar audio activado antes de iniciar; desactivarlo y comprobar que persiste. En actualización, conservar la elección anterior. No borrar sesiones del teléfono para hacer esta prueba: usar un simulador o dispositivo de prueba.
3. Denegar y después permitir micrófono/reconocimiento, comprobar los avisos y que nada empieza automáticamente. Verificar preparación sin modelo y voz de práctica no disponible.
4. Activar guías, dictar una frase larga con descendentes, pausar/reanudar, girar, ampliar letra y probar interlineados. Repetir en iPad y pantalla completa.
5. Probar VoiceOver y tamaño accesible, colores claros/oscuros y alto contraste. La accesibilidad es una ayuda en desarrollo, no certificación.

## Para estudiantes

`InterfaceLanguage` es una preferencia de presentación (`en`/`es`). `CaptureLanguage` configura el procesamiento (`en-US`/`es-ES`) y se guarda en cada sesión. Separarlas evita que una acción visual cambie la fuente de datos.

SwiftUI localiza las claves literales con el locale del entorno. `uiKey` da contexto de tipo a expresiones condicionales; `LocalizedStringKey` convierte únicamente mensajes de la aplicación almacenados como String. Los textos del usuario usan String/Text(verbatim:) y **nunca** se buscan en el catálogo. `InterfaceLocalization` selecciona el recurso para anuncios UIKit. Los catálogos en `Resources/en.lproj` y `es.lproj` incluyen `InfoPlist.strings` para las razones de permiso.

`NotebookTextView` utiliza UITextView y un único NSLayoutManager: mide y dibuja el mismo texto. `NotebookLayoutManager` obtiene los fragmentos reales de línea, su línea base y el descenso de la fuente, y dibuja una regla por línea. El rectángulo del fragmento incluye interlineado y no equivale a los límites de tinta: confundirlos desplaza la guía hacia la línea siguiente. Una prueba geométrica cambia anchos/tamaños/interlineados y comprueba que las guías no se solapen con la línea siguiente. La prueba visual sigue siendo necesaria.

Referencias: [localización en SwiftUI](https://developer.apple.com/documentation/SwiftUI/Preparing-views-for-localization), [LocalizedStringKey](https://developer.apple.com/documentation/SwiftUI/LocalizedStringKey), [NSLayoutManager](https://developer.apple.com/documentation/uikit/nslayoutmanager).
