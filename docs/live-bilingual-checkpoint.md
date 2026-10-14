> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Traducción bilingüe en vivo — build fuente 24

Actualizado 2026-10-13. Objetivo: leer original y traducción simultáneamente durante la captura. Selector Original/Traducción/Ambos en el botón existente, sin controles permanentes adicionales. Preferencia recordada; idioma de captura y menús independientes.

No cambia esquema V8, identidad com.innovalogic.voicetoread, audio ni guardado. Vista previa temporal limitada a 40 párrafos; cuatro por lote, solo confirmados. Ambos presenta pares verticales, etiquetas, espera y provisional original. Traducción↔Ambos conserva el buffer; Original lo descarta sin detener captura.

Estado: implementación y validación local terminadas. Entrega en main mediante el commit `feat: show original and translated live captions together`; resultado Cloud y disponibilidad TestFlight todavía no confirmados. Consultar el check del SHA exacto, no el resultado de una versión anterior. Pruebas del simulador usan texto y traducción prefijados DEBUG, no el motor real de Apple. Compilación moderna, TestFlight y prueba física se registrarán por separado.

## Evidencia local

- 13 tests de TranslationTests pasaron en `/private/tmp/VoiceToRead24-tests.xcresult`. Ese bundle global falló por dos interacciones del menú luego corregidas; no presentarlo como éxito global.
- iPhone SE 3 / iOS 17.2: ambos recorridos pasaron en `/private/tmp/VoiceToRead24-ui.xcresult` (21.251 s y 20.441 s). Tras ajustar el anclaje del iPad, repetición final inglesa 22.587 s y española 22.063 s en `/private/tmp/VoiceToRead24-iphone-final.xcresult`, TEST EXECUTE SUCCEEDED.
- iPad Air 5 / iOS 17.2: recorrido final pasó en `/private/tmp/VoiceToRead24-ipad-final.xcresult` (25.640 s), TEST SUCCEEDED. Primera ejecución con popover fuera de pantalla falló; se corrigió anclando al botón.
- Los recorridos seleccionan Ambos con micrófono activo, comprueban que sigue activo, pausan expresamente, comparan UUID original/traducción, cambian las tres opciones, reanudan y giran en pantalla completa. Usan datos sintéticos DEBUG.
- Release genérico iOS sin firma pasó: `/private/tmp/VoiceToRead24-release.log`. Verificados versión de build 24, bundle `com.innovalogic.voicetoread`, familias iPhone/iPad y ausencia de los textos/proveedor DEBUG de traducción en el ejecutable Release. No es un archivo firmado/subido.
- Catálogos: 512 claves Localizable y 2 de permisos por idioma, claves/placeholders coincidentes. Metadata EN/ES dentro de límites.
- Capturas originales en `/private/tmp/live24-iphone-final-shots` y `/private/tmp/live24-ipad-shots`; inspección de pares, etiquetas y pantalla completa.

La compilación local con Xcode 15.2 no prueba la rama de Translation de Apple. Sigue pendiente probar los modelos reales, demora/calidad, texto provisional, VoiceOver/Dynamic Type, seguimiento de lectura, segundo plano y persistencia de la opción en un dispositivo compatible. No atribuir a los fixtures la evaluación del motor real. Sin cambios de política/servicios ni migración.

## Ajuste visual — build fuente 25

Línea fina entre original y traducción únicamente en Ambos, incluida la espera de traducción. Conserva etiquetas e interlineado; usa el color primario adaptable al fondo claro/oscuro y se oculta a VoiceOver por ser decorativa. No cambia captura, traducción, cola ni almacenamiento. Compilación Debug y recorrido bilingüe existente pasaron en iPhone SE 3/iOS 17.2: `/private/tmp/VoiceToRead25-visual.xcresult`, TEST SUCCEEDED (22.736 s). Capturas en `/private/tmp/live25-shots`; se inspeccionó la línea entre los dos textos. No se añadieron tests para decoración ni se repitió la suite completa. Entrega en main; Cloud/TestFlight de este ajuste pendientes de confirmación.

## Recuperación de entrega — build fuente 26

Confirmado fallo Cloud de `01f566d` (check `115246510250`, build remoto `102b9164-554f-4530-a62a-36f3d262696d`): faltaba @ViewBuilder en productionRunner. Ese cambio de fuente 25 no llegó por esa compilación a TestFlight. Corrección mínima de fuente 26: añadir el result builder a la propiedad auxiliar. Detalle en build-incidents.md. Release local pasó (`/private/tmp/VoiceToRead26-release.log`, BUILD SUCCEEDED). Cloud del SHA corregido pasó (ver resultado final abajo); no confundir los recorridos simulados locales con la compilación de la rama Apple Translation.

### Resultado remoto de la corrección

El 2026-10-13, el SHA `2da928440decb7c7d4da2bdac58dcce2b5ae10b0` pasó Archive - iOS en Xcode Cloud, check final `115263454589`: 0 errores, 0 fallos de tests reportados, 0 incidencias de análisis y 4 advertencias. [Compilación](https://appstoreconnect.apple.com/). Esto verifica compilación de la rama moderna de Translation; no evalúa traducción real ni instalación en el iPhone. Las advertencias de AVAudioPCMBuffer/AVAssetExportSession, preconcurrency y allowBluetooth permanecen.

Procesamiento y disponibilidad del build en TestFlight pendientes de confirmación. El número fuente 26 no debe confundirse con el número que asigne el flujo Cloud. El commit posterior únicamente registra este resultado y puede disparar otra compilación con el mismo código.

Para acceder: Subtítulos → bocadillo con A junto a pantalla completa → Ambos. En pantalla completa, el mismo botón aparece en la barra inferior. El idioma hablado se mantiene según la voz a reconocer; no se cambia a español solo para leer una traducción española.

## Tarjetas — fuente 27, 2026-10-13

El usuario confirmó que ya funciona la vista bilingüe en su iPhone, pero pidió distinguir mejor los párrafos. Ambos ahora usa tarjetas compactas redondeadas: inglés azul, español verde, etiquetas explícitas y sombra suave. La paleta depende del idioma, no de ser original/traducción. Se incluyen provisional y espera; modo oscuro adapta los fondos y alto contraste usa bordes fuertes sobre blanco/negro. No hay migración ni cambios de captura/traducción.

Validación de esta entrega:
- iPhone SE 3 / iOS 17.2: recorridos inglés y español pasaron (22.593 s / 21.780 s), incluyendo alternar vistas, pausar/reanudar y fullscreen horizontal. Bundle `/private/tmp/VoiceToRead27-visual.xcresult`.
- iPad Air 5 / iOS 17.2: recorrido inglés pasó en oscuro (26.073 s) y oscuro con contraste aumentado (26.981 s); capturas de ambos recorridos inspeccionadas. Bundles `/private/tmp/VoiceToRead27-ipad-dark.xcresult` y `/private/tmp/VoiceToRead27-ipad-contrast.xcresult`. Se restauró el aspecto inicial del simulador.
- Release genérico iOS sin firma pasó: `/private/tmp/VoiceToRead27-release.log`.
- Validadores de localización (512 claves + 2 de permisos), metadatos y `git diff --check` pasaron.

Los recorridos UI usan traducción prefijada DEBUG; no miden precisión ni latencia real. Las tarjetas todavía requieren comprobación en el teléfono. Compilación Cloud y disponibilidad TestFlight de fuente 27 pendientes al preparar este commit; verificar su SHA exacto antes de anunciar entrega.
