# Preparación de App Store — VoiceToRead

Actualizado 2026-10-13 · paquete de preparación, **no enviado a App Review**. Fuente 0.1.0 (1); evidencia actual en [inicio del proyecto](project-identity.md). Nuevo registro de App Store Connect pendiente, bundle `com.innovalogic.voicetoread`, equipo `7799N4RYUG`. Conservar esta identidad y sus sesiones.

## Material preparado

| Material | Archivo | Estado |
|---|---|---|
| Descripción, subtítulo, palabras clave y novedades EN/ES | [Metadata JSON](app-store-metadata.json) | Borrador listo para revisar/copiar |
| Política de privacidad consolidada EN/ES | [Política](privacy-policy-draft.md) | Responsable y correo confirmados; falta proceso de soporte y URL pública |
| Soporte y preguntas frecuentes EN/ES | [Soporte](store/support.md) | Correo, dominio y Hostinger confirmados; página pendiente |
| Instrucciones para el revisor | [Notas](store/review-notes.md) | Falta dispositivo probado, contacto privado y build final |
| Datos tratados y manifiesto | [Privacidad técnica](privacy.md) | Revisar informe del archivo final |
| Compilación, firma y recuperación | [Runbook](distribution-runbook.md) / [incidencias](build-incidents.md) | Consultar antes de repetir exportación |
| Evidencia y aceptación | [Checklist](release-checklist.md) / [validación](validation-report.md) | Separar simulador, Cloud, TestFlight y prueba física |

## Decisiones del titular pendientes

El titular confirmó `dariofernandomeneses@gmail.com` para soporte/privacidad y `https://innovalogic.tech/` como sitio, alojado en Hostinger. Responsable confirmado por el titular: **Dario Fernando Meneses Ceron**, persona natural. Esta confirmación documental no verifica ni modifica la identidad registrada en Apple Developer. Proponemos `/voicetoread/privacy/` y `/voicetoread/support/`; esas rutas no se consideran publicadas ni verificadas. Los campos definitivos de URL de la metadata permanecen vacíos hasta comprobar las páginas públicas. Revisar el manejo real de mensajes de soporte (proveedor, acceso y conservación) y adaptar la política antes de publicarla. El correo o teléfono de contacto privado de App Review se completa directamente en App Store Connect.

Elegir versión pública, precio, territorios, categoría principal/secundaria, copyright y disponibilidad por plataforma. Propuesta editorial: Education/Educación; no marcar Kids Category solo por ofrecer práctica supervisada a niños. Si no se ofrece un EULA personalizado, revisar el [acuerdo estándar de Apple](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) y confirmar su uso. No inventar datos fiscales, condición de comerciante ni declaraciones legales.

## Pasos antes de enviar

1. Terminar la aceptación en iPhone e iPad reales: permisos denegados/concedidos, descarga de modelos, ambas lenguas, modo avión después de preparación, interrupción y Reanudar, audio largo, exportaciones, migración, favoritas y correcciones.
2. Preparar un archivo con SDK admitido por Apple el día del envío. Xcode 15.2 local sirve para comprobar compatibilidad iOS 17; no sustituye el archivo moderno de distribución. Revisar [requisitos de envío](https://developer.apple.com/app-store/submitting/) al preparar el archivo final. No asumir que un número de build Cloud es el número efectivo en TestFlight.
3. Configurar Archive para **TestFlight and App Store** si el flujo actual es Internal Testing Only. Compilar una versión elegible para revisión pública y verificar número único, firma, entitlements e informe de privacidad del archivo. Cambiar el flujo no convierte builds internos ya existentes en públicos.
4. Publicar y verificar sin iniciar sesión la política y el soporte; completar sus URLs en App Store Connect. Añadir el contacto confirmado a la política dentro de la app en la siguiente revisión del texto. No usar marcadores PENDING como contenido público.
5. Revisar App Privacy contra el binario: la propuesta es **Data Not Collected** porque el contenido se procesa/guarda localmente y no hay servidor del desarrollador. Verificar prácticas del soporte, Apple y cualquier SDK antes de presentar esa respuesta. Apple distingue tratamiento local de recogida fuera del dispositivo; requiere política pública. [App Privacy](https://developer.apple.com/app-store/app-privacy-details/).
6. Completar el cuestionario de edad para las funciones reales, sin fijar una edad antes de sus respuestas. Completar cifrado según el archivo; el proyecto usa protección del sistema, no un algoritmo propio. No añadir una exención automática sin confirmar sus condiciones. [Edad](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating), [cifrado](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance).
7. Capturar pantallas reales con contenido de ejemplo propio: lectura en vivo, A mi ritmo/corrección, favoritas, traducción/práctica y ajustes separados. Entregar juegos EN/ES para iPhone e iPad con tamaños aceptados actualmente. Los screenshots de tests en iPhone SE/iPad Air sirven para QA; no se anuncian como el juego comercial definitivo. [Especificaciones](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).
8. Evaluar VoiceOver, Voice Control, texto grande, contraste y orientación en cada plataforma antes de declarar etiquetas de accesibilidad. Tener botones etiquetados o pasar XCTest no prueba soporte integral. [Criterios de Apple](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/).
9. Seleccionar el build aprobado internamente, pegar metadata/notas y revisar todo con el titular. **Enviar a App Review y publicar requieren una instrucción explícita posterior.**

## Posicionamiento honesto

Herramienta de apoyo para comprender conversaciones, leer a su ritmo y practicar idiomas, incluida ayuda para personas con pérdida auditiva o baja visión y actividades infantiles supervisadas. No prometer precisión perfecta, diagnóstico, tratamiento, interpretación profesional ni compatibilidad absoluta. Audio de micrófono; no extracción del audio interno de YouTube. Traducción requiere iOS/iPadOS 18+, build compatible y modelos preparados; iOS 17 conserva las funciones compatibles. Reducción de ruido puede atenuar voces distantes.

## Estado histórico

El usuario confirmó uso de TestFlight y traducción del proyecto base en su iPhone; esa confirmación no corresponde a la nueva identidad VoiceToRead. Los fallos de exportación 9–12 y recuperación local están en el runbook; no deben presentarse como el estado actual sin consultar el SHA/build concreto. La nueva funcionalidad y esta documentación se validan por separado; estar en GitHub no demuestra instalación en el teléfono.

## Comprobación de los textos

Ejecuta `python3 scripts/validate-store-metadata.py` para verificar límites de campos EN/ES. `--ready` rechaza los datos pendientes antes de envío; actualmente debe rechazarlos. Pasarlo no sustituye verificar URLs públicas, binario, declaraciones ni aceptación física.

## Publicación de las páginas en Hostinger

1. Revisar el manejo/conservación de mensajes antes de usar el texto como política definitiva. No convertir una decisión pendiente en una promesa pública.
2. Identificar cómo está construido el sitio existente (WordPress, constructor u otro). Conocer Hostinger como proveedor no identifica el editor ni concede acceso al panel. No cambiar DNS ni reemplazar el sitio para añadir estas páginas.
3. Añadir páginas de privacidad y soporte de VoiceToRead usando los borradores EN/ES enlazados arriba. Mantener el correo `dariofernandomeneses@gmail.com` visible y utilizable. Las rutas propuestas pueden adaptarse al sitio real. Retirar las notas editoriales y todos los marcadores pendientes solo después de resolverlos.
4. Abrir ambas páginas sin iniciar sesión, desde móvil, y comprobar HTTPS, contenido completo EN/ES, enlaces y correo. La portada del dominio no sustituye la página de privacidad de esta app.
5. Solo entonces completar `privacyPolicyURL` y `supportURL` en la metadata y App Store Connect. `websiteURL` identifica la portada; `proposedPublicURLs` documenta las rutas previstas sin afirmar que existan.

Esta copia deja preparada la documentación para un futuro repositorio GitHub independiente. No modifica Hostinger, no publica la política y no envía correos al contacto facilitado.
