# Lectores y filtros: siete ajustes — 2026-11-07

**Corrección posterior:** la ubicación superpuesta se sustituyó por el acceso junto a las pestañas y una fila de salida en pantalla completa. Podcasts también iguala las fuentes y Lecciones guiadas incorpora ampliación. Ver [corrección vigente y validación](fullscreen-layout-corrections.md).

## Cambios visibles

1. **Podcasts, expandir/contraer:** botón circular flotante de 48 puntos, abajo a la derecha, tanto en la vista normal como en pantalla completa. En vista normal queda en el área de lectura, encima del transporte; en pantalla completa solo queda Contraer. Se respetan las áreas seguras.
2. **Podcasts, fragmentos:** cada botón de reproducir usa `AppControlSymbol`, igual que los demás lectores. La acción sigue siendo reproducir ese fragmento; no se convierte en otra acción.
3. **Podcasts, lectura completa:** frases separadas con espacio vertical dentro de la tarjeta del fragmento. Se respetan puntos, preguntas, exclamaciones y saltos de párrafo mediante rangos de Foundation; una pausa breve no crea por sí sola un párrafo ni se insertan silencios en el audio.
4. **Podcasts, traducción:** tarjetas con el color configurado por idioma (por defecto inglés azul y español verde). En pantalla completa, original izquierda y traducción derecha desde 700 puntos de ancho, con disposición apilada en pantallas estrechas o tamaños de accesibilidad. En la transcripción normal se usa una disposición adaptable al espacio disponible. Un fragmento sigue emparejado con su traducción completa: no se presume que ambos idiomas tengan el mismo número de oraciones.
5. **Verbos y frases:** selector **Todos / Pendientes / Realizados**, independiente del botón Favoritos. Permite favoritos pendientes y conserva búsquedas, grupo y tiempo. El selector ocupa su propia fila para evitar truncamientos. Las estrellas y checks existentes se conservan; cambiar el filtro no escribe marcas.
6. **Cuentos:** pantalla completa en el lector, con el mismo botón flotante. Oculta cabecera, opciones y transporte para ampliar la lectura; al contraer recupera los controles y el texto. Se conservan mensajes de error. No se puede expandir durante una traducción en curso, para mantener a la vista su cancelación.
7. **Mis prácticas:** pantalla completa en la vista donde se practica una frase, con el mismo botón flotante. Oculta navegación y pestañas; conserva respuesta visible/oculta, ejemplo lento, grabación, intento, resultados y Anterior/Siguiente. No crea una práctica ni una ronda nueva.

Los lectores dejan un margen desplazable para que el botón no cubra el final del contenido. En Cuentos se conserva la misma instancia de `StoryReadingText`; Mis prácticas conserva el mismo ScrollView, modelo, índice y ronda. La lectura de Podcasts mantiene el reproductor fuera de las ramas normal/completa, conservando el audio, velocidad y posición.

## Resaltado y seguimiento de Podcasts

`PodcastReadingParagraphs` devuelve rangos UTF-16 del texto original. No cambia los archivos del episodio, el audio, las traducciones ni los manifiestos de tiempos. El lector aplica el rango de la palabra sobre la oración que la contiene, desplazando solo sus coordenadas para presentarla.

El resaltado sigue las palabras del audio. Con Seguir narración activo, la vista desplaza la oración en curso al entrar en ella; los espacios entre cues no vuelven a desplazar repetidamente la misma oración. La rotación vuelve a ubicar la oración. Con seguimiento desactivado no se fuerza ese desplazamiento. Se puede desplazar manualmente una oración larga.

## Límites del alcance

No se modificaron servicios de captura, reconocimiento, traducción o reproducción, ni repositorios, esquemas guardados o recursos de contenido. El filtro es una consulta de presentación sobre las mismas marcas. Se mantienen las confirmaciones de guardar, descartar, sustituir traducciones y borrar, junto con las aprobaciones de Cuentos. Entrar/salir de pantalla completa no llama a reproducir, detener, cerrar ni restablecer un intento.

## Comprobaciones ejecutadas en Windows

- Referencias y sintaxis del proyecto Xcode: parser OpenStep, tres targets y esquema con tests unitarios/UI válidos.
- Podcasts: 30 fragmentos bilingües, audios, manifiestos, duraciones y rangos por palabra válidos.
- Verbos: 130 entradas completas, cobertura de los 125 verbos únicos de Excel, seis idiomas y AFI por forma.
- Localización: 1118 claves de interfaz y dos de InfoPlist, sin diferencias de claves ni placeholders entre idiomas.
- Auditoría del diff: servicios y contenido sin cambios; llamadas existentes de audio/almacenamiento, confirmaciones, sheets, cierre y atajos conservados; delimitadores Swift y `git diff --check` correctos.

Estas comprobaciones no ejecutan iOS ni prueban visualmente la app. No hay Xcode, Swift ni simulador en el equipo Windows.

## Pruebas preparadas para Mac/iPhone

Se añadieron tests unitarios de pendientes combinados con favoritos, separación por frases/saltos y offsets Unicode, además de cobertura de todos los cues del podcast sobre los rangos de lectura.

Se ampliaron regresiones UI para verificar el botón circular por fragmento, tarjetas bilingües adaptables, salida abajo a la derecha, posición/velocidad de audio al expandir/contraer, conservación del texto de Cuentos, respuesta/frase actual de Mis prácticas y marcas pendientes/realizadas.

**Pendiente de ejecutar:** compilación, XCTest y revisión real en iPhone/iPad, vertical/horizontal, claro/oscuro, VoiceOver, alto contraste, texto grande y seguimiento durante audio. Usar `bash scripts/validate-macos.sh`; la compilación Archive de Xcode Cloud no sustituye las suites de tests.

En dispositivo, revisar también entrar/salir mientras suena el original o una traducción aprobada, y mientras se escucha un ejemplo o intento en Mis prácticas; comprobar que se conserva la reproducción y que las confirmaciones siguen disponibles al volver a la vista normal.
