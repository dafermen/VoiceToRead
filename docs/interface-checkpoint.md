> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Entrega — source build 21

2026-10-11. Código publicado en `main`: `59f4eae9a8d233cac49dea4fe0cc5397553663f0`. Identidad `com.innovalogic.voicetoread`, esquema V7 y mínimo iOS 17 conservados.

## Cambios

- Interfaz English/Español, independiente de la voz reconocida, la traducción y el idioma fijo de una sesión abierta.
- Permisos y preparación de modelos visibles con acciones; avisos de voces de práctica destacados. Autorizar o preparar no inicia captura.
- Guardar audio activado inicialmente en instalaciones nuevas, conservando elecciones anteriores y el antiguo valor desactivado de instalaciones sin preferencia explícita.
- Renglones por párrafo, calculados con la línea base y descendentes de TextKit; texto y guías se redistribuyen juntos.

## Verificación local completada

- **92 unitarias aprobadas**, cero fallos: `build21-verified.log`, `VoiceToRead-21-Verified.xcresult`, TEST SUCCEEDED. Fue antes del último ajuste de altura de dos textos de preparación; ese cambio de presentación se comprobó con UI después.
- **Cuatro escenarios UI iPhone aprobados** en tandas dirigidas. `build21-ui.log`: renglones/interrupción/giro/reanudar (50,356 s) e idioma independiente durante pausa (27,804 s). Esa tanda tuvo además dos fallos de selectores, por lo que no pasó globalmente.
- `build21-ui-verified.log` / `VoiceToRead-21-UI-Verified.xcresult`: preparación inicial (13,391 s) y práctica de sesión española (33,348 s), TEST SUCCEEDED.
- **Preparación final sin truncamiento**: `build21-preparation-final.log` / `VoiceToRead-21-Preparation-Final.xcresult`, 14,821 s, TEST SUCCEEDED.
- **Tres recorridos UI iPad**, fuente final: renglones/giro/reanudar (71,486 s), idioma independiente durante pausa (230,819 s), preparación (12,088 s). `build21-ipad.log` / `VoiceToRead-21-iPad.xcresult`, TEST EXECUTE SUCCEEDED. Hubo esperas de notificación de animaciones de XCTest; no fallaron las aserciones.
- Capturas de ajustes españoles, preparación y renglones en vertical/horizontal revisadas para iPhone e iPad: `/private/tmp/screens21`, `/private/tmp/screens21-ipad`.
- **Release final universal aprobado**: `build21-release-final.log`, BUILD SUCCEEDED. Fuente 0.1.0 (21), UIDeviceFamily `[1,2]`, sin firma local. El catálogo extraído por Swift también fue validado.
- **480 claves** por idioma y dos razones de permiso por idioma; paridad y placeholders correctos. Las 370 claves extraídas por el compilador están cubiertas, incluyendo etiquetas neutrales y formatos. `scripts/validate-localization.py` reproduce la verificación.

Artefactos en `/private/tmp`. Xcode local 15.2 / simuladores iOS 17.2. Los motores modernos Speech/Translation se compilan por separado en Cloud. Simulación no acredita precisión de voz real, instalación TestFlight ni aprobación de accesibilidad.

## Compilación Cloud

[Archive – iOS](https://appstoreconnect.apple.com/) **aprobado** para `59f4eae9a8d233cac49dea4fe0cc5397553663f0`: check final `114617065401`, `success`, terminado el 2026-10-12 a las 00:39:42 UTC (20:39:42 del 11 de octubre en Nueva York). Cero errores y cuatro advertencias existentes: allowBluetooth obsoleto, captura de AVAudioPCMBuffer y AVAssetExportSession no Sendable, y sugerencia @preconcurrency para AVFAudio. No se declara compatibilidad completa con modo Swift 6.

Apple publicó el resultado con otro check ID; el inicial `114613990875` conservaba in_progress. Consultar todos los check-runs del SHA antes de diagnosticar una espera. El commit posterior de documentación no cambia código ni configuración de la app. Archive aprobado no confirma procesamiento ni instalación en TestFlight.

## Aceptación pendiente del usuario

Revisar TestFlight una vez que la nueva compilación termine y se procese. Comprobar idiomas, permisos y modelos reales, captura/traducción y voces, VoiceOver, tamaño accesible, fondo oscuro y uso prolongado en iPhone/iPad. No borrar las sesiones del dispositivo para verificar valores de instalación nueva.

Guía: [interfaz y preparación](interface-and-onboarding.md). Explicación para estudiantes: [junior](junior-guide.md) y [recorrido de código](code-walkthrough.md). Historial: [incidentes](build-incidents.md), [build 20](accessibility-checkpoint.md).
