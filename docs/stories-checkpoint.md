# Cuentos — primera versión, 2026-10-25

Inicio ofrece Talk / Listen / Train / Stories, traducidos según la interfaz. El selector usa dos filas con texto accesible o cuando las cuatro opciones no caben. No se cambian los motores de Conversar, Escuchar ni Entrenar.

Biblioteca independiente en Application Support/VoiceToRead/Stories/stories.json, con escritura atómica, protección de archivo y exclusión de copia de seguridad, como los entrenamientos. El ejemplo inicial es una adaptación propia de Los tres cerditos. Se puede crear y editar título, texto e idiomas, con los seis idiomas existentes. Los datos de sesiones y entrenamientos no se leen ni reescriben.

El lector narra el cuento completo con la voz guardada en Ajustes para el idioma elegido. Controles: reproducir, pausar/reanudar, detener, lectura lenta y tamaño de texto. Las palabras se resaltan con rangos UTF-16 del sintetizador y UITextView mantiene el rango visible sin reconstruir el texto por palabra. No se usa el micrófono ni se conserva audio.

Preparación para adultos: traducción Apple existente y revisión editable por párrafo. La narración traducida se habilita tras guardar la revisión; el original se puede leer desde el comienzo. Cambiar origen/idiomas requiere confirmar la pérdida de la traducción de ese cuento. La traducción sustituye la anterior solo cuando finaliza y el documento de origen sigue vigente. Eliminación y descarte de cambios llevan confirmación. La etiqueta para adultos describe el flujo; no constituye un bloqueo parental ni una cuenta infantil.

La voz se detiene y limpia resaltado al salir, cambiar texto/idioma, entrar en segundo plano o recibir interrupciones de audio. Se rechazan callbacks tardíos. Se preservan pausas, selección manual y voces de los otros módulos.

Verificación: pruebas XCTest de almacenamiento independiente, archivo corrupto, traducciones incompletas/obsoletas, revisión, pausa y callbacks tardíos; recorrido UI de creación/traducción/revisión/borrado. En Windows no se ejecutan XCTest ni la narración real: pasar compilación Xcode Cloud y probar en iPhone/iPad, incluyendo párrafos largos, idiomas asiáticos, auriculares y Dynamic Type. Archive correcto no acredita disponibilidad TestFlight ni lectura física validada.
