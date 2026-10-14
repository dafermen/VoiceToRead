> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Pronunciación — punto de reanudación, build 19

Fecha: 2026-10-11. Base: ab1e323, main. Usuario autorizó práctica local y confirmó no tener Azure; dejar evaluación en línea documentada. Si llega aviso real de cuota agotada, detener trabajo y conservar este estado; no hay contador de cuota consultable en el repositorio.

- [x] Pantalla de escuchar/pronunciar/comparar desde Aprender inglés, selección de palabras/frases, voz normal/lenta.
- [x] Grabación temporal de 15 segundos, reproducción y reconocimiento opcional estrictamente local, sin notas de pronunciación.
- [x] Cancelación, protección, limpieza y permisos explícitos; documentación para usuarios/estudiantes y plan futuro en línea.
- [x] 83 pruebas unitarias finales y Release aprobados; ambas UI iniciales aprobadas.
- [x] UI final aprobada en 39,348 s; capturas verticales revisadas. Giro/cierre probado; captura durante animación no valida visualmente todo el landscape.
- [x] Código, pruebas y documentación guardados en Git; al retomar, comparar HEAD/origin/main para confirmar publicación.
- [ ] Comprobación independiente de Cloud/TestFlight y aceptación física.

Logs en `/private/tmp/VoiceToRead-19-*`. Primera compilación Debug aprobada. Antes de continuar: git status, este archivo y el reporte. No repetir implementación ni afirmar pruebas pendientes como aprobadas. Identidad/esquema sin cambios.

## Evidencia y límites

`/private/tmp/VoiceToRead-19-unit-final.log` / `VoiceToRead-19-Unit-Final.xcresult`: 83 pruebas aprobadas. `VoiceToRead-19-release-final.log`: Release aprobado. Las dos pruebas UI iniciales pasaron; `/private/tmp/VoiceToRead-19-ui-final.log` / `VoiceToRead-19-UI-Final.xcresult` verifican el ajuste visual final.

Primeras aserciones fallidas (ya corregidas): URL con barra final y atributo de protección no expuesto por el simulador. Verificar protección real en iPhone, además de voces/modelos, permisos, silencio/ruido, Bluetooth, interrupciones, VoiceOver y texto grande. No hay una evaluación objetiva de pronunciación en esta entrega.

Resultado final UI: **TEST SUCCEEDED**. No se repitió toda la suite UI histórica; pasaron el recorrido anterior de aprendizaje y el nuevo de pronunciación. Release final aprobado con build 19.
