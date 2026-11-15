# Pendiente: detección automática entre dos idiomas en Escuchar

Fecha: 2026-11-15. **Estado: propuesta para un bloque futuro. No hay un interruptor de detección automática ni cambios de reconocedor en esta entrega.**

## Objetivo propuesto

Permitir que, de los dos idiomas elegidos por el usuario, se detecte el idioma hablado y se traduzca al otro. Por ejemplo, inglés → español o español → inglés. La selección manual seguiría disponible. De aprobarse tras pruebas, el modo automático sería optativo y estaría desactivado inicialmente.

## Viabilidad por validar

Los backends actuales se configuran con un idioma concreto. Apple documenta un `locale` para [SFSpeechRecognizer](https://developer.apple.com/documentation/speech/sfspeechrecognizer/init%28locale%3A%29) y para [SpeechTranscriber](https://developer.apple.com/documentation/speech/speechtranscriber/init%28locale%3Atranscriptionoptions%3Areportingoptions%3Aattributeoptions%3A%29). Estas interfaces no demuestran por sí solas que la app pueda alternar con fiabilidad entre los dos idiomas en un flujo continuo.

No basta con detectar el idioma del texto obtenido: si se transcribió usando el idioma equivocado, ese texto puede estar mal y no ser una señal fiable. Hay que evaluar la identificación a partir del audio y su integración con los motores disponibles, recursos descargados y dispositivos compatibles.

La sesión guardada tiene actualmente un idioma principal. Una implementación bilingüe deberá resolver el idioma por párrafo, la dirección de traducción y la persistencia antes de cambiarlo automáticamente. No debe reinterpretar como otro idioma los párrafos ya capturados ni alterar sesiones anteriores.

## Riesgo de pérdida de palabras y retraso

Todavía **no se sabe cuánto retraso añadiría ni si perdería palabras**: no se ha hecho un prototipo ni una medición. Es un cambio funcional, no un checkbox de presentación.

Factores que se deben comprobar:

- La identificación puede necesitar contexto adicional. Esperar ese contexto podría retrasar el primer texto.
- Cambiar o reiniciar un reconocedor podría afectar palabras que estén en proceso o justo en el límite entre idiomas.
- Frases cortas, nombres, números, préstamos y cambios de idioma dentro de una oración pueden producir decisiones incorrectas u oscilaciones.
- Ejecutar trabajo adicional podría aumentar uso de CPU, memoria, batería y temperatura; hay que medirlo en dispositivos reales.
- Recursos no descargados o diferencias entre motores/dispositivos podrían limitar los pares disponibles o provocar errores.

Son riesgos a investigar, no fallos comprobados de la app ni efectos de la opción de tiempos por párrafo.

## Prototipo y aceptación antes de integrar

1. Definir si se detectará al comenzar una intervención o continuamente, y qué hacer cuando no haya confianza suficiente. Diseñar una vuelta clara al modo manual.
2. Mantener la captura independiente de la decisión de idioma. Investigar cómo conservar los límites y rangos de los fragmentos sin descartar audio o duplicar palabras. No ocultar retrasos mediante buffers que crezcan sin límite.
3. Comparar modo manual y prototipo con el mismo audio de referencia: palabras omitidas, sustituidas y repetidas, especialmente al inicio y al alternar; tiempo hasta texto provisional y final; exactitud de la dirección de traducción.
4. Probar frases completas y mezcladas, silencios, ruido, habla rápida, pausas/reanudación, interrupciones, segundo plano y rutas de audio. Verificar la compatibilidad por par y el funcionamiento sin red.
5. Medir consumo, memoria y latencia durante sesiones largas; conservar las marcas de tiempo y las identidades de párrafo al recibir revisiones tardías.
6. Fijar criterios de aceptación a partir de las mediciones y conservar el funcionamiento manual si no se cumplen. No prometer ausencia de pérdida de palabras o latencia adicional sin evidencia.

Implementar y presentar un interruptor solo después de esa evaluación y de un alcance aprobado para el siguiente bloque. La entrega actual añade únicamente tiempos visibles y no activa ninguno de estos procesos.
