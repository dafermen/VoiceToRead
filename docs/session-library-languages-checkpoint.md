# Checkpoint — biblioteca y cuatro idiomas

Fecha: 2026-10-17. Proyecto: VoiceToRead, `com.innovalogic.voicetoread`.

## Cambios

Ver [uso y arquitectura](session-library-and-languages.md). Guardadas primero; borradores/papelera separados; barra lateral iPad. Origen y destino explícitos para inglés, español, francés y coreano. Colores, conversación, reproducción, práctica y exportación usan el idioma seleccionado. Menús continúan en español/inglés.

## Validación local

- Xcode 15.2 / simulador iOS 17.2, sin firma de distribución.
- Suite inicial: 140 pruebas unitarias; 139 aprobadas. La restante detectó que un locale implícito antiguo y su nuevo valor explícito se comparaban como documentos distintos. Se corrigió la igualdad semántica conservando ambos formatos JSON.
- Repetición de TranslationTests y AppSettingsTests: **42/42 aprobadas**, incluyendo las doce direcciones, exportación coreana, migración V10→V11 y conservación de correcciones por destino tras reabrir.
- Inicio: nombres de botones, giro y pantalla completa aprobados en iPhone. Conversación francés/coreano aprobada con captura/traducción simuladas.
- Biblioteca iPhone: guardadas primero, borradores separados y tarjetas francés/coreano en Ambos aprobadas (`vtr-languages-library5.xcresult`).
- iPad Air: barra lateral, guardadas y borradores aprobados (`vtr-languages-ipad.xcresult`).
- Papelera: recorrido de eliminar, deshacer, restaurar y eliminar definitivamente aprobado.
- Compilación Release para simulador x86_64 aprobada. Permanecen las dos advertencias de concurrencia ya existentes (CaptionViewModel y callback de cierre de SessionTranslationView).
- Catálogos: 773 claves de interfaz y 2 de permisos, paridad en/es y cobertura de claves extraídas por el compilador.
- Sitio: 10 páginas bilingües, enlaces internos y ZIP de Hostinger validados. Texto App Store validado y paquete local regenerado; no enviado a Apple ni desplegado en Hostinger.

El recorrido final de Inicio y sus selectores compactos pasó en `vtr-languages-home-final.xcresult`, con nombres de idioma completos en vertical/horizontal.

Los resultados completos están en `/private/tmp/vtr-languages-unit.xcresult`, `/private/tmp/vtr-languages-final.xcresult` y sus logs. El primer resultado de interfaz contenía dos fallos de escenario: una sesión ficticia enviada a papelera sin finalizar y una comprobación de pulsación antes de acabar la animación del menú. Se corrigieron las fixtures; no se relajaron las protecciones de datos del producto. La prueba de reproducción encontró el mismo punto de activación AX inválido de SwiftUI Menu en iOS 17 que documentan los recorridos anteriores: se pulsa el centro visible del control y se verifica su selección real. Un intento posterior no llegó a iniciar XCTest y fue cancelado; se cerró el simulador adicional y se repitió con firma ad hoc local, sin modificar servicios del Mac ni datos del iPhone.

## Pendiente antes de publicar

Xcode 15.2 excluye el código de Translation y SpeechAnalyzer moderno. La validación local de las doce direcciones comprueba selección, texto, persistencia y voz solicitada mediante dobles; no certifica calidad ni disponibilidad de modelos Apple. Validar esos caminos con SDK reciente y francés/coreano en dispositivos reales, con descarga, modo avión, voces, interrupciones, VoiceOver y textos largos.

La documentación de soporte y el ZIP están preparados localmente. La nueva entrega no se considera disponible en TestFlight hasta confirmar el build de Xcode Cloud/App Store Connect. GitHub no expuso checks/statuses del commit previo al comenzar esta entrega.

## Evidencia visual

Capturas con contenido de prueba, sin grabaciones de usuarios: [biblioteca iPhone](qa/session-library-languages/library-iphone.png), [barra lateral iPad](qa/session-library-languages/library-ipad.png), [Inicio horizontal](qa/session-library-languages/home-names-landscape.png), [conversación francés/coreano](qa/session-library-languages/conversation-fr-ko.png), [reproducción bilingüe](qa/session-library-languages/playback-fr-ko.png).
