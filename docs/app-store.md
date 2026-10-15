# Preparación de App Store — VoiceToRead

Actualización 2026-10-15: [reproducción unificada y traducción al detener](playback-unification.md), con [evidencia y pendientes](playback-unification-checkpoint.md). Verificar en dispositivo descargas iniciales, permisos, auriculares/interrupciones, VoiceOver y lectura EN↔ES antes de enviar a revisión. La compilación local con Xcode 15.2 no ejecuta el traductor Apple de iOS 18+.

Actualizado 2026-10-15 · paquete de preparación, **no enviado a App Review**. Fuente 1.0 (1); evidencia actual en [inicio del proyecto](project-identity.md). Registro confirmado por captura del titular: Apple ID **6822564230**, SKU `voicetoread-ios-001`, estado **1.0 Prepare for Submission**. Versión fuente alineada; falta un nuevo archivo apto para distribución pública. Bundle `com.innovalogic.voicetoread`, equipo `7799N4RYUG`. Conservar esta identidad y sus sesiones.

## Material preparado

| Material | Archivo | Estado |
|---|---|---|
| Descripción, subtítulo, palabras clave y novedades EN/ES | [Metadata JSON](app-store-metadata.json) | Borrador listo para revisar/copiar |
| Política de privacidad consolidada EN/ES | [Política](privacy-policy-draft.md) | Responsable, correo y conservación confirmados; HTTPS verificado 2026-10-14 |
| Soporte y preguntas frecuentes EN/ES | [Soporte](store/support.md) | Página EN/ES publicada; HTTPS verificado |
| Instrucciones para el revisor | [Notas](store/review-notes.md) | Falta dispositivo probado, contacto privado y build final |
| Datos tratados y manifiesto | [Privacidad técnica](privacy.md) | Revisar informe del archivo final |
| Compilación, firma y recuperación | [Runbook](distribution-runbook.md) / [incidencias](build-incidents.md) | Consultar antes de repetir exportación |
| Evidencia y aceptación | [Checklist](release-checklist.md) / [validación](validation-report.md) | Separar simulador, Cloud, TestFlight y prueba física |

## Decisiones del titular pendientes

El titular confirmó **Dario Fernando Meneses Ceron**, persona natural, y `dariofernandomeneses@gmail.com` para soporte/privacidad. Confirmó el subdominio **https://voicetoread.innovalogic.tech/** en Hostinger, administrado con hPanel, y borrar correos de soporte de Gmail dentro de los 90 días posteriores a resolverlos, salvo obligación legal. Esta confirmación documental no verifica ni modifica la identidad registrada en Apple Developer. La web EN/ES está publicada; las URLs de privacidad/soporte se verificaron por HTTPS y se registraron en los metadatos. El titular confirmó app gratuita sin compras y disponibilidad inicial Estados Unidos/Colombia; falta aplicar esas opciones en Apple. El contacto privado de App Review se completa directamente en App Store Connect.

Versión pública 1.0. Confirmar categoría principal/secundaria y copyright, y aplicar precio/territorios ya elegidos. Propuesta editorial: Education/Educación; no marcar Kids Category solo por ofrecer práctica supervisada a niños. Si no se ofrece un EULA personalizado, revisar el [acuerdo estándar de Apple](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) y confirmar su uso. No inventar datos fiscales, condición de comerciante ni declaraciones legales.

## Pasos antes de enviar

1. Terminar la aceptación en iPhone e iPad reales: permisos denegados/concedidos, descarga de modelos, ambas lenguas, modo avión después de preparación, interrupción y Reanudar, audio largo, exportaciones, migración, favoritas y correcciones.
2. Preparar un archivo con SDK admitido por Apple el día del envío. Xcode 15.2 local sirve para comprobar compatibilidad iOS 17; no sustituye el archivo moderno de distribución. Revisar [requisitos de envío](https://developer.apple.com/app-store/submitting/) al preparar el archivo final. No asumir que un número de build Cloud es el número efectivo en TestFlight.
3. Configurar Archive para **TestFlight and App Store** si el flujo actual es Internal Testing Only. Compilar una versión elegible para revisión pública y verificar número único, firma, entitlements e informe de privacidad del archivo. Cambiar el flujo no convierte builds internos ya existentes en públicos.
4. Publicar y verificar sin iniciar sesión la política y el soporte; completar sus URLs en App Store Connect. Sincronizar el texto y añadir el enlace público a la política dentro de la app. No usar marcadores PENDING como contenido público.
5. Revisar App Privacy contra el binario: la propuesta es **Data Not Collected** porque el contenido se procesa/guarda localmente y no hay servidor del desarrollador. Verificar prácticas del soporte, Apple y cualquier SDK antes de presentar esa respuesta. Apple distingue tratamiento local de recogida fuera del dispositivo; requiere política pública. [App Privacy](https://developer.apple.com/app-store/app-privacy-details/).
6. Completar el cuestionario de edad para las funciones reales, sin fijar una edad antes de sus respuestas. Completar cifrado según el archivo; el proyecto usa protección del sistema, no un algoritmo propio. No añadir una exención automática sin confirmar sus condiciones. [Edad](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating), [cifrado](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance).
7. Capturar pantallas reales con contenido de ejemplo propio: lectura en vivo, A mi ritmo/corrección, favoritas, traducción/práctica y ajustes separados. Entregar juegos EN/ES para iPhone e iPad con tamaños aceptados actualmente. Los screenshots de tests en iPhone SE/iPad Air sirven para QA; no se anuncian como el juego comercial definitivo. [Especificaciones](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
8. Evaluar VoiceOver, Voice Control, texto grande, contraste y orientación en cada plataforma antes de declarar etiquetas de accesibilidad. Tener botones etiquetados o pasar XCTest no prueba soporte integral. [Criterios de Apple](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/).
9. Seleccionar el build aprobado internamente, pegar metadata/notas y revisar todo con el titular. **Enviar a App Review y publicar requieren una instrucción explícita posterior.**

## Posicionamiento honesto

Herramienta de apoyo para comprender conversaciones, leer a su ritmo y practicar idiomas, incluida ayuda para personas con pérdida auditiva o baja visión y actividades infantiles supervisadas. No prometer precisión perfecta, diagnóstico, tratamiento, interpretación profesional ni compatibilidad absoluta. Audio de micrófono; no extracción del audio interno de YouTube. Traducción requiere iOS/iPadOS 18+, build compatible y modelos preparados; iOS 17 conserva las funciones compatibles. Reducción de ruido puede atenuar voces distantes.

## Estado histórico

Además del uso del proyecto base, el 2026-10-14 el usuario confirmó instalación y funcionamiento básico de VoiceToRead desde TestFlight en su iPhone. No se conoce el número instalado ni se ha probado todavía la futura versión pública 1.0. Los fallos de exportación 9–12 y recuperación local están en el runbook; no deben presentarse como el estado actual sin consultar el SHA/build concreto. La nueva funcionalidad y esta documentación se validan por separado; estar en GitHub no demuestra instalación en el teléfono.

## Comprobación de los textos

Ejecuta `python3 scripts/validate-store-metadata.py` para verificar límites de campos EN/ES. `--ready` rechaza los datos pendientes antes de envío; actualmente debe rechazarlos. Pasarlo no sustituye verificar URLs públicas, binario, declaraciones ni aceptación física.

## Publicación de las páginas en Hostinger

La web está preparada con privacidad, soporte, seguridad y accesibilidad EN/ES. Seguir [la guía de publicación](website-publication.md): ZIP, carpeta del subdominio, SSL y comprobación sin iniciar sesión. Esa guía también explica el funcionamiento para estudiantes.

URLs previstas: `https://voicetoread.innovalogic.tech/privacy/` y `https://voicetoread.innovalogic.tech/support/`. El certificado consultado no cubría el subdominio; resolverlo en hPanel antes de usar esas URLs. Tras verificar publicación, actualizar metadata y enlazar/sincronizar la política dentro de la app. No se modificó el binario ni se envió a revisión en esta tarea.

Paquete práctico con campos y orden de entrega: [submission-kit.md](store/submission-kit.md).

Nueva entrega de lectura accesible: [voz traducida y controles](translated-speech.md). Los textos EN/ES y notas del revisor se actualizaron como borrador; validar el nuevo binario y comparar capturas antes de publicar.
