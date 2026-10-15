# Distribución de VoiceToRead

Esta app es independiente. **Registro de Apple, workflow Cloud y TestFlight pendientes**. No reutilizar los identificadores o archivos firmados de la app anterior. Estado de validación: [identidad](project-identity.md).

| Dato | Valor actual |
|---|---|
| Proyecto / esquema | VoiceToRead.xcodeproj / VoiceToRead |
| Bundle ID | com.innovalogic.voicetoread |
| Equipo configurado | 7799N4RYUG |
| Versión / build fuente inicial | 0.1.0 / 1 |
| Git | https://github.com/dafermen/VoiceToRead.git, rama main |
| App Store Connect ID | Pendiente de creación |
| Xcode Cloud / grupo TestFlight | Pendientes de configurar |
| Almacenamiento | Application Support/VoiceToRead/Sessions.store |

## Primera entrega

1. Registrar el Bundle ID con el equipo y crear el nuevo registro VoiceToRead en App Store Connect; SKU propuesto `voicetoread-ios`. La aceptación del nombre todavía debe confirmarla Apple.
2. Usar el repositorio independiente ya conectado: `dafermen/VoiceToRead`, remoto `origin`, rama `main`. Subir los commits validados allí; no usar el repositorio del proyecto base.
3. En Xcode, Integrate → Create Workflow, elegir VoiceToRead y conceder acceso al repositorio nuevo. Usar `main`, esquema compartido VoiceToRead, Archive iOS y preparación TestFlight para pruebas internas. Para publicación pública elegir una preparación elegible de App Store.
4. Elegir un Xcode/SDK admitido por Apple al enviar. La compilación local con Xcode 15.2 no verifica las ramas modernas de Speech/Translation ni demuestra elegibilidad de subida.
5. Inspeccionar el resultado del commit exacto: compilación, exportación/firma, subida y procesamiento son etapas distintas. Resolver acuerdos/permisos desde la cuenta del titular si Apple los solicita.
6. Crear un grupo interno, asignar el build procesado y el tester. Instalar la nueva app desde su invitación de TestFlight; no esperar una actualización de la instalación anterior.
7. Registrar CFBundleVersion real y la aceptación física. Subidas posteriores usan un número superior al último aceptado; el número de ejecución Cloud puede ser diferente.

Antes de cada entrega: ejecutar pruebas pertinentes, comprobar estado Git, revisar metadatos y leer incidentes conocidos. Guardar/exportar datos importantes desde la app anterior antes de eliminarla. La nueva app no importa automáticamente esas sesiones.

## Si falla la exportación

Descargar Archive y Logs desde los artefactos del build concreto. Revisar el error de exportación detallado, no deducir la causa solamente por exit-code 70. Los siguientes procedimientos son lecciones heredadas del código base: no afirman que VoiceToRead haya tenido esos fallos ni que un workaround antiguo funcione hoy.

## 5. Diagnóstico rápido antes de modificar nada

Abrir dentro del ZIP Logs:

~~~text
app-store-export-archive-logs/xcodebuild-export-archive.log
app-store-export-archive-logs/*.xcdistributionlogs/IDEDistribution.critical.log
app-store-export-archive-logs/*.xcdistributionlogs/IDEDistribution.standard.log
~~~

El comando mostrado como Run command y el exit-code 70 no contienen por sí solos la causa. Buscar errores anteriores a EXPORT FAILED. Comparar la primera operación que falla entre intentos.

En este incidente, listTeams devolvió 502 y después apareció “No profiles … were found”. No se demostró que faltaran perfiles realmente: la consulta previa ya había fallado. No revocar certificados ni recrear identificadores basándose únicamente en ese mensaje secundario.

No copiar el comando del worker Cloud para ejecutarlo en el Mac: /Volumes/workspace y localhost:6667 pertenecen a ese entorno y no son rutas/servicios del equipo local.

## 6. Alternativa comprobada: exportar el archivo Cloud desde el Mac

Requisitos: archivo confiable de este proyecto descargado de Artifacts, Xcode instalado y cuenta Apple configurada con acceso al equipo. Una petición de autenticación o llavero se atiende en la interfaz de macOS; nunca escribir contraseñas en documentación o chats.

Descomprimir el ZIP de Archive en una carpeta local. Conservar el original. No alterar el ejecutable ni los metadatos de SDK/compilador para simular otra compilación. Para corregir únicamente el número de entrega de un archivo existente, trabajar en una copia: actualizar CFBundleVersion en Products/Applications/VoiceToRead.app/Info.plist y ApplicationProperties.CFBundleVersion en el Info.plist del archivo, y volver a exportar/firmar. No modificar un IPA firmado para subirlo sin volver a firmar.

Desde la raíz del repositorio, en bash/zsh, ajustar solo la ruta del archivo real:

~~~sh
export VOICETOREAD_ARCHIVE='/ruta/real/VoiceToRead.xcarchive'
export VOICETOREAD_XCODEBUILD='/Applications/Xcode 15.2.app/Contents/Developer/usr/bin/xcodebuild'
mkdir -p build
export VOICETOREAD_DISTRIBUTION_DIR="$(mktemp -d "$PWD/build/distribution.XXXXXX")"
test -d "$VOICETOREAD_ARCHIVE"
test -x "$VOICETOREAD_XCODEBUILD"
~~~

Los dos test deben terminar con código 0; si no, corregir las rutas antes de seguir. build/ está ignorado por Git. Usar un directorio nuevo evita mezclar una entrega con otra.

Inspeccionar identidad y SDK del archivo:

~~~sh
plutil -p "$VOICETOREAD_ARCHIVE/Info.plist"
plutil -p "$VOICETOREAD_ARCHIVE/Products/Applications/VoiceToRead.app/Info.plist"
~~~

Confirmar el bundle ID, versión y SDK esperado. El archivo previo a exportar puede mostrar equipo/firma vacíos; validar el resultado de distribución, no concluir que está roto solo por esos campos.

Crear opciones de exportación:

~~~sh
python3 - <<'PY'
import os, plistlib
from pathlib import Path
options = {
    "method": "app-store",
    "destination": "export",
    "teamID": "7799N4RYUG",
    "signingStyle": "automatic",
    "uploadSymbols": False,
    "manageAppVersionAndBuildNumber": False,
}
path = Path(os.environ["VOICETOREAD_DISTRIBUTION_DIR"]) / "ExportOptions.plist"
with path.open("wb") as file:
    plistlib.dump(options, file)
PY
~~~

Este ejemplo reproduce opciones aceptadas por Xcode 15.2. Herramientas nuevas pueden preferir el nombre app-store-connect. Consultar el help de la versión utilizada antes de adaptar las opciones.

Exportar sin subir todavía:

~~~sh
set -o pipefail
"$VOICETOREAD_XCODEBUILD" -exportArchive \
  -archivePath "$VOICETOREAD_ARCHIVE" \
  -exportPath "$VOICETOREAD_DISTRIBUTION_DIR/Export" \
  -exportOptionsPlist "$VOICETOREAD_DISTRIBUTION_DIR/ExportOptions.plist" \
  -allowProvisioningUpdates \
  2>&1 | tee "$VOICETOREAD_DISTRIBUTION_DIR/export.log"
~~~

-allowProvisioningUpdates permite que Xcode gestione lo necesario para la firma usando la cuenta configurada; puede crear o actualizar perfiles. No modifica el código fuente.

Exigir código de salida 0 y EXPORT SUCCEEDED. Revisar DistributionSummary.plist y el IPA: identificador correcto, equipo, perfil de App Store y get-task-allow=false. En el caso registrado apareció beta-reports-active=true. El IPA es un ZIP firmado; inspeccionarlo no requiere alterar su contenido.

Si falla, conservar el log y corregir el error concreto. No pasar a upload suponiendo que exportó.

## 7. Subir el mismo archivo

Este paso envía la app a Apple. Ejecutarlo cuando la entrega esté autorizada. Conservar exactamente el archivo que se acaba de verificar.

~~~sh
python3 - <<'PY'
import os, plistlib
from pathlib import Path
root = Path(os.environ["VOICETOREAD_DISTRIBUTION_DIR"])
with (root / "ExportOptions.plist").open("rb") as file:
    options = plistlib.load(file)
options["destination"] = "upload"
options["uploadSymbols"] = True
with (root / "UploadOptions.plist").open("wb") as file:
    plistlib.dump(options, file)
PY

set -o pipefail
"$VOICETOREAD_XCODEBUILD" -exportArchive \
  -archivePath "$VOICETOREAD_ARCHIVE" \
  -exportPath "$VOICETOREAD_DISTRIBUTION_DIR/Upload" \
  -exportOptionsPlist "$VOICETOREAD_DISTRIBUTION_DIR/UploadOptions.plist" \
  -allowProvisioningUpdates \
  2>&1 | tee "$VOICETOREAD_DISTRIBUTION_DIR/upload.log"
~~~

La operación vuelve a preparar y firmar para la subida. Usamos manageAppVersionAndBuildNumber=false para conservar el número explícito ya verificado en el archivo y el IPA. En el primer intento, true conservó el 1: no confiar en esa opción para incrementar automáticamente. Confirmar siempre el número efectivo en App Store Connect.

En la ejecución comprobada, la salida final fue:

~~~text
Uploaded package is processing.
Upload succeeded.
Uploaded VoiceToRead
** EXPORT SUCCEEDED **
~~~

Si terminó bien, no repetir la subida por no verlo inmediatamente en TestFlight. Revisar primero el procesamiento y cualquier correo de rechazo posterior.

## 8. Terminar en TestFlight

1. Abrir VoiceToRead → TestFlight → iOS y localizar el paquete nuevo por versión, número y fecha.
2. Resolver la información pendiente que Apple solicite según la app real. No copiar una declaración de cifrado sin revisar su aplicabilidad.
3. Asignar la compilación al grupo interno Dev si no se añadió automáticamente.
4. Comprobar invitación y acceso del tester.
5. En iPhone, abrir TestFlight y actualizar. Registrar versión/build efectivamente instalados.
6. Probar grabación optativa, corrección, reproducción, subtítulos, pausa/reanudación y orientación. Seguir [la lista de audio y subtítulos](media-and-subtitles.md).

Las capturas de las 04:37 del 10 de octubre confirman 0.1.0 (1) procesada, en Dev, con una invitación y sin instalaciones registradas. Después se subió 0.1.0 (13); sus pasos posteriores están pendientes.

Para instalar una compilación concreta en iPhone: TestFlight → VoiceToRead → Previous Builds, o Versions and Build Groups → versión → build → Install. El número 1 puede contener código posterior al 8 si una exportación local reinició la numeración: comprobar fecha y procedencia. No atribuir con certeza la falta de actualización automática a esa numeración sin evidencia del dispositivo. No desinstalar la app como primer paso; contiene sesiones locales.

## 9. Qué guardar para la siguiente persona

Registrar fecha y zona horaria, commit, número Cloud, Xcode/macOS/SDK, versión/build de App Store Connect, resultado de cada fase y pruebas de dispositivo. Conservar logs y artefactos localmente en build/ o en almacenamiento privado del equipo.

No subir ZIPs de logs, archivos de firma, IPA, xcarchive o datos personales a GitHub. El repositorio contiene el diagnóstico resumido, no credenciales ni registros íntegros de la cuenta.

La ruta /private/tmp usada durante el incidente no es almacenamiento permanente. Esta guía reproduce el procedimiento en build/ para futuras ejecuciones.

## Referencias

- [Estados de compilación, incluido Ready to Submit](https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses).
- [Instalar una compilación concreta en TestFlight](https://testflight.apple.com/).

- [Distribución mediante archivos y Organizer](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/).
- [Certificados administrados por Apple](https://developer.apple.com/help/account/certificates/cloud-managed-certificates).
- [Acciones de Xcode Cloud](https://developer.apple.com/documentation/xcode/configuring-your-xcode-cloud-workflow-s-actions).
- [Requisitos de SDK de Apple](https://developer.apple.com/news/upcoming-requirements/?id=04282026a).

## Build 16: Translation branch

Use a fresh archive from source build 16 or later. Translation generation is compiled only when the SDK supplies the Translation module and runs only on iOS 18+. A successful Xcode 15.2 local build verifies compatibility UI/data logic, not the Apple translation implementation. Keep bundle identifier, signing team and store path unchanged.

## 2026-10-14: VoiceToRead ya en TestFlight; preparación pública

Evidencia: el titular confirmó que la nueva app se ve e instala en el iPhone. El workflow Default mostrado tenía Archive iOS + Internal Testing Only y postacción Dev. La primera compilación verde sin builds visibles no demostraba disponibilidad; revisar siempre preparación, exportación, procesamiento y asignación al grupo.

Para App Store: usar TestFlight and App Store, generar un archivo nuevo con versión 1.0 y comprobar su número efectivo. No reutilizar una compilación Internal Only. Versión fuente alineada a 1.0 en esta preparación; firma y bundle ID se conservan. La web pasó de un fallo SSL inicial a HTTPS válido en privacidad/soporte EN/ES. Los enlaces ya se registran en metadatos y en la app. Gratis y Estados Unidos/Colombia confirmados por el titular; falta aplicarlos en Apple. Ver [paquete de publicación](store/submission-kit.md).

Incidente de capturas: los attachments de XCTest para iPhone 15/iOS 17.2 tuvieron 1178 × 2556; Apple espera 1179 × 2556. Capturar con simctl a tamaño nativo, comprobar dimensiones y entregar JPEG sin alfa. No estirar imágenes ni confundir una captura QA con el material comercial. La primera prueba de privacidad falló por consultar `app.links`: SwiftUI exponía los controles de otro tipo. La consulta por identificador accesible resolvió el fallo en inglés y español sin cambiar la funcionalidad de Link.

## Lectura accesible y voz traducida — 2026-10-15

Consultar el [checkpoint de síntesis/lectura](translated-speech-checkpoint.md) antes de distribuir esta entrega. Release local sin firma, 102 unitarias y recorridos UI en iPhone/iPad verificados. No confundir los primeros fallos de selectores/animaciones de XCTest (corregidos y repetidos) con un fallo de firma de Xcode Cloud. Confirmar commit, build distribuido y voces reales en el dispositivo; el SDK 15.2 local no comprueba el backend moderno de Translation.
