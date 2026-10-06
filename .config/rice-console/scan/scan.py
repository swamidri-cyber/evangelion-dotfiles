#!/usr/bin/env python3
# ─────────────────────────────────────────────────────────────────────────────
#  scan.py — arma el catálogo de juegos del modo consola.
#
#  Lee Windows montado en solo lectura (/mnt/windows, ver PENDIENTES.md) y el
#  Steam de Linux. Junta Steam (2 cuentas), Epic, Xbox, GOG, EA, Ubisoft, Riot,
#  Roblox y juegos sueltos; la "última vez jugado" sale de Steam y, para los
#  demás, de C:\Windows\Prefetch (Windows guarda ahí cuándo corrió cada .exe).
#
#  Salida: ~/.config/rice-console/games.json (lista ordenada por recientes).
#  Uso:    python3 scan.py [--win /mnt/windows]
# ─────────────────────────────────────────────────────────────────────────────
import json, os, sys, glob, base64, re, sqlite3, shutil, tempfile, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vdf, appinfo

WIN = sys.argv[sys.argv.index('--win') + 1] if '--win' in sys.argv else '/mnt/windows'
HOME = os.path.expanduser('~')
LSTEAM = f'{HOME}/.local/share/Steam'
WSTEAM = f'{WIN}/Program Files (x86)/Steam'
OUT = f'{HOME}/.config/rice-console/games.json'

# Cuentas de Steam: la principal y la vieja
ACCOUNTS = {'1574010028': 'swami_totto', '852144764': 'pisonik2018'}
# Apps de Steam que no son juegos para el menú
STEAM_SKIP = {480, 228980, 431960}

games = {}

# Sin Windows montado (lo normal: se monta solo para escanear) se conserva lo
# que ya se sabía de Windows y se actualiza solo lo de Linux.
WIN_OK = os.path.isdir(f'{WIN}/Windows/System32')
if not WIN_OK and os.path.exists(OUT):
    for g in json.load(open(OUT))['games']:
        on = [o for o in g.get('installedOn', []) if o != 'linux']
        if 'installedOn' in g:
            g['installedOn'] = on
            if g['store'] == 'steam':
                g['installed'] = bool(on)
        games[g['id']] = g
    print('Windows no está montado: uso el catálogo anterior para Windows')

def add(key, **g):
    """Suma un juego (o completa uno existente con la misma clave)."""
    cur = games.setdefault(key, {'id': key, 'installed': False, 'lastPlayed': 0,
                                 'playtime': 0, 'os': 'windows'})
    for k, v in g.items():
        if k in ('lastPlayed', 'playtime'):
            cur[k] = max(cur.get(k, 0), v or 0)
        elif k == 'installed':
            cur[k] = cur[k] or v
        elif v is not None:
            cur[k] = v

# ── Prefetch: última ejecución de cada .exe ──────────────────────────────────
prefetch = {}
for f in glob.glob(f'{WIN}/Windows/Prefetch/*.pf'):
    exe = os.path.basename(f).rsplit('-', 1)[0].upper()
    prefetch[exe] = max(prefetch.get(exe, 0), int(os.path.getmtime(f)))

def pf(*exes):
    return max([prefetch.get(e.upper()[:29], 0) for e in exes] + [0])

# ── Steam ────────────────────────────────────────────────────────────────────
info = {}
for p in (f'{LSTEAM}/appcache/appinfo.vdf', f'{WSTEAM}/appcache/appinfo.vdf'):
    if os.path.exists(p):
        info.update(appinfo.load(p))

def steam_apps(userdir):
    if not os.path.exists(userdir):
        return {}
    d = vdf.load(userdir)
    for k in ('UserLocalConfigStore', 'Software', 'Valve', 'Steam', 'apps'):
        d = vdf.ci(d, k)
    return d

for uid, acc in ACCOUNTS.items():
    for base in (WSTEAM, LSTEAM):
        for appid, a in steam_apps(f'{base}/userdata/{uid}/config/localconfig.vdf').items():
            if not appid.isdigit() or not isinstance(a, dict):
                continue
            i = int(appid)
            meta = info.get(i, {})
            if i in STEAM_SKIP or str(meta.get('type', '')).lower() not in ('game', ''):
                continue
            lp, pt = int(a.get('LastPlayed', 0)), int(a.get('Playtime', 0))
            if not (lp or pt) or not meta.get('name'):
                continue
            add(f'steam:{i}', title=meta['name'], store='steam', steamid=i,
                account=acc, lastPlayed=lp, playtime=pt,
                launch={'windows': f'steam://rungameid/{i}', 'linux': f'steam://rungameid/{i}'})

def steam_installed(steamdir, os_name):
    lf = f'{steamdir}/steamapps/libraryfolders.vdf'
    if not os.path.exists(lf):
        return
    for lib in vdf.load(lf).get('libraryfolders', {}).values():
        path = lib.get('path', '')
        if os_name == 'windows':
            if not path.upper().startswith('C:'):
                continue  # D:\ y E:\ ya no existen (el disco ahora es Linux)
            path = WIN + path[2:].replace('\\', '/')
        for m in glob.glob(f'{path}/steamapps/appmanifest_*.acf'):
            st = vdf.load(m).get('AppState', {})
            i = int(st.get('appid', 0))
            if i in STEAM_SKIP or str(info.get(i, {}).get('type', 'game')).lower() != 'game':
                continue
            key = f'steam:{i}'
            if os_name == 'windows':
                wdir = lib.get('path', '') + '\\steamapps\\common\\' + st.get('installdir', '')
                add(key, watch={'dirs': [wdir], 'procs': []})
            add(key, title=st.get('name'), store='steam', steamid=i, installed=True,
                lastPlayed=int(st.get('LastPlayed', 0)),
                launch={'windows': f'steam://rungameid/{i}', 'linux': f'steam://rungameid/{i}'})
            games[key].setdefault('installedOn', [])
            if os_name not in games[key]['installedOn']:
                games[key]['installedOn'].append(os_name)

steam_installed(WSTEAM, 'windows')
steam_installed(LSTEAM, 'linux')

# ── Epic (catálogo cacheado: incluye los regalados que reclamaste) ───────────
cat = f'{WIN}/ProgramData/Epic/EpicGamesLauncher/Data/Catalog/catcache.bin'
installed_epic = set()
for m in glob.glob(f'{WIN}/ProgramData/Epic/EpicGamesLauncher/Data/Manifests/*.item'):
    installed_epic.add(json.load(open(m)).get('AppName'))
if os.path.exists(cat):
    for it in json.loads(base64.b64decode(open(cat, 'rb').read())):
        if 'games' not in [c.get('path') for c in it.get('categories', [])]:
            continue
        app = (it.get('releaseInfo') or [{}])[0].get('appId')
        title = it.get('title', '').replace('?', '').strip()
        uri = f"com.epicgames.launcher://apps/{it['namespace']}%3A{it['id']}%3A{app}?action=launch&silent=true"
        add(f'epic:{app}', title=title, store='epic', installed=app in installed_epic,
            launch={'windows': uri})

# ── Xbox / Microsoft Store ───────────────────────────────────────────────────
XBOX = {  # carpeta en C:\XboxGames → (ID de paquete!App, ejecutables para Prefetch)
    'Among Us': ('Innersloth.AmongUs_fw5x688tam7rm!Game', ['AMONG US.EXE']),
    'Minecraft for Windows': ('Microsoft.MinecraftUWP_8wekyb3d8bbwe!Game', ['MINECRAFT.WINDOWS.EXE', 'MINECRAFT.EXE']),
    'Minecraft- Java Edition': ('Microsoft.4297127D64EC6_8wekyb3d8bbwe!Minecraft', ['MINECRAFTLAUNCHER.EXE', 'JAVAW.EXE']),
}
for folder, (aumid, exes) in XBOX.items():
    man = f'{WIN}/XboxGames/{folder}/Content/appxmanifest.xml'
    if not os.path.exists(man):
        continue
    t = open(man, encoding='utf-8', errors='replace').read()
    title = re.search(r'<DisplayName>([^<]+)', t).group(1)
    add(f'xbox:{aumid.split("_")[0]}', title=title, store='xbox', installed=True,
        lastPlayed=pf(*exes), launch={'windows': f'shell:AppsFolder\\{aumid}'},
        watch={'dirs': [f'C:\\XboxGames\\{folder}\\Content'], 'procs': [e[:-4] for e in exes]})

# ── GOG Galaxy (biblioteca de GOG + instalados) ──────────────────────────────
gdb = f'{WIN}/ProgramData/GOG.com/Galaxy/storage/galaxy-2.0.db'
if os.path.exists(gdb):
    tmp = tempfile.mkdtemp()
    for f in glob.glob(gdb + '*'):
        shutil.copy(f, tmp)
    c = sqlite3.connect(f'{tmp}/galaxy-2.0.db')
    inst = {r[0] for r in c.execute('select productId from InstalledBaseProducts')}
    lastp = {k: v for k, v in c.execute('select gameReleaseKey, lastPlayedDate from LastPlayedDates')}
    for key, val in c.execute("select releaseKey, value from GamePieces where gamePieceTypeId="
                              "(select id from GamePieceTypes where type='title') and releaseKey in "
                              "(select releaseKey from LibraryReleases)"):
        title = json.loads(val).get('title')
        if not key.startswith('gog_') or 'Amazon Prime' in title:
            continue
        gid = int(key[4:])
        lp = int(time.mktime(time.strptime(lastp[key], '%Y-%m-%d %H:%M:%S'))) if key in lastp else 0
        add(f'gog:{gid}', title=title, store='gog', installed=gid in inst, lastPlayed=lp,
            launch={'windows': f'"C:\\Program Files (x86)\\GOG Galaxy\\GalaxyClient.exe" /command=runGame /gameId={gid}'})
    shutil.rmtree(tmp)
# Juegos de GOG instalados sin Galaxy (instalador suelto)
for info_f in glob.glob(f'{WIN}/GOG Games/*/goggame-*.info'):
    d = json.load(open(info_f, encoding='utf-8-sig'))
    task = next((t for t in d.get('playTasks', []) if t.get('isPrimary')), None)
    if not task:
        continue
    folder = os.path.dirname(info_f)
    winpath = 'C:' + folder[len(WIN):].replace('/', '\\') + '\\' + task['path']
    add(f'gog:{d["gameId"]}', title=d['name'], store='gog', installed=True,
        lastPlayed=pf(os.path.basename(task['path'].replace('\\', '/'))),
        launch={'windows': winpath}, watch={'dirs': [winpath.rsplit('\\', 1)[0].split('\\Atlas')[0]], 'procs': []})

# ── EA app (hay registro pero los juegos ya no están en disco) ───────────────
for d in glob.glob(f'{WIN}/ProgramData/EA Desktop/InstallData/*'):
    add(f'ea:{os.path.basename(d)}', title=os.path.basename(d), store='ea', installed=False,
        launch={'windows': 'origin2://library/open'})

# ── Ubisoft ──────────────────────────────────────────────────────────────────
if os.path.isdir(f'{WIN}/Program Files (x86)/Ubisoft/Ubisoft Game Launcher/games/Trackmania'):
    add('ubisoft:trackmania', title='Trackmania', store='ubisoft', installed=True,
        lastPlayed=pf('TRACKMANIA.EXE'), launch={'windows': 'uplay://launch/5595/0'},
        watch={'dirs': [r'C:\Program Files (x86)\Ubisoft\Ubisoft Game Launcher\games\Trackmania'], 'procs': ['Trackmania']})
games.pop('epic:Pigeon', None)  # Trackmania de Epic = el mismo de Ubisoft

# ── Riot ─────────────────────────────────────────────────────────────────────
if os.path.isdir(f'{WIN}/Riot Games/VALORANT'):
    add('riot:valorant', title='VALORANT', store='riot', installed=True,
        lastPlayed=pf('VALORANT-WIN64-SHIPPING.EXE', 'VALORANT.EXE'),
        launch={'windows': '"C:\\Riot Games\\Riot Client\\RiotClientServices.exe" --launch-product=valorant --launch-patchline=live'},
        watch={'dirs': [r'C:\Riot Games\VALORANT'], 'procs': ['VALORANT-Win64-Shipping', 'VALORANT']})

# ── Roblox ───────────────────────────────────────────────────────────────────
if glob.glob(f'{WIN}/Users/*/AppData/Local/Roblox/Versions/*/RobloxPlayerBeta.exe'):
    add('roblox:player', title='Roblox', store='roblox', installed=True,
        lastPlayed=pf('ROBLOXPLAYERBETA.EXE'), launch={'windows': 'roblox-player:'},
        watch={'dirs': [], 'procs': ['RobloxPlayerBeta']})

# ── Juegos sueltos (sin tienda) ──────────────────────────────────────────────
LOCAL = [  # (título, ruta en C:, exe para Prefetch)
    ('Grand Theft Auto IV', r'C:\Program Files (x86)\DODI-Repacks\Grand Theft Auto IV\GTAIV.exe', 'GTAIV.EXE'),
    ('Detroit: Become Human', r'C:\Program Files (x86)\Detroit Become Human\DetroitBecomeHuman.exe', 'DETROITBECOMEHUMAN.EXE'),
    ('Heavy Rain', r'C:\Program Files (x86)\Heavy Rain\HeavyRain.exe', 'HEAVYRAIN.EXE'),
    ('The Walking Dead: Season Two', r'C:\Program Files (x86)\The Walking Dead Season 2\TheWalkingDead2.exe', 'THEWALKINGDEAD2.EXE'),
    ('Un Vecino Infernal', r'C:\Program Files (x86)\JoWooD\Un Vecino Infernal\Bin\Game.exe', 'GAME.EXE'),
    ('Heavenly Bodies', r'C:\Games\Heavenly Bodies\Heavenly Bodies.exe', 'HEAVENLY BODIES.EXE'),
    ('Migurinth', r'C:\Users\Swami\AppData\Local\Migurinth\Migurinth.exe', 'MIGURINTH.EXE'),
]
for title, path, exe in LOCAL:
    if os.path.exists(WIN + path[2:].replace('\\', '/')):
        key = 'local:' + re.sub(r'[^a-z0-9]+', '-', title.lower()).strip('-')
        add(key, title=title, store='local', installed=True, lastPlayed=pf(exe),
            launch={'windows': path}, watch={'dirs': [path.rsplit('\\', 1)[0]], 'procs': [] if exe == 'GAME.EXE' else [exe[:-4].title()]})

# ── Si un juego suelto/de otra tienda también existe en Steam, se queda con
#    el instalado (evita duplicados tipo "Detroit" de Steam sin instalar).
by_title = {}
for k, g in list(games.items()):
    t = re.sub(r'[^a-z0-9]', '', g['title'].lower())
    if t in by_title:
        other = games[by_title[t]]
        keep, drop = (g, other) if g['installed'] and not other['installed'] else (other, g)
        keep['lastPlayed'] = max(keep['lastPlayed'], drop['lastPlayed'])
        keep['playtime'] = max(keep['playtime'], drop['playtime'])
        keep.setdefault('steamid', drop.get('steamid'))
        keep.setdefault('alsoOn', []).append(drop['store'])
        games.pop(drop['id'])
        by_title[t] = keep['id']
    else:
        by_title[t] = k

for g in games.values():
    g['os'] = 'linux' if 'linux' in g.get('installedOn', []) else 'windows'

out = sorted(games.values(), key=lambda g: (-g['lastPlayed'], g['title'].lower()))
os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump({'scanned': int(time.time()), 'games': out}, open(OUT, 'w'), ensure_ascii=False, indent=1)
print(f'{len(out)} juegos ({sum(g["installed"] for g in out)} instalados) → {OUT}')
