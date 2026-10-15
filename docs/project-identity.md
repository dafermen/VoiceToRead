# VoiceToRead — inicio independiente

## Identidad actual

- Proyecto y esquema: `VoiceToRead.xcodeproj` / `VoiceToRead`.
- Bundle ID: `com.innovalogic.voicetoread`.
- Tests UI: `com.innovalogic.voicetoread.uitests`; unitarios: `com.innovalogic.voicetoread.unittests`.
- Versión inicial: `0.1.0`, build `1`. Esquema de datos V8.
- Equipo configurado: `7799N4RYUG`; registrar el nuevo identificador en esa cuenta antes de distribuir.
- Carpeta: `/Users/dariomeneses/Projects/VoiceToRead`.
- Responsable: Dario Fernando Meneses Ceron; contacto: dariofernandomeneses@gmail.com.
- Base de código copiada del snapshot `409c0acaaf62dd80ce64bd43190a62453f5f0c86`. No se copian cachés, archivos de distribución, credenciales ni configuración Git del proyecto base.

## Datos e independencia

Esta es otra aplicación: no actualiza la instalación anterior ni puede leer automáticamente su contenedor privado. Las sesiones existentes permanecen en la aplicación anterior. Exportarlas antes de eliminarla; no se implementa aquí una migración entre apps. Las nuevas sesiones se guardan dentro del contenedor propio en `Application Support/VoiceToRead/Sessions.store`.

Repositorio independiente confirmado por el titular: https://github.com/dafermen/VoiceToRead.git. Configurado como `origin`, rama `main`. Se comprobó que el remoto estaba vacío antes de la primera subida. No enviar cambios al remoto del proyecto base.

## Registro confirmado y distribución pendiente

1. **Confirmado por captura del titular, 2026-10-13 23:19:42:** VoiceToRead, bundle `com.innovalogic.voicetoread`, Apple ID **6822564230**, SKU `voicetoread-ios-001`, idioma principal English (U.S.). [Ficha de App Store Connect](https://appstoreconnect.apple.com/apps/6822564230/distribution/info). Estado visible: **1.0 Prepare for Submission**. No implica subida de un build, TestFlight ni aprobación.
2. Configurar firma automática para el equipo y el nuevo identificador.
3. Conceder a Xcode Cloud acceso al repositorio GitHub `dafermen/VoiceToRead`, ya creado y conectado.
4. Crear un workflow del esquema VoiceToRead con Archive iOS y preparación TestFlight; elegir un SDK admitido por Apple.
5. Crear el grupo interno, asignar la compilación procesada y comprobar la instalación como nueva app.
6. Publicar las páginas propias de privacidad/soporte y completar los requisitos de App Store antes de revisión pública.

No reutilizar el App Store Connect app ID ni los archivos firmados de la app anterior. El número de ejecución Cloud y CFBundleVersion pueden diferir. El primer build fuente es 1; los siguientes deben superar el último aceptado por Apple.

## Validación

Validación ejecutada el 2026-10-13 con Xcode 15.2:

- Xcode reconoce app, tests unitarios y tests UI con esquema compartido VoiceToRead.
- iPhone SE 3 / iOS 17.2: 99 pruebas unitarias y 2 recorridos UI aprobados (bilingüe en vivo; reproducción por párrafos/edición/favoritas). Bundle `/private/tmp/VoiceToRead-initial-tests.xcresult`; log `/private/tmp/VoiceToRead-initial-tests.log`.
- Debug de simulador y Release genérico iOS compilaron. Release: `/private/tmp/VoiceToRead-initial-release.log`, sin firma de distribución.
- Inspección del .app Release: nombre/ejecutable VoiceToRead, bundle com.innovalogic.voicetoread, versión 0.1.0/build 1, iPhone+iPad, permisos, assets y manifiesto. Ejecutable sin la marca anterior ni traducción prefijada DEBUG.
- Localización: 512 claves y 2 permisos EN/ES; metadatos, scripts shell y enlaces relativos de documentación correctos. Búsqueda del árbol sin referencias a la marca/identificador anteriores.
- Persisten dos advertencias locales heredadas de concurrencia: callback @MainActor en SessionTranslationView y callback Sendable en CaptionViewModel. El log unitario también emite avisos SQLite al retirar almacenes temporales; todas las aserciones pasaron. No se declaran corregidos por este renombrado.

Estos resultados no incluyen firma, archive moderno, registro de Apple, Cloud, TestFlight ni prueba física de la identidad nueva. Xcode 15.2 no compila la implementación moderna de Translation. El proyecto base permanece intacto. Los reportes heredados no sustituyen estas pruebas.

## Versión de la ficha

La ficha muestra **1.0**. El 2026-10-14 se alineó MARKETING_VERSION a **1.0** en Debug y Release; CURRENT_PROJECT_VERSION conserva **1** como valor fuente. Cloud puede asignar otro número: verificar siempre el Info.plist del archivo y TestFlight. Subtítulo y categorías se veían vacíos en la captura inicial.

El titular confirmó el 2026-10-14 que VoiceToRead ya se instaló desde TestFlight y funciona en su iPhone. Es evidencia de instalación/uso básico, no de toda la matriz de aceptación ni de la versión 1.0 aún por compilar. El workflow mostrado usa Internal Testing Only; cambiarlo a TestFlight and App Store y crear un archivo nuevo antes de revisión pública.

## Preparación 1.0 — 2026-10-14

- MARKETING_VERSION 1.0 en Debug/Release; bundle y esquema V8 conservados.
- Privacidad local: responsable, contacto, plazo de soporte y tratamiento web; enlaces EN/ES verificados públicamente por HTTPS.
- Release genérico iOS sin firma compiló; Info.plist confirma 1.0 (1), bundle esperado, iOS 17 e iPhone/iPad. Ejecutable sin `--store-screenshots`, `Learning together` ni `--ui-test-review`. Log: `/private/tmp/VoiceToRead-store-release.log`.
- iPhone 15/iOS 17.2: recorridos de biblioteca/lectura/edición/privacidad EN/ES aprobados. Evidencia: `/private/tmp/VoiceToRead-store-iphone-v2.xcresult`.
- iPad Pro 12.9 (6.ª gen.)/iPadOS 17.2: mismos recorridos EN/ES aprobados y capturas nativas generadas. Evidencia: `build/store-ipad-20261014-070944/Tests.xcresult`.
- Localización: 519 claves y 2 permisos, paridad EN/ES y placeholders correctos. Textos de tienda dentro de límites. `--ready` sigue rechazando el envío mientras falten archivo público, declaraciones y aceptación final.
- Persisten dos warnings heredados de concurrencia (SessionTranslationView y CaptionViewModel). Esta entrega no los presenta como corregidos. No se repitió la batería unitaria completa: los cambios funcionales son enlaces/texto de privacidad y versión; se verificaron los recorridos afectados y Release.

Xcode 15.2 local no compila la rama moderna de Translation. Estas pruebas no certifican el SDK actual de distribución, precisión del reconocimiento, traducción real, firma ni aceptación física 1.0. El responsable eligió gratis sin compras y Estados Unidos/Colombia; esas opciones aún deben aplicarse en Apple. No hubo envío a App Review ni modificación autenticada de la ficha.

Capturas finales de iPhone: `build/store-iphone-20261014-072025/Tests.xcresult`, ambos recorridos aprobados. Se revisaron visualmente 12 candidatos (biblioteca, lectura y edición; EN/ES; iPhone/iPad). JPEG sin alfa: iPhone 1179 × 2556, iPad 2048 × 2732. Archivos en `docs/store/screenshots/`; paquete regenerable en `build/app-store/VoiceToRead-AppStore-1.0.zip`. No incluye capturas sintéticas de traducción.

## Lectura accesible — 2026-10-15

Fuente 1.0 (1), sin migración de datos ni cambio de identidad. Añade voz de traducción, visor ampliado, frase anterior y acciones circulares de sesiones. Detalles y evidencia: [guía](translated-speech.md) / [checkpoint](translated-speech-checkpoint.md). No implica un envío a revisión ni una actualización instalada.
