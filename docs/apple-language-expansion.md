# Alemán, neerlandés y ruso — 2026-11-20

> Corrección 2026-11-21: [instalación, dictado local y reservas de modelos](speech-preparation-and-language-swap.md). El camino de compatibilidad de esta entrega se amplía con DictationTranscriber antes del adaptador antiguo.

## Alcance

Se amplían los idiomas de contenido de seis a nueve: inglés, español, francés,
coreano, japonés, mandarín simplificado, alemán, neerlandés y ruso.
Los identificadores nuevos son `de-DE`, `nl-NL` y `ru-RU`; los códigos de
traducción/exportación son `de`, `nl` y `ru`. Se conservan todos los identificadores
previos, las preferencias existentes y el formato de las bibliotecas guardadas.
Rumano queda excluido de esta entrega.

- Los selectores compartidos permiten elegir los nuevos idiomas de origen/destino
  en Conversar, Escuchar, sesiones guardadas, Mis prácticas y Cuentos.
- Los nombres se muestran como Alemán · Deutsch, Neerlandés · Nederlands y
  Ruso · Русский en la interfaz española, con etiquetas accesibles existentes.
  Los botones de los participantes, finalizar y los saludos usan su propio idioma.
- Ajustes → Voces permite elegir y probar voces instaladas para cada idioma.
  La selección automática nunca elige una voz de otro idioma. Las preferencias
  de voz, vocabulario y colores siguen separadas por idioma.
- Ajustes → Colores incorpora tres preferencias persistentes y su restauración.
  Se propagan a tarjetas originales/traducidas, ambos diseños y pantalla completa.
- Lecciones guiadas incorpora 378 paquetes nuevos: 126 lecciones × tres idiomas.
  Incluyen títulos, objetivos, los 20 párrafos, explicaciones, expresiones,
  instrucciones y ficha. El total es 882 paquetes externos, además del español
  incluido en cada lección. El idioma aprendido y los 2520 audios siguen en inglés.
- Verbos añade significado y equivalencias de cada forma para los 130 verbos,
  en los tres idiomas. IPA y conjugaciones inglesas se conservan. La búsqueda
  existente también encuentra los nuevos significados.
- Los contenidos de Podcasts conservan su formato editorial actual inglés/español;
  esta entrega no crea episodios o narraciones adicionales.
- Menús y mensajes de la aplicación siguen en inglés/español. El idioma de
  contenido se escoge independientemente; no se añaden traducciones de la interfaz.

## Compatibilidad y privacidad

Durante el uso, reconocimiento, traducción y síntesis emplean exclusivamente
servicios de Apple. La disponibilidad real depende de la versión de iOS,
dispositivo, pareja de idiomas y recursos descargados. La app mantiene las
comprobaciones y mensajes existentes; un idioma seleccionado no garantiza que
su modelo esté instalado o admita reconocimiento local en ese dispositivo.

`LanguageSpeechTranscriber` selecciona el motor antes de capturar audio. Prefiere
el adaptador moderno existente; si informa idioma/dispositivo no compatible,
consulta el adaptador Apple de compatibilidad existente. Este exige
`supportsOnDeviceRecognition` y `requiresOnDeviceRecognition = true`. No hay
fallback remoto. Permisos, recursos locales ausentes y descargas mantienen sus
flujos. Un error o interrupción no cambia el motor durante una sesión. La elección
se mantiene al pausar/reanudar y se vuelve a resolver al cambiar de idioma.
Resultados de preparación cancelados o de un idioma anterior se descartan.

La traducción continúa comprobando `LanguageAvailability` antes de procesar.
Las confirmaciones, revisiones de Cuentos y edición manual no se eliminan.
Las preferencias de origen y destino siguen evitando escoger el mismo idioma.

Los nuevos textos educativos se preparan en desarrollo con el mismo procedimiento
de traducción por IA utilizado por los paquetes existentes. Se distribuyen como
JSON estáticos; la app no llama a OpenAI para generar estas traducciones ni
contiene su clave. Son traducciones automáticas, no una certificación lingüística.
No se envían grabaciones o textos del usuario durante esta preparación.
La revisión editorial de las nuevas glosas corrigió formas no traducidas, errores
morfológicos y sentidos distintos del ejemplo (cultivar verduras, extender una
manta, comer una comida y hacer una pausa). El validador incluye regresiones
para estas correcciones. Las sugerencias de revisión no se aplican indiscriminadamente.

Referencias de Apple consultadas:

- [Disponibilidad de Traducción](https://www.apple.com/ios/feature-availability/#translate-translate-app).
- [Idiomas de SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber/supportedlocales).
- [Idiomas de SFSpeechRecognizer y límites de disponibilidad](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportedlocales()).

La comprobación editorial también contrastó [behauen en Duden](https://www.duden.de/rechtschreibung/behauen) y [resetten en Onze Taal](https://onzetaal.nl/taalloket/engelse-werkwoorden).

## Generación y validación

`scripts/generate-lesson-support.py --lesson SPK-B1-001 --locales de nl ru`
conserva los paquetes existentes. El generador valida las claves y valores no
vacíos. `scripts/generate-verb-language-support.py` conserva los idiomas previos
y solo añade equivalencias faltantes. Ambos leen la clave local de desarrollo;
las credenciales no se imprimen ni se incorporan al repositorio.

Verificaciones ejecutadas correctamente en Windows (2026-11-20):

- Catálogos de interfaz: paridad inglés/español y parámetros de interpolación.
- Catálogos educativos: claves completas en los 882 paquetes, 130 verbos × nueve
  idiomas; integridad del audio y rangos UTF-16 de las 126 lecciones.
- Conservación exacta de lecciones, audio, tiempos, imágenes, episodios, cuentos
  y equivalencias de verbos anteriores frente al commit base.
- Referencias del proyecto Xcode, destinos, esquema, delimitadores Swift y diff.

Resultados: 1127 claves de interfaz con paridad, 126 lecciones completas, 2520
audios (291,6 MiB), 882 paquetes externos, 130 verbos completos en nueve idiomas
y los 30 fragmentos del podcast sin cambios. Se verificó que el generador de
glosas conserva los idiomas ya presentes sin volver a llamar a la API.

XCTest ampliado para persistencia de los nuevos idiomas/colores, restauración,
compatibilidad de voces, serialización y exportación en ambos sentidos, carga de
todos los paquetes y selección/cancelación de motores locales. Windows no tiene
Xcode ni simulador: estas pruebas nativas quedan preparadas para Mac. Un archivo
compilado en Xcode Cloud no demuestra por sí solo que XCTest haya sido ejecutado.

Aceptación en iPhone/iPad: elegir cada idioma en ambos sentidos; comprobar
permisos/modelos y prueba sin red, pausa/reanudación, grabación/guardado/exportación,
voces descargadas, tarjetas y colores, columnas/pantalla completa, contenido de
las 126 lecciones y búsqueda/glosas de Verbos. Probar también los seis idiomas
anteriores, Dynamic Type y VoiceOver.

La detección automática entre dos idiomas sigue aplazada; véase
[la propuesta documentada](automatic-listening-language-detection.md).
