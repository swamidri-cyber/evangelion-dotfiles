#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  covers.py — baja portada, fondo y logo de cada juego de games.json.
#
#  Juegos de Steam: CDN público de Steam con su appid. Los demás (Epic, GOG,
#  sueltos…) se buscan por nombre en el buscador de la tienda de Steam, que
#  tiene casi todo; si no aparece, el menú dibuja una tarjeta con el título.
#  Guarda en ~/.cache/rice-console/art/<id>/{cover.jpg,hero.jpg,logo.png} y
#  anota en games.json qué imágenes hay. Solo baja lo que falta.
# ─────────────────────────────────────────────────────────────────────────────
import json, os, re, shutil, sys, urllib.request, urllib.parse
from concurrent.futures import ThreadPoolExecutor

HOME = os.path.expanduser('~')
DB = f'{HOME}/.config/rice-console/games.json'
ART = f'{HOME}/.cache/rice-console/art'
CDN = 'https://cdn.cloudflare.steamstatic.com/steam/apps/{}/{}'
FILES = {'cover.jpg': 'library_600x900.jpg', 'hero.jpg': 'library_hero.jpg',
         'logo.png': 'logo.png', 'header.jpg': 'header.jpg'}
# Nombres que el buscador no encuentra solo (o encuentra mal)
ALIASES = {'Minecraft: Java Edition': None, 'Minecraft for Windows': None,
           'VALORANT': None, 'Roblox': None, 'Fortnite': None, 'Migurinth': None,
           'Un Vecino Infernal': 'Neighbours back From Hell',
           'Dead Space (2023)': 'Dead Space', 'Trackmania': 'Trackmania',
           'Trine Enchanted Edition': 'Trine Enchanted Edition',
           # appid directo cuando el nombre no alcanza
           'Rocket League': 252950, 'Hitman 3: Contracts': 247430,
           'Trine 4: Definitive Edition': 690640}

# Imágenes que Windows ya tiene guardadas (pantallas de carga de Xbox) o
# logos públicos, para los juegos que no están en Steam
MC_LOGO = '/mnt/windows/XboxGames/Minecraft for Windows/Content/data/gui/dist/hbui/assets/minecraftLogo-7cda8bcf49c5676ea7d2.png'
LOCAL_ART = {
    'xbox:Microsoft.MinecraftUWP': MC_LOGO,
    'xbox:Microsoft.4297127D64EC6': MC_LOGO,
    'riot:valorant': 'https://upload.wikimedia.org/wikipedia/commons/f/fc/Valorant_logo_-_pink_color_version.svg',
}
# SteamGridDB (opcional): con una clave gratis en este archivo, baja portadas
# de lo que falte (Roblox, Fortnite, Migurinth…). Ver PENDIENTES.md.
SGDB_KEY_FILE = f'{HOME}/.config/rice-console/steamgriddb.key'
SGDB_ALIASES = {'Minecraft for Windows': 'Minecraft: Bedrock Edition'}
# Portadas elegidas a mano (id del juego → imagen)
COVER_URLS = {
    # Migurinth = fork de Modrinth App (lanzador de Minecraft con mods)
    'local:migurinth': 'https://cdn2.steamgriddb.com/grid/6feccc03fbeeaf86aa12c79fbb9210d2.jpg',
}

def get(url, timeout=20, headers=None):
    req = urllib.request.Request(url, headers={'User-Agent': 'rice-console/1.0', **(headers or {})})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()

def norm(s):
    return re.sub(r'[^a-z0-9]', '', s.lower().replace('™', '').replace('®', ''))

def search_steam(title):
    term = ALIASES.get(title, title)
    if term is None or isinstance(term, int):
        return term
    q = urllib.parse.quote(term)
    try:
        items = json.loads(get(f'https://store.steampowered.com/api/storesearch/?term={q}&cc=us&l=english'))['items']
    except Exception:
        return None
    for it in items:  # primero coincidencia exacta, después la que empieza igual
        if norm(it['name']) == norm(term):
            return it['id']
    for it in items:
        if norm(it['name']).startswith(norm(term)) or norm(term).startswith(norm(it['name'])):
            return it['id']
    return None

def fetch(g):
    sid = g.get('steamid') or search_steam(g['title'])
    if sid:
        g['steamid'] = sid
    d = os.path.join(ART, g['id'].replace(':', '_'))
    os.makedirs(d, exist_ok=True)
    have = {}
    for local, remote in FILES.items():
        p = os.path.join(d, local)
        if not os.path.exists(p) and sid:
            try:
                data = get(CDN.format(sid, remote))
                if len(data) > 1000:
                    open(p, 'wb').write(data)
            except Exception:
                pass
        if os.path.exists(p):
            have[local.split('.')[0]] = 'file://' + p
    # Juegos nuevos: Steam guarda sus imágenes en rutas con hash. La API de la
    # tienda (IStoreBrowseService/GetItems, sin clave) da esas rutas: portada
    # vertical oficial (library_capsule) y fondo (library_hero).
    if sid and ('cover' not in have or 'hero' not in have):
        try:
            q = urllib.parse.quote(json.dumps({'ids': [{'appid': sid}],
                'context': {'language': 'english', 'country_code': 'US'},
                'data_request': {'include_assets': True}}))
            items = json.loads(get(f'https://api.steampowered.com/IStoreBrowseService/GetItems/v1?input_json={q}'))
            a = items['response']['store_items'][0].get('assets', {})
            fmt = 'https://shared.akamai.steamstatic.com/store_item_assets/' + a['asset_url_format']
            for local, key in (('cover.jpg', 'library_capsule_2x'), ('hero.jpg', 'library_hero')):
                k = local.split('.')[0]
                if k not in have and a.get(key):
                    data = get(fmt.replace('${FILENAME}', a[key]))
                    if len(data) > 1000:
                        p = os.path.join(d, local); open(p, 'wb').write(data)
                        have[k] = 'file://' + p
        except Exception:
            pass
    # Si no, la API de la tienda da al menos la cabecera, que sirve de portada.
    if sid and 'cover' not in have and 'header' not in have:
        try:
            det = json.loads(get(f'https://store.steampowered.com/api/appdetails?appids={sid}'))
            url = det[str(sid)]['data']['header_image']
            p = os.path.join(d, 'header.jpg'); open(p, 'wb').write(get(url))
            have['header'] = 'file://' + p
        except Exception:
            pass
    if g['id'] in COVER_URLS and 'cover' not in have:
        try:
            p = os.path.join(d, 'cover.jpg'); open(p, 'wb').write(get(COVER_URLS[g['id']]))
            have['cover'] = 'file://' + p
        except Exception:
            pass
    src = LOCAL_ART.get(g['id'])
    if src and 'header' not in have and 'cover' not in have:
        p = os.path.join(d, 'header.png')
        try:
            if src.startswith('http'):
                svg = os.path.join(d, 'logo.svg'); open(svg, 'wb').write(get(src))
                os.system(f'magick -background "#0a0a0a" -density 300 "{svg}" -resize 560x300 '
                          f'-gravity center -extent 920x430 "{p}"')
            else:
                shutil.copy(src, p)
            if os.path.exists(p):
                have['header'] = 'file://' + p
        except Exception:
            pass
    if not have.get('cover') and os.path.exists(SGDB_KEY_FILE):
        p = os.path.join(d, 'cover.jpg')
        try:
            key = open(SGDB_KEY_FILE).read().strip()
            h = {'Authorization': 'Bearer ' + key}
            q = urllib.parse.quote(SGDB_ALIASES.get(g['title'], g['title']))
            found = json.loads(get(f'https://www.steamgriddb.com/api/v2/search/autocomplete/{q}', headers=h))['data']
            if found:
                grids = json.loads(get(f'https://www.steamgriddb.com/api/v2/grids/game/{found[0]["id"]}?dimensions=600x900', headers=h))['data']
                if grids:
                    open(p, 'wb').write(get(grids[0]['url']))
                    have['cover'] = 'file://' + p
        except Exception:
            pass
    g['art'] = have
    return g['title'], sid, sorted(have)

db = json.load(open(DB))
with ThreadPoolExecutor(8) as ex:
    for title, sid, have in ex.map(fetch, db['games']):
        if '-v' in sys.argv or not have:
            print(f'{title[:40]:40} {sid} {have}')
json.dump(db, open(DB, 'w'), ensure_ascii=False, indent=1)
print('listo:', sum(1 for g in db['games'] if g['art'].get('cover')), 'con portada de', len(db['games']))
