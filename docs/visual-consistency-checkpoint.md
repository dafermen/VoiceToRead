# Checkpoint — uniformidad visual

Fecha: 2026-10-17. Proyecto VoiceToRead, bundle `com.innovalogic.voicetoread`.

Esta revisión documenta el estado anterior a la retirada del botón Inicio superior. Consulta [la siguiente revisión](language-controls-checkpoint.md) para selectores compartidos y nombres independientes del modo sencillo.

## Alcance

Inicio sencillo, barra de Escuchar ahora, transporte compartido de audio y práctica, acciones de aprendizaje y cierre de ventanas. Ver [guía](home-controls.md). Son cambios de presentación y navegación, sin migración, modificación de grabaciones, reconocimiento o traducción.

## Validación

- Xcode 15.2, simulador iPhone 15 con iOS 17.2: compilación Debug y cuatro recorridos de interfaz aprobados en `vtr-consistency-final.xcresult`.
- Práctica: reproducir/pausar audio, mostrar traducción, abrir/cerrar pronunciación, guardar una expresión y reabrirla. Nombres visibles fuera del círculo y cierre a la derecha.
- Inicio normal: activar/desactivar nombres, girar, pantalla completa y navegación existente.
- Inicio sencillo: las seis tarjetas tienen tamaños coherentes, nombres siempre presentes, barra compacta, acceso a Opciones de lectura y regreso a Inicio.
- Español, modo oscuro y tamaño de accesibilidad máximo: controles de Inicio y Acciones de sesión accesibles, con adaptación vertical.
- La inspección de capturas detectó un icono de Inicio desbordado al aumentar la letra al máximo. Se fijó el tamaño de los símbolos decorativos conservando texto dinámico y áreas de toque. Los dos recorridos afectados se repitieron y aprobaron en `vtr-consistency-home-final.xcresult`.
- Catálogos: 773 claves de interfaz, 2 de permisos, paridad en/es y cobertura de 493 claves extraídas por el compilador. `git diff --check` sin errores.

El primer intento de interfaz pasó Práctica, pero el nuevo escenario de Inicio buscaba «Reading options» donde el menú todavía decía «Recording options». Se unificó el nombre con el destino real y el recorrido final aprobó. Permanece la advertencia previa de aislamiento MainActor en el callback de cierre de SessionTranslationView. No se alteró lógica de audio ni persistencia.

Los resultados y logs completos se guardan en `/private/tmp/vtr-consistency-*.xcresult` y `.log`. Esta revisión valida presentación en simulador: no certifica disponibilidad de idiomas Apple ni publicación en TestFlight.

## Capturas de verificación

Datos de prueba, sin sesiones de usuarios: [Inicio claro](qa/visual-consistency/home-light.png), [Inicio oscuro con letra grande](qa/visual-consistency/home-dark-large.png), [barra sencilla](qa/visual-consistency/reader-simple.png), [práctica con nombres](qa/visual-consistency/practice-names.png).

## Entrega

No considerar estos cambios disponibles en TestFlight hasta confirmar el procesamiento y distribución de la nueva compilación. La revisión de diseño en simulador no sustituye la comprobación en iPhone/iPad físico con VoiceOver.
