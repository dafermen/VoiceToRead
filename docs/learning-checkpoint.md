> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Aprender inglés — punto de reanudación (build 18)

Autorizado: un solo icono Capture Preferences y primera etapa de aprendizaje: escuchar/repetir más lento, revelar español y guardar expresiones con contexto/audio. Dictado, repaso programado y evaluación de pronunciación quedan para etapas posteriores. Usuario pide detenerse si se recibe aviso de cuota agotada; no existe un indicador de cuota disponible en este proyecto.

Base estable: 5258b8a. Revisar git status antes de continuar; no descartar trabajo del usuario.

- [x] Icono único de preferencias.
- [x] Aprendizaje desde sesiones, audio por fragmento, velocidad/bucle y español oculto.
- [x] Colección local de expresiones, independiente del diccionario de reconocimiento.
- [x] Persistencia/migración, pruebas relevantes y documentación.
- [x] Cambios listos para commit/push; verificar HEAD y origin/main al retomar.
- [ ] Cloud/TestFlight y aceptación en iPhone.

Si se interrumpe: abrir este archivo, git diff y los logs /private/tmp/VoiceToRead-18*. No publicar como probado lo que no haya terminado.

## Validación final local
- **76 pruebas unitarias y 1 recorrido UI aprobados**, cero fallos. Las 5 nuevas pruebas de aprendizaje cubren unidades/tiempos, persistencia/reapertura/borrado, independencia de traducción, V6→V7 y parada/bucle de audio.
- Resultado: `/private/tmp/VoiceToRead-18-Tests.xcresult`; log `/private/tmp/VoiceToRead-18-tests.log` (**TEST SUCCEEDED**).
- Release: `/private/tmp/VoiceToRead-18-release.log` (**BUILD SUCCEEDED**). Build 18, identidad, iOS mínimo 17, orientaciones, background audio, assets y privacidad verificados.
- Captura `/private/tmp/Saved-learning-expression.png` revisada visualmente en iPhone SE de simulador: controles, lectura y expresiones visibles.
- Enlaces locales, plist del proyecto y diff comprobados.
- Incidente resuelto: primer Debug referenciaba PlaybackButtonStyle privado; reemplazado por un estilo estándar antes de las pruebas aprobadas.

## Siguiente paso, sin repetir implementación
Consultar `git status --short`, `git log -3 --oneline` y comparar HEAD/origin/main. Verificar check-runs del commit en GitHub y su entrega TestFlight. Compilación local no confirma instalación en el iPhone. Pruebas físicas pendientes: Bluetooth/interrupciones, accesibilidad, calidad del audio a 0.75× y sesiones reales. No falta implementar ninguna de las tres funciones aprobadas de esta primera etapa; dictado/repaso programado/pronunciación siguen fuera de alcance.


## Actualización 2026-10-11
La etapa siguiente de práctica local ya está autorizada e implementada en build 19; consultar [su checkpoint](pronunciation-checkpoint.md). La evaluación especializada de sonidos sigue pendiente de un servicio externo. Este archivo conserva la evidencia histórica de build 18.
