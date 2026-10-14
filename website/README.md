# Web pública de VoiceToRead

Sitio estático EN/ES para **https://voicetoread.innovalogic.tech/**. Preparado para subir con el Administrador de archivos de hPanel. **La preparación local no equivale a publicación.**

## Generar y comprobar

Desde la raíz del repositorio, con Python 3.9 o posterior:

```sh
python3 website/build.py
python3 website/check.py
python3 -m http.server 8765 --bind 127.0.0.1 --directory website/dist
```

Abrir `http://127.0.0.1:8765/`. Detener con Control-C. Los enlaces parten de la raíz del sitio; para previsualizar usar el servidor, no abrir HTML directamente con `file://`.

- `build.py`: plantilla HTML y textos de presentación, seguridad y accesibilidad.
- `style.css`: diseño adaptable, foco de teclado, impresión y contraste forzado.
- `../docs/privacy-policy-draft.md`: fuente bilingüe de la política. El generador extrae los apartados por idioma y excluye las notas editoriales.
- `../docs/store/support.md`: fuente de preguntas frecuentes.
- `dist/`: archivos públicos generados y versionados; no editar directamente.
- `VoiceToRead-Hostinger.zip`: artefacto local regenerable, excluido de Git; contiene únicamente `dist/`, sin carpeta contenedora.
- `check.py`: comprueba estructura, idiomas, enlaces, anclas, recursos y contenido exacto del ZIP. No certifica accesibilidad ni publicación.

La web funciona sin JavaScript, cookies propias, cuentas, formularios, paquetes npm ni fuentes externas. Las consultas se abren en el correo del visitante. Los registros del alojamiento y Gmail se explican por separado en la política.

## Rutas

| Página | Español | English |
|---|---|---|
| Inicio | `/` | `/en/` |
| Privacidad | `/privacy/` | `/en/privacy/` |
| Soporte | `/support/` | `/en/support/` |
| Seguridad | `/security/` | `/en/security/` |
| Accesibilidad | `/accessibility/` | `/en/accessibility/` |

Cada selector de idioma conserva la página actual. Se generan canonical, hreflang, sitemap y robots. La portada indica que App Store está en preparación; no hay enlace ficticio de descarga. El ejemplo de subtítulos es ilustrativo, no una captura real de la app.

Para publicar y completar App Store Connect, seguir [la guía de Hostinger](../docs/website-publication.md).
