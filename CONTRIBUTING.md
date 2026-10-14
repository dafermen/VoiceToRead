# Cómo contribuir a VoiceToRead

Empieza por el [índice de documentación](docs/README.md). Si estás aprendiendo, sigue la [guía junior](docs/junior-guide.md) y el [recorrido del código](docs/code-walkthrough.md).

## Preparación

1. Abre el checkout real de VoiceToRead y comprueba git status. El nombre anterior VoiceToRead puede seguir en configuraciones antiguas del editor.
2. Crea una rama para un cambio acotado; revisa cambios locales existentes antes de editar.
3. Abre VoiceToRead.xcodeproj y el esquema VoiceToRead. El proyecto usa referencias explícitas: añadir un archivo al disco no garantiza que esté en el target.
4. Consulta [development](docs/development.md) para herramientas y [testing](docs/testing.md) para las comprobaciones.

## Estilo y responsabilidades

Usa UpperCamelCase para tipos y lowerCamelCase para miembros. Mantén vistas, coordinación, motores y persistencia con responsabilidades claras. Los protocolos deben representar fronteras útiles, no añadir capas por costumbre.

Documenta con comentarios `///` los contratos importantes: entradas/salidas, propiedad del buffer, aislamiento, errores y decisiones. Explica por qué una cola tiene límite o por qué se conserva un identificador; no comentes cada asignación obvia. Los nuevos comentarios didácticos están en español; se mantienen los nombres Swift y la interfaz en inglés.

Verifica APIs de Apple contra su documentación oficial y su disponibilidad. @unchecked Sendable o @preconcurrency no son sustitutos de analizar concurrencia. La API moderna debe compilarse/probarse con herramientas modernas; una prueba en Xcode 15.2 puede excluirla.

## Datos que deben conservarse

- Bundle ID com.innovalogic.voicetoread y carpeta de datos VoiceToRead: mantienen continuidad.
- Cambios de modelos persistentes: requieren revisar migraciones de usuarios existentes.
- Originales de reconocimiento: las correcciones se guardan aparte.
- Audio y continuidad en segundo plano: decisiones explícitas por sesión.
- Ante fallos: conservar datos recuperables, mostrar el problema y evitar reinicios ocultos del micrófono.

No incorporar secretos, perfiles, certificados, paquetes de distribución, logs privados de Apple ni grabaciones/transcripciones personales al repositorio.

## Validación y revisión

Para cambios funcionales, ejecuta las pruebas relacionadas y los checks requeridos del proyecto. Para cambios de documentación/comentarios, comprueba vínculos, rutas, sintaxis de ejemplos y que no se haya alterado lógica ejecutable. No declarar pruebas físicas realizadas si solo se ejecutaron mocks o simulador.

Describe en el commit/PR el problema, cambio, evidencia y límites. Usa feat:, fix:, docs:, test:, refactor: o chore:. Revisa git diff --check y el diff completo antes de publicar.

## Entregas

Actualizar la documentación de una función forma parte de terminarla. Mantén el README breve, las explicaciones en docs y las decisiones importantes junto al código.

Antes de compilar para TestFlight, leer [distribution-runbook](docs/distribution-runbook.md) y [build-incidents](docs/build-incidents.md). Registrar resultados por etapa: archive, export, upload, processing, grupo de testers e instalación. El éxito de una no implica el de las siguientes.

El workflow nuevo todavía debe configurarse. Si se elige cualquier cambio en main como disparador, también incluirá docs. Publicar documentación puede iniciar Cloud; no presentar ese resultado como validación funcional nueva.
