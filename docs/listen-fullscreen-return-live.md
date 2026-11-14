# Escuchar: volver al texto en vivo en pantalla completa

Fecha: 2026-11-13.

## Uso

Al desplazarse hacia párrafos anteriores en Escuchar, el seguimiento automático se pausa para permitir la lectura. En pantalla completa aparece ahora una flecha hacia abajo junto a Contraer y, si corresponde, Reanudar. Su nombre accesible es **Volver al texto en vivo**.

Al pulsarla, baja al último contenido y vuelve a seguir los nuevos párrafos. El botón desaparece mientras se está siguiendo el texto. No es un control de audio: si la captura estaba activa continúa activa; si estaba pausada no se reanuda por pulsar esta flecha.

Funciona con Original, Traducción y Ambos, incluidas las columnas bilingües. Fuera de pantalla completa se conservan los botones de retorno existentes.

## Implementación acotada

- En el original se reutiliza `followLive` y su `scrollToLive`, incluido el segundo desplazamiento después del layout.
- En traducción/ambos, `LiveReaderFollowControlKey` permite que la fila de controles acceda únicamente al binding de seguimiento del lector. Se publica al estar en pantalla completa, sin seguimiento y con contenido. El identificador de la instancia evita conservar el control de otro lector.
- `LiveSpanishView` conserva sus estados de buffer y trabajo de traducción, su identidad y sus callbacks. Al habilitar el seguimiento se ejecuta su manejador existente para ir a `translationBottom`; las traducciones que llegan después también siguen ese estado.
- La flecha usa el estilo circular de 48 puntos y queda a la izquierda de Reanudar/Contraer. Los controles comparten una fila, sin superponerse unos a otros ni añadir otra barra permanente. Se conserva el margen desplazable que despeja los controles al llegar al final.
- El lector bilingüe expone para accesibilidad si está siguiendo el texto o leyendo párrafos anteriores. Se reutilizan las traducciones existentes de las etiquetas.

No se modifican servicios de grabación, reconocimiento o traducción, datos guardados, selectores, confirmaciones ni acciones de guardar/descartar. El retorno solo cambia el estado de seguimiento. No invoca iniciar, pausar, detener ni programar una traducción.

## Validación

Ejecutado localmente en Windows:

- Parser OpenStep, referencias del proyecto, targets y esquema de pruebas válidos.
- 1118 claves de interfaz y dos de InfoPlist con paridad de idiomas/placeholders.
- Auditoría de llamadas existentes de audio/almacenamiento, confirmaciones, sheets, cierre y atajos: conservadas. Servicios, persistencia y contenido sin cambios.
- Delimitadores Swift y `git diff --check` correctos.

Se prepararon tres regresiones UI: `testListenFullscreenReturnToLiveOriginal`, `testListenFullscreenReturnToLiveTranslation` y `testListenFullscreenReturnToLiveBothColumns`. Comprueban desplazarse hacia atrás, aparición del control, vuelta al seguimiento, separación entre botones, captura activa conservada, captura pausada conservada y opciones de guardar/descartar al terminar.

**Pendiente de ejecutar en Mac/iPhone:** compilación, XCTest y revisión real del desplazamiento, traducciones que llegan mientras se lee, VoiceOver, letra grande, orientación vertical/horizontal y posiciones de los controles. No hay Xcode ni simulador iOS en el equipo Windows. Los verificadores de fuente/recursos no ejecutan estas pruebas ni demuestran el comportamiento en dispositivo. Usar `bash scripts/validate-macos.sh`; Archive de Xcode Cloud no sustituye las suites UI.
