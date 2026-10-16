# Checkpoint — experiencia accesible

Fecha: 2026-10-15. Implementación de los ocho puntos descritos en la [guía de uso y desarrollo](accessible-experience.md).

## Cambios y prioridades

1. Proteger datos y facilitar recuperación: esquema V9 con `SessionTrash`, Deshacer y Eliminados recientemente durante 30 días; favoritas protegidas.
2. Evitar confusión: pausa explícita, Reanudar grabación, nombres de botones opcionales, modo sencillo y preparación guiada sin captura automática.
3. Facilitar lectura y comunicación: lectura enfocada, controles adaptables al tamaño de letra, selección silenciosa de párrafos y Escribir una respuesta con voz a petición.

Las preferencias nuevas no alteran el idioma de captura ni obligan a usar el modo sencillo. Descartar borradores continúa siendo definitivo. La papelera conserva audio, correcciones y traducciones hasta restauración o eliminación definitiva/expiración. El contenido escrito para responder no se guarda.

## Validación

- 109 pruebas unitarias correctas en iPhone 15 e iPad Air de quinta generación, simuladores iOS 17.2. Incluyen migración V8→V9, reapertura, restauración con audio/traducción, expiración a 30 días, protección de favoritas y rechazo de traducciones tardías sobre sesiones eliminadas.
- Seis recorridos finales correctos en iPhone: guía inicial sin captura, lectura enfocada con letra máxima, pausa/reanudación, papelera con Deshacer/restauración/borrado definitivo, auditoría de Inicio sencillo y geometría/navegación silenciosa del reproductor.
- Tres recorridos finales correctos en iPad: lectura enfocada con letra máxima, pausa/reanudación y reproductor original/traducción. La ejecución anterior también aprobó papelera, Inicio sencillo, respuesta escrita y traducción automática al detener.
- Respuesta escrita (decir/pausar/reanudar/detener y borrado al salir) y guía del modo sencillo aprobadas en ambos simuladores.
- Release sin firma para dispositivo compilada correctamente; bundle `com.innovalogic.voicetoread`, versión 1.0, iPhone/iPad, iOS mínimo 17, manifiesto de privacidad presente y bandera de fixtures DEBUG ausente. Último ajuste de Reanudar compilado en Release y comprobado en iPhone e iPad: botón visible y pulsable con letra máxima.
- Catálogos EN/ES con 624 claves y dos permisos: mismos identificadores e interpolaciones; 446 claves extraídas por el compilador cubiertas. Textos de App Store dentro de límites; diez páginas del paquete Hostinger con enlaces y ZIP validados.

## Problemas encontrados y corregidos

- Restaurar una fila de la biblioteca podía dejar el botón de acciones afectado por el gesto del enlace: botones independientes con área de pulsación y estilo borderless; Deshacer guarda UUID en lugar de retener un modelo eliminado.
- El estilo compacto del transporte podía perder el nombre accesible de Play/Pause/Resume: etiqueta explícita incluso cuando el nombre visual está oculto.
- Con letra máxima, los controles se superponían: distribución vertical y desplazamiento de pantalla; símbolos contenidos en sus botones y etiquetas de texto ampliables. Con letra máxima, Reanudar se coloca antes de la explicación para quedar visible. La preparación inicial no reaparece durante una pausa.
- La condición del aviso inicial se restringe al estado `idle`; una referencia inicial a un estado inexistente `ready` produjo un error de compilación y se corrigió antes de distribuir.
- Una ejecución local con paralelismo de simuladores no produjo resultados y se canceló. Las comprobaciones se repiten con `-parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO SWIFT_EMIT_LOC_STRINGS=YES`.

## Límites y próximos pasos de aceptación

La compilación local utiliza Xcode 15.2. Las pruebas de traducción automática usan respuestas simuladas; no verifican la descarga ni el motor Translation de iOS 18+. Probar en iPhone/iPad físicos traducción, micrófono, ruido, voz, auriculares, alarmas, segundo plano y sesiones prolongadas.

La auditoría automática seleccionada verifica descripciones, traits y áreas de pulsación en Inicio sencillo; no certifica toda la app. Verificar recorridos reales con VoiceOver, Control por voz, Control por botón y Acceso total con teclado, ambos idiomas, orientación y letra grande. No declarar compatibilidad completa en App Store hasta esa aceptación.

Persisten dos avisos de concurrencia previos en `SessionTranslationView` y `CaptionViewModel`; no son errores de compilación. Respaldar/exportar sesiones importantes antes de actualizar producción: una migración probada no sustituye un respaldo.

## Distribución y documentación pública

La actualización se envía a `main` para que Xcode Cloud genere una compilación. Su disponibilidad en TestFlight depende de finalizar distribución y procesamiento; comprobar el estado remoto antes de anunciarla. No se ha enviado esta actualización a revisión de App Store. El paquete `website/VoiceToRead-Hostinger.zip` contiene las políticas de retención y accesibilidad actualizadas y requiere publicarse en Hostinger; generar el ZIP no modifica el sitio público.

## Evidencia visual

Capturas de simulador con contenido ficticio, para QA y no para promocionar una disponibilidad no verificada:

- [Reproductor bilingüe, tamaño habitual](qa/accessible-experience/iphone-bilingual-player.png).
- [Lectura enfocada, tamaño de accesibilidad máximo](qa/accessible-experience/iphone-largest-text-reader.png). En este tamaño se desplaza el texto y la pantalla para alcanzar todos los controles; no se comprime la letra para encajar.

- [Reanudar visible antes de la explicación, letra máxima](qa/accessible-experience/iphone-largest-text-resume.png).
