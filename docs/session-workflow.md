# Sesiones: iniciar, guardar y descartar

## Build 20: idioma y pausas visibles

Settings recuerda el idioma para nuevas sesiones; inglés sigue siendo inicial. Después de iniciar, se conserva hasta guardar/descartar y crear otra sesión. Una pausa o interrupción muestra un panel persistente con micrófono apagado y **Resume / Reanudar**, incluso en fullscreen; pide feedback háptico y anuncio accesible al pasar a pausa. El micrófono no vuelve solo. Fondos pastel y renglones se eligen en Aa o Settings y persisten. [Guía completa](inclusive-use.md).


Flujo introducido en build 14 y ampliado en fuente 0.1.0 build 15. La disponibilidad de cada entrega en TestFlight debe comprobarse por separado.

## Recorrido principal

1. En Captions, elige Guardar audio, Reducir ruido y Segundo plano; cada control indica su estado. La elección se recuerda para futuras sesiones y al cerrar/reabrir la app.
2. Pulsa el micrófono circular para iniciar. Cambia a pausa mientras escucha y a reproducir para continuar. El cuadrado circular termina la captura.
3. Tras Stop, pulsa Save Session para conservarla en la biblioteca o Discard para eliminar el texto y cualquier audio, previa confirmación.
4. El + azul prepara otra sesión con un solo toque si ya guardaste. Si queda un borrador pendiente, ofrece Save and new session, Discard and new session o Cancel. No inicia el micrófono automáticamente.

Los iconos mantienen etiquetas para VoiceOver y áreas de toque de 44 puntos. Guardar y Descartar conservan texto visible porque deciden qué datos se conservan. Durante la escucha, los indicadores de audio y segundo plano abren las preferencias sin ir a Settings. En fullscreen se mantienen los controles de captura y el acceso mediante indicadores compactos.

## Preferencias frente a captura actual

En la versión actual, Guardar audio está activado en instalaciones nuevas; Segundo plano y Reducir ruido están inicialmente desactivados. Se conservan las elecciones anteriores del usuario. La grabación usa la preferencia que había al iniciar. Cambiar Audio durante una sesión prepara la siguiente, sin crear audio retroactivo. Segundo plano puede activarse/desactivarse para la sesión actual desde sus preferencias. Llamadas o interrupciones de iOS siguen deteniendo la captura; no hay reanudación automática.

## Borradores de recuperación

Los resultados finales se guardan en disco durante la escucha, junto con el audio si se activó. Stop mantiene el borrador pendiente de decisión. Sessions los muestra separados de Saved sessions, incluso después de reabrir la app. Puedes abrirlos para revisar el texto/audio y después guardarlos o descartarlos desde esa lista. El borrador activo debe detenerse antes de esas acciones.

Guardar quita la marca de borrador y conserva la identidad, texto, audio, correcciones y tiempos. Descartar borra estos datos de esa sesión; las copias previamente exportadas quedan bajo control de su destino. Si hay un error de almacenamiento se muestra y no se inicia otra sesión automáticamente. La recuperación conserva lo que ya se escribió: no garantiza recuperar texto provisional ni todas las muestras de audio tras una terminación abrupta. Los datos locales están excluidos del backup; exporta lo importante.

## Para quien desarrolla

- AppSettings guarda preferencias; CaptionViewModel mantiene el estado actual y la elección de audio de esa captura.
- SessionCoordinator conecta Start/Stop, checkpoints, publicación y descarte. newSession protege las decisiones pendientes.
- TranscriptRepository crea sesión y SessionDraft juntos; publish elimina la marca. La migración V5 añade este modelo y deja guardadas todas las sesiones anteriores sin marca.
- Pruebas: persistencia de preferencias, separación Stop/Save, descarte aislado, migración V4, reapertura de borrador y recorrido de UI incluyendo fullscreen horizontal.

La grabación que empieza a mitad de sesión queda fuera de esta entrega; requiere definir el desplazamiento del audio respecto a los subtítulos.

## Revisión y captura — build 15

- El botón principal cambia de micrófono a Pausa y después a Reanudar. Pausa conserva la sesión, finaliza los resultados pendientes y apaga el micrófono. Reanudar continúa el mismo borrador; Stop termina la captura y muestra Guardar/Descartar. En el reproductor, Play/Pause controla únicamente el audio guardado.
- Transcribing indica solo transcripción; Recording con icono rojo indica que se está grabando audio. El medidor muestra nivel recibido, no calidad ni exactitud del reconocimiento. Durante pausa/interrupción se limpia.
- Una interrupción con sesión iniciada muestra que hay un borrador disponible y ofrece Resume. La causa completa se consulta tocando el aviso. No se reinicia el micrófono automáticamente: si iOS sigue ocupándolo, el nuevo intento mostrará el error. Lo recuperable es lo escrito, no texto provisional perdido.
- Al detener, aparece un nombre sugerido con fecha/hora, editable en el mismo lugar que Save Session. Al editar puedes limpiar el campo con la X; Done cierra el teclado. Dejarlo vacío usa la sugerencia; se eliminan espacios extremos y se limita a 120 caracteres. No se envía texto a ningún servicio para generar nombres.
- Pellizcar el área de lectura cambia la letra entre 14 y 60 puntos base, respetando Dynamic Type. La elección queda guardada al terminar el gesto. Aa y acciones de accesibilidad permiten ajustar sin gestos de dos dedos.
- En Sessions, tocar un párrafo con audio y tiempos abre el reproductor desde esa frase. Los textos antiguos sin tiempos siguen siendo legibles/editables. Véase [audio y subtítulos](media-and-subtitles.md).

## Traducir después de guardar

Sessions → sesión → Translate to Spanish abre la lectura en español, inglés o ambos. El lápiz corrige únicamente español; editar inglés deja la traducción pendiente de actualización. La captura conserva su flujo actual. [Guía y límites](translation.md).


## Actualización build 21

Ver [interfaz bilingüe y primera preparación](interface-and-onboarding.md). El idioma de menús es independiente del idioma hablado. Guardar audio está activado inicialmente solo en instalaciones nuevas; las elecciones anteriores se conservan. Los renglones se calculan con el texto de cada párrafo. Estado de entrega: [checkpoint](interface-checkpoint.md).

## Actualización 23 — 2026-10-12

Build 23 protege sesiones guardadas con Favorita y añade un filtro sin copiar archivos. Quitar protección no elimina; se requiere un borrado posterior confirmado. Los borradores deben publicarse antes de protegerlos.

## Controles claros — 2026-10-16

Al releer el original o las tarjetas bilingües, una flecha hacia abajo dentro de un círculo permite **Volver al texto en vivo** y retomar el seguimiento. Desaparece al activarlo. VoiceOver conserva ese nombre y la acción Leer subtítulos anteriores. No necesitas entender los términos Following/Follow latest.

La pantalla normal usa la pestaña Ajustes, sin otro botón pequeño duplicado. En pantalla completa conserva Preferencias de captura porque la pestaña no está disponible. Los controles rápidos visibles antes de empezar permiten elegir Guardar audio, Reducir ruido y Segundo plano; se adaptan a columna cuando no cabe una fila. Los indicadores durante la sesión conservan acceso a las preferencias y explican su efecto en la captura actual o futura.

Para comunicarte en español y escuchar inglés, abre **Hablar y traducir** antes de iniciar una sesión. Sus modos Automático y Por botón están separados del idioma de los menús y de la grabación de sesiones. [Pasos y límites](speak-and-translate.md).

## Navegación actual — 2026-10-16

Texto y traducción permite corregir/exportar; Audio y subtítulos es el único reproductor de sesiones. Ya no se ofrecen marcadores de frases ni exportación de marcadores. Favoritos de sesiones completas siguen protegidos. En Subtítulos, Hablar y traducir está junto al selector en vivo; Comprobar preparación está en Ajustes y los avisos necesarios siguen en el lector. [Guía completa](simplified-navigation.md).
