# tmxh 1.2.6

A `tmxh` egy Perl parancssori segéd interaktív tmux panelekhez. A panelben futó shellnek küld parancsot, így egy már megnyitott SSH-kapcsolaton keresztül is használható.

## Gyors kezdés

A tmux szervert elérő gépen futtasd. A forrásmappából a `./bin/tmxh` paranccsal indíthatod. Linux, tmux és Perl szükséges. Az önteszt Bash-t és az alapvető GNU segédprogramokat használja.

```bash
tmxh                  # Csatlakozás a FELHASZNÁLÓ-codex munkamenethez, szükség esetén létrehozva azt.
tmxh --create         # Létrehozás vagy előkészítés a terminál átvétele nélkül.
```

A két indítási mód közül válassz. A csatlakozásból **Ctrl+B**, majd **D** billentyűvel válhatsz le. A következő parancsokat a saját terminálodból vagy egy másik terminálból futtasd. A meglévő `FELHASZNÁLÓ-codex` munkamenethez elég a művelet nevét megadni.

```bash
tmxh run --timeout 30 'pwd; hostname'
tmxh bg 'sleep 5; printf "kész\n"'
```

A `bg` visszaad egy feladatazonosítót, például `J2`. A következő példákban a tényleges azonosítót használd.

```bash
tmxh status J2
tmxh read J2
tmxh wait J2 --timeout 30
tmxh log rx -n 30
```

**Már megnyitott SSH-kapcsolathoz** először azonosítsd a panelt bemenet küldése nélkül. A példában `codex:0.0` a munkamenet, az ablak és a panel.

```bash
tmxh -t codex:0.0 --expect-cmd ssh doctor --no-probe
tmxh -t codex:0.0 --expect-cmd ssh run --timeout 30 'hostname; pwd'
```

A `doctor --no-probe` új panelen jelezheti, hogy még nincs naplózás. Ellenőrizd a `pane_cmd` mezőt és a célpanelt. Az első `run` elindítja a naplózást. Ha a kapcsolat megszakad, ellenőrizd a végrehajtott lépéseket, és állítsd helyre a kapcsolatot az eredeti panelben.

## Részletes használat

### Célzás és naplózás indítása

| Művelet | Példa |
| --- | --- |
| Az aktív panel kiválasztása és a naplózás indítása | `tmxh ensure` |
| Munkamenet kiválasztása névvel | `tmxh -s munka info` |
| Konkrét ablak és panel | `tmxh -t munka:1.0 info` |
| tmux panelazonosító | `tmxh -t %3 info` |
| Célvizsgálat shellparancs küldése nélkül | `tmxh -t munka:1.0 doctor --no-probe --json` |

A `-s`, `-w` és `-p` külön kapcsolókkal is megadható a munkamenet, az ablakindex és a panelindex. A `-p %3` az adott munkameneten belül keres, a `-t %3` a tmux szerveren. A cél alapértelmezésben a `FELHASZNÁLÓ-codex` munkamenet aktív panelje. A `--session-name munka` a fióknévből és a logikai névből képez azonosítót. A `--session-id novarobot-munka` pontos tmux nevet választ. Az egyszerű `run`, `bg`, `info` és `ensure` meglévő munkamenetet használ. Csatlakozáshoz futtasd a `tmxh` parancsot, önálló létrehozáshoz a `tmxh --create` parancsot. A `--no-create` akkor hasznos, ha közvetlenül csatlakoznál, és a hiányzó munkamenetnél hibát vársz. Meglévő SSH-célhoz a `--expect-cmd ssh` ellenőrzi az előtérparancsot. Az `info` elindíthatja a naplózást, a `doctor --no-probe` passzív panelvizsgálatot végez.

### Parancsok és feladatállapotok

| Parancs | Viselkedés |
| --- | --- |
| `run 'parancs'` | Vár a shell zárójelzőjére, alapértelmezésben élő terminálkimenettel. |
| `bg 'parancs'`, `run -n 'parancs'` | Beküldi a bemenetet és visszaad egy azonosítót. Egy panelen a shell sorban dolgozza fel a bemenetet. |
| `status [J2]` | A feladat állapota vagy a munkamenet feladatlistája. Kapcsolók például `--running`, `--long`, `--limit N`, `--json`. |
| `read J2` | A mentett olvasási pozíciótól olvas. `--all` a teljes tartományt, `--no-advance` a pozíció módosítása nélküli olvasást, `--tail N` az utolsó sorokat kéri. `--raw` megtartja a napló bájtjait. |
| `wait J2`, `wait --all` | Egy feladatra vagy az éppen futónak nyilvántartott feladatokra vár. `--no-print` elnémítja a terminálátiratot. |
| `interrupt` | Ctrl+C-t küld az adott panelnek, és a függő feladatokat megszakítottként rögzíti. A célprogram viselkedése dönti el, mikor áll le ténylegesen. A `--clear` Ctrl+U-t is küld. |
| `clean-jobs --older 24` | Törli a 24 óránál régebbi, lezárt feladatmetaadatokat. A `--all` minden lezárt feladatra érvényes. |

A `run` és a `wait` alapértelmezés szerint korlátlanul vár. A `--timeout S` a várakozás, a `--idle S` a kimenet nélküli idő határa. Az időkorlát elérése után a shellben a parancs tovább futhat. A később megérkező zárójelzőt a `status` vagy a `read` feldolgozza. Egy `bg` sikeres visszatérése a beküldést igazolja. A shell eredményét a feladat `status` és `exit` mezőjében ellenőrizd.

A shellszöveget egyetlen idézett argumentumként add át. Alapmódban például a `cd` hatása a panelben megmarad. A `--subshell` és a `--cwd DIR` alhéjban futtat, a `--eval` here-dokumentumból olvasott shellszöveget értékel ki. Az ismételhető `--env K=V` a parancs előtt exportálja a változót. A név betűvel vagy aláhúzással kezdődik, és ASCII betűkből, számokból vagy aláhúzásból állhat. Az értéket szó szerint adja át, a szóközökkel és a shell metakaraktereivel együtt. A `run --output fájl` a gyűjtött kimenetet helyi fájlba írja. A `run --json` befejezéskor ad egy JSON-objektumot, a `wait --json` pedig feladatösszesítést. Ha nincs futó feladat, a `wait --all --json` válasza `{"jobs":[]}`. A `run`, a `read` és a `capture` JSON-kimenete az átiratot UTF-8 szövegként értelmezi. A `read --raw` megőrzi a bájtokat, JSON-nal együtt pedig bájtonként ábrázolja őket. A `read --json` `new_bytes` mezője továbbra is bájtokat számol.

A panelátirat tartalmazhat promptot, parancsvisszhangot, vezérlőkaraktereket és a helper jelzőit. Interaktív program, jelszóprompt vagy háttérbe tett shellparancs esetén a kimenet és a befejezés értelmezése eltérhet a szokásos parancsétól. `exit` és `exec` alapmódban bezárhatja vagy lecserélheti a panel shelljét.

### Panelműveletek és fájlmásolás

| Parancs | Funkció |
| --- | --- |
| `capture -S 100` | A látható képernyő és az előzmények pillanatképe. A `-e` megtartja a tmux által kiadott vezérlőkódokat. |
| `send --enter 'echo próba'` | Szöveget küld, majd Entert. A kapcsoló nélkül a parancssor szerkesztés alatt marad. |
| `keys Enter` | Egy vagy több tmux billentyűnév küldése. |
| `tail --for 10` | A panelkimenet élő követése tíz másodpercig. |
| `idle --for 2 --timeout 30` | Két másodpercnyi kimeneti csendet vár, legfeljebb harminc másodpercig. |
| `push ./helyi.sh /cél/helyi.sh --verify md5` | Base64-kódolással másol a panel gépére. Cél nélkül a panel munkakönyvtárába kerül a fájl. |
| `attach` | Csatlakozik egy meglévő munkamenethez. A `--create` itt is engedélyezi a létrehozást. |
| `kill` | Bezárja a kiválasztott regisztrált munkamenetet és annak kapcsolatait. |

A `push` alapértelmezett ellenőrzése `size`. A `--verify md5` a másolt tartalom egyezését is vizsgálja, a `--verify none` kihagyja az utóellenőrzést. A célgépen a `base64 -d` parancsnak működnie kell. A másolás felülírhatja a létező célfájlt, és a kódolt tartalom bekerül a terminálátiratba és a TX-naplóba.

### Munkamenetek listázása és kezelése

```bash
tmxh list                                 # Saját, ténylegesen futó munkamenetek.
tmxh list -all                            # Saját regisztrált munkamenetek, leálltak is.
tmxh list --user novarobot                # Egy fiók futó munkamenetei.
tmxh list --user '*' --all                # Minden elérhető fiók regisztrált munkamenetei.
tmxh clean                                # Saját leállt sessionlinkek törlése.
tmxh clean --session-name munka           # Egy logikai név szűrése.
tmxh clean --user '*'                     # Elérhető fiókok leállt sessionlinkjei.
tmxh kill                                 # Saját alapértelmezett session bezárása.
tmxh kill --session-id novarobot-munka    # Bezárás pontos tmux névvel.
tmxh kill --user '*' --session-name munka # A megadott logikai név fiókonként.
```

A `list` táblázata az azonosítót, a fiókot, az utolsó frissítést és az állapotot mutatja. A `--all` és a `-all` alak egyenértékű. Gépi feldolgozáshoz add meg a `--json` kapcsolót. A fiókok home könyvtára az `/etc/passwd` fájlból jön. Több fiókhoz idézőjelek között add át a `'*'` értéket. Más felhasználók kezelése rendszergazdai jogosultságot igényel. A más fiókokhoz tartozó tmux szerverek felderítése a szokásos `/tmp/tmux-UID/default` socketet használja. A saját fiók a jelenlegi tmux kliens socketjét vagy a beállított tmux indítót használja.

A `clean` csak a leállt regisztrációk linkjeit törli. A `kill` a kiválasztott regisztrált sessiont bezárja, a leállítás idejét az archívum auditnaplójába írja, majd törli a linket. A `--all-tmux-kill` közvetlenül a Linux folyamatlistából keresi a kiválasztott fiók tmux szerver- és kliensfolyamatait, és azonnal leállítja azokat. Ilyenkor a sessionlinkek megmaradnak. Több fiók folyamatainak leállítását a `tmxh --all-tmux-kill --user '*'` indítja.

### Naplók és konfiguráció

Az alapértelmezett adatkönyvtár `~/tmux`. Minden indulás külön archívumot kap, például `~/tmux/archive/novarobot-codex.20261125-131521`. A `~/tmux/sessions/codex` link a hozzá tartozó aktuális archívumra mutat. Rendes bezáráskor a link megszűnik, az archívum megmarad. Másik tmux sockethez használj külön adatgyökeret.

| Fájl | Tartalom |
| --- | --- |
| `panes/<panelazonosító száma>-<PID>/rx.log` | A panel nyers PTY-kimenete a naplózó indításától, a kézi bevitel látható visszhangjával együtt. A könyvtárnévben a tmux panelazonosítójának száma szerepel. |
| `tx.log` | A helper által küldött vagy küldésre előkészített szöveg és billentyűk. |
| `audit.log` | Időbélyeges műveleti bejegyzések, például `SUBMIT`, `DONE`, `SEND`, `KEYS` és `KILL`. |
| `jobs/J2.json` | A parancs, az állapot, a célpanel és a naplóbeli pozíciók. |

A `log audit`, `log tx` és `log rx` az adott napló végét mutatja. A `--path` kiírja az útvonalat, a `-f` követi a naplót. Másik ablak RX-naplójához add meg ugyanazt a célpanelt. A tmux a panel megjelenő kimenetét adja át, ezért a helyben gépelt és terminálon visszhang nélküli billentyűk nem kerülnek a TX-naplóba. A TX és az audit méretküszöbe alapértelmezésben 20 MiB. A panel RX-naplója megmarad, mert a feladatok bájtpozíciókkal hivatkoznak rá. Új állományok védett jogosultsággal jönnek létre. Régi állapotkönyvtár esetén a meglévő jogosultságok megmaradnak.

A `~/tmux/config` vagy a `--config fájl` egyszerű `kulcs = érték` sorokat fogad.

```ini
session_name = codex
state_dir = ~/tmux
# Meglévő SSH-panelhez külön beállítható az expect_cmd = ssh.
timeout = 60
guard = 3
```

A `TMUXH_SESSION`, `TMUXH_WINDOW`, `TMUXH_PANE`, `TMUXH_STATE_DIR` és `TMUXH_CONFIG` alapértéket ad. A `TMUXH_TMUX` tmux binárist vagy kompatibilis indítószkriptet választ. A konfiguráció felülírja a célra vonatkozó környezeti alapértékeket, a parancssor a konfigurációt. A `default_session` és `tmux_dir` a `session_name` és `state_dir` megfelelője. A relatív adatútvonal a fiók home könyvtárához képest értendő. A `create` kulccsal külön felülírható a parancs nélküli csatlakozás és a névvel megadott műveletek létrehozási alapértéke. A `--quiet` az állapotüzeneteket, a `--verbose` a hibakeresési részletességet szabályozza. A `--no-pipe` alkalmas például képernyőkép lekérésére, a feladatkövető futtatásnak viszont szüksége van az RX-naplóra.

### Debian-csomag

A `tmux-1.2.6.deb` telepítése a `sudo apt install ./tmux-1.2.6.deb` paranccsal indítható. A csomag a `tmux` és a `perl` csomagtól függ. A bináris a `/opt/ds/tools/tmxh/bin`, a dokumentáció a `/opt/ds/tools/tmxh` könyvtárba kerül. A postinst a `/opt/ds/tools/tmxh/install.sh -t` parancsot futtatja. A telepítő a `/opt/ds/bin/tmxh` linket hozza létre, valamint a `/usr/bin/tmxh` linket. Ha a `/opt/bin` már létezik, az is bekerül a linkláncba.

A `./make-deb.sh` elkészíti a `tmux-1.2.6.deb` fájlt az aktuális munkakönyvtárban. A `./make-deb.sh --set-version VERZIÓ` a szöveges forrásfájlokban frissíti az aktuális kiadási verziót. A csomagoláshoz a `debian/version` adja a verziót. A csomag a `make-deb.sh` és a `debian/` fájljait is tartalmazza.

### Kilépési kódok és önteszt

A befejeződött parancs saját kilépési kódját a helper továbbadja. A helper jelzései közé tartozik a `2` használati vagy működési hibára, a `3` hiányzó célra vagy feladatra, a `4` tmux-hibára, az `5` eltérő vagy elveszett panelre, a `124` időkorlátra és a `130` megszakításra. A kódok átfedhetnek a shellparancs saját kódjaival. A feladatállapot és a diagnosztika segít az ok azonosításában.

```bash
perl -c bin/tmxh
podchecker bin/tmxh
./test-tmuxh.sh
```

Az önteszt külön tmux socketet és ideiglenes könyvtárat használ. A `KEEP=1` megtartja a tesztfájlokat, a tesztszerver minden esetben leáll.

További leírások: [AI-ügynök útmutatója](tmux-agent-HU.md), [specifikáció és műszaki felépítés](tmux-project-HU.md).
