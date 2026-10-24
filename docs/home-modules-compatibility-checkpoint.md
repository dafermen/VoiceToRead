# Inicio y compatibilidad — 2026-10-24

Bloque autorizado: Talk / Listen / Train; nueva conversación circular en cabecera; Listen cambia entre iniciar, detener y nueva sesión, conservando Pausar/Reanudar y las decisiones Guardar/Descartar. Los botones de turno hablan el idioma del participante; los selectores muestran nombre localizado y nativo sin duplicaciones.

El control de pantalla completa se ancla por fuera del inset transitorio de traducción para que ese mensaje no cambie su posición. No se cambian los modelos de datos, las traducciones guardadas, entrenamientos ni la protección de favoritas.

Mínimo de instalación: iOS/iPadOS 18. Se comprueba SpeechTranscriber.isAvailable antes de elegir el motor moderno; si no está disponible se usa el adaptador local SFSpeechRecognizer ya existente. Sus permisos y disponibilidad por idioma siguen siendo obligatorios. Esto corrige la selección por versión de iOS solamente; no garantiza compatibilidad universal ni confirma la causa del aviso observado en el iPhone 11.

Se consulta LanguageAvailability antes del turno y se distingue un par no admitido de uno que necesita descarga. La descarga/consentimiento continúa a cargo de prepareTranslation, sin activar el micrófono desde las comprobaciones. Ajustes explica requisitos y preparación.

Referencias Apple: https://developer.apple.com/documentation/speech/speechtranscriber/isavailable y https://developer.apple.com/documentation/translation/languageavailability

Validación: comprobación de localizaciones y revisión estática en Windows; se actualizaron los recorridos XCTest de módulos, turnos y controles de sesión. XCTest y prueba física no ejecutados aquí. Xcode Cloud debe verificar compilación del SHA publicado. La disponibilidad efectiva en TestFlight se comprueba por separado. Validar en iPhone 11 la versión de iOS, el mensaje exacto, permiso de reconocimiento, modelos locales y par de idiomas.
