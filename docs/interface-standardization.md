# Estándar visual compartido — 2026-11-05

Esta entrega unifica la presentación y los accesos equivalentes. Conserva los destinos de navegación, acciones, condiciones de disponibilidad, avisos importantes y confirmaciones. No migra datos ni modifica captura, traducción, reproducción, voces, exportación, contenidos educativos o preferencias guardadas.

## Convenciones

| Elemento | Convención |
| --- | --- |
| Acción circular | Círculo de 48 × 48 puntos, símbolo de 21 puntos semibold y geometría estable al cambiar de estado. |
| Acción principal de cabecera | Azul, símbolo blanco. Detener captura conserva el rojo y el cuadrado. |
| Transporte secundario | Círculo neutro, mismo símbolo y tamaño. El estado desactivado conserva la condición del botón. |
| Pantalla completa | Estilo circular con material, contorno y respuesta por opacidad; mantiene la ubicación y visibilidad propias del módulo. |
| Nombres de controles | Etiquetas opcionales donde corresponde; nombres accesibles presentes aun con iconos solos. Los idiomas, estados e instrucciones siguen visibles. |
| Opciones | Mismo símbolo de tres puntos, tamaño mínimo y tratamiento de etiquetas. Accesos actuales conservados a la izquierda. |
| Selectores y tarjetas | Radio compartido de 12 puntos; se conservan el color por idioma, encabezados y tamaño de lectura. |
| Ventanas internas | Título inline, botón Volver nativo y confirmaciones existentes. Las listas principales conservan su jerarquía. |

`AppInterface`, `AppControlSymbol`, `AppFloatingControlStyle`, `AppOptionsLabel` y `NamedCircleControl` viven junto a los componentes de presentación existentes en `AppSettings.swift`. No tienen acceso a repositorios ni ejecutan acciones de audio. Los botones originales siguen siendo dueños de sus closures, accesibilidad, shortcuts y reglas de disponibilidad.

## Alcance por módulo

- **Conversar y Escuchar:** acciones de cabecera comparten símbolo/círculo; opciones y expansión/contracción usan los estilos compartidos. Se conserva el lector despejado y Reanudar en pausa, con su énfasis accesible.
- **Guardado > Audio y subtítulos:** transporte y reproducción de tarjetas comparten geometría; Anterior, Siguiente, retroceso de diez segundos y preferencias permanecen disponibles en las mismas condiciones.
- **Lecciones guiadas:** controles de párrafo y barra inferior siguen la misma familia visual. Pausar/Reanudar y Detener se conservan. La barra se apila con tamaños de accesibilidad.
- **Podcasts:** transporte y pantalla completa comparten estilo con los demás lectores. Karaoke, velocidad, resaltado y posición no cambian.
- **Mis prácticas:** opciones y nombres de grabar/detener/escuchar intento respetan los estilos y la preferencia de etiquetas. Revelar respuesta, traducción automática, edición puntual y resultados permanecen iguales.
- **Cuentos:** opciones, esquinas y etiquetas de reproducción siguen el estándar; traducciones por idioma, revisión adulta, original y confirmaciones permanecen iguales.
- **Verbos:** reproducción con el mismo círculo y etiqueta de transporte. IPA, filtros, favoritos, completados y traducciones permanecen iguales.
- **Ajustes y herramientas internas:** se comparten selectores y estilos; Comprobar micrófono y Privacidad adoptan título inline.

No se fuerza a todos los módulos a tener los mismos controles. Los menús conservan sus acciones y orden para evitar alterar el flujo conocido. Crear, borrar y guardar mantienen sus nombres y confirmaciones. Se conservan las áreas seguras, los tamaños de texto, el modo oscuro, Alto contraste y Reducir movimiento.

## Validación de esta entrega

Ejecutado en Windows:

- Proyecto Xcode: parser OpenStep, referencias de archivos, tres targets y esquema con los targets unitario/UI válidos.
- Localización: 1115 claves y dos mensajes InfoPlist con paridad de idiomas y placeholders (`python -X utf8 scripts/validate-localization.py`).
- Lecciones: 126 documentos, 2520 audios, rangos por palabra y 504 paquetes de apoyo válidos.
- Podcasts: 30 fragmentos bilingües, audios, tiempos y rangos por palabra válidos.
- Verbos: 130 entradas completas; cobertura de los 125 verbos únicos de Excel, seis idiomas e IPA válida según el validador de catálogo.
- Metadatos de tienda: límites de texto válidos.
- Auditoría del diff: llamadas a modelos/servicios, condiciones `disabled`, argumentos de confirmaciones y sheets, hooks de ciclo de vida, atajos e identificadores existentes conservados; inicialización y persistencia de ajustes sin cambios. Delimitadores revisados en 74 archivos Swift. `git diff --check` sin errores.

Estos controles estáticos y de recursos no equivalen a ejecutar la app. No hay `xcodebuild`, `swift` ni simulador iOS en este equipo; compilación, XCTest y validación visual física quedan pendientes.

## Pruebas nativas preparadas y aceptación pendiente

Se ampliaron `testGuidedLessonRendersBundledContentWithoutRecording` y `testPodcastEntryAndVisiblePlaybackWithoutMicrophonePrompt` para revisar controles estables, pausa/reanudación y nombres. Se añadió `testPodcastIconOnlyControlsKeepAccessibleNamesAndNavigation` para reproducir, pausar, detener y volver con etiquetas ocultas. El esquema ya incluye estos tests; no se han ejecutado en Windows.

En Mac: ejecutar `bash scripts/validate-macos.sh` para Debug/Release y suites unitarias/UI. La compilación de archivo de Xcode Cloud por sí sola no demuestra que esas suites hayan pasado.

Antes de dar aprobación visual, revisar en iPhone e iPad:

- Recorrer Conversar, Escuchar, Guardado, Lecciones, Mis prácticas, Cuentos, Podcasts, Verbos y Ajustes; entrar, volver y cerrar sin alterar datos.
- Grabar, pausar/reanudar, detener, guardar/descartar; favoritas protegidas, confirmaciones de borrado y edición conservadas.
- Original, traducción, tarjetas, audio por párrafo, reproducción continua y retroceso cuando corresponde.
- Etiquetas activas/inactivas, español/inglés de interfaz, selección de idiomas y preferencias tras volver a abrir.
- Vertical/horizontal y pantalla completa, sin solapamientos con la barra de inicio o cámara; último párrafo visible.
- Texto accesible grande, VoiceOver, contraste aumentado, oscuro/claro y Reducir movimiento.

Reglas futuras: reutilizar los componentes existentes; no añadir escalado al presionar; no sustituir un contenedor lector por otro que reinicie su estado; conservar accesibilidad y acciones aunque se cambie una etiqueta o un estilo.
