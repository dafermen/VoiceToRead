# Tiempo por párrafo en Escuchar

Fecha: 2026-11-15.

## Uso y alcance

En **Ajustes > Escuchar > Mostrar tiempo en los párrafos** se puede activar o desactivar la marca `HH:MM:SS`. Está desactivada por defecto y conserva la selección al volver a abrir la app. El ajuste se puede cambiar durante una sesión.

El lector de Escuchar, normal y a pantalla completa, muestra el tiempo discretamente en el encabezado. Con tamaños de accesibilidad, el encabezado se apila para dar espacio al idioma y la marca. Funciona en Original, Traducción y Ambos, tanto intercalado como en columnas. Los párrafos provisionales muestran el inicio del bloque en curso y pueden revisarse hasta que el reconocimiento los finaliza.

La marca representa el **inicio del párrafo en la línea de tiempo del audio de la sesión**. No es la hora del día, la hora de llegada de una traducción ni un cronómetro que avance en todas las tarjetas. La línea de captura acumula audio; las pausas no añaden audio. También funciona si no se guarda un archivo de audio. La precisión es la del rango que ya entrega el reconocedor; no se inventan tiempos nuevos ni se altera su segmentación.

## Implementación

- Preferencia independiente `showListeningParagraphTimes` en `AppSettings`/UserDefaults, valor inicial false. No modifica idiomas, audio, tamaño de letra ni preferencias existentes.
- Encabezado compartido `ListeningParagraphHeader` y formateador existente `SessionClock.format`, con dígitos monoespaciados, estilo caption y nombre accesible localizado.
- Los rangos de audio ya se producen sobre la sesión en los backends de producción: `SpeechTranscriber` aplica el offset de captura y el backend anterior usa `CapturedAudio.sessionStart`. No se cambiaron esos servicios.
- El original usa `CaptionSegment.start`. El lector bilingüe recibe un mapa UUID → inicio para los mismos 40 párrafos que ya procesa. Original y traducción consultan el mismo UUID, incluida la tarjeta pendiente de traducir.
- `ReviewParagraph` conserva solo ID/texto. Las marcas son vistas separadas; no se añaden a la transcripción, al texto que se traduce ni al contenido exportado.
- Cambiar la preferencia conserva las instancias, el buffer y el trabajo de traducción. El seguimiento existente ajusta el desplazamiento solo si el usuario sigue el texto en vivo; si estaba leyendo hacia atrás, conserva ese estado.

## Validación de esta entrega

Comprobado en Windows: paridad de 1121 claves de interfaz y dos de InfoPlist; parser OpenStep, referencias/targets/esquema válidos; auditoría de llamadas existentes de audio/almacenamiento, confirmaciones, sheets y cierre conservadas; servicios, persistencia, reloj y contenido sin modificaciones; delimitadores Swift y `git diff --check` correctos. El cambio de AppSettings se limita al nuevo booleano y su carga/persistencia.

Pruebas nativas preparadas: preferencia desactivada inicialmente, persistencia independiente de idiomas/audio/tamaño; límites de segundos/minutos/horas; activación desde Ajustes durante la captura; misma marca para original/traducción; conservación en pantalla completa/horizontal y en pausa; retirada de las marcas y conservación de Guardar/Descartar.

**Pendiente en Mac/iPhone:** compilación, XCTest y revisión de visibilidad, contraste, VoiceOver, texto grande, reanudación después de una pausa y traducciones que terminan más tarde. Windows no dispone de Xcode/simulador; los verificadores de fuente no ejecutan esas pruebas. Ejecutar `bash scripts/validate-macos.sh` y revisar en dispositivo. Archive de Xcode Cloud no equivale a una suite UI aprobada.

## Mejora futura separada

La detección automática entre dos idiomas queda **documentada, sin implementar ni habilitar**. Ver [alcance y evaluación de pérdida de palabras/retrasos](automatic-listening-language-detection.md).
