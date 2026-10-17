# Inicio coherente y acciones fáciles de encontrar

Actualizado: 2026-10-17.

La presentación busca apoyar a personas con baja visión, dificultades auditivas o del habla, personas que aprenden otro idioma y niños acompañados por un adulto. Las etiquetas y los tamaños adaptables reducen la necesidad de memorizar iconos; no constituyen una certificación de accesibilidad.

## Uso

- **Mostrar nombres de los botones:** las herramientas de Subtítulos muestran un icono y su nombre debajo. Una cuadrícula adapta las columnas al ancho y al tamaño de letra. Desactivar la opción recupera los iconos compactos; los nombres accesibles permanecen.
- **Modo sencillo:** Conversación, Escuchar ahora, Mis sesiones, Practicar idioma, Escribir y hablar y Preparar VoiceToRead comparten estilo, ancho y altura mínima de 64 puntos. Siempre muestran nombres. La altura puede crecer para acomodar texto ampliado, y la pantalla permite desplazamiento.
- **Ajustes:** contiene preferencias y preparación; no duplica los accesos a Conversación ni a Escribir y hablar.
- **Escribir y hablar:** Inicio sencillo o Subtítulos → Acciones de sesión. Es útil para comunicar una frase sin usar la propia voz: escribe el texto, selecciona idioma de voz/velocidad y pulsa Decir respuesta. No traduce; para un intercambio entre idiomas usa Conversación. El texto es temporal y se borra al salir. Pausa/detén captura antes para evitar grabar la voz sintetizada.

## Para estudiantes: qué ocurría y cómo se corrige

`CaptionScreen` cambiaba una fila (`HStack`) por una columna (`VStack`) al mostrar nombres, pero conservaba un `Spacer`. Un Spacer ocupa el espacio libre del eje principal: horizontal en una fila, vertical en una columna. Esa reutilización producía un hueco grande. La cabecera ahora construye ambas disposiciones explícitamente y usa Spacer solo en la fila.

Además, un icono `Image` no adquiere texto visual por tener `accessibilityLabel`: ese nombre sirve para tecnologías de apoyo. `readerControlLabel` crea el icono y, si `AppSettings.showButtonNames || AppSettings.simpleMode`, añade un `Text` localizado. Lee la misma instancia observable de preferencias que usa la pantalla; no crea otra fuente de verdad en UserDefaults. `LazyVGrid` usa columnas adaptables para que los nombres no se compriman en una única fila. Pantalla completa organiza herramientas y transporte por separado.

`SimpleHomeActionStyle` centraliza fondo, espaciado, altura mínima y flecha. `SimpleHomeLabelStyle` reserva un ancho para el icono y permite varias líneas de texto. Los seis accesos reutilizan ambos estilos; cada acción mantiene su identificador y su destino. Una altura mínima, en lugar de una altura fija, permite texto grande sin recortarlo.

`WrittenResponseView` reutiliza el sintetizador existente: el cambio es de nombre y ubicación, no de motor ni almacenamiento. No se ha modificado el flujo de Conversación ni la biblioteca de sesiones.

## Verificación

Ver [evidencia de esta revisión](home-controls-checkpoint.md). Las pruebas de interfaz comprueban cambios reales desde Ajustes, nombres, tamaños, orientación y navegación. La calidad de traducción/voz y la aceptación con tecnologías de apoyo requieren comprobación en dispositivo físico.
