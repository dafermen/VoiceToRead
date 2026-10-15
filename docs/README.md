# Documentación de VoiceToRead

- [Traducción bilingüe en vivo (build 24)](translation.md).
- [Estado de entrega build 24](live-bilingual-checkpoint.md).

- [Reducción de ruido: uso, límites y explicación para estudiantes](noise-reduction.md).
- [Estado de entrega build 22](noise-checkpoint.md).

## Ampliación inclusiva e idiomas — build 20

[Guía para usuarios, familias y docentes](inclusive-use.md): inglés/español, apoyo a audición/baja visión, iPad, Practicar idioma, aviso de pausa y papel con renglones. [Estado de validación y reanudación](accessibility-checkpoint.md). Los apartados por build que siguen conservan el historial.


Actualizada el 11 de octubre de 2026. Los documentos de aprendizaje están en español; la interfaz de la app y parte de la documentación técnica conservan el inglés.

La identidad vigente es **VoiceToRead 0.1.0 (1)**. Empezar por [inicio del proyecto](project-identity.md): los informes antiguos son historial heredado y no prueban distribución de esta nueva app.

## Por dónde empezar

| Necesidad | Documento |
| --- | --- |
| Conocer la app, instalar el proyecto y consultar sus funciones | [README principal](../README.md) |
| Aprender desde cero cómo funciona el proyecto | [Guía para estudiantes y desarrolladores junior](junior-guide.md) |
| Encontrar la clase o función que realiza una tarea | [Recorrido del código](code-walkthrough.md) |
| Preparar el Mac y ejecutar validaciones | [Desarrollo](development.md) |
| Entender las decisiones de diseño | [Arquitectura](architecture.md) y [ADRs](decisions/ADR-006-xcode-15-compatibility.md) |
| Compilar, firmar y llevar una versión a TestFlight | [Guía de distribución](distribution-runbook.md) |
| Investigar errores que ya ocurrieron | [Historial de incidentes](build-incidents.md) |
| Saber qué se probó realmente | [Resultados de validación](validation-report.md) |
| Planificar pruebas pendientes | [Pruebas](testing.md), [audio y subtítulos](media-and-subtitles.md) y [fiabilidad](reliability.md) |
| Preparar una publicación pública | [Lista de publicación](release-checklist.md) y [App Store](app-store.md) |
| Entender el tratamiento de los datos | [Privacidad](privacy.md) |

Consulta también [el nuevo flujo de sesiones](session-workflow.md): preferencias recordadas, controles compactos, recuperación y Guardar/Descartar.

## Estado al cerrar esta actualización

- Las versiones TestFlight 0.1.0 (5) y (6) tuvieron confirmación del usuario de funcionamiento básico en su iPhone.
- Las mejoras posteriores incluyen corrección de texto, audio opcional, reproducción y subtítulos SRT/WebVTT.
- La compilación Cloud 11 produjo el archivo con Xcode 26.6. Su exportación automática falló.
- Ese mismo archivo se exportó y subió desde el Mac con Xcode 15.2 el 10 de octubre. Apple confirmó la subida y el inicio del procesamiento.
- Las capturas confirman que esa subida terminó como 0.1.0 (1), asignada a Dev. La gestión automática no incrementó el número.
- Se volvió a firmar y subir una copia como 0.1.0 (13), con numeración explícita. El usuario confirmó posteriormente que la actualización llegó al iPhone y que ambas opciones de captura funcionan. Las pruebas físicas completas de audio/subtítulos siguen pendientes.
- Fuente build 14 añade preferencias persistentes y el flujo de borradores/Guardar/Descartar. Su distribución es un paso separado.
- La exportación automática de Cloud continúa sin solución confirmada. Existe una alternativa comprobada para este archivo; no una garantía de compatibilidad futura.

## Cómo interpretar el historial

Los informes `phase-*-report.md`, [el informe de entrega inicial](implementation-report.md) y las secciones antiguas de validación describen lo conocido en sus fechas. No son el estado actual. Mantenerlos permite aprender qué se intentó y por qué se cambió de camino.

Al documentar un resultado, distinguir: implementado, compilado, probado en simulador, probado en dispositivo, subido, procesado y disponible para testers. Cada palabra requiere evidencia distinta.

Build 15 añade revisión por frase, feedback de captura, reanudación manual, nombres y ampliación por gesto. Su validación y entrega se registran por separado en el informe de pruebas.

Build 16 incorpora [traducción al español](translation.md) de sesiones guardadas, edición independiente y exportación bilingüe. La validación local y la prueba real del traductor se distinguen en el informe.

- [Build 17: punto de reanudación y validación](implementation-checkpoint.md) — seis mejoras de traducción, estado verificable y pruebas pendientes.


## Aprender inglés — build 18

Escucha/repite fragmentos a 0.75× o 1×, revela el español y conserva expresiones con contexto/audio. Capture Preferences ahora tiene un solo icono. Consulta [la guía de aprendizaje](learning.md) para uso, arquitectura V7 y límites.


## Práctica de pronunciación

[Guía de uso y explicación para estudiantes](pronunciation.md) · [Punto de reanudación build 19](pronunciation-checkpoint.md).


## Actualización build 21

Ver [interfaz bilingüe y primera preparación](interface-and-onboarding.md). El idioma de menús es independiente del idioma hablado. Guardar audio está activado inicialmente solo en instalaciones nuevas; las elecciones anteriores se conservan. Los renglones se calculan con el texto de cada párrafo. Estado de entrega: [checkpoint](interface-checkpoint.md).

## Actualización 23

- [A mi ritmo, edición directa y favoritas](at-my-pace.md): uso y arquitectura.
- [Checkpoint de entrega](pace-checkpoint.md): resultados y pendientes reales.
- [Preparación de App Store](app-store.md): índice de política, soporte, textos EN/ES, notas para revisión y decisiones del titular.

## Sitio público y políticas — VoiceToRead

La web bilingüe se genera en `website/dist/`. La [guía de publicación y explicación para estudiantes](website-publication.md) cubre HTML/CSS, generación desde documentos, idiomas, validación, hPanel y SSL. El [README de la web](../website/README.md) contiene los comandos. Sitio preparado; subida y HTTPS públicos pendientes.

- [Escuchar traducciones: guía de uso inclusivo y desarrollo](translated-speech.md)
- [Validación y pendientes de voz traducida](translated-speech-checkpoint.md)
