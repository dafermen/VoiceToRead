# Inicio coherente y acciones fáciles de encontrar

Actualizado: 2026-10-17.

La presentación busca apoyar a personas con baja visión, dificultades auditivas o del habla, personas que aprenden otro idioma y niños acompañados por un adulto. Las etiquetas y los tamaños adaptables reducen la necesidad de memorizar iconos; no constituyen una certificación de accesibilidad.

## Uso

- **Mostrar nombres de los botones:** funciona de forma independiente al modo sencillo. Los controles de captura, reproducción, acciones de sesión, práctica y cierre leen la misma preferencia. Los idiomas, destinos de navegación y decisiones Guardar/Cancelar conservan texto; los nombres para VoiceOver nunca se ocultan. En el modo estándar, las herramientas de Subtítulos muestran un icono y su nombre debajo. Una cuadrícula adapta las columnas al ancho y al tamaño de letra. Desactivar la opción recupera los iconos compactos; los nombres accesibles permanecen.
- **Modo sencillo:** Conversación, Escuchar ahora, Mis sesiones, Practicar idioma, Escribir y hablar y Preparar VoiceToRead comparten estilo, ancho y altura mínima de 64 puntos. Usan tarjetas blancas sobre fondo gris en apariencia clara, como Sesiones; los colores semánticos se adaptan a la apariencia oscura. Siempre muestran nombres. La altura puede crecer para acomodar texto ampliado, y la pantalla permite desplazamiento.
- **Escuchar ahora en modo sencillo:** Se elimina la flecha Inicio duplicada: se vuelve al menú tocando Inicio en la barra inferior, incluso desde la misma pestaña. Acciones de sesión muestra solo el icono o icono con nombre según la preferencia. Si el texto no cabe, pasan a una columna y permiten varias líneas. Opciones de lectura conserva el mismo nombre en el acceso y en la pantalla.
- **Ajustes:** contiene preferencias y preparación; no duplica los accesos a Conversación ni a Escribir y hablar.
- **Escribir y hablar:** Inicio sencillo o Subtítulos → Acciones de sesión. Es útil para comunicar una frase sin usar la propia voz: escribe el texto, selecciona idioma de voz/velocidad y pulsa Decir respuesta. No traduce; para un intercambio entre idiomas usa Conversación. El texto es temporal y se borra al salir. Pausa/detén captura antes para evitar grabar la voz sintetizada.

## Para estudiantes: qué ocurría y cómo se corrige

`CaptionScreen` cambiaba una fila (`HStack`) por una columna (`VStack`) al mostrar nombres, pero conservaba un `Spacer`. Un Spacer ocupa el espacio libre del eje principal: horizontal en una fila, vertical en una columna. Esa reutilización producía un hueco grande. La cabecera ahora construye ambas disposiciones explícitamente y usa Spacer solo en la fila.

Además, un icono `Image` no adquiere texto visual por tener `accessibilityLabel`: ese nombre sirve para tecnologías de apoyo. `readerControlLabel` crea el icono y, si `AppSettings.showButtonNames`, añade un `Text` localizado. Lee la misma instancia observable de preferencias que usa la pantalla; no crea otra fuente de verdad en UserDefaults. `LazyVGrid` usa columnas adaptables para que los nombres no se compriman en una única fila. Pantalla completa organiza herramientas y transporte por separado.

`SimpleHomeActionStyle` centraliza fondo, espaciado, altura mínima y flecha. `SimpleHomeLabelStyle` reserva un ancho para el icono y permite varias líneas de texto. Los seis accesos reutilizan ambos estilos; cada acción mantiene su identificador y su destino. Una altura mínima, en lugar de una altura fija, permite texto grande sin recortarlo.

`WrittenResponseView` reutiliza el sintetizador existente: el cambio es de nombre y ubicación, no de motor ni almacenamiento. No se ha modificado el flujo de Conversación ni la biblioteca de sesiones.

## Verificación

Ver [evidencia de esta revisión](home-controls-checkpoint.md). Las pruebas de interfaz comprueban cambios reales desde Ajustes, nombres, tamaños, orientación y navegación. La calidad de traducción/voz y la aceptación con tecnologías de apoyo requieren comprobación en dispositivo físico.

## Convenciones compartidas de presentación

- Las ventanas que solo se cierran usan **✓ arriba a la derecha**, con el nombre accesible Listo/Done y área mínima de 44 puntos. `DoneToolbar` define esa posición para evitar decisiones diferentes por pantalla.
- Las acciones adicionales de esas ventanas (opciones de Conversación, editar traducción, pantalla completa, editar la vista previa y reemplazar texto) van a la izquierda. Solo aparecen cuando tienen una función real; no añadimos menús vacíos para hacer las ventanas idénticas.
- Los editores conservan **Cancelar a la izquierda / Guardar o Aplicar a la derecha**: cerrar una ventana y decidir qué hacer con cambios sin guardar son acciones diferentes. Volver a la pantalla anterior conserva la navegación del sistema. Ocultar el teclado de Escribir y hablar se hace desde la barra del teclado, sin añadir otro check a la cabecera.
- `PlaybackTransport`, compartido por Audio y subtítulos y Practicar idioma, dibuja el símbolo dentro de un círculo de 56 puntos. Cuando se muestran nombres, el texto queda debajo, fuera del fondo de color. Anterior y Siguiente comparten columna y alineación; tamaños de accesibilidad usan una columna vertical.
- Pronunciación, mostrar/ocultar traducción, traducir y guardar expresiones usan `PracticeActionStyle`: acción sin relleno, icono con nombre opcional cuando existe, área mínima de 44 puntos. Eliminar conserva su significado destructivo.

### Por qué no pintar todo el botón de reproducción

En SwiftUI los modificadores se aplican a la vista que los precede. Antes, `background` rodeaba todo el `Label`, incluido el nombre al activar Mostrar nombres. Ahora se aplica únicamente al `Image` dentro de un `VStack`, y `Text` es un hermano debajo. El botón sigue siendo un único elemento accesible y mantiene su nombre dinámico Reproducir/Pausa/Reanudar; la acción de audio no cambia.

Para un fondo adaptable, `systemGroupedBackground` describe el exterior y `secondarySystemGroupedBackground` las tarjetas. Evitamos fijar blanco puro porque dificultaría leer en modo oscuro. No se alteran los colores asignados a cada idioma: siguen distinguiendo original y traducción.

Ver [validación de uniformidad](visual-consistency-checkpoint.md).

## Selectores de idioma y regreso a Inicio

`LanguagePickerControl` centraliza texto azul, fondo tenue, chevron y área mínima de 44 puntos para Conversación, Escuchar ahora, preferencias de captura, Ajustes, traducción guardada y Escribir y hablar. En formularios se mantiene el nombre del campo para distinguir idioma hablado, destino de traducción e idioma de voz. El idioma de la interfaz permanece en su apartado separado.

El componente recibe un `Binding<CaptureLanguage>` y una lista de opciones: comparte presentación, no las reglas de negocio. Captura sigue bloqueando cambios durante una sesión, su destino excluye el origen y Conversación sigue intercambiando participantes cuando eliges el idioma del otro. La traducción guardada conserva su propio destino y sus correcciones.

`AccessibleControlLabelStyle` consulta `AppSettings` del entorno, igual que el reproductor. Ya no consulta una copia de preferencias globales ni fuerza nombres cuando `simpleMode` está activo. Los estados de captura (audio/ruido/segundo plano) mantienen nombres y estado porque no son herramientas identificables por un icono aislado.

La pestaña Inicio controla un camino de navegación con `HomeDestination`. Vaciar ese camino vuelve al menú sin recrear `SessionCoordinator`: no descarta la sesión ni reinicia la captura. Evita retirar un botón de regreso sin comprobar que el destino alternativo realmente funciona.
