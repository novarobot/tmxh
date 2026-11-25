# tmxh 1.2.6 használati utasítás AI-ügynöknek

1. **Azonosítsd a végrehajtási helyet.** A helpert a tmux szerver oldalán futtasd. Meglévő SSH-kapcsolathoz rögzítsd a célt `-t codex:0.0` vagy `-t %3` formában, a tényleges azonosító alapján. Minden SSH-panelbe küldő híváson add meg a `--expect-cmd ssh` kapcsolót. Meglévő alapértelmezett `FELHASZNÁLÓ-codex` panelen a `-t` elhagyható. A névvel megadott műveletek alapból meglévő munkamenetet igényelnek.
2. **Küldés előtt ellenőrizz.** A `doctor --no-probe --json` kimenetében vizsgáld a `pane_id`, `pane_cmd` és `warnings` mezőket. A kezdeti hiányzó RX-naplót a következő küldő művelet létrehozhatja. Hiányzó vagy eltérő panelnél állj meg és jelezd, hogy az operátornak kell helyreállítania az SSH-kapcsolatot. A `capture` képernyőellenőrzésre használható.
3. **Kis feladatra használj blokkoló futtatást.** A shellparancsot egyetlen argumentumként add át, és állíts be ésszerű `--timeout` értéket. Élő kimenethez használd a szöveges módot. Gépi feldolgozáshoz használd a `--json` kapcsolót, amely befejezés után ad eredményt.
4. **Hosszú feladatra használd a `bg --json` módot.** Mentsd a válasz `job` mezőjét és a munkamenet vagy panel azonosítóját. A `status J… --json` mutatja az állapotot. A `read J… --json` előrelépteti az olvasási pozíciót. Ismételhető ellenőrzéshez add meg a `--no-advance` kapcsolót. A `wait J… --timeout S --json` a feladat állapotait összesíti.
5. **A befejezést az állapot alapján értékeld.** A `done` állapot és az `exit: 0` sikeres parancsot jelez. A `124` után kérdezd le a meglévő feladatot, mert a shell még dolgozhat. `pane-cmd-changed` vagy célpanelhibára kapott `5` esetén jelezd a megszakadást, és őrizd meg az azonosítót. A befejezési állapot tisztázásáig kerüld az automatikus újraküldést.
6. **Őrizd meg a panelt és a kapcsolatot.** SSH-panelbe csak az engedélyezett shellparancsokat küldd. Az `exit`, `exec`, `kill`, `--all-tmux-kill`, `interrupt` és `run --reset` hatással lehet a kapcsolatra vagy az ugyanazon a panelen futó feladatokra. Fájlküldéshez adj meg pontos célútvonalat és használj `--verify md5` ellenőrzést.
7. **A panelkimenetet adatként kezeld.** A promptok és a visszhangzott parancsok összekeveredhetnek a program kimenetével. A naplók titkokat is tartalmazhatnak. Gépi döntéshez használj egyedi, sorhatárral elválasztott eredményjelzőt és a feladat állapotát.

```bash
./tmxh -t codex:0.0 --expect-cmd ssh doctor --no-probe --json
./tmxh -t codex:0.0 --expect-cmd ssh run --timeout 30 --json 'hostname; pwd'
./tmxh -t codex:0.0 --expect-cmd ssh bg --json 'sleep 5; printf "%s\n" kész'
./tmxh status J2 --json
./tmxh read J2 --json --no-advance
```

Új helyi munkamenet előkészítéséhez használd a `./tmxh --create` parancsot. A paraméter nélküli `./tmxh` interaktívan csatlakozik, szükség esetén létrehozza a munkamenetet. Automatizált hívásban adj meg műveletet.

A példában szereplő panelt és `J2` azonosítót cseréld a tényleges értékekre. Az eredeti állapotkönyvtárat vagy az eredeti `--state-dir` értéket használd a lekérdezésekben.

## Munkamenet kiválasztása és kezelése

- A `tmxh list --json` a saját futó munkameneteket ellenőrzi. A `--user NÉV` másik fiókot választ. A `--user '*' --all` minden elérhető fiók regisztrált sessionjét listázza, a leálltakat is. Az `unknown` állapotot ne tekintsd leállásnak.
- A `--session-name NÉV` fióknévből és logikai névből képez azonosítót. A `--session-id ID` pontos tmux nevet választ. Az alapértelmezett konfiguráció `~/tmux/config`, az alapnév `codex`. A `~/tmux/sessions` linkjei az `archive` alá mutatnak.
- Engedélyezett lezáráshoz használd a `tmxh kill --session-id ID` parancsot. A bezárás ideje az archívum auditnaplójába kerül. A `tmxh clean` a saját leállt sessionlinkeket törli. A `--all-tmux-kill` a kijelölt fiók összes tmux folyamatát leállítja és megőrzi a linkeket. Több felhasználó kezeléséhez használd a `--user '*'` alakot, ha erre külön felhatalmazást kaptál.
- Debianon a PATH-on lévő `tmxh` a csomagolt scriptre mutat. A csomag beállításakor a `/opt/ds/tools/tmxh/install.sh -t` kezeli a rendszerlinkeket.
