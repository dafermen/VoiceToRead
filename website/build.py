#!/usr/bin/env python3
"""Build a portable, bilingual HTML site using only Python's standard library.

Edit policy/support in docs/, presentation copy below and style.css. No content is
fetched at build time, and the deployed pages need no Python or JavaScript.
"""
from pathlib import Path
from html import escape
import re
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
HERE = ROOT / 'website'
OUT = HERE / 'dist'
BASE = 'https://voicetoread.innovalogic.tech'
EMAIL = 'dariofernandomeneses@gmail.com'
OWNER = 'Dario Fernando Meneses Ceron'
DATE = '2026-10-13'
PAGES = ('home', 'privacy', 'support', 'security', 'accessibility')
COPY = {
    'es': {
        'names': ['Inicio', 'Privacidad', 'Soporte', 'Seguridad', 'Accesibilidad'],
        'skip': 'Saltar al contenido', 'nav': 'Navegación principal',
        'lang': 'Cambiar idioma', 'other': 'English', 'otherCode': 'en',
        'tag': 'SUBTÍTULOS · TRADUCCIÓN · PRÁCTICA',
        'hero': 'Cada voz,<br><em>a tu ritmo.</em>',
        'intro': 'Sigue una conversación, lee en dos idiomas y vuelve a escuchar una frase cuando lo necesites. VoiceToRead te ayuda a comprender con más calma.',
        'platform': 'Para iPhone y iPad compatibles', 'status': 'Publicación en App Store en preparación',
        'help': 'Conoce cómo funciona', 'private': 'Lee nuestra política de privacidad',
        'example': 'Ejemplo ilustrativo de lectura bilingüe', 'exampleTitle': 'Una idea, dos idiomas.',
        'original': 'Original · Inglés', 'translation': 'Traducción · Español',
        'phrase': 'Take your time. We can read this together.',
        'translated': 'Tómate tu tiempo. Podemos leer esto juntos.',
        'exampleNote': 'El texto original y su traducción se distinguen con etiquetas y color.',
        'section': 'Más espacio para comprender.',
        'features': [('01', 'Lee con comodidad', 'Amplía el texto, ajusta el contraste o usa pantalla completa. Elige un fondo suave y guías de lectura.'), ('02', 'Escucha a tu ritmo', 'Reproduce un párrafo, repítelo y corrige sus palabras antes de pasar al siguiente. Tú decides cuándo avanzar.'), ('03', 'Practica un idioma', 'Escucha una frase y compara tu pronunciación. Usa inglés o español sin cambiar el idioma de los menús.')],
        'privacyTitle': 'Tus conversaciones, en tu dispositivo.',
        'privacyText': 'La app no envía tus grabaciones ni transcripciones a un servidor del desarrollador. Tú decides qué guardar, borrar y compartir.',
        'privacyNote': 'Las sesiones no forman parte del respaldo del dispositivo. Exporta lo importante antes de desinstalar.',
        'accessTitle': 'Distintas formas de seguir la misma conversación.',
        'accessText': 'Herramientas de lectura para apoyar a personas con dificultades auditivas o baja visión, y práctica de idiomas con acompañamiento adulto para niños. La disponibilidad de funciones depende del dispositivo y los modelos instalados.',
        'accessLink': 'Explora las opciones de accesibilidad',
        'limits': 'Los subtítulos y las traducciones pueden contener errores. Comprueba la información importante. VoiceToRead no sustituye la interpretación profesional ni los servicios de accesibilidad que necesites.',
        'updated': 'Actualizado el 13 de octubre de 2026', 'onPage': 'En esta página',
        'privacyIntro': 'Qué información utiliza VoiceToRead, dónde permanece y qué puedes hacer con ella.',
        'supportIntro': 'Respuestas claras para empezar, recuperar una sesión y leer a tu ritmo.',
        'securityIntro': 'Cómo cuidar tus grabaciones y comunicar un problema de seguridad.',
        'accessibilityIntro': 'Ajusta la lectura a tus necesidades. Si encuentras una barrera, queremos conocerla.',
        'contact': 'Hablemos', 'contactText': '¿Necesitas ayuda o tienes una consulta de privacidad?',
        'emailLink': 'Escribir al soporte', 'owner': 'Responsable · Persona natural',
        'footer': 'Una herramienta de InnovaLogic para leer lo que se dice.',
    },
    'en': {
        'names': ['Home', 'Privacy', 'Support', 'Security', 'Accessibility'],
        'skip': 'Skip to content', 'nav': 'Main navigation',
        'lang': 'Change language', 'other': 'Español', 'otherCode': 'es',
        'tag': 'CAPTIONS · TRANSLATION · PRACTICE',
        'hero': 'Every voice,<br><em>at your pace.</em>',
        'intro': 'Follow a conversation, read in two languages and listen to a phrase again whenever you need. VoiceToRead gives you room to understand.',
        'platform': 'For compatible iPhone and iPad devices', 'status': 'App Store release in preparation',
        'help': 'See how it works', 'private': 'Read our privacy policy',
        'example': 'Illustrative bilingual reading example', 'exampleTitle': 'One idea, two languages.',
        'original': 'Original · English', 'translation': 'Translation · Spanish',
        'phrase': 'Take your time. We can read this together.',
        'translated': 'Tómate tu tiempo. Podemos leer esto juntos.',
        'exampleNote': 'Labels and color distinguish the original text from its translation.',
        'section': 'More room to understand.',
        'features': [('01', 'Read comfortably', 'Enlarge the text, adjust contrast or go fullscreen. Choose a soft background and reading guides.'), ('02', 'Listen at your pace', 'Play one paragraph, repeat it and correct its words before moving on. You decide when to continue.'), ('03', 'Practice a language', 'Listen to a phrase and compare your pronunciation. Use English or Spanish independently of the menu language.')],
        'privacyTitle': 'Your conversations, on your device.',
        'privacyText': 'The app does not send your recordings or transcripts to a developer server. You choose what to save, delete and share.',
        'privacyNote': 'Sessions are excluded from device backup. Export important content before uninstalling.',
        'accessTitle': 'Different ways to follow the same conversation.',
        'accessText': 'Reading tools to support people with hearing loss or low vision, plus language practice for children with adult guidance. Feature availability depends on your device and installed models.',
        'accessLink': 'Explore accessibility options',
        'limits': 'Captions and translations may contain errors. Check important information. VoiceToRead does not replace professional interpretation or the accessibility services you need.',
        'updated': 'Updated October 13, 2026', 'onPage': 'On this page',
        'privacyIntro': 'What information VoiceToRead uses, where it stays and the choices you have.',
        'supportIntro': 'Clear answers to help you start, recover a session and read at your own pace.',
        'securityIntro': 'How to look after your recordings and report a security concern.',
        'accessibilityIntro': 'Make reading work for you. If you encounter a barrier, we want to hear about it.',
        'contact': 'Get in touch', 'contactText': 'Need help or have a privacy question?',
        'emailLink': 'Email support', 'owner': 'Responsible person · Individual',
        'footer': 'An InnovaLogic tool to read what is being said.',
    },
}
SECURITY = {
'es': '''### Grabación bajo tu control
El micrófono empieza cuando inicias o reanudas la escucha. Guardar audio está activado inicialmente y puedes desactivarlo antes de empezar. Continuar en segundo plano es opcional. Después de una interrupción, comprueba el estado y pulsa Reanudar cuando estés listo.

### Protege el dispositivo y tus copias
Usa el código de bloqueo y mantén iOS o iPadOS actualizado. Las sesiones se guardan en el espacio local de la app; esto no es una garantía de seguridad absoluta. Exporta solo a destinos en los que confíes y revisa quién puede acceder a ellos. Las favoritas evitan borrados accidentales, pero no crean una copia de seguridad.

### Respeta a quienes participan
Antes de grabar o compartir una conversación, informa a quienes participan y obtén los permisos necesarios. Evita incluir información sensible de otras personas en consultas al soporte. Comprueba y corrige la transcripción antes de compartirla.

### Comunica un problema de seguridad
Escribe a [dariofernandomeneses@gmail.com](mailto:dariofernandomeneses@gmail.com) con el asunto «VoiceToRead — Seguridad». Incluye la versión de la app, el dispositivo, lo que ocurrió y los pasos para reproducirlo. No incluyas contraseñas, claves ni grabaciones privadas. Te contactaremos por correo para revisar el caso; no ofrecemos un servicio de emergencias ni un plazo de respuesta garantizado.

### Información relacionada
La [política de privacidad](/privacy/) explica almacenamiento, eliminación, soporte y servicios de terceros. En [Soporte](/support/) encontrarás ayuda para los problemas más habituales.''',
'en': '''### Recording under your control
The microphone starts when you start or resume listening. Audio saving is initially enabled and you can turn it off before starting. Background continuation is optional. After an interruption, check the recording state and choose Resume when you are ready.

### Protect your device and exported copies
Use a device passcode and keep iOS or iPadOS updated. Sessions are saved in the app’s local storage; this is not a guarantee of absolute security. Export only to destinations you trust and check who can access them. Favorites protect against accidental deletion, but do not create a backup.

### Respect the people taking part
Before recording or sharing a conversation, inform participants and obtain the necessary permissions. Avoid including other people’s sensitive information in support requests. Check and correct transcripts before sharing them.

### Report a security concern
Email [dariofernandomeneses@gmail.com](mailto:dariofernandomeneses@gmail.com) with the subject “VoiceToRead — Security”. Include the app version, device, what happened and reproduction steps. Do not include passwords, keys or private recordings. We will follow up by email to investigate; this is not an emergency service and no response time is guaranteed.

### Related information
The [privacy policy](/en/privacy/) explains storage, deletion, support and third-party services. Visit [Support](/en/support/) for help with common problems.'''
}
ACCESS = {
'es': '''### Leer y escuchar a tu ritmo
VoiceToRead ofrece texto grande o en negrita, ajustes de interlineado, contraste alto, fondos claros y guías de lectura opcionales. Puedes usar pantalla completa y orientación vertical u horizontal en iPhone y iPad compatibles.

En las sesiones guardadas, «A mi ritmo» reproduce un párrafo y espera a que elijas el siguiente. Puedes repetirlo, corregirlo y volver a leer sin avanzar automáticamente.

### Dos idiomas, claramente separados
Elige inglés o español para capturar voz. Esta elección es independiente del idioma de la interfaz. Durante la lectura en vivo, Original, Traducción o Ambos permiten elegir qué ver. Las tarjetas bilingües tienen etiquetas de idioma, además de colores distintos.

### Una ayuda, con límites claros
La app puede apoyar la lectura a personas con dificultades auditivas o baja visión. No se garantiza que responda a todas las necesidades de accesibilidad. Las transcripciones y traducciones pueden equivocarse; comprueba datos importantes. No sustituye servicios profesionales de interpretación ni debe usarse como único recurso en una emergencia.

Los niños pueden practicar un idioma con acompañamiento adulto. La comparación de pronunciación es una práctica de escucha y repetición, no una evaluación clínica ni una puntuación de pronunciación.

### Preparación antes de una conversación
La app requiere iOS o iPadOS 17 o posterior. La traducción requiere iOS o iPadOS 18 o posterior, una compilación compatible y modelos preparados. El reconocimiento local depende del dispositivo y del idioma. Prepara los recursos con Internet y comprueba su disponibilidad antes de una reunión o clase.

### Accesibilidad de esta web
Las páginas usan títulos y enlaces descriptivos, etiquetas de idioma, navegación por teclado y un enlace para saltar al contenido. Puedes ampliar el texto desde tu navegador. La información no depende solo del color y las páginas funcionan sin JavaScript.

### Ayúdanos a detectar barreras
Escribe a [dariofernandomeneses@gmail.com](mailto:dariofernandomeneses@gmail.com). Indica la pantalla o página, el dispositivo y la herramienta de accesibilidad que utilizas, si corresponde. No necesitas compartir un diagnóstico médico. Revisaremos tu caso para buscar una solución.''',
'en': '''### Read and listen at your own pace
VoiceToRead offers larger or bold text, line spacing, high contrast, light backgrounds and optional reading guides. You can use fullscreen and portrait or landscape orientation on compatible iPhone and iPad devices.

In saved sessions, At my pace plays one paragraph and waits for you to choose the next. You can repeat it, correct it and reread without automatically advancing.

### Two languages, clearly separated
Choose English or Spanish for speech capture, independently of the interface language. During live reading, Original, Translation or Both lets you choose what to see. Bilingual cards have language labels as well as different colors.

### Support with clear limits
The app can support reading for people with hearing loss or low vision. It is not guaranteed to meet every accessibility need. Captions and translations can be wrong; verify important details. It does not replace professional interpretation and should not be your only resource in an emergency.

Children can practice a language with adult guidance. Pronunciation comparison is a listening and repetition exercise, not a clinical assessment or a pronunciation score.

### Prepare before a conversation
The app requires iOS or iPadOS 17 or later. Translation requires iOS or iPadOS 18 or later, a compatible build and prepared models. Local recognition depends on your device and language. Prepare resources while online and check availability before a meeting or class.

### Accessibility on this website
These pages use descriptive headings and links, language labels, keyboard navigation and a skip-to-content link. You can enlarge text in your browser. Information does not rely on color alone, and the pages work without JavaScript.

### Help us identify barriers
Email [dariofernandomeneses@gmail.com](mailto:dariofernandomeneses@gmail.com). Tell us which screen or page, device and assistive tool you use, if applicable. You do not need to share a medical diagnosis. We will review your report to look for a solution.'''
}


def url(lang, page='home'):
    return ('/en/' if lang == 'en' else '/') + (page + '/' if page != 'home' else '')


def inline(source):
    # Escape source text first. Only explicit Markdown links and bold are allowed.
    value = escape(source)
    value = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', value)
    return re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', value)


def markdown(source, lang):
    """The docs use a small Markdown subset: paragraphs, h3 and bullet lists."""
    # Markdown permits a paragraph immediately after a heading without a blank line.
    source = re.sub(r'^(### [^\n]+)\n(?=\S)', r'\1\n\n', source, flags=re.MULTILINE)
    output, headings = [], []
    for block in source.strip().split('\n\n'):
        if block.startswith('### '):
            title = block[4:]
            anchor = 'section-' + str(len(headings) + 1)
            headings.append((anchor, title))
            output.append(f'<h2 id="{anchor}">{inline(title)}</h2>')
        elif block.startswith('- '):
            items = block.split('\n- ')
            output.append('<ul>' + ''.join('<li>' + inline(x.removeprefix('- ')) + '</li>' for x in items) + '</ul>')
        else:
            output.append('<p>' + inline(block.replace('\n', ' ')) + '</p>')
    html = '\n'.join(output)
    html = html.replace('../privacy-policy-draft.md', url(lang, 'privacy'))
    return html, headings


def doc_section(file, lang):
    source = (ROOT / file).read_text()
    heading = '## Español' if lang == 'es' else '## English'
    return source.split(heading + '\n', 1)[1].split('\n## ', 1)[0].split('\n---', 1)[0].strip()


def layout(lang, page, body):
    c = COPY[lang]
    name = c['names'][PAGES.index(page)]
    title = 'VoiceToRead — ' + (('Lee lo que se dice' if lang == 'es' else 'Read what is being said') if page == 'home' else name)
    desc = c['intro'] if page == 'home' else c[page + 'Intro']
    nav = ''.join(f'<a href="{url(lang,p)}"' + (' aria-current="page"' if p == page else '') + f'>{c["names"][PAGES.index(p)]}</a>' for p in ('privacy', 'support', 'accessibility'))
    footer_nav = ''.join(f'<a href="{url(lang,p)}">{c["names"][PAGES.index(p)]}</a>' for p in PAGES[1:])
    return f'''<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{escape(title)}</title>
<meta name="description" content="{escape(desc)}">
<meta name="theme-color" content="#142c3a">
<link rel="canonical" href="{BASE}{url(lang,page)}">
<link rel="alternate" hreflang="es" href="{BASE}{url('es',page)}">
<link rel="alternate" hreflang="en" href="{BASE}{url('en',page)}">
<link rel="alternate" hreflang="x-default" href="{BASE}{url('es',page)}">
<link rel="icon" type="image/png" href="/assets/app-icon.png">
<link rel="stylesheet" href="/assets/style.css">
</head>
<body>
<a class="skip" href="#main">{c['skip']}</a>
<header class="header wrap">
<a class="brand" href="{url(lang)}"><img src="/assets/app-icon.png" width="42" height="42" alt=""><span>VoiceToRead<small>by InnovaLogic</small></span></a>
<nav aria-label="{c['nav']}">{nav}</nav>
<a class="language" href="{url(c['otherCode'],page)}" lang="{c['otherCode']}" hreflang="{c['otherCode']}" aria-label="{c['lang']}: {c['other']}">{c['other']} <span aria-hidden="true">↗</span></a>
</header>
<main id="main" tabindex="-1">{body}</main>
<footer class="footer"><div class="wrap"><div class="footer-top"><div><a class="footer-brand" href="{url(lang)}">VoiceToRead<span aria-hidden="true">.</span></a><p>{c['footer']}</p></div><nav aria-label="{'Más información' if lang == 'es' else 'More information'}">{footer_nav}</nav></div><div class="footer-bottom"><p>{c['owner']}<br><strong>{OWNER}</strong></p><a class="email" href="mailto:{EMAIL}">{EMAIL}</a><a href="https://innovalogic.tech/">InnovaLogic <span aria-hidden="true">↗</span></a></div></div></footer>
</body></html>'''


def contact(lang):
    c = COPY[lang]
    return f'<section class="contact"><div><h2>{c["contact"]}</h2><p>{c["contactText"]}</p></div><a class="button" href="mailto:{EMAIL}?subject=VoiceToRead">{c["emailLink"]} <span aria-hidden="true">↗</span></a></section>'


def home(lang):
    c = COPY[lang]
    features = ''.join(f'<article><span class="number">{n}</span><h3>{title}</h3><p>{text}</p></article>' for n,title,text in c['features'])
    return f'''<section class="hero wrap"><div class="hero-copy"><p class="eyebrow">{c['tag']}</p><h1>{c['hero']}</h1><p class="lead">{c['intro']}</p><a class="button" href="{url(lang,'support')}">{c['help']} <span aria-hidden="true">↗</span></a><p class="availability">{c['platform']}<br><span>{c['status']}</span></p></div><figure class="reading-example"><figcaption>{c['example']}</figcaption><div class="example-frame"><div class="frame-heading"><span class="reading-dot" aria-hidden="true"></span>VoiceToRead<span aria-hidden="true">Aa</span></div><h2>{c['exampleTitle']}</h2><div class="caption-card english"><p class="caption-label">{c['original']}</p><p lang="en">{c['phrase']}</p></div><div class="caption-card spanish"><p class="caption-label">{c['translation']}</p><p lang="es">{c['translated']}</p></div><p class="example-note">{c['exampleNote']}</p></div></figure></section>
<section class="features wrap"><h2>{c['section']}</h2><div class="feature-grid">{features}</div></section>
<section class="privacy-band"><div class="wrap privacy-inner"><div><p class="eyebrow">{'PRIVACIDAD DESDE EL PRINCIPIO' if lang == 'es' else 'PRIVACY FROM THE START'}</p><h2>{c['privacyTitle']}</h2></div><div><p>{c['privacyText']}</p><a class="text-link" href="{url(lang,'privacy')}">{c['private']} <span aria-hidden="true">→</span></a><p class="fine">{c['privacyNote']}</p></div></div></section>
<section class="access-section wrap"><h2>{c['accessTitle']}</h2><div><p>{c['accessText']}</p><a class="text-link" href="{url(lang,'accessibility')}">{c['accessLink']} <span aria-hidden="true">→</span></a><p class="fine">{c['limits']}</p></div></section><div class="wrap">{contact(lang)}</div>'''


def article(lang, page):
    c = COPY[lang]
    if page == 'privacy':
        source = doc_section('docs/privacy-policy-draft.md', lang)
    elif page == 'support':
        source = doc_section('docs/store/support.md', lang)
    else:
        source = (SECURITY if page == 'security' else ACCESS)[lang]
    body, headings = markdown(source, lang)
    toc = '<nav class="toc" aria-label="' + c['onPage'] + '"><strong>' + c['onPage'] + '</strong>' + ''.join(f'<a href="#{anchor}">{escape(title)}</a>' for anchor,title in headings) + '</nav>' if headings else ''
    identity = f'<div class="policy-owner"><strong>{OWNER}</strong><br>{c["owner"]}<br><a class="email" href="mailto:{EMAIL}">{EMAIL}</a></div>' if page == 'privacy' else ''
    return f'<div class="wrap document"><header class="document-heading"><p class="eyebrow">VOICETOREAD / {c["names"][PAGES.index(page)].upper()}</p><h1>{c["names"][PAGES.index(page)]}</h1><p class="lead">{c[page+"Intro"]}</p><p class="date"><time datetime="{DATE}">{c["updated"]}</time></p></header><div class="document-grid"><aside>{toc}{identity}</aside><article class="prose">{body}</article></div>{contact(lang)}</div>'


def build():
    OUT.mkdir(exist_ok=True)
    (OUT / 'assets').mkdir(exist_ok=True)
    shutil.copyfile(HERE / 'style.css', OUT / 'assets/style.css')
    shutil.copyfile(ROOT / 'VoiceToRead/Assets.xcassets/AppIcon.appiconset/AppIcon.png', OUT / 'assets/app-icon.png')
    for lang in COPY:
        for page in PAGES:
            target = OUT / url(lang, page).strip('/') / 'index.html'
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(layout(lang, page, home(lang) if page == 'home' else article(lang, page)))
    (OUT / 'robots.txt').write_text(f'User-agent: *\nAllow: /\nSitemap: {BASE}/sitemap.xml\n')
    locs = ''.join(f'<url><loc>{BASE}{url(lang,page)}</loc></url>' for lang in COPY for page in PAGES)
    (OUT / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+locs+'</urlset>\n')
    # Deploy only dist; source, Git history and app files never enter this archive.
    with zipfile.ZipFile(HERE / 'VoiceToRead-Hostinger.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for file in sorted(OUT.rglob('*')):
            if file.is_file():
                archive.write(file, file.relative_to(OUT))
    print('Generated 10 bilingual pages and website/VoiceToRead-Hostinger.zip')

if __name__ == '__main__':
    build()
