# Corrección de tipografía y accesos de pantalla completa

Fecha: 2026-11-07. Sustituye la ubicación superpuesta de los lectores de la entrega anterior. No cambia motores de audio, traducción, reconocimiento, contenidos ni datos guardados.

## Seis observaciones corregidas

1. **Podcasts en pantalla completa:** original y traducción usan el mismo tamaño, peso, escala de accesibilidad e interlineado. Se conserva el tamaño elegido en Opciones de lectura y el resaltado por palabra. La traducción ya no se reduce al 65 %.
2. **Podcasts, expandir/contraer:** el acceso normal se publica al mismo componente de la raíz que usa Escuchar, al lado de Inicio/Ajustes. Se retiró el overlay del área de lectura. En pantalla completa, Contraer ocupa su propia fila inferior.
3. **Idioma de Podcasts:** la biblioteca y el lector componen un `Text` localizado para el idioma con otro texto para nivel/duración. No interpolan `LocalizedStringKey` en un `String` literal; así desaparece la descripción técnica visible en las capturas.
4. **Cuentos:** usa el mismo acceso inferior normal y la fila independiente para Contraer. Se conserva el bloqueo de expandir durante una traducción para mantener su cancelación visible. Contraer siempre está disponible.
5. **Mis prácticas:** usa la misma ubicación y fila de salida. Se conserva la misma frase, respuesta visible/oculta, ronda, grabación/ejemplo y resultados; no se abre un segundo lector.
6. **Lecciones guiadas:** incorpora pantalla completa. La misma lista conserva sus IDs, posición y controles; se ocultan navegación y pestañas. Si la narración está activa, Pausar/Reanudar y Detener permanecen encima de la fila de Contraer.

## Tamaño menor de Podcasts — ajuste posterior

Opciones de lectura > Tamaño del texto en pantalla completa permite ahora **16–72 puntos**, con pasos de dos puntos (antes 28–72, con pasos de cuatro). El original y la traducción siguen compartiendo el mismo tamaño y la misma escala de accesibilidad.

Se conserva la clave `podcastKaraokeTextSize`, el valor elegido anteriormente y el predeterminado de 40 puntos. El usuario puede bajar el deslizador hasta el nuevo mínimo. No cambia el tamaño global de Ajustes, la vista normal de Podcasts ni los demás módulos. El límite aplicado al lector también admite 16 puntos; cambiar solo el deslizador habría dejado el mínimo visual en 28.

Verificaciones de este ajuste: revisión de las dos líneas del rango, auditoría de llamadas/estado, parser del proyecto y `git diff --check`. Compilación y comprobación visual en iPhone pendientes de Xcode/TestFlight.

## Distribución compartida

`ReaderFullScreenPresentation` reutiliza `HomeFullScreenSource` para que todos los accesos normales se dibujen en el mismo lugar que Escuchar. La raíz respeta el estado habilitado del lector. Los accesos antiguos de Conversar/Escuchar conservan su comportamiento predeterminado.

En pantalla completa, un `VStack` estable mantiene el contenido en su primer espacio y coloca una fila de salida debajo: icono de 48 puntos y margen vertical de ocho puntos, para un total de 64 puntos. La fila es hermana del contenido; no usa overlay y no forma parte del ScrollView. Así el lector recibe menos altura real y no puede quedar visualmente detrás del botón. Respeta cámara y zona de inicio. El transporte de las lecciones queda dentro del área de contenido, encima de la salida.

Se retiraron los márgenes artificiales de 64 puntos que antes compensaban los overlays en Podcasts, Cuentos y Mis prácticas. Se mantiene el margen normal de lectura. No se introducen nuevas hojas, rutas o reconstrucciones condicionales del lector, ni llamadas de reproducir/detener al cambiar de modo.

## Validación local

- Parser del proyecto Xcode: referencias, targets y esquema válidos.
- Localización: 1118 claves y dos entradas InfoPlist, con paridad de idiomas/placeholders.
- Podcasts: 30 fragmentos, audio, duraciones, manifiestos y rangos de palabras válidos.
- Lecciones: validación del catálogo, audio y traducciones de apoyo ejecutada con el validador existente.
- Auditoría del diff: servicios y recursos de contenido sin modificaciones; llamadas existentes de audio/almacenamiento, confirmaciones, sheets, cierre y atajos conservados. Delimitadores Swift y `git diff --check` correctos.

Son verificaciones de fuente/recursos, no ejecución de iOS. En Windows no hay `xcodebuild`, Swift ni simulador iOS; compilación nativa, XCTest y revisión en dispositivo siguen pendientes.

## Regresiones preparadas para Mac

Se ampliaron los escenarios UI existentes de Podcasts, Cuentos, Mis prácticas y Lecciones guiadas:

- Acceso normal de 48 puntos abajo a la derecha, sin intersección con controles visibles.
- Contraer en una fila cuya posición queda por debajo del viewport del lector, en vertical y horizontal.
- Metadatos del podcast legibles, sin `LocalizedStringKey`, y captura bilingüe para revisar fuentes iguales.
- Narración guiada pausada antes de ampliar; misma pausa, párrafo y posición al contraer; transporte encima de la salida.
- Texto de Cuentos y frase/respuesta de Mis prácticas conservados al cambiar de modo.

Ejecutar `bash scripts/validate-macos.sh`. Comprobar además en iPhone/iPad el tamaño de fuente, los controles al lado de las pestañas, rotación, VoiceOver, tamaños de accesibilidad, alto contraste y claro/oscuro. Una compilación Archive en Xcode Cloud no demuestra por sí sola que las suites de tests o la revisión visual hayan pasado.
