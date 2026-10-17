# Nueva orientación: comunicación primero

Fecha: 2026-10-17. Decisión autorizada por el titular después de observar dificultades de uso inicial sin explicación.

## Propósito y alcance

VoiceToRead abre en Conversación para ayudar a comunicarse: personas con dificultades auditivas o del habla, baja visión, personas que usan un nuevo idioma y aprendizaje acompañado. No se solicita declarar una discapacidad. No se promete reconocimiento o traducción perfectos.

Inicio ofrece Conversar / Escuchar. Conversar presenta idiomas, mensajes y acciones claras. Escuchar conserva captura continua para reuniones, clases y conferencias. Guardado conserva biblioteca y acceso a práctica. Conversar siempre traduce; Escribir respuesta permite comunicar sin hablar. Escuchar conserva la lectura del original sin traducción. Los nombres de acciones se muestran por defecto cuando no existe una elección previa. No cambia la captura de audio de otras apps ni añade acceso al audio interno de Zoom/Teams.

## Recuperación antes de modificar

Tag anotado y respaldado en GitHub: `before-conversation-home-2026-10-17`, commit `9b30323`.

Para comparar sin cambiar el checkout actual:

```sh
git fetch origin --tags
git worktree add ../VoiceToRead-before-conversation before-conversation-home-2026-10-17
```

No usar reset --hard ni force push. Para una reversión de distribución, crear una rama desde main y revertir los commits de esta orientación, comprobar pruebas y entregar con un número de build nuevo. El tag conserva código/documentación; no es una copia del contenido privado del iPhone. Exportar sesiones importantes desde la app antes de cualquier reinstalación. Este cambio no modifica el esquema del almacén.

También se conserva Ajustes → Experiencia de inicio → Inicio anterior como comparación reversible dentro de la app. La nueva preferencia no borra preferencias de captura ni sesiones.

## Criterios de aceptación

- Abrir y empezar a conversar sin menú de seis destinos ni ventana adicional.
- Terminar un turno, ver ambos textos y escuchar el destino; repetir audio o volver a hablar; Escribir respuesta crea un mensaje nuevo.
- Conversar no ofrece desactivar traducción ni corregir el turno; una preferencia antigua en false no impide traducir. Escuchar conserva Original/Traducción/Ambos.
- Escribir una respuesta y reproducirla; texto temporal claramente diferenciado de sesiones guardadas.
- Cambiar a Escuchar sin dos micrófonos activos; conservar sesiones, recuperación y exportación.
- Inicio anterior reversible; nombres accesibles, texto grande, idiomas EN/ES y colores sin depender solo del color.
- Prueba posterior con personas nuevas: conversar, responder por escrito y pasar a una reunión sin explicación. Registrar dudas antes de retirar el inicio anterior.

## Ajuste de coherencia visual y simplificación

Conversar y Escuchar usan el mismo título, selector de modos, márgenes, columnas de idioma y espacio de estado. La lectura queda en el centro y el transporte al pie. En letra de accesibilidad el contenido permite desplazamiento. Escuchar conserva captura, pausa, guardar/descartar y sus herramientas en Acciones de sesión (esquina superior izquierda).

Se retiraron el interruptor Traducir conversación y Corregir mensaje. La traducción sigue siendo parte obligatoria de Conversar: finalizar → traducir → reproducir. Escribir respuesta crea una respuesta nueva; Cancelar conserva el intercambio anterior. Repetir audio sigue disponible. No cambia la edición de sesiones guardadas ni los modelos, colores o idiomas elegidos.

Validación de este ajuste: 26 pruebas unitarias y cinco recorridos de iPhone aprobados en la primera pasada. La prueba de iPad detectó un menú que solo exponía la primera acción; se sustituyó por un menú nativo. La repetición final pasó en iPad (alineación, menú de lectura, traducción obligatoria e inicio anterior) y en iPhone (alineación vertical/horizontal y exclusión mutua del micrófono). El recorrido general de iPad también pasó. La cabecera horizontal coloca idiomas y estado en una fila para conservar área de lectura.

Resultados locales: `build/home-refinement/iphone.xcresult`, `iphone-final.xcresult`, `ipad.xcresult` y `ipad-final.xcresult`. El primer resultado de iPad conserva el fallo del menú para diagnóstico; `ipad-final` verifica la corrección. Se revisaron visualmente las capturas finales y se validaron 790 claves de interfaz, 2 de permisos y 498 claves extraídas por el compilador, además de las 10 páginas del sitio. Los recorridos de voz/traducción usan dobles de prueba: queda la comprobación física con los recursos de Apple en TestFlight.

Evidencia vigente: [Conversar en iPhone](qa/home-refinement/iphone/Aligned-Converse.png), [Escuchar listo](qa/home-refinement/iphone/Aligned-Listen-ready.png), [horizontal](qa/home-refinement/iphone/Aligned-Converse-landscape.png), [Conversar en iPad](qa/home-refinement/ipad/Aligned-Converse.png) y [Escuchar en iPad](qa/home-refinement/ipad/Aligned-Listen.png). Las capturas de la primera entrega muestran opciones hoy retiradas; se conservan como evidencia histórica, no como interfaz vigente.

## Validación de la primera entrega (2743c60)

Se han aprobado 28 pruebas unitarias de preferencias y conversación, y los recorridos UI de conversación integrada, respuesta escrita, lectura sin traducción, regreso al inicio anterior, exclusión mutua del micrófono e idiomas francés/coreano. La conversación anterior también pasó después de corregir una expectativa obsoleta del test (Spanish → Español). La revisión visual detectó y corrigió botones demasiado altos con letra de accesibilidad: ahora se apilan dentro del contenido desplazable; la barra fija se reserva para tamaños normales. La repetición de las pruebas de letra máxima y lectura sin traducción/inicio anterior pasó después de ese ajuste.

La prueba de iPad Air (5.ª generación), iOS 17.2, pasó después de retomar la ejecución interrumpida; verifica Conversar, Escuchar y Guardado. Resultado local: `build/conversation-first-validation/tablet.xcresult`. La captura de iPad quedó revisada junto a las de iPhone. Se validaron 790 claves de interfaz y 2 de permisos en ambos idiomas, 508 claves extraídas por el compilador y las 10 páginas del sitio de soporte.

Entorno local: Xcode 15.2 / simuladores iOS 17.2. Los recorridos de traducción usan dobles de prueba; las APIs modernas y los recursos reales requieren comprobación con el build de Cloud y dispositivo físico. No considerar disponible en TestFlight hasta confirmar el build correspondiente. Las pruebas con dobles no certifican precisión de Apple Speech/Translation ni sustituyen pruebas con usuarios.

## Cómo decidir si esta orientación funciona

Dar el teléfono a una persona que no conozca la app y pedirle, sin señalar botones:

1. «Pide un vaso de agua a alguien que habla otro idioma y escucha su respuesta».
2. «Ahora quieres leer lo que dice alguien en tu mismo idioma».
3. «Responde escribiendo, sin usar tu voz».
4. «Vas a una conferencia: quieres seguirla y conservarla».
5. «Encuentra una sesión que ya habías guardado».

Registrar si completa cada tarea sin ayuda, el primer botón que toca, dudas, retrocesos y cualquier texto que no entiende. Probar con personas con necesidades distintas, sin asumir que una sola configuración sirve para todas. Si no encuentran Conversar/Escuchar o confunden conversación temporal con sesión guardada, ajustar antes de publicar. Se puede seleccionar Inicio anterior durante la evaluación; no hace falta reinstalar.

## Evidencia visual

Las capturas de `qa/conversation-first/` son pruebas de interfaz con texto y audio simulados, no material promocional ni prueba de precisión lingüística. Incluyen inicio, respuesta escrita, lectura sin traducción, letra grande y iPad. Antes de App Store, generar capturas con contenido real revisado y completar las pruebas físicas de accesibilidad.
