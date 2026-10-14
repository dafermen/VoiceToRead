# Desarrollo de VoiceToRead

Estado e identidad vigentes: [inicio del proyecto](project-identity.md). Versión **0.1.0 (1)**, esquema de datos **V8**. La copia tiene Git local sin remoto; la configuración de Apple y GitHub se realiza para esta nueva app.

## Preparar el entorno

Abrir `VoiceToRead.xcodeproj`, esquema compartido `VoiceToRead`. Hay tres targets: app, `VoiceToReadUnitTests` y `VoiceToReadTests`. Xcode 15.2 permite verificar compatibilidad iOS 17; no compila las ramas de Speech/Translation que necesitan SDK modernos. Esas ramas deben validarse con un Xcode compatible antes de distribuir. No añadir npm, CocoaPods ni scripts de otros proyectos: esta app es nativa.

Cuando sea necesario escoger la instalación local:

```sh
export DEVELOPER_DIR='/Applications/Xcode 15.2.app/Contents/Developer'
xcodebuild -list -project VoiceToRead.xcodeproj
xcodebuild -showdestinations -project VoiceToRead.xcodeproj -scheme VoiceToRead
```

El proyecto tiene referencias explícitas a archivos; añadir nuevas fuentes al target correspondiente en Xcode.

## Validación

```sh
bash scripts/validate-macos.sh
python3 scripts/validate-localization.py
python3 scripts/validate-store-metadata.py
```

`VOICETOREAD_SIMULATOR_ID` permite elegir un simulador. El script de Mac guarda logs/resultados en `build/validation-*`, ejecuta la suite, compila Debug/Release e inspecciona identidad, permisos, manifiesto, orientaciones y assets. Las pruebas no equivalen a aceptación física: consultar [testing](testing.md).

Para una prueba concreta se puede usar `xcodebuild test -project VoiceToRead.xcodeproj -scheme VoiceToRead -destination 'platform=iOS Simulator,id=UDID' -only-testing:VoiceToReadUnitTests CODE_SIGNING_ALLOWED=NO`. Sustituir UDID por uno real. `scripts/validate-assembler.sh` verifica únicamente el ensamblador mediante un paquete temporal Swift; no sustituye las pruebas de la app. En Windows, `pwsh -File scripts/validate-static.ps1` solo verifica estructura, referencias y textos.

## Firma y distribución

Bundle ID `com.innovalogic.voicetoread`, equipo configurado `7799N4RYUG`. Registrar esta nueva identidad con Apple; no hay perfil ni registro App Store Connect confirmado para ella. Seleccionar un dispositivo compatible y firma automática en Xcode. No guardar claves, perfiles ni certificados en Git.

```sh
export VOICETOREAD_TEAM_ID='7799N4RYUG'
export VOICETOREAD_BUNDLE_ID='com.innovalogic.voicetoread'
bash scripts/archive-macos.sh
```

El script crea un archivo firmado si la cuenta está preparada y no lo sube. El SDK del archivo debe cumplir las exigencias de Apple vigentes al enviarlo. Para Cloud/TestFlight seguir [distribución](distribution-runbook.md).

## Datos y estudiantes

El contenedor nuevo utiliza `Application Support/VoiceToRead/Sessions.store`, con esquema V8 y migraciones internas V1→V8. Estas migraciones no transportan datos entre aplicaciones con Bundle IDs distintos. No borrar/recrear automáticamente un almacén que falle al abrirse. Guías: [junior](junior-guide.md), [recorrido del código](code-walkthrough.md) y [arquitectura](architecture.md).

Registrar cada resultado con commit, toolchain, dispositivo, bundle y número efectivo. Los reports/checkpoints heredados describen la base histórica y no demuestran una entrega de VoiceToRead.
