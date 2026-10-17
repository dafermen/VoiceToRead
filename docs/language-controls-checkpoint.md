# Checkpoint — idiomas, nombres y pestaña Inicio

Fecha: 2026-10-17. Proyecto VoiceToRead (`com.innovalogic.voicetoread`).

## Cambios

- Selector azul reutilizado en Conversación, captura, Ajustes, traducción guardada y respuesta hablada. Valores y reglas de cada flujo siguen separados.
- Sin Inicio superior duplicado en Escuchar ahora. Rutas explícitas permiten regresar al menú con la pestaña inferior, manteniendo el coordinador y la sesión.
- Nombres independientes del modo sencillo, leídos desde el mismo `AppSettings` en el entorno. Los controles de captura, opciones, reproducción, práctica y cierre comparten esa preferencia; los idiomas, destinos, estados de captura y decisiones de guardado siguen explícitos.
- VoiceOver mantiene nombres al ocultar texto visual: el estilo compacto delega en `LabelStyle.iconOnly`, en lugar de descartar el título. Los nombres del transporte se encuentran fuera de los círculos.

## Verificación

- Compilación Debug y seis recorridos de interfaz aprobados, sin fallos, con Xcode 15.2 / iPhone 15 / iOS 17.2: `/private/tmp/vtr-controls-final.xcresult` (log con el mismo nombre).
- Conversación: elegir francés/coreano, mantener reglas del par y colores. Escuchar ahora: elegir origen y destino mediante el mismo selector azul.
- Nombres: activar/desactivar en Inicio normal, modo sencillo y reproducción; conservar los nombres accesibles al ocultar el texto. Práctica: reproducir, mostrar traducción, abrir pronunciación y guardar/reabrir expresión.
- Inicio inferior: volver desde Escuchar ahora al volver a tocar la pestaña; salir y regresar durante una captura conserva el estado de escucha y sus ocho párrafos de prueba.
- Rotación, español, modo oscuro y tamaño máximo de accesibilidad revisados. En letra máxima la preparación permite desplazamiento; no se espera que todo el contenido quepa a la vez.
- Catálogos: 774 claves de interfaz y 2 de permisos con paridad en/es; 492 claves extraídas por el compilador cubiertas. `git diff --check` sin errores.
- Sitio de soporte: 10 páginas bilingües, recursos, enlaces y ZIP de despliegue validados.
- Permanece la advertencia previa de aislamiento MainActor del callback de cierre de `SessionTranslationView`. La barra nativa de navegación de iOS puede conservar solo los símbolos (por ejemplo el check de cierre); los controles del contenido sí presentan los nombres según la preferencia.

Capturas con datos de prueba: [lector sin nombres](qa/language-controls/Simple-reader-icons.png), [lector con nombres](qa/language-controls/Simple-reader-names.png), [selector en Conversación](qa/language-controls/Conversation-French-Korean.png), [reproductor](qa/language-controls/Playback-shared-names.png), [Práctica](qa/language-controls/Practice-named-controls.png), [texto grande en oscuro](qa/language-controls/Reader-dark-Spanish-large.png).

## Notas para continuar

Se corrigieron errores locales de integración durante la refactorización: sintaxis de NavigationLink por valor, conservación del componente de estado de captura y acceso a ajustes MainActor desde helpers de estilo. `LabelStyle.makeBody` no debe leer directamente el modelo aislado: delega la lectura a `PreferenceControlLabel.body`. El helper del transporte se marca MainActor. Ejecutar una sola compilación por DerivedData para evitar bloqueo de build.db.

Las pruebas locales usan Xcode 15.2 / iOS 17.2. Las elecciones de idioma se verifican con dobles; no certifican la calidad de modelos Apple. Confirmar el resultado de Xcode Cloud y procesamiento de TestFlight antes de afirmar que hay una actualización instalable. La web de soporte se prepara localmente; su ZIP no se publica automáticamente en Hostinger.
