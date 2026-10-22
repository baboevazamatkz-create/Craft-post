#!/usr/bin/env bash
# Генерирует web/ (его нет в git) и подставляет название, язык, значки.
set -euo pipefail
cd "$(dirname "$0")/.."
[ -d web ] || flutter create --platforms=web --org kz.craftsystem --project-name craft_post .
cp tool/web/manifest.json web/manifest.json
mkdir -p web/icons
cp tool/web/Icon-*.png web/icons/
cp tool/web/favicon.png web/favicon.png
python3 - <<'PY'
import re
p='web/index.html'
s=open(p,encoding='utf-8').read()
s=s.replace('<html>','<html lang="ru">',1)
s=re.sub(r'<title>.*?</title>','<title>CRAFT Посты</title>',s)
s=re.sub(r'<meta name="description" content="[^"]*">','<meta name="description" content="Подготовка постов Instagram для CRAFT SYSTEM">',s)
s=re.sub(r'<meta name="apple-mobile-web-app-title" content="[^"]*">','<meta name="apple-mobile-web-app-title" content="CRAFT Посты">',s)
# Адрес сайта определяется из адреса страницы: работает и в /Craft-post/,
# и в /craft-post/, и в корне (GitHub отдаёт оба написания имени).
s=s.replace('<base href="$FLUTTER_BASE_HREF">',
  '<script>document.write(\'<base href="\' + location.pathname.replace(/[^/]*$/, \'\') + \'">\');</script>')
if 'theme-color' not in s:
    s=s.replace('</head>','  <meta name="theme-color" content="#008DC8">\n</head>',1)
open(p,'w',encoding='utf-8').write(s)
PY
