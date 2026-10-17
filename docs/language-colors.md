# Colores por idioma

## Uso

Los controles de Conversación, las tarjetas bilingües en vivo, las tarjetas de Texto y traducción y las de Audio y subtítulos comparten una paleta por idioma. **Inglés es azul y español verde de forma predeterminada**, incluso cuando español es el original e inglés la traducción. Reproducir en inglés/español usa el color del idioma que va a sonar; Corregir mensaje conserva un estilo neutro. Las dos posiciones de los botones no cambian: español a la izquierda, inglés a la derecha.

En **Ajustes → Colores por idioma**, selecciona azul, verde, morado o naranja para cada idioma. La vista previa cambia al instante. La selección se guarda en este dispositivo sin pulsar Guardar. **Restaurar colores predeterminados** devuelve inglés a azul y español a verde; no cambia el idioma de captura, la interfaz ni las sesiones. Puedes elegir el mismo color para ambos: aparece una explicación porque entonces las etiquetas son la única distinción entre idiomas.

La paleta utiliza fondos suaves con texto oscuro en modo claro y fondos oscuros con texto claro en modo oscuro. Los nombres de idioma, los iconos y los estados permanecen visibles; nunca se depende únicamente del color. Alto contraste, tanto de la app como del sistema, mantiene superficies blancas/negras y bordes fuertes sin borrar los colores guardados. Los botones deshabilitados conservan su color de idioma y el sistema expone su estado deshabilitado a VoiceOver.

**Fondo de lectura** sigue cambiando el área del lector, pero ya no sustituye el color de las tarjetas de idioma. Los modos de lectura que no muestran tarjetas conservan su fondo habitual. Esto mantiene la relación entre botones y tarjetas. La función apoya orientación visual, lectura y aprendizaje de idiomas; no supone que todas las personas distingan los colores igual.

## Para estudiantes de desarrollo

`LanguageColor` define cuatro identificadores estables, un acento y fondos claros/oscuros. `AppSettings` guarda `englishLanguageColor` y `spanishLanguageColor` como cadenas en `UserDefaults`. Valores ausentes o desconocidos usan azul/verde, por lo que no hace falta migrar la base de sesiones. `color(for:)` resuelve el idioma, no el rol original/traducción.

`LanguageButtonStyle` y `LiveLanguageCard` comparten `LanguageColor.background`. `PlaybackTextCard` consulta `AppSettings`; `LiveSpanishView` recibe ambas preferencias explícitamente desde `CaptionScreen`. Así las pruebas pueden inyectar ajustes aislados y una actualización visual no reinicia reconocimiento ni traducción. `LanguageColorsView` usa bindings para guardar los cambios y muestra las mismas tarjetas usadas en reproducción.

La prioridad visual es: alto contraste → fondo blanco/negro; en otro caso → color del idioma adaptado a claro/oscuro. El papel permanece fuera de la tarjeta. El borde de reproducción activa usa el acento del idioma y conserva la etiqueta Escuchando ahora; en alto contraste usa el color principal.

## Validación

- Preferencias: valores iniciales, persistencia, restauración, valores desconocidos y separación respecto a idioma hablado/interfaz.
- Paleta: contraste calculado de cada fondo con negro/blanco, incluyendo prioridad de alto contraste. Esta prueba no sustituye la revisión visual ni demuestra cumplimiento integral de accesibilidad.
- Interfaz: elegir colores, volver a entrar, verlos en la conversación, restaurar, comprobar ambos sentidos y revisar capturas claras/oscuras.
- La voz/traducción de las pruebas UI es ficticia y exclusiva de DEBUG. El cambio es de presentación; no altera audio, texto guardado ni exportaciones.

## Evidencia local — 2026-10-16

- 11 pruebas de `AppSettingsTests` aprobadas, incluida persistencia/restauración y contraste de las cuatro paletas. El recorrido UI de dos turnos también pasó en `/private/tmp/vtr-language-colors.xcresult`.
- Las dos pruebas nuevas UI inicialmente consultaban la etiqueta del selector en vez de su valor accesible. Corregido el uso de `value`; ambos recorridos finales claro/oscuro pasan en `/private/tmp/vtr-language-colors-final.xcresult`.
- iPad Air 5 / iOS 17.2: 1 recorrido UI aprobado, `/private/tmp/vtr-language-colors-ipad.xcresult`.
- Release para simulador sin firma: BUILD SUCCEEDED (`/private/tmp/vtr-language-colors-release.log`). Conserva dos advertencias previas de aislamiento/concurrencia en `CaptionViewModel` y `SessionTranslationView`.
- Localización: 734 claves + 2 permisos; 477 extraídas cubiertas. Metadatos App Store, sitio bilingüe de 10 páginas y diff comprobados. Paquetes de web y textos regenerados localmente; no se publica Hostinger.
- Capturas: [predeterminados](qa/language-colors/defaults.png), [ajustes](qa/language-colors/Language-colors-light.png), [conversación clara](qa/language-colors/Language-conversation-light.png), [oscura](qa/language-colors/Language-conversation-dark.png) e [iPad](qa/language-colors/ipad.png).

Estas pruebas usan servicios ficticios DEBUG para voz/traducción; el cambio visual no modifica esos motores. La disponibilidad en TestFlight depende de la compilación, distribución y procesamiento de Apple y se confirma por separado.
