# Publicación del sitio de VoiceToRead en Hostinger

Preparado el **13 de octubre de 2026**. El titular confirmó el subdominio y el uso del Administrador de archivos de hPanel. Responsable: **Dario Fernando Meneses Ceron**, persona natural. Contacto: **dariofernandomeneses@gmail.com**.

## Estado y decisiones confirmadas

- Web bilingüe preparada en `website/dist/`, con inicio, privacidad, soporte, seguridad y accesibilidad.
- ZIP local: `website/VoiceToRead-Hostinger.zip`. Puede regenerarse desde GitHub con `python3 website/build.py`.
- Soporte por Gmail. El titular aprobó eliminar correos del buzón dentro de los 90 días posteriores a resolver una consulta, salvo obligación legal. La política aclara que los respaldos del proveedor siguen sus propios procesos. Este es un procedimiento que el titular debe cumplir; la web no borra correos automáticamente.
- No se dispone de acceso autenticado a hPanel en esta sesión. No se han subido archivos, modificado DNS ni cambiado el sitio principal.
- Incidente inicial: HTTPS fallaba por certificado sin el subdominio. **Resuelto en la comprobación del 2026-10-14:** privacidad y soporte EN/ES responden HTTPS 200 con verificación TLS y contacto correcto. No fue necesario desactivar TLS.

## Subir el ZIP con hPanel

1. En Hostinger, abrir el panel del alojamiento que contiene **voicetoread.innovalogic.tech**. Consultar la carpeta asignada al subdominio. No asumir que es la raíz `public_html` del dominio principal: puede tener una carpeta propia.
2. En **Administrador de archivos**, abrir esa carpeta. Si ya contiene una web, descargar una copia de sus archivos antes de reemplazar nada. No tocar carpetas de otras webs.
3. Subir `VoiceToRead-Hostinger.zip` y elegir **Extraer** en la carpeta del subdominio. Deben quedar `index.html`, `assets/`, `privacy/`, `support/`, `security/`, `accessibility/`, `en/`, `robots.txt` y `sitemap.xml` directamente allí, sin una carpeta adicional `dist` o `website`.
4. Si existe una portada de bienvenida (`index.php`, `default.php` u otra), identificarla y conservar una copia antes de retirarla. La prioridad del servidor puede ocultar el nuevo `index.html`. No eliminar archivos desconocidos del sitio principal.
5. En la sección **SSL** del panel, comprobar el certificado para el subdominio completo y activar/instalar el SSL de Hostinger si hace falta. Confirmar que el subdominio apunta al alojamiento correcto si la emisión falla. No comprar un certificado ni cambiar DNS a ciegas.
6. Con SSL válido, activar la redirección HTTPS desde hPanel si no está activa. No compartir contraseñas o claves en el chat.
7. Comprobar las rutas de la tabla siguiente en ventana privada y desde un iPhone, sin sesión de Hostinger. Cambiar entre Español y English, comprobar texto completo, navegación, ampliación de texto y correo de contacto.
8. El ZIP ya no es necesario en el servidor tras extraerlo; puede eliminarse allí, conservando la copia local.

Guías oficiales: [Administrador de archivos de Hostinger](https://www.hostinger.com/support/4548688-basic-actions-in-the-file-manager-in-hostinger/), [SSL de Hostinger](https://support.hostinger.com/en/articles/1583258-how-to-install-lifetime-ssl-at-hostinger), [problemas al emitir SSL](https://www.hostinger.com/support/5613445-how-to-fix-a-failed-lifetime-ssl-installation-in-hostinger/).

## URLs públicas para Apple

| Campo | URL pública verificada |
|---|---|
| Marketing URL / web | `https://voicetoread.innovalogic.tech/` |
| Privacy Policy URL | `https://voicetoread.innovalogic.tech/privacy/` |
| Support URL | `https://voicetoread.innovalogic.tech/support/` |
| Privacidad en inglés | `https://voicetoread.innovalogic.tech/en/privacy/` |
| Soporte en inglés | `https://voicetoread.innovalogic.tech/en/support/` |

El 2026-10-14 se completaron `privacyPolicyURL` y `supportURL` de `docs/app-store-metadata.json` con URLs verificadas y se añadieron los enlaces, responsable y apartados de soporte/web a la política local de la app. Copiar las URLs del idioma correspondiente en App Store Connect. La app mantiene el texto local para consultar sin Internet.

Apple exige una política accesible y datos de contacto de soporte. Seguridad y accesibilidad complementan la web; no reemplazan los formularios de App Store Connect. Fuentes: [App Review, sección 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy), [gestionar App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/), [preparación para revisión](https://developer.apple.com/app-store/review/).

## Lo que la web no resuelve por sí sola

Registro e instalación interna confirmados. Continúan pendientes la distribución pública 1.0, aceptación física final, revisión de capturas, edad, cifrado, App Privacy y contacto privado del revisor. El titular eligió gratuita y Estados Unidos/Colombia; falta aplicar estas opciones en Apple. La web no garantiza aprobación. Ver [preparación de App Store](app-store.md) y [checklist](release-checklist.md).

No se ha creado un contrato EULA personalizado ni se han inventado datos fiscales o jurídicos. Revisar el acuerdo estándar de Apple al preparar la ficha. No cambiar de categoría a Kids por mencionar aprendizaje supervisado.

## Para estudiantes: cómo funciona esta web

1. **Contenido:** Python lee los documentos de privacidad y soporte del repositorio. Así una corrección de política se mantiene en una fuente, no en diez copias manuales.
2. **Presentación:** `build.py` combina ese contenido con HTML semántico (`header`, `nav`, `main`, `article`, `footer`). CSS organiza columnas en escritorio y una columna en pantallas pequeñas.
3. **Idiomas:** cada idioma tiene URLs propias. Los enlaces permiten pasar a la misma página en el otro idioma, incluso sin JavaScript. `lang` ayuda al lector de pantalla a pronunciar correctamente.
4. **Despliegue:** el servidor solo entrega archivos. No ejecuta Python ni recibe formularios. El correo usa un enlace `mailto:` que abre el programa de correo del visitante.
5. **Verificación:** `check.py` detecta enlaces rotos, anclas inexistentes, falta de idioma y diferencias entre los archivos y el ZIP. Una revisión visual complementa esos controles; no prueba por sí sola accesibilidad integral.
6. **HTTPS:** el certificado debe incluir el nombre del subdominio. Un fallo de certificado sucede antes de que el navegador pueda confiar en la página; modificar HTML no lo corrige.

Para actualizar, editar fuentes, regenerar, validar y subir el nuevo ZIP. No editar solo `dist/`: el siguiente build sobrescribiría esos cambios. Si se añade analítica, formularios o un proveedor externo, revisar también privacidad y las declaraciones de la tienda.

## Validación de esta entrega

- Generación y validación de 10 páginas EN/ES; enlaces internos, anclas y recursos sin fallos.
- ZIP comprobado byte por byte contra los archivos de `dist/`.
- Las diez rutas devolvieron HTTP 200 en un servidor local.
- Chrome temporal: 40 combinaciones de página/ancho (320, 390, 768 y 1440 px), sin desbordamiento horizontal; cambio de idioma de privacidad a su equivalente correcto.
- Revisión visual de portada en escritorio y móvil, y privacidad en inglés en móvil. No equivale a una auditoría completa con lector de pantalla.
- Metadata EN/ES dentro de límites. No se ejecutaron pruebas de la app: esta entrega solo modifica web/documentación, sin cambios Swift ni de firma.
- Comprobación posterior 2026-10-14: privacidad y soporte EN/ES publicados, HTTPS 200 y contacto presente.
