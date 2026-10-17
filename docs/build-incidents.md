> Historial técnico heredado del proyecto base. Los nombres y rutas se adaptaron a VoiceToRead; los builds, hashes y resultados antiguos no validan esta nueva app ni indican disponibilidad en TestFlight. Evidencia actual: [inicio del proyecto](project-identity.md).

# Incidentes de desarrollo y distribución

## 2026-10-12 — build 22: conexión de XCTest al simulador

El primer intento compiló, pero el daemon de XCTest agotó 120 segundos al iniciar la sesión de control antes de ejecutar pruebas. Se canceló únicamente ese xcodebuild; no se registra como suite aprobada. Al intentar apagar el simulador ya estaba Shutdown por la limpieza de XCTest. Se volvió a arrancar y `simctl bootstatus -b` confirmó Finished antes de repetir. No se borraron los datos del simulador ni del iPhone, ni se reinició powerd. Los resultados de la repetición se registran en [checkpoint de ruido](noise-checkpoint.md).

La repetición terminó TEST SUCCEEDED: 95 unitarias y UI iPhone (33,287 s). El mismo recorrido UI iPad terminó TEST EXECUTE SUCCEEDED (51,624 s). Release y Archive Cloud pasaron. Para el SHA `32e549b`, el check inicial `114875255384` fue sustituido por el resultado final `114877221766` (2026-10-12 15:13:38 UTC, success, cero errores/cuatro advertencias existentes). No esperar indefinidamente al ID inicial; consultar todos los checks del SHA.

Al introducir Voice Processing, habilitarlo antes de consultar el formato del input y antes del tap; mantener la elección al reanudar. El control de ganancia y el ducking no son niveles de reducción de ruido. Comprobar calidad y rutas en dispositivo; la prueba UI usa un doble sin DSP y no demuestra mejora acústica.

## Build 21 — resultado Cloud publicado con otro identificador

El check inicial `114613990875` continuó mostrando in_progress. Al consultar de nuevo los check-runs del commit `59f4eae`, Apple devolvió `114617065401`, completado satisfactoriamente el 2026-10-12 a las 00:39:42 UTC. Archive duró aproximadamente 16 minutos, sin errores; conservó cuatro advertencias existentes (allowBluetooth, AVAudioPCMBuffer, AVAssetExportSession y AVFAudio). No diagnosticar un bloqueo basándose solo en el ID inicial ni repetir builds mientras todavía pueden estar ejecutándose. Consultar `gh api repos/dafermen/VoiceToRead/commits/<SHA>/check-runs` y distinguir el resultado de Archive de procesamiento y disponibilidad en TestFlight.

## 2026-10-11 — Renglones y pruebas al activar audio inicialmente (build 21)

La primera prueba geométrica mostró que `lineFragmentUsedRect` y `boundingRect(forGlyphRange:)` incluyen espacio de layout: dibujar después de su maxY invadía la línea siguiente. Se usa ahora la línea base real de TextKit y el descenso de UIFont, con separación mínima entre renglones. La prueba contrasta reglas con límites de tinta independientes de CoreText e incluye vueltas a vertical, fuentes grandes e interlineados. Pasó en la suite final; revisar también capturas y aceptación física.

Activar Save audio por defecto en instalaciones nuevas expuso dos pruebas con `CaptionMicrophone`, un doble que no implementa grabación real. El modelo devolvía correctamente RecordingFailure.unavailable; por ello no empezaba y fallaban las aserciones posteriores de pausa/idioma. Esos escenarios configuran explícitamente audio desactivado. Las pruebas de AppSettings siguen exigiendo audio inicialmente activado y preservación de valores anteriores. No modificar el comportamiento de producción para satisfacer un doble incompleto.

Los resultados fallidos recopilaron diagnósticos del simulador durante varios minutos después de terminar las aserciones. La ejecución acabó por sí misma; un intento de SIGINT llegó después y no detuvo ningún proceso. Las repeticiones utilizan `-collect-test-diagnostics never`, conservando logs y xcresult. No reiniciar powerd ni cambiar firma por esta espera. La ejecución final `VoiceToRead-21-Verified.xcresult` cerró normalmente: 92 pruebas, cero fallos.

La primera tanda UI encontró dos selectores incorrectos: SwiftUI propagó el identificador de la tarjeta al botón de permiso y las hojas superpuestas mostraron dos botones Done después de traducir Listo al inglés. Se comprobaron los botones por su etiqueta de acción y se limitó Done a la barra Pronunciation. El nuevo recorrido de preparación y el de práctica pasaron. La revisión visual detectó además un aviso de micrófono truncado en iPhone pequeño; se fijó su altura de texto y se añadió una aserción de ajuste de líneas. El recorrido final de preparación pasó después de ese cambio.

En iPad, XCTest esperó varias veces 60 segundos la notificación de fin de animaciones al abrir selectores. Continuó y los tres recorridos terminaron aprobados. Conservar ese dato como latencia del recorrido automatizado, sin diagnosticar un bloqueo del dispositivo físico ni reiniciar servicios del Mac.

Antes de UI se retiró exclusivamente el runner de pruebas del simulador iPhone para evitar el ejecutable antiguo documentado en build 20. No se eliminaron la app ni sesiones del teléfono físico.


## 2026-10-11 — renglones y compilador gráfico del simulador

La prueba con el runner correcto llegó a activar renglones y bloqueó la interfaz. La muestra de `VoiceToRead` (`voicetoread20-app.sample`) situó el hilo principal en RenderBox → Metal → `XPCCompilerConnection::setupConnection`, esperando al servicio del compilador gráfico. No era evidencia de un bucle infinito de nuestros párrafos ni de un problema del reconocimiento.

Se sustituyó Canvas por una pequeña `UIViewRepresentable` que dibuja guías con CoreGraphics, sin introducir una canalización de shaders para líneas horizontales. Se calculan preferencias antes de dibujar, se limitan a 1000 guías y se rechazan dimensiones no finitas. La capa se redibuja al cambiar tamaño, ignora gestos y no añade elementos de accesibilidad. El recorrido final de iPhone activó el interruptor, giró a horizontal y reanudó sin bloqueo: aprobado en 86,863 s (`VoiceToRead-20-confirmed.log`). La muestra del bloqueo original no demuestra un fallo en dispositivos físicos.


## 2026-10-11 — XCTest ejecutaba un runner antiguo

Al repetir UI con `CODE_SIGNING_ALLOWED=NO` y el mismo DerivedData, los errores señalaban líneas que ya no contenían esas aserciones. Se comprobó que el runner instalado en iPad conservaba UUID x86_64 `108B9B7C-CEE9-3F45-BFAE-CC266509A385`, mientras el compilado era `62F25D16-F3A6-3227-93CF-257E6A3AAC42`. Ambos eran binarios universales, así que no era simple reducción de arquitectura. No interpretar esos resultados como validación del código nuevo.

Se detuvo solamente nuestra ejecución de pruebas y se retiró `com.innovalogic.voicetoread.uitests.xctrunner` de los simuladores antes de repetir. No se borró la app del iPhone ni se reiniciaron servicios de energía del Mac. Al iniciar iPad hubo un error transitorio de launchd_sim; `simctl bootstatus -b` completó después el arranque. Registrar el resultado del nuevo xcresult por separado. Las siguientes ejecuciones usaron firma ad hoc de simulador (`CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`), sin credenciales de distribución.

Para investigar: comparar `dwarfdump --uuid` del ejecutable de tests compilado y del instalado (localizarlo con `xcrun simctl get_app_container <simulator-id> com.innovalogic.voicetoread.uitests.xctrunner app`). Detener la prueba antes de retirar únicamente su runner. En ejecuciones con varios destinos, stdout puede estar en `xcresult/Staging/.../StandardOutputAndStandardError.txt`, no en el log exterior mientras se ejecuta. Esperar la finalización del xcresult para emitir un resultado definitivo.

La prueba también necesitaba desplazamientos cortos para no saltarse filas de Settings y tocar el interruptor visible de renglones, no el centro de toda su fila. El idioma pasó a la primera sección de Settings como mejora real de acceso.


## 2026-10-11 — infraestructura local de pruebas

Un DerivedData nuevo quedó esperando `actool` mientras el Release final compiló correctamente. Se canceló solo esa ejecución y se reutilizó la caché de iconos sin cambios, recompilando Swift. El siguiente recorrido UI pasó para renglones/pausa y práctica española, pero una navegación a Sessions falló y el runner unitario no inició. La cancelación con SIGINT produjo un fallo interno de Xcode al finalizar logs: el stdout conserva los resultados individuales, pero no hay un xcresult final válido para esa ejecución. No confundir pruebas individuales aprobadas con suite completa aprobada. La suite unitaria anterior sí tiene 88 aprobaciones y bundle terminado. El rerun aislado de edición/audio llegó a confirmar compartir SRT, pero las consultas de accesibilidad de la hoja nativa quedaron esperando con reintentos de 30 s. Se canceló y se conserva como verificación incompleta, sin atribuirle una causa no demostrada.

## 2026-10-11 — pausa poco visible y nueva distribución universal

El usuario informó que una alarma pausó la captura sin que lo notara. Build 20 añade un aviso persistente de micrófono apagado y Reanudar destacado, también en fullscreen. No reactiva el micrófono automáticamente. La prueba con interrupción simulada se registra separada de una alarma real en dispositivo.

Para esta compilación verificar UIDeviceFamily `[1,2]`, las cuatro orientaciones iPad y un número de build superior al último entregado. El cambio de preferencias no debe reinterpretar sesiones antiguas: `ConferenceSession.language` ya existe y snapshots sin sourceLocale son inglés. La fuente pasa a build 20; Cloud puede usar su propio número. Inspeccionar el archivo exportado antes de subir.

Persisten las advertencias de herramienta: Xcode 15.2 local no compila las ramas modernas SpeechAnalyzer/Translation; una prueba local verde no certifica esos caminos. Los incidentes de firma/HTTP 502 descritos abajo no se declaran resueltos por este cambio de UX. Validar por separado archive, export, upload, procesamiento y asignación al grupo Dev.


Registro actualizado el 10 de octubre de 2026. Las horas del relato usan America/New_York; los logs pueden incluir UTC o la hora del worker. “Resuelto” solo se aplica al paso para el que existe evidencia.

## 1. Ruta y nombre del proyecto

Durante el desarrollo de la base hubo cambios de nombre y rutas; algunas herramientas conservaron un cwd anterior inexistente. Para esta copia la ruta vigente es `/Users/dariomeneses/Projects/VoiceToRead` y el proyecto es `VoiceToRead.xcodeproj`.

Confirmar pwd y git status antes de editar. Si un entorno restringe escrituras a otra carpeta, usar sus permisos normales o actualizar el workspace; no borrar ni clonar de nuevo para resolver el fallo. El remoto actual es `https://github.com/dafermen/VoiceToRead.git`, rama `main`. Esta nueva identidad usa `com.innovalogic.voicetoread` y almacenamiento propio; no conserva la continuidad de la instalación anterior.

## 2. Mac antiguo y dispositivo más nuevo

El Mac de desarrollo usa Ventura y Xcode 15.2. El objetivo original iOS 26 no compilaba allí. Se implementó compatibilidad iOS 17, selección de motor por compilador/OS y validación local con simulador iOS 17.2.

Los primeros intentos de instalación USB en un iPhone con iOS 27 mostraron Waiting to reconnect, dispositivo bloqueado y luego Could not support development al montar la imagen de desarrollo. Un error de dispositivo bloqueado no demuestra por sí solo incompatibilidad de Xcode; la segunda comprobación aportó un error diferente.

Camino útil: pruebas locales compatibles más compilación moderna en Cloud y distribución por TestFlight. El usuario confirmó funcionamiento básico de builds 5 y 6. Eso no certifica todas las funciones posteriores ni hace compatible el depurador antiguo con cualquier iPhone.

## 3. Acuerdos de Apple, GitHub y nombre ocupado

Durante la configuración aparecieron obstáculos distintos:

| Síntoma | Qué significaba / lección |
| --- | --- |
| Apple Developer Program License Agreement needs to be reviewed | Revisar el acuerdo con el titular de la cuenta; es una acción en Apple Developer |
| You must have Admin permission to the repository | El alta de Xcode Cloud necesita acceso adecuado al repositorio |
| La cuenta GitHub sigue visible después de borrarla en Xcode Accounts | La cuenta local y el acceso remoto de Cloud al repositorio son configuraciones distintas |
| Name VoiceToRead is already being used | El nombre de App Store Connect estaba ocupado; se adoptó VoiceToRead |
| Workflow has no actions / Required to Pass | Añadir una acción; para esta distribución se usó Archive – iOS |
| Archive con Deployment Preparation=None | No prepara una entrega TestFlight; escoger la opción correspondiente al alcance |
| Missing Compliance | Completar la información de exportación solicitada por Apple |
| No Builds Available / Invited | Distinguir asignación de build, invitación, aceptación e instalación |

El historial demuestra que finalmente hubo un producto Cloud y TestFlight funcional, pero no conserva todos los clics exactos que corrigieron los permisos. No atribuir la solución a borrar credenciales si no existe evidencia.

## 4. Micrófono interrumpido al reproducir video

El usuario intentó reproducir YouTube en el mismo iPhone y recibió un mensaje de interrupción del micrófono. La app ahora configura mezcla de audio y ofrece continuidad en segundo plano por sesión. Eso no autoriza ni implementa captura interna de otras aplicaciones.

La fuente debe sonar por el altavoz y alcanzar el micrófono. Llamadas, rutas y decisiones de otras apps pueden interrumpirlo. La compatibilidad real debe probarse para cada escenario; no prometer que funciona con cualquier video o reunión.

## 5. Espera de Xcode y powerd

En una validación anterior, Xcode quedó esperando al servicio de energía. El comando de reinicio mediante launchctl devolvió Operation not permitted incluso con sudo. El usuario informó que killall powerd terminó sin error, pero el historial no demuestra que eso haya sido la causa de la recuperación.

No incorporar esos comandos en scripts del proyecto ni presentarlos como remedio de firma o del HTTP 502. Antes de intervenir servicios del sistema, investigar el proceso bloqueado y conservar diagnósticos. No desactivar protecciones de macOS.

## 6. Regresiones detectadas en pruebas de interfaz

La validación de audio/subtítulos detectó seguimiento inestable al añadir párrafos a una lista lazy. Se corrigió el scroll coalesciendo actualizaciones y repitiéndolo después del layout, respetando la relectura.

También se ajustaron una espera de carga de fixture largo, la identificación de un botón de edición duplicado y el cierre de la hoja nativa de compartir en las pruebas. Los 12 escenarios pasaron entre la ejecución final completa y la repetición enfocada. No describirlo como una única ejecución completa de 12/12 después de todos los ajustes.

## 7. Builds 9, 10 y 11: Archive correcto, exportación fallida

| Ejecución | Herramientas observadas | Resultado |
| --- | --- | --- |
| Build 9 | Xcode 27.0 (27A266a) | ARCHIVE SUCCEEDED; exportaciones App Store, Ad Hoc y Development fallan |
| Build 10 | Xcode 27.0 (27A266a) | Mismo HTTP 502 en consulta del equipo |
| Build 11 | Xcode 26.6 (17F113), macOS Tahoe 26.5.1 seleccionado | ARCHIVE SUCCEEDED; mismo HTTP 502 |
| Exportación desde Mac, 10/oct, ~00:06 | Xcode 15.2 sobre el archivo Cloud 11 | EXPORT SUCCEEDED |
| Subida desde Mac, 10/oct, ~00:07 | Mismo archivo, destination=upload | Upload succeeded; Apple inicia procesamiento |

Los logs de exportación mostraron esta secuencia:

~~~text
Session Proxy Provider: Unable to authenticate with App Store Connect
HTTP 502 ... /services/QH65B2/listTeams.action
error: exportArchive Communication with Apple failed
error: exportArchive No profiles for 'com.innovalogic.voicetoread' were found
** EXPORT FAILED **
~~~

El endpoint localhost:6667 es el proxy del worker de Cloud. No es el servidor del Mac del desarrollador. La consulta de equipo ya había fallado cuando apareció el mensaje sobre perfiles.

### Qué se intentó y qué demuestra

- Repetir la compilación mantuvo el error.
- Cambiar de Xcode 27 a 26.6 mantuvo el error. No fue una reparación.
- Revisar el comando visible y exit-code 70 no bastó; la causa observable estaba en el ZIP Logs.
- Exportar el mismo archivo desde el Mac sí funcionó, con firma Cloud Managed Apple Distribution.
- Subir desde el Mac también funcionó. No se reescribió el código ni se alteró el SDK del binario.
- No se revocaron certificados ni se cambió el bundle ID como remedio.
- Se preparó un informe para Apple; el usuario indicó que todavía no lo había enviado.

### Conclusión acotada

Se aisló el fallo de comunicación/autenticación del entorno Cloud y se comprobó una alternativa desde el Mac. No se determinó si la causa interna de Apple era una incidencia de servicio, autorización de sesión u otro problema. No se reparó ni se confirmó recuperada la exportación automática de Cloud.

El IPA exportado conservó SDK iphoneos26.5 y DTXcodeBuild 17F113. Xcode 15.2 se usó para exportar/subir un binario moderno, no para recompilarlo con su SDK antiguo.

El número “Build 11” identifica una ejecución Cloud. El archivo fuente tenía CFBundleVersion=1; la opción de gestión automática de versión/build se habilitó para subir. Las capturas del 10 de octubre a las 04:37 confirman el número final 0.1.0 (1), procesamiento Complete, grupo Dev y estado Ready to Submit. La gestión automática conservó el 1. No etiquetar la entrega como “TestFlight build 11” sin comprobarlo allí.

### Evidencia y conservación

Se leyeron los ZIPs originales de Logs de builds 9, 10 y 11 y el archivo de Build 11. El log local de subida terminó en Uploaded package is processing, Upload succeeded y EXPORT SUCCEEDED.

Las evidencias locales se generaron bajo /private/tmp/VoiceToRead-Build11-LocalExport y otros directorios temporales de diagnóstico. Pueden desaparecer y no están en Git. Para nuevos intentos usar un directorio privado persistente y la [guía de distribución](distribution-runbook.md).

## 8. Advertencias Swift pendientes

Build 11 mostró:

- AudioConversion: importación de AVFAudio y captura de AVAudioPCMBuffer no Sendable en un closure @Sendable.
- RecordingExport, en SessionMediaView: captura de AVAssetExportSession no Sendable en el handler de cancelación; sería error en Swift 6 language mode.
- En builds anteriores se observó advertencia sobre la captura weak de self en AudioCaptureService.

No fueron el error de exportación: Archive terminó correctamente. Son deuda técnica que debe analizarse antes de migrar el modo de lenguaje. Revisar aislamiento, propiedad y cancelación; no aplicar atributos para silenciarlas sin pruebas con el SDK moderno. Esta actualización documental no las corrige.

## 9. Qué hacer si vuelve a ocurrir

1. Identificar si falla compilación, firma, subida, procesamiento o acceso del tester.
2. Guardar el error completo del ZIP Logs, con fecha/build/commit/herramientas.
3. Si se repite listTeams 502 con Archive correcto, utilizar la alternativa de exportación local comprobada, verificando que siga siendo compatible.
4. Si el Mac también falla, diagnosticar su nuevo error; no suponer que sea el mismo.
5. Si Apple rechaza el procesamiento, conservar ese rechazo por separado de Upload succeeded.
6. Actualizar este registro con el resultado observado, incluyendo intentos que no funcionaron.

## 10. Entrega reciente con número menor que las anteriores

La subida local más reciente apareció como build 1 debajo de los builds 8, 7, 6 y 5. El usuario aún veía la versión anterior en iPhone. Esto demuestra una secuencia de numeración confusa, pero no prueba por sí solo la causa de la selección automática en el teléfono. Ready to Submit no impide pruebas internas, según la documentación de Apple enlazada en la guía de distribución.

Se conservó el archivo Cloud original y se preparó una copia con CFBundleVersion=13 en los dos Info.plist pertinentes. El ejecutable archivado permaneció idéntico; SDK iphoneos26.5 y compilador 17F113 se conservaron. Se exportó y firmó con Xcode 15.2 y manageAppVersionAndBuildNumber=false; se verificaron identidad, versión, firma y perfil de distribución. La comprobación codesign requirió acceso al almacén de confianza fuera del sandbox; en ese contexto pasó. La subida 0.1.0 (13) terminó con Upload succeeded y EXPORT SUCCEEDED.

Estado posterior: el usuario confirmó la actualización en iPhone y el funcionamiento de los interruptores de audio/segundo plano. La entrega siguiente usa build 14 en fuente; antes de subir, comprobar que el número elegido siga disponible. Cloud sigue teniendo el fallo de exportación documentado; esta subida local no lo resuelve.

## 11. Preferencias y flujo de sesión: mejora solicitada tras confirmar funcionamiento

El usuario inicialmente informó que Audio/Background no se activaban, pero después confirmó que sí funcionaban. Se retiraron los cambios provisionales de ese diagnóstico; no hubo una corrección publicada como si se hubiera demostrado un fallo.

La petición posterior fue de experiencia de usuario: evitar Captions → New Session → Settings cada vez. Fuente build 14 recuerda las preferencias, añade controles rápidos y circulares, y separa borradores de recuperación de sesiones guardadas. Stop deja una decisión pendiente; Guardar conserva y Descartar elimina. La marca SessionDraft se incorpora por migración aditiva V5 para no convertir las sesiones antiguas en borradores.

Para la próxima compilación: el script de validación debe esperar UIBackgroundModes=[audio], porque el chequeo antiguo que rechazaba todo audio en segundo plano ya no corresponde a la app. Verificar también migración V4/V5, recuperar un borrador al reabrir y confirmar en un iPhone que el cierre de captura y el descarte no afectan otras sesiones. No confundir el build fuente 14 con el número de ejecución de Xcode Cloud ni con una subida aceptada por TestFlight.

### Validación del flujo nuevo

Las pruebas compatibles pasaron (59 unitarias y dos escenarios UI en ejecuciones finales). El primer intento UI excedió la espera al finalizar una ráfaga sintética de 320 párrafos: el fixture del flujo corto usa ahora ocho; los escenarios de lectura larga conservan su fixture original. Otro intento consultaba Stop durante la animación de rotación; se sustituyó la comprobación inmediata por una espera hasta que el control sea interactuable. El recorrido final guardar → nueva sesión → fullscreen horizontal → descartar pasó, conservando la sesión previamente guardada. Estos ajustes del test no prueban rendimiento prolongado con audio real.

## 12. Próxima entrega: revisión de audio y controles (fuente 15)

La confirmación del usuario de que la app funciona no demuestra que futuras modificaciones hayan llegado al teléfono. Build 15 necesita un archivo nuevo del commit correspondiente. Mantener bundle ID y esquema V5; no reutilizar el ejecutable del archivo 13/14 para intentar entregar estas funciones. Si Cloud repite el error de exportación, revisar el ZIP de esa compilación antes de aplicar el procedimiento de firma local.

Pausa no crea otra sesión; la interrupción tampoco debe hacerlo al reanudar. Para diagnosticar saltos incorrectos, comprobar UUID del párrafo, tiempos guardados, duración real del audio y si hubo correcciones. No equiparar el medidor de entrada con una prueba de transcripción correcta.

Validación local de esta mejora: se cancelaron varios intentos de compilación lentos y se recogieron tiempos del compilador. El getter del lector tardó 175943 ms comprobando tipos. Se separaron contenido, estilo, gestos y seguimiento; la repetición midió menos de un segundo por componente. Los indicadores de tiempo fueron flags locales de diagnóstico, no cambios de configuración publicados. También se cerraron los compiladores residuales de intentos cancelados.

La primera ejecución completa pasó 61 pruebas unitarias. Los dos escenarios UI detectaron un teclado que podía permanecer abierto tras editar el nombre y una consulta de prueba que no encontraba el desplegable por nombre. Se añadió manejo explícito del foco/Done y un botón identificable para desplegar frases. El resultado de la repetición se registra en validation-report.md.

La repetición confirmó la reproducción/pausa. La prueba del nombre necesitó una corrección adicional: borrar con retrocesos desde el centro del campo dejaba caracteres de la fecha. Se añadió un botón accesible para limpiar el nombre y se usó ese recorrido. La ejecución final pasó el guardado y la consulta del nombre en historial, también tras girar a horizontal.

## 13. Traducción guardada y validación con SDK antiguo — 2026-10-10

Xcode 15.2 no incluye Translation. La app conserva iOS 17 mediante importación condicional y comprobación iOS 18; la generación real necesita un archivo compilado con SDK moderno. Los tests con traducción prefijada solo validan el flujo de datos, edición, reproducción y exportación. No atribuirles calidad de traducción ni prueba offline.

En la prueba de hojas anidadas, buscar Done globalmente coincidía con Translation y Audio & subtitles. Se limitó al navigation bar del reproductor. Las siguientes pruebas no pudieron activar el Menu de Compartir al volver de la hoja, incluso esperando a que fuera accesible. Se sustituyó por un botón normal y un diálogo nativo de formatos. Conservar los logs fallidos como evidencia de automatización, no como fallos del traductor de Apple.

El check de GitHub de `35fdc3b` (build fuente 15) se consultó durante esta entrega y reportó Archive – iOS satisfactorio. Eso no certifica instalación en el iPhone ni cambia el diagnóstico histórico de los builds 9–12.

El recorrido final de lectura/edición/reproducción/compartir pasó. La hoja nativa expone Guardar en Archivos con un tipo distinto de Button; se consulta por su etiqueta, como los tests existentes de compartir. Release y 67 tests unitarios pasaron. Los nombres de los artefactos y los límites están en el informe de validación.

Xcode Cloud finalizó satisfactoriamente el archivo del commit de implementación `d9ebefa` a las 17:32:22 UTC: cero errores y tres advertencias preexistentes de concurrencia de audio. No se ha confirmado todavía la descarga de idiomas ni la traducción real en un iPhone. Durante el seguimiento, Apple publicó un check-run nuevo para el resultado final, mientras el ID inicial seguía mostrando in_progress. Para próximas compilaciones, consultar los check-runs del commit otra vez; no depender indefinidamente del primer ID.


## Build 17 — nuevas comprobaciones de regresión
La primera prueba usaba un selector Format incompleto y una expectativa sobre la palabra inicial después de empezar el audio. Al comprobar explícitamente Pause, se detectó que el reproductor se abría sin empezar. La selección se pasó a una única entidad identificable con sheet(item:), evitando separar el booleano de presentación del UUID del párrafo. Los formatos se hicieron visibles mediante segmentos TXT/PDF/SRT/VTT. Ver resultado de la corrección en [el punto de reanudación](implementation-checkpoint.md). La exportación espera al cierre de la vista previa antes de abrir la hoja nativa. Estos problemas de interfaz no deben atribuirse al servicio de traducción Apple.


## Build 18 — aprendizaje
El primer Debug detectó una referencia a PlaybackButtonStyle, privado en SessionMediaView. Se sustituyó por un estilo SwiftUI estándar. Después pasaron 76 pruebas unitarias, el recorrido UI de aprendizaje y Release. Para reanudar con poco cupo, leer [el checkpoint](learning-checkpoint.md); no volver a implementar modelos ni migración V7.


## 2026-10-11 — build 19

Práctica local autorizada sin cuenta Azure: no crear dependencia de un servicio ausente ni presentar reconocimiento como evaluación de pronunciación. Mantener numeración fuente 19 y comprobar Cloud/TestFlight por separado; no reutilizar una compilación anterior como evidencia de entrega. La primera compilación Debug local terminó bien; resultados posteriores en el [checkpoint](pronunciation-checkpoint.md).

Las pruebas iniciales UI de build 19 pasaron; una prueba unitaria falló por URL con barra final y atributo de protección no expuesto en el simulador. La comparación de rutas y condición de dispositivo fueron corregidas; las 83 pruebas unitarias finales y Release pasaron. Comprobar protección con bloqueo real en iPhone. Se compactó el selector tras inspección visual.

## Actualización 23 — 2026-10-12

Build 23: no confundir la reproducción anterior “desde una frase” con reproducción limitada. La nueva limita muestras mediante scheduleSegment. No resuelvas etiquetas UIKit congeladas recreando el TabView ni borres datos para habilitar V8. Los modelos V1–V7 se conservan. Registrar por separado resultado local, check Cloud del SHA exacto, procesamiento y disponibilidad TestFlight. Historial de exportación 502/builds 9–12 sigue siendo evidencia histórica, no un fallo confirmado en esta entrega.

### Validación UI de build 23

El primer fixture imponía `-playbackAtMyPace NO` mediante argumentos de lanzamiento. Ese dominio de preferencias sobreescribía la elección al reconstruir la vista después de guardar. Se cambió por limpiar solo esa preferencia al iniciar el fixture DEBUG; la app normal conserva la elección. Las pruebas posteriores confirmaron parada, edición y selección. Al aumentar el lector, los tests de exportación deben desplazar la lista de acciones, no el lector, con movimientos pequeños para no saltarse filas. Ver evidencia final en el checkpoint. No presentar un fallo del selector de XCTest como fallo de exportación sin revisar la pantalla.

La repetición final de exportación pasó usando desplazamientos lentos dentro de la lista. La prueba de traducción debe seleccionar expresamente el primer párrafo: cambiar a A mi ritmo selecciona el párrafo en la posición actual del audio. Edición, cancelación y exportación traducida pasaron. En iPad, confirmationDialog se presenta como popover sin fila Cancelar; tocar fuera cancela y conserva la protección. Esperar que la ventana sea realmente horizontal antes de tomar capturas: encontrar un botón ya visible no prueba que haya terminado la rotación.

## Build 24 — selección de lectura bilingüe

La primera ejecución UI con Menu/Picker encontró `kAXErrorCannotComplete` al tocar el selector en iPhone SE/iOS 17.2, aunque el botón era visible en el video de XCTest. Se conservó el botón explícito anterior y se añadió un confirmationDialog nativo con tres opciones, para usar la misma interacción que los demás controles. La repetición debe verificar el acceso real, no sustituirlo por un toque ciego en coordenadas. La suite de 13 tests de traducción pasó en esa primera ejecución; el resultado global fue fallido por los dos recorridos UI. Ver el checkpoint para resultados posteriores.

En iPad, anclar el confirmationDialog al lector completo posicionó parte del popover fuera de pantalla; se verificó en video de XCTest. El selector se ancla al propio botón, también cuando se mueve a la barra de pantalla completa. No se cambia el test por coordenadas para ocultar ese defecto.

## Build fuente 25 — fallo Cloud y corrección fuente 26

El check `115246510250` del SHA `01f566d` falló con `Branches have mismatching types 'AppleTranslationRunner' and 'some View'` en SessionTranslationView.swift:336. Al extraer `productionRunner` de `body`, faltó `@ViewBuilder`: body hereda ese result builder del protocolo View, pero una propiedad auxiliar no. La rama moderna usa dos tipos de vista, mientras Xcode 15.2 solo compila la alternativa sin Translation y por eso las pruebas locales no detectaron el fallo.

Se añadió `@ViewBuilder` explícitamente en fuente 26. La vista y su selector no cambian. Verificar el check del SHA corregido antes de afirmar disponibilidad; el éxito local no cubre una rama eliminada por `#if canImport`. El fallo fue de compilación, no de firma ni configuración del usuario. No cambiar certificados ni modelos por este error. Cuatro advertencias de concurrencia/deprecación se reportaron aparte y no explican este fallo.

Resultado de corrección 26: el SHA `2da928440decb7c7d4da2bdac58dcce2b5ae10b0` pasó Cloud con 0 errores y 4 advertencias, check `115263454589`. Esto confirma que @ViewBuilder resuelve el error de ramas con tipos distintos. Disponibilidad TestFlight separada; ver checkpoint bilingüe.

## 2026-10-17 — Migración V11 y cuatro idiomas

La prueba de compatibilidad encontró una diferencia entre `targetLocale == nil` (formato histórico) y `en-US` explícito para una fuente española. La igualdad ahora compara idiomas efectivos, además de fuente, generado y correcciones; no elimina metadatos ni reescribe sesiones antiguas. Las 42 pruebas de traducción/ajustes se repitieron correctamente.

En las fixtures de interfaz, `moveToTrash` rechazó correctamente una sesión que todavía no tenía `endedAt`. Se finaliza la sesión ficticia antes de enviarla a papelera. Un chequeo inmediato de `isHittable` durante el cierre del Picker era prematuro; se espera brevemente la condición, manteniendo la prueba de pulsación real. Ver [checkpoint](session-library-languages-checkpoint.md). Los simuladores no validan modelos de francés/coreano ni el SDK Translation excluido por Xcode 15.2.
