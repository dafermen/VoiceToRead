# Verificación de Inicio y Ajustes

Fecha: 2026-10-17. Entorno local: Xcode 15.2, simuladores iOS 17.2.

## Alcance

Nombres visibles en herramientas de Inicio, tarjetas uniformes en modo sencillo, retirada de accesos a Conversación/Escribir una respuesta en Ajustes y nuevo nombre/ubicación Escribir y hablar. La biblioteca Sessions no se reorganiza en este bloque.

## Resultados finales

- Pantalla completa con captura activa y rotación: aprobada en la ejecución final `/private/tmp/vtr-home-fullscreen-stable.xcresult`. Comprueba texto visible, controles, pausa y regreso a pestañas.

- iPhone 15: aprobados los recorridos de nombres/orientación/pantalla completa y modo sencillo con ambas preferencias. Resultado: `/private/tmp/vtr-home-iphone-final.xcresult` (las dos pruebas de Inicio aprobadas; la prueba antigua de lectura móvil se verifica por separado).
- Capturas inspeccionadas: [nombres en iPhone vertical](qa/home-controls/iphone-names-portrait.png), [horizontal](qa/home-controls/iphone-names-landscape.png), [Inicio sencillo](qa/home-controls/iphone-simple.png).

- iPad Air (5.ª generación): 2 pruebas aprobadas, nombres/orientación y modo sencillo con ambas preferencias. Resultado: `/private/tmp/vtr-home-ipad-final.xcresult`.
- Capturas inspeccionadas: [Inicio sencillo en iPad](qa/home-controls/ipad-simple.png), [nombres en iPad horizontal](qa/home-controls/ipad-names-landscape.png).

## Evidencia y límites

- Prueba de nombres: activa la preferencia desde Ajustes, comprueba cada etiqueta y acceso, gira a horizontal, abre Escribir y hablar y desactiva los nombres para recuperar iconos de 44 puntos.
- Prueba de modo sencillo: compara ancho/alto de las seis acciones con Mostrar nombres apagado y encendido; entra en Escuchar ahora y vuelve a Inicio.
- Escribir y hablar: el recorrido existente de escribir, reproducir, pausar, reanudar, detener y salir aprobó; volver abre el editor vacío. La demostración de preparación también aprobó.
- Auditoría automática de descripciones, rasgos accesibles y zonas de toque del inicio sencillo: aprobada. No sustituye pruebas con VoiceOver, Control por voz ni personas usuarias.
- Captura con el tamaño de texto de accesibilidad máximo: iniciar, pausar, encontrar Reanudar y detener aprobó.
- Release para simulador compiló antes del último ajuste de alineación visual. Persisten los dos avisos heredados de concurrencia en CaptionViewModel y SessionTranslationView; no se modificaron en este bloque.
- Localización: 736 claves y 2 permisos, idiomas y parámetros coincidentes; 478 claves extraídas cubiertas. Metadatos de tienda y las 10 páginas bilingües de soporte validados.

## Incidencias de la verificación

Las primeras pruebas tocaban el texto o el margen de las filas Toggle, sin cambiar su estado. SwiftUI expone toda la fila como un switch; la prueba ahora pulsa dentro del interruptor visible y comprueba su valor. Otra selección de prueba confundía el botón Volver a Inicio con la pestaña Inicio: ahora usa el identificador readerHomeButton.

Una ejecución simultánea de simuladores se interrumpió por lentitud y un error del servicio de simulación. Se repiten los recorridos de forma secuencial. No se presentan esos intentos como aprobados.

La comprobación antigua de texto nuevo en pantalla completa consultaba `isHittable` sobre un párrafo no interactivo mientras cambiaba su posición. XCTest rechazaba su punto de activación. Ahora comprueba la intersección del texto con el área visible del lector; mantiene las comprobaciones de pulsación de los botones y de captura activa al girar. La fixture de estrés emitía 320 párrafos iniciales y avanzaba entre consultar el contador y buscar su texto. El recorrido de rotación usa ahora la fixture existente de 8 párrafos (historia desplazable), espera su carga inicial y sigue recibiendo frases cada dos segundos. No cambia el código de seguimiento del lector.

## Distribución

La compilación local no equivale a disponibilidad en TestFlight. Consultar el estado del commit en GitHub/Xcode Cloud y comprobar la nueva versión en el dispositivo antes de cerrar aceptación.
