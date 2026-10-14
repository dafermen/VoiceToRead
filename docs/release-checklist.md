# Lista de publicación — VoiceToRead

## Identidad y distribución nueva

- [x] Crear registro VoiceToRead con bundle com.innovalogic.voicetoread: Apple ID 6822564230, confirmado por captura del titular del 2026-10-13.
- [ ] Verificar firma del nuevo identificador con el equipo configurado 7799N4RYUG.
- [x] Alinear MARKETING_VERSION a 1.0 en Debug/Release (2026-10-14).
- [x] Crear/conectar repositorio GitHub independiente: `dafermen/VoiceToRead`, rama `main`.
- [x] Cloud y grupo Dev configurados para pruebas internas; titular confirma instalación en iPhone.
- [ ] Cambiar Archive a TestFlight and App Store y crear una compilación pública 1.0 nueva.
- [ ] Verificar esquema VoiceToRead, versión/build efectivos, firma y SDK admitido al enviar.
- [ ] Compilar ramas modernas de Speech/Translation con SDK compatible.
- [ ] Verificar exportación, subida, procesamiento, asignación a testers e instalación de esta app.

## Validación funcional

- [x] Registrar validaciones locales de esta copia en project-identity.md; limitaciones y warnings explícitos.
- [ ] Probar iPhone/iPad reales, ambos idiomas, permisos, descarga de modelos y modo avión.
- [ ] Verificar pausa/alarma/reanudar, segundo plano y sesiones de 30/60/120 minutos.
- [ ] Probar guardado, recuperación, edición, favoritos, audio y exportaciones TXT/PDF/SRT/WebVTT.
- [ ] Probar VoiceOver, texto grande, contraste, tarjetas bilingües, renglones y orientación.
- [ ] Verificar protección de datos, exclusión de respaldo y recuperación ante errores del almacén.
- [ ] Confirmar que la instalación anterior conserva sus datos; ninguna migración entre apps está implementada.

## Publicación pública

- [x] Responsable y contacto confirmados: Dario Fernando Meneses Ceron, dariofernandomeneses@gmail.com.
- [x] Sitio previsto: voicetoread.innovalogic.tech, Hostinger/hPanel.
- [x] Política de correos de soporte confirmada: Gmail, 90 días tras resolución salvo obligación legal.
- [x] Web bilingüe y ZIP de hPanel preparados; [guía](website-publication.md).
- [x] HTTPS válido en privacidad y soporte EN/ES, 2026-10-14.
- [x] Añadir enlaces EN/ES, responsable y contacto/retención/web dentro de la política local.
- [x] Páginas de privacidad y soporte EN/ES responden HTTPS 200 con contacto correcto.
- [ ] Confirmar licencia/copyright, precio, territorios, categorías y versión pública.
- [ ] Completar privacidad, edad y cifrado según el binario final.
- [x] Preparar y revisar visualmente 12 capturas reales EN/ES en simuladores iPhone/iPad, tamaños y JPEG sin alfa comprobados.
- [ ] Comparar los candidatos de screenshots contra el build público final.
- [ ] Completar contacto privado de App Review.
- [ ] Ejecutar scripts/validate-store-metadata.py --ready tras resolver los pendientes.
- [ ] Obtener instrucción del titular para envío público a App Review.

Las pruebas ya ejecutadas se registran en [inicio del proyecto](project-identity.md). Los reports/checkpoints anteriores son antecedentes del código base, no evidencia de aceptación de la identidad nueva.

Decisión del titular (2026-10-14): gratuita, sin compras dentro de la app, Estados Unidos y Colombia. Falta aplicarla en App Store Connect. Ver [paquete de entrega](store/submission-kit.md).
