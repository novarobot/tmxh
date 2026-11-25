# tmxh 1.2.6 — specifikáció és műszaki felépítés

## Specifikáció

| Terület | Követelmény | Megvalósítás |
| --- | --- | --- |
| Környezet | Meglévő tmux panel vezérlése, akár nyitott SSH-kapcsolaton keresztül. | A helper a tmux szerverhez csatlakozik. A panelben levő shell terminálbemenetként kapja a parancsot. A shell és a kapcsolat saját állapota a panelben marad. |
| Alapértelmezés | A `FELHASZNÁLÓ-codex` munkamenet keresése és szükség esetén létrehozása. | A `has-session` pontos névegyezéssel keres. A parancs nélküli hívás csatlakozik, szükség esetén helyi shellt indít. A `--create` önmagában leválasztva indít. A névvel megadott műveletek alapból meglévő munkamenetet igényelnek. |
| Paraméterezés | Másik munkamenet, ablak vagy panel választható. | `-s`, `-w`, `-p`, illetve `-t` összetett cél vagy szerveroldali panelazonosító. A feladat a tényleges panelhez és induló folyamathoz kötődik. |
| Blokkoló futtatás | Élő kimenet, várakozás a befejezésre és a kilépési kód továbbadása. | Kezdő- és zárójelző az RX-naplóban. Az élő olvasó a részleges sorokat is kiírja. Időkorlát, csendkorlát és panelvesztés külön állapotot kap. |
| Aszinkron futtatás | A hívó feladatazonosítót kap, és később követheti a feladatot. | Munkamenetenkénti `J<n>` azonosító, JSON-metaadat, `status`, `read` és `wait`. Egy panel egy shell-bemeneti folyamot használ. |
| Naplózás | A helper által küldött bemenet és a megjelenő panelkimenet visszakövethető. | Külön audit-, TX- és RX-napló. A `pipe-pane` a naplózás indítása utáni PTY-adatot rögzíti. A közvetlen kézi gépelésből a terminál által visszhangzott szöveg megjelenik az RX-ben. |
| Kapcsolatvesztés | Az SSH vagy a panel kiesését észlelni és jelezni kell. | `--expect-cmd ssh` ellenőrzés küldés előtt, időszakos ellenőrzés futó feladaton. A helper nem épít újra SSH-kapcsolatot. |
| Üzemeltetés | Fájlmásolás, diagnosztika, használati útmutató és önteszt. | Base64-alapú `push`, `doctor`, beépített súgó és POD, kétnyelvű Markdown-dokumentáció, elkülönített Bash-önteszt. |

## Végrehajtási modell

A `tmxh` egyetlen futtatható Perl-fájl, alapmodulokkal. A tmux parancsokat argumentumlistával indítja. A panelhez tartozó shell és a helper külön folyamat. A terminálprotokoll POSIX-szerű interaktív shellre épül. Az ellenőrzések Linuxon, Bash alatt, tmux 3.3a-val futottak.

1. A `main` betölti az alapértékeket és a konfigurációfájlt, feldolgozza a közös kapcsolókat és meghívja a parancskezelőt. Parancs nélkül az explicit `--create` az `ensure` kezelőhöz irányít, egyébként az `attach` kezelő fut.
2. A küldő parancs kiválasztja a panelt. Megadott elvárt előtérparancs esetén ellenőrzi a panel állapotát, majd előkészíti a naplózást. A panelenkénti RX-csatornát a tmux folyamatosan táplálja.
3. A munkamenetenkénti küldési zár védi a feladatazonosító kiosztását és az egy feladathoz tartozó bemenet elküldését. A kezdőjelző, a parancs és a kilépési kódot kiíró zárójelző ebben a sorrendben kerül a panelre.
4. `run` és `wait` esetén az olvasó egész sorokon keresi a jelzőket, a megjelenítés pedig külön bájtpozíció alapján halad. `status` és `read` esetén az olvasó a rendelkezésre álló adatból frissíti a feladatot.
5. A háttérfeladat futtatását nem külön helperfolyamat felügyeli. A panel és az RX-szűrő tovább élhet, a befejezést a következő lekérdezés állapítja meg. A várakozási időkorlát visszaadja a vezérlést a hívónak, a panelben futó parancs még folytatódhat.

Példa jelzőkre és befejezésre.

```text
TMUXH-BEG-J12
... terminálátirat ...
TMUXH-END-J12-7
```

A shell saját kódja itt `7`. A nyers átirat tartalmazhat promptot, echo-visszhangot és a jelzőket is. A jelzőillesztés sortöréseket, egyes terminálvezérlőket és szélső szóközöket kezel.

## Állapot és fájlformátumok

| Útvonal az állapotgyökérben | Író és jelentés |
| --- | --- |
| `<archívum>/counter` | A helper növekvő számlálója. |
| `<archívum>/submit.lock`, `pipe.lock` | A feladatbeküldés és a naplózó indításának zárolása. |
| `<archívum>/jobs/J<n>.json` | Panel, PID, eredeti és várt előtérparancs, shellszöveg, futási mód, állapot, időpontok, kilépési kód és bájtpozíciók. |
| `<archívum>/meta.json` | A legutóbb előkészített panel, annak naplója és a helper verziója. |
| `<archívum>/rxfilter.pl` | A helper által kiírt Perl szűrő. |
| `<archívum>/panes/<panelazonosító száma>-<PID>/rx.log` | Nyers bináris PTY-adat. Az `rx.log.pid` a szűrő PID-jét tárolja. |
| `<archívum>/tx.log`, `audit.log` | Időbélyeges műveleti adatok. Méretküszöbnél a helper `.1` végű példányba forgatja őket. |

A JSON-fájlok ideiglenes fájlba írással és átnevezéssel frissülnek. A `start_offset` a beküldés előtti RX-pozíció, a `scan_offset` a jelzőkeresés következő pozíciója, a `read_offset` a felhasználói deltaolvasás kurzora. A `beg_offset` a kezdőjelző után, az `end_offset` a zárójelző után vagy megszakításkor az addig elért pozíción áll.

A `1.0` feladatainál hiányozhat a `pane_pid` mező, ezért ezekhez a helper a régi, közös `<munkamenet>/rx.log` fájlt olvassa. Az 1.2.6 a munkamenet teljes állapotfáját időbélyeges archívumba teszi. Az új feladatok az aktív archívum panelenkénti naplójába kerülnek. Létező `pipe-pane` csatorna esetén a helper csak saját, azonosítható csatornát vesz át. Másik naplózó esetén hibát jelez.

| Feladatállapot | Jelentés |
| --- | --- |
| `running` | Beküldve, a zárójelző még hiányzik. Ebbe a sorban álló feladat is beletartozik. |
| `done` | Felismert zárójelző, a shell kódja az `exit` mezőben. |
| `timeout`, `idle` | A várakozás idő- vagy csendkorlátot ért el. Későbbi zárójelzővel `done` állapotba kerülhet. |
| `interrupted` | A helper megszakítást küldött a panelnek. |
| `pane-cmd-changed` | A panel bezárult, a figyelt folyamat megváltozott vagy a várt előtérparancs eltűnt. |

## Függvények

### Belépési pontok és konfiguráció

| Függvény | Feladat |
| --- | --- |
| `main` | A konfiguráció és a közös kapcsolók beolvasása, parancsválasztás és kilépési kód. |
| `cfg_defaults`, `load_config_file` | Alapértékek, környezeti alapbeállítások és a konfigurációs fájl betöltése. |
| `common_opts`, `set_target` | Közös Getopt-beállítások és a célcím összetevőinek feloldása. |
| `usage_text`, `cmd_help`, `cmd_version` | A beépített súgó és verzió megjelenítése. |

### tmux, állapotkönyvtár és naplók

| Függvény | Feladat |
| --- | --- |
| `tmux`, `tmux_alive`, `tmux_ver` | A tmux kliens meghívása, elérhetősége és verziója. |
| `session_exists`, `pane_format`, `list_panes`, `resolve_pane` | Pontos munkamenetkeresés, panelmetaadatok lekérése és a cél kiválasztása. |
| `pane_current_command_of`, `last_screen_line`, `warn_if_unexpected` | Előtérfolyamat és prompt vizsgálata, diagnosztikai figyelmeztetés. |
| `check_input_pane`, `ensure_all`, `save_meta` | A bemenet céljának ellenőrzése, szükséges környezet előkészítése és a panel metaadatainak mentése. |
| `init_paths`, `init_state`, `panel_rx_path`, `job_rx_path` | Az állapotkönyvtár és a panelhez vagy korábbi feladathoz tartozó naplóútvonalak feloldása. |
| `filter_source`, `pipe_pid_alive`, `ensure_pipe`, `stop_pipe` | Szűrő forrása, a naplózó azonosítása, indítása, szükség szerinti leállítása. |
| `log_append`, `log_audit`, `log_tx`, `rotate_small_logs` | Zárolt naplóírás, audit- és TX-formátum, a méretküszöb kezelése. |
| `send_text`, `send_keys` | Darabolt szöveg vagy tmux-billentyűk küldése és naplózása. |
| `read_records`, `read_range` | Teljes sorok és tetszőleges bájttartomány olvasása. |

### Feladatkövetés

| Függvény | Feladat |
| --- | --- |
| `next_job_id`, `job_file`, `save_job`, `load_job` | Azonosító és fájlnév képzése, JSON-állapot mentése és betöltése. |
| `job_num`, `all_jobs`, `running_jobs` | Numerikus sorrend, teljes lista és futó feladatok kiválasztása. |
| `build_job_text`, `send_job` | Shellbemenet és jelzők összeállítása, naplózott beküldés. |
| `marker_beg`, `marker_exit` | A kezdőjelző és a zárójelző kilépési kódjának felismerése. |
| `check_job_panel`, `job_exit_code` | Panelvesztés és folyamatváltozás észlelése, a visszaadandó kód kiválasztása. |
| `wait_job`, `reap_job`, `reap_all` | Várakozás és élő megjelenítés, valamint egy vagy több feladat állapotának frissítése. |
| `run_blocking`, `probe_shell` | Belső futtatás gyűjtött kimenettel és a shell átviteli próbája. |
| `job_output`, `job_dur`, `job_line` | A tárolt kimenet, futási idő és embernek szánt állapotsor előállítása. |

### Parancskezelők és általános segédek

| Függvény | Feladat |
| --- | --- |
| `cmd_ensure`, `cmd_info`, `cmd_doctor` | Előkészítés, összegzés és célzott diagnosztika. |
| `cmd_run`, `cmd_status`, `cmd_read`, `cmd_wait` | Futtatás, feladatállapot, deltaolvasás és várakozás. A `bg` és `jobs` ezekhez tartozó parancsálnevek. |
| `cmd_tail`, `cmd_idle`, `cmd_capture` | RX-követés, kimeneti csend és képernyőpillanatkép. |
| `cmd_send`, `cmd_keys`, `cmd_interrupt`, `cmd_push` | Nyers szöveg, billentyűk, megszakítás és Base64-alapú fájlmásolás. |
| `cmd_log`, `cmd_clean_jobs`, `cmd_clean`, `cmd_kill`, `cmd_attach` | Naplókezelés, lezárt feladatmetaadatok törlése, regisztrációs linkek takarítása, leállítás és csatlakozás. A `cmd_attach` külső terminálból az `attach-session`, tmux kliensből a `switch-client` parancsot hívja. |
| `ts`, `ts_fmt`, `fmt_dur`, `err`, `dbg`, `fail` | Időformázás, diagnosztikai üzenetek és hibakódos leállás. |
| `slurp`, `spew`, `fsize` | Fájlolvasás, átnevezéses fájlírás és méretlekérés. |
| `sq`, `trim`, `oneline`, `deansi`, `strip_ts`, `clean_line` | Shellidézés, sorformázás, vezérlőkódok és a régi időbélyegek kezelése. |

## Munkamenet-nyilvántartás és életciklus

Az alapértelmezett konfiguráció a fiók home könyvtárában található `tmux/config`. A `session_name` vagy `default_session` a logikai név, alapértéke `codex`. A `state_dir` vagy `tmux_dir` az adatgyökér, alapértéke `~/tmux`. A logikai névből a program `FELHASZNÁLÓ-NÉV` azonosítót képez. A `--session-id` pontos azonosítót használ. A fiókok és home könyvtáraik forrása az `/etc/passwd`.

A `register_session` az `archive` könyvtárban létrehozza az `ID.ÉÉÉÉHHNN-ÓÓPPMM` nevű archívumot, majd átnevezéssel publikálja a rövid nevű `sessions/NÉV` linket. Az `@tmxh_archive` tmux sessionopció összeköti az élő példányt az archívummal. Az archívum létrehozását és a link módosítását a `.register.lock` koordinálja. A tmux `session-closed` hook ugyanazt a linkcélt ellenőrzi törlés előtt, így egy újraindított, azonos nevű session új linkjét megőrzi.

A `list` a tmux élő sessionjeit és a lemezen lévő nyilvántartást veti össze. Alapból a saját futó munkameneteket mutatja. A `-all` azonos a `--all` kapcsolóval, és a leállt vagy ellenőrizhetetlen állapotú regisztrációkat is kiírja. `--user '*'` esetén minden elérhető helyi fiókot vizsgál. A táblázat oszlopai az ID, a fiók, a frissítési idő és az állapot. A JSON `updated` mező Unix-idő.

A `clean` csak a bizonyíthatóan leállt session linkjét távolítja el. A `kill` az archívumban időbélyeges `KILL` auditbejegyzést készít, a tmuxban lezárja a sessiont, és eltávolítja a hozzá tartozó linket. A `--all-tmux-kill` a Linux `/proc` felületén vizsgálja a folyamat tulajdonosát, nevét és futtatható állományát, majd `SIGKILL`-t küld. Ez a művelet kihagyja a fájlalapú nyilvántartást és a tmux lezárási hookjait, ezért a linkek a későbbi `clean` futtatásáig megmaradnak.

| Függvény | Feladat |
| --- | --- |
| `accounts`, `selected_accounts`, `account_config`, `home_path` | Fiókok felderítése, fiókválasztás, konfiguráció és útvonalak. |
| `valid_session`, `session_label`, `session_id_alive` | Névellenőrzés, logikai linknév és az egzakt tmux cél futásellenőrzése. |
| `registered_archive`, `last_archive`, `register_session` | Aktuális vagy korábbi archívum feloldása és új archívum regisztrálása. |
| `close_hook`, `remove_archive_link` | tmux lezárási hook és a várt link zárolt eltávolítása. |
| `account_tmux`, `live_sessions`, `session_rows` | Fiókhoz kötött tmux lekérdezés, élő állapot, összevont adatok. |
| `cmd_list_sessions`, `manage_sessions`, `run_as_account` | Táblázat és JSON, célzott takarítás vagy lezárás, más fiók műveletének futtatása annak jogosultságaival. |
| `cmd_all_tmux_kill` | Folyamatok azonosítása és leállítása a fájlalapú nyilvántartás használata nélkül. |

## Debian-telepítés

A csomag architektúrája `all`, a függőségei `tmux` és `perl`. A postinst egyetlen telepítési feladata a `/opt/ds/tools/tmxh/install.sh -t` indítása. Az install.sh ellenőrzi az útvonalakat és beállítja a linkláncot. Ha `/opt/bin` hiányzik, a `/usr/bin/tmxh` a `/opt/ds/bin/tmxh` linkre mutat. Eltávolításkor a prerm ugyanennek a scriptnek a `-r` módját hívja. A közös mappák és a felhasználói archívumok megmaradnak.

A `make-deb.sh` a `debian/control`, `debian/postinst`, `debian/prerm` és `debian/version` fájlokból épít. A csomag a futtatható fájlt, a két nyelven elérhető dokumentációt, a telepítőt, az öntesztet és a csomagépítés forrásait is tartalmazza. A `--set-version VERZIÓ` a szöveges forrásfájlok kiadási verzióját frissíti. A csomagépítés külön lépés.

## Ellenőrzés és működési határok

A `test-tmuxh.sh` saját tmux socketet indít külön munkakönyvtárban. Ellenőrzi a normál és aszinkron futtatást, a kilépési kódot, a környezeti változók átadását, az UTF-8 JSON-kimenetet, az üres várakozást, a diagnosztikát és a fájlmásolást.

A panel megvizsgálása és a tmux bemenetküldés két külön művelet. Kapcsolatvesztés közben a távoli végrehajtás eredménye bizonytalan lehet, ezért a feladat azonosítóját és naplóját meg kell őrizni. Ugyanazon a panelen a kézi beavatkozás, több egyidejű állapotleolvasás vagy interaktív alkalmazás megoszthatja a shell bemenetét vagy az olvasási kurzort. Fájlmásoláskor a tartalom és a parancs a terminálon keresztül megy, ezért a naplók tárolásának és hozzáférésének szabályait az üzemeltetési környezetben kell meghatározni.
