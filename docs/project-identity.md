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

El repositorio Git es local y no tiene remoto configurado. Las referencias `https://github.com/dafermen/VoiceToRead` en ejemplos de documentación indican el destino propuesto; no confirman que el repositorio exista. No enviar cambios al remoto del proyecto base.

## Activación de distribución pendiente

1. Registrar `com.innovalogic.voicetoread` y crear el registro VoiceToRead en App Store Connect. Apple debe aceptar el nombre; la búsqueda pública no lo reserva.
2. Configurar firma automática para el equipo y el nuevo identificador.
3. Crear/conectar el nuevo repositorio GitHub y conceder acceso a Xcode Cloud.
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
