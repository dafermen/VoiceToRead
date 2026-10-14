# VoiceToRead 1.0 — paquete para App Store

Preparado el 2026-10-14. **No enviado a App Review.** App Store Connect: [VoiceToRead](https://appstoreconnect.apple.com/apps/6822564230/distribution/info). Este paquete prepara los archivos y las respuestas verificadas; no modifica por sí mismo la cuenta de Apple.

## Decisiones confirmadas

| Campo | Valor |
|---|---|
| Nombre | VoiceToRead |
| Responsable | Dario Fernando Meneses Ceron, persona natural |
| Bundle ID | com.innovalogic.voicetoread |
| Apple ID / SKU | 6822564230 / voicetoread-ios-001 |
| Versión pública | 1.0 |
| Precio | Gratis, sin compras dentro de la app |
| Países iniciales | Estados Unidos y Colombia |
| Idioma principal | English (U.S.) |
| Idioma adicional preparado | Español (es-ES) |
| Soporte/privacidad | dariofernandomeneses@gmail.com |
| Copyright propuesto | 2026 Dario Fernando Meneses Ceron |
| Categoría propuesta | Education; confirmar antes de guardar |

Precio y países fueron elegidos por el titular el 2026-10-14. No se debe activar automáticamente disponibilidad en todos los países ni en futuros territorios. El copyright y la categoría se presentan para revisión del titular.

El comando `python3 scripts/prepare-store-copy.py` genera campos en texto plano EN/ES y `build/app-store/VoiceToRead-AppStore-1.0.zip` con la documentación y capturas disponibles. El ZIP es una entrega para revisar; **no se sube como binario a Apple**.

## Campos para copiar

La fuente completa de descripciones y palabras clave es [app-store-metadata.json](../app-store-metadata.json), sección `localizations`. El validador comprueba límites de caracteres. No copiar `ownerPending`, notas internas ni marcadores PENDING en la ficha pública.

| Campo | English (U.S.) | Español |
|---|---|---|
| Subtitle | Live Captions & Translation | Subtítulos y traducción |
| Privacy Policy URL | https://voicetoread.innovalogic.tech/en/privacy/ | https://voicetoread.innovalogic.tech/privacy/ |
| Support URL | https://voicetoread.innovalogic.tech/en/support/ | https://voicetoread.innovalogic.tech/support/ |
| Marketing URL (opcional) | https://voicetoread.innovalogic.tech/en/ | https://voicetoread.innovalogic.tech/ |

Las cuatro URLs de privacidad/soporte respondieron HTTPS 200 con el contacto del titular el 2026-10-14. La app incluye enlaces que siguen el idioma de los menús y conserva una explicación local para consultar sin Internet.

## Orden de entrega

1. **Xcode Cloud → Default → Archive – iOS:** cambiar Distribution Preparation de **TestFlight (Internal Testing Only)** a **TestFlight and App Store** y guardar. Puede mantenerse la postacción TestFlight Internal Testing para Dev. El cambio no convierte un archivo interno anterior en uno público.
2. Tras subir este código, ejecutar un build de `main` que incluya MARKETING_VERSION **1.0**. Comprobar en el archivo y en TestFlight su versión y número efectivos: CURRENT_PROJECT_VERSION=1 en Git no implica que Cloud suba el número 1. Elegir un número admitido y no reutilizado para la versión.
3. Esperar exportación, carga y procesamiento completos. Instalar **ese mismo build** desde TestFlight y terminar la aceptación física. Una compilación verde por sí sola no demuestra distribución.
4. **Distribution → versión 1.0:** pegar textos EN/ES, cargar capturas revisadas y seleccionar el build apto para App Store. La app no exige cuenta, por lo que no hay credenciales de demostración que proporcionar.
5. **App Information / Pricing and Availability:** confirmar categoría/copyright; aplicar gratis, Estados Unidos y Colombia. Completar edad y derechos de contenido según las funciones reales. No seleccionar Kids Category automáticamente por permitir práctica con acompañamiento adulto.
6. **App Privacy:** revisar las declaraciones contra el binario final y los servicios descritos en la política. El contenido de sesiones es local; no hay analítica del desarrollador. La propuesta documental de Data Not Collected requiere revisión final, no se presenta automáticamente. Contestar export compliance según la criptografía efectiva del archivo.
7. **App Review:** completar en privado nombre, teléfono y correo de contacto. Usar [notas de revisión](review-notes.md), añadir modelos/OS realmente probados y el build seleccionado. No publicar el teléfono en GitHub.
8. Revisar la ficha y resolver todos los pendientes del [checklist](../release-checklist.md). Solo con la instrucción del titular, **Add for Review → Submit for Review**. Seleccionar el modo de lanzamiento que el titular prefiera; preparar archivos no autoriza publicación automática.

## Pruebas que aún deben realizarse con el build final

- iPhone e iPad: capturar inglés/español; comprobar permisos, preparación de modelos, texto, audio y guardado.
- iOS/iPadOS 18+ compatible: traducción real Original/Traducción/Ambos. El Xcode 15.2 local no valida esta implementación moderna.
- Interrupción por alarma/llamada → pausa visible → Reanudar; segundo plano activado/desactivado.
- Reproducir por frases, editar antes de compartir, exportar audio/texto/subtítulos y proteger favoritas.
- VoiceOver, texto grande, orientación y contraste antes de declarar características de accesibilidad.
- Confirmar precio/países, enlaces, capturas y versión/build seleccionados en Apple.

El titular ya confirmó instalación y funcionamiento básico de VoiceToRead en iPhone por TestFlight. No se convierte esa observación en una aceptación completa de todos los puntos anteriores.

## Capturas

El procedimiento reproducible está en [screenshots/README.md](screenshots/README.md). Los candidatos muestran la interfaz real de biblioteca, lectura y revisión con texto ficticio propio, sin conversaciones privadas. Revisar su apariencia contra el build final. No se usan traducciones sintéticas para anunciar traducción real.

Referencias oficiales: [enviar a revisión](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app/), [builds internos](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers), [tamaños de capturas](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [metadatos y capturas reales](https://developer.apple.com/app-store/review/guidelines/#metadata).
