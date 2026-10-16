# Escucha accesible, preferencias y notas

## Para quién y para qué

VoiceToRead apoya a personas con dificultades auditivas o visuales, a quienes necesitan comprender otro idioma y a niños que practican acompañados por un adulto. Estas mejoras ayudan a seguir el texto al propio ritmo; no equivalen a una certificación de accesibilidad ni sustituyen interpretación profesional.

## Cómo usarlo

1. En **Sesiones → Audio y subtítulos**, elige el idioma y **A mi ritmo** o **Continuo**. Se recuerdan las preferencias. “Ambos” escucha el original y después la traducción de cada párrafo.
2. Abre **Velocidad de lectura** para elegir **Velocidad del original**, **Velocidad de la traducción** y **Pausa entre idiomas**: sin pausa, uno o dos segundos. Los ajustes también se ofrecen en Traducción y se comparten con los marcadores. La pausa solo ocurre entre los dos idiomas del mismo párrafo.
3. La tarjeta que suena muestra un borde y **Escuchando ahora**. No depende únicamente de un color. Durante la espera se muestra **Pausa entre idiomas**. Pausa detiene la espera; Reanudar concede de nuevo el intervalo completo. Detener, salir, cambiar párrafo o una interrupción cancela la cola.
4. Si deslizas el texto, se suspende el desplazamiento automático. **Seguir audio** vuelve a mostrar la tarjeta activa. El reproductor sigue cambiando el párrafo al avanzar el audio; usa Pausa o A mi ritmo para detener ese avance y releer.
5. **Párrafos** permite buscar en el original y la traducción vigente. Tocar un resultado empieza la escucha desde ese párrafo, respetando el modo elegido. Anterior/Siguiente continúan seleccionando sin reproducir automáticamente. Traducción también tiene búsqueda y escucha directa en cada resultado.
6. En **Marcadores**, añade una **Nota del marcador** opcional. Guardar modifica únicamente la nota; Cancelar la descarta; guardar una nota vacía la elimina. **Escuchar** reproduce ese párrafo con la voz local y el idioma guardado, sin abrir otra ventana. Esta escucha del marcador usa el texto corregido, no exporta voz generada y se deshabilita mientras no esté permitido reproducir. Eliminar el marcador elimina su nota; no elimina la transcripción.
7. En Captions, antes de comenzar, **Antes de una reunión o clase** abre la preparación. Revisa micrófono, reconocimiento, espacio, idiomas y disponibilidad de voces. La descarga de modelos se inicia explícitamente. La disponibilidad de una voz no garantiza funcionamiento sin conexión: haz la prueba de reproducción y la prueba real sin internet antes del evento. El modo sencillo conserva su acceso Preparar VoiceToRead.

Si una sesión no tiene traducción vigente, el reproductor usa el original sin borrar la preferencia para futuras sesiones. Guardamos el papel del idioma (original/traducción/ambos), no una elección fija inglés/español: al cambiar el idioma hablado de una sesión, la preferencia sigue siendo coherente.

## Párrafos largos en un iPhone pequeño

En **Ajustes → Subtítulos**, **Opciones de lectura** de la conversación en vivo o **Preferencias de lectura** del reproductor, mueve **Tamaño del texto** hacia la izquierda. El rango base es **14–60 puntos**; prueba 16 o 18 si necesitas ver más contenido. El valor se muestra junto al control y se recuerda entre sesiones. La instalación nueva sigue usando 28 y se conserva cualquier elección anterior válida.

Reducir la letra no garantiza que todo párrafo quepa: puedes desplazar el área de texto. En reproducción, selecciona **A mi ritmo** para que se detenga al terminar el párrafo (después de ambos idiomas si elegiste Ambos), lee con calma y elige Siguiente cuando estés listo. En Continuo, el audio sigue determinando el avance. El tamaño de accesibilidad de iOS continúa ampliando el tamaño base: no se desactiva para forzar el texto dentro de la pantalla.

## Para estudiantes: cómo funciona

- `CaptionTextSize` centraliza el rango y la validación de valores no finitos. `CaptionSizeControl` comparte el slider y el valor visible entre las tres pantallas. El gesto de pellizco y las acciones de VoiceOver usan la misma función de límites; así una pantalla no vuelve a imponer el antiguo mínimo de 20. La preferencia mantiene la clave `captionSize`, sin migrar la base de sesiones.
- `ParagraphAudioStep.make` crea pasos con UUID del párrafo, idioma, texto y, cuando existe, intervalo de grabación. No modifica los archivos originales.
- `ParagraphPlayback` coordina los motores de audio y voz. Cada finalización real avanza el índice. Si el siguiente paso es el otro idioma del mismo párrafo, programa una tarea cancelable para esperar. No usa un temporizador para adivinar cuándo acaba la voz.
- Cancelar una tarea y cambiar su token UUID impide que una espera antigua reproduzca contenido después de salir o detener. La cola observa interrupciones durante la espera, cuando los motores están inactivos. Pausa conserva el paso pendiente; Reanudar reinicia el intervalo seleccionado.
- Cada paso utiliza la velocidad del original o de la traducción según su papel. Los controles usan `AppStorage` para preferencias locales. Cambiar una preferencia detiene el audio correspondiente antes de reanudar explícitamente.
- `PlaybackLanguagePreference` convierte el papel guardado al idioma de la sesión. Solo una selección explícita del usuario cambia esa preferencia; el fallback por falta de traducción no la sobrescribe.
- `PlaybackTextCard.speaking` recibe el estado real del reproductor. Agrega borde y etiqueta sin alterar el tamaño de fuente relativo entre idiomas. El arrastre suspende el seguimiento; no usa animaciones repetitivas ni anuncia cada palabra con VoiceOver.
- El esquema **V10** agrega `BookmarkNote`, con clave única del marcador y texto. No cambia las clases de esquemas anteriores. `SessionMigrationPlan` añade V9→V10; la base anterior se migra mediante SwiftData. La nota permanece separada de texto original, correcciones y traducciones.
- `TranscriptRepository` valida que el marcador siga existiendo, guarda con rollback ante error y elimina las notas al quitar marcadores o eliminar definitivamente una sesión. La papelera conserva las notas mientras la sesión sea recuperable.

## Privacidad y límites

Notas y preferencias quedan en el dispositivo. No añadimos servidores, analítica, cuentas ni servicios de evaluación. Las notas no se incluyen automáticamente en exportaciones de transcripción. La política de sesiones locales y exclusión de respaldo se mantiene. El usuario debe exportar los contenidos que quiera conservar fuera del dispositivo.

Las pruebas del simulador no certifican la accesibilidad completa, la inteligibilidad de voces ni la disponibilidad de modelos de traducción. Probar VoiceOver, auriculares, interrupciones de llamadas/alarmas, orientación y tamaños grandes en dispositivos físicos antes de publicar.

Ver [verificación y entrega](listening-comfort-checkpoint.md).
