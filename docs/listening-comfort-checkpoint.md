# Checkpoint — comodidad de escucha (2026-10-16)

## Alcance

Implementadas las siete propuestas: tarjeta activa, pausa opcional entre idiomas, preferencias persistentes, velocidades independientes, notas/escucha de marcadores, búsqueda por párrafo bilingüe y preparación accesible antes del evento. Esquema V10 aditivo; no reemplazar la base del usuario.

## Verificación

- **119 pruebas unitarias aprobadas** en iPhone 15 / iOS 17.2: incluye migración V9→V10, reapertura y eliminación de notas, orden bilingüe, velocidades independientes, pausa/reanudar/cancelar durante la espera y preferencias según idioma de captura.
- **2 recorridos finales de interfaz aprobados en iPhone**: preferencias y búsqueda visible, notas de marcadores con reproducción directa y sincronización del marcador con Traducción. Bundle: `/private/tmp/vtr-comfort-final-phone.xcresult` (121 pruebas en total, sin fallos).
- **3 recorridos aprobados en iPad Air 5 / iOS 17.2**: texto de accesibilidad en horizontal, escucha de español a inglés y geometría bilingüe con navegación silenciosa. Bundle: `/private/tmp/vtr-comfort-ipad.xcresult`.
- La primera ejecución aprobó preparación sin iniciar captura, escucha inline inglés→español y geometría bilingüe. Detectó búsqueda oculta en Párrafos; se corrigió usando una barra de búsqueda siempre visible y se volvió a comprobar en el bundle final. `/private/tmp/vtr-comfort-verified.xcresult` conserva ese fallo inicial; no considerarlo un resultado completamente aprobado.
- **Release para dispositivo compiló sin firma**: `/private/tmp/vtr-comfort-release.log`. No equivale a validar exportación/firmado de App Store.
- Localización: 657 claves EN/ES, 2 permisos y 467 claves extraídas por el compilador cubiertas. Metadatos de tienda y `git diff --check` correctos. Paquete local de textos regenerado en `build/app-store/VoiceToRead-AppStore-1.0.zip`.
- Capturas sintéticas inspeccionadas: [búsqueda iPhone](qa/listening-comfort/iphone-search.png), [iPad bilingüe](qa/listening-comfort/ipad-bilingual-player.png), [iPad horizontal con texto grande](qa/listening-comfort/ipad-large-landscape.png). Con tamaño de accesibilidad extremo, los controles inferiores se alcanzan desplazando la pantalla.
- Xcode 15.2/SDK iOS 17.2 local: traducciones de interfaz probadas con fixtures; traducción real de Apple requiere un build moderno y dispositivo compatible. No se verificó VoiceOver completo en un dispositivo físico.

Para futuras ejecuciones usar target **VoiceToReadTests**, no `VoiceToReadUITests`. Se reinstaló solamente el ejecutor de pruebas de iPad para evitar el problema de caché ya observado; no se borró la aplicación del usuario ni su base de datos.

## Entrega

No enviado a revisión de App Store. Que el código compile localmente no confirma disponibilidad en TestFlight. Comprobar Xcode Cloud después del push y actualizar desde TestFlight cuando Apple termine de procesar.

## Aceptación física pendiente

- Ambos: escuchar original completo, pausa seleccionada y traducción completa; A mi ritmo debe detenerse antes del próximo párrafo.
- Pausar/detener y cambiar de pantalla durante el intervalo; no debe iniciar voz tardía. Probar llamada/alarma y desconectar auriculares durante la espera.
- Verificar las velocidades, reabrir reproductor y usar una sesión con idioma de captura opuesto.
- Con texto largo, deslizar manualmente y volver con Seguir audio. Probar VoiceOver, texto de accesibilidad y horizontal en iPhone/iPad.
- Añadir nota, reabrir la app, comprobarla, quitar marcador y verificar conservación de la transcripción.
- Buscar palabras que solo estén en la traducción; escuchar resultado y probar Sin resultados.
- Comprobar voces/modelos con internet y luego con modo avión real, sin asumir que voz disponible equivale a descarga completa.
