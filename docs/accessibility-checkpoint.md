> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Punto de reanudación — build 20

2026-10-11. Base: `0b820fc`. Cambios autorizados implementados: orientación inclusiva, iPad universal, idioma inglés/español, Practicar idioma, pausa visible, papel claro y renglones. Sin cambio de esquema V7 ni de identidad.

## Estado técnico

- Preferencias persistentes; inglés inicial; idioma inmutable por sesión; reconocimiento, traducción y práctica en ambos sentidos; payloads antiguos interpretados como inglés.
- Pausa con aviso persistente, Reanudar y anuncio accesible; no reinicio automático del micrófono.
- Colores claros con texto oscuro; guías CoreGraphics decorativas; alto contraste tiene prioridad.
- Paquete Release 0.1.0 (20) compilado, familia `[1,2]`, icono iPad y cuatro orientaciones. La fuente local usa Xcode 15.2; la compilación moderna también quedó aprobada (ver entrega abajo).

## Evidencia y límites

88 unitarias aprobadas en `VoiceToRead-20-Unit.xcresult`, antes del ajuste final de dibujo y snapshot de diccionario. El log final `VoiceToRead-20-confirmed.log` registra dos recorridos UI aprobados: lectura con renglones/pausa/giro/Reanudar y práctica española. Su tercer recorrido falló al abrir Sessions; después el runner unitario quedó esperando. Al cancelar Xcode no finalizó el bundle. No declarar toda esa suite aprobada.

La traducción guardada con edición/audio/exportación pasó en la ejecución anterior `VoiceToRead-20-UI.xcresult`. La repetición aislada final (`VoiceToRead-20-regression-final.log`) abrió Sessions, corrigió/guardó traducción y reprodujo audio, pero quedó esperando la jerarquía de la hoja nativa de compartir durante varios minutos. Se canceló; no cuenta como aprobación final integral. Una captura tardía mostró «Preparing file…», sin confirmar la presentación de la hoja. Revisar compartir en el dispositivo.

iPad: configuración y Release universales comprobados; capturas anteriores de vertical y fullscreen horizontal revisadas con fondo amarillo y pausa. La última ejecución `VoiceToRead-20-ipad-final.log` no consiguió iniciar XCTest y fue cancelada. Queda pendiente el recorrido final de renglones en iPad y la aceptación física. No reinstalar ni borrar datos del iPhone para resolver problemas del simulador.

Más detalle: [informe de validación](validation-report.md), [incidentes](build-incidents.md), [guía inclusiva](inclusive-use.md).

## Próxima aceptación

1. Comprobar el check de Archive del commit publicado; éxito local no acredita TestFlight.
2. En iPhone/iPad: preparar ambos modelos, transcribir voz real, traducir en ambos sentidos y conservar idioma al reanudar.
3. Probar alarma real, segundo plano, VoiceOver, tamaños accesibles, ventana dividida y compartir en iPad.
4. No repetir la compilación o cambiar firma por un error de exportación sin consultar los logs detallados y el historial de incidentes.

## Entrega de código y compilación moderna

Código publicado en `main`: `25d24ac1308e0581830d2741c45ce76b6138e307`. [Archive – iOS](https://appstoreconnect.apple.com/) aprobado el 2026-10-11 a las 17:46:15 UTC; check `114533808792`, conclusión `success`, cero errores y cuatro advertencias (concurrencia de AVAssetExportSession/AVAudioPCMBuffer, import AVFAudio y nombre obsoleto allowBluetooth). Son advertencias en código de audio existente; no impidieron Archive. No declarar migración a modo Swift 6 completa.

Esto valida compilación moderna, no voz/traducción real, prueba física ni instalación TestFlight. Comprobar procesamiento, asignación al grupo Dev y actualización en el dispositivo. El commit posterior de documentación no cambia Swift ni configuración de la app.
