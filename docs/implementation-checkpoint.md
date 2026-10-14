> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Punto de reanudación — mejoras de traducción (build 17)

Solicitud autorizada: seis mejoras propuestas, documentación y repositorio. El usuario avisa que queda aproximadamente 5% de su cupo; conservar estado verificable, no publicar código sin validar.

Base estable: e1b56c1 (build 16). Identidad com.innovalogic.voicetoread y esquema V6 se conservan.

## Lista de trabajo
- [x] Escuchar audio original desde un párrafo traducido.
- [x] Diccionario personal para reconocimiento y términos españoles.
- [x] Traducción incremental que conserve ediciones de párrafos sin cambios.
- [x] Búsqueda bilingüe entre sesiones y acceso al resultado.
- [x] Vista previa de idioma/formato/vigencia antes de compartir.
- [x] Traducción opcional durante captura sobre texto final, sin bloquear micrófono.
- [x] Pruebas locales y documentación de usuario/junior.
- [x] Código y documentación publicados en `main`: commit `a135f0e`.
- [ ] Comprobación moderna en Xcode Cloud y entrega TestFlight.

## Reanudar
Consultar git status y git diff antes de editar. No asumir que una compilación local con Xcode 15.2 valida Translation (requiere SDK moderno y iOS 18). Revisar check-runs del commit en GitHub para Cloud; éxito Cloud no confirma instalación TestFlight. Conservar traducciones completas anteriores ante fallos/cancelaciones. No cambiar certificados ni identidad.

## Estado de validación
- **71 pruebas unitarias aprobadas**, incluidas 10 de traducción.
- **Tres recorridos UI aprobados** entre las últimas ejecuciones: búsqueda española, bloqueo de traducción obsoleta y lectura/edición/audio/pausa/vista previa/exportación SRT.
- Corrección confirmada: sheet(item:) entrega el párrafo correcto al reproductor. El recorrido final pasó en 51,509 segundos, sin fallos.
- Evidencia UI final: `/private/tmp/VoiceToRead-17-ui-verified.log` y `/private/tmp/VoiceToRead-17-UI-Verified.xcresult`.
- Debug y Release finales compilados; `/private/tmp/VoiceToRead-17-release-final.log`. Identidad/build 17 verificados; 118 enlaces locales, plist y diff revisados.
- Los conjuntos anteriores `VoiceToRead-17-Tests.xcresult` y `VoiceToRead-17-UI-Final.xcresult` incluyen los fallos ya corregidos. No presentarlos como ejecuciones completas exitosas.
- Próximo: consultar check-runs de `a135f0e` (o el commit documental posterior) en GitHub. Al terminar esta sesión no había check registrado y la última consulta falló con «error connecting to api.github.com». El push del código sí terminó correctamente. Xcode 15.2 no verifica las APIs modernas de Translation/SpeechAnalyzer.
- Pendiente iPhone/TestFlight: descargar modelos, calidad, latencia, batería, interrupciones. La vista en directo es temporal y experimental; para exportar español se traduce la sesión guardada.

## Continuación mínima
1. `git status --short` y `git log -3 --oneline`: conservar cualquier cambio nuevo del usuario.
2. `gh api repos/dafermen/VoiceToRead/commits/a135f0e/check-runs` (también consultar HEAD si hay un commit documental posterior).
3. Si Cloud falla, leer su error específico antes de modificar código/certificados; no confundir un fallo de exportación con compilación Swift.
4. Si Cloud pasa, revisar TestFlight y asignación al grupo Dev. No afirmar instalación del iPhone sin confirmación.
5. Probar vista española en directo/modelos/diccionario en un iPhone compatible. Todo el código y las pruebas locales de las seis mejoras están terminados; no volver a implementarlos desde cero.
