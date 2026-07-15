# WorkHronos

Minimalni Toggl klon — native macOS aplikacija za praćenje vremena. SwiftUI + SQLite (GRDB), build preko Swift Package Manager-a, bez Xcode-a.

## Features

- Start/stop timer sa nazivom projekta; timer preživljava restart aplikacije (running entry je red u bazi).
- Toggl semantika editovanja: trajanje running timer-a se može menjati (pomera start), start vreme editable, a kod zaustavljenih entry-ja se menjaju start, end, trajanje i datum.
- Nedeljni pregled (ISO nedelja, ponedeljak start) sa grupisanjem po projektu i totalima.
- Autocomplete naziva projekata iz istorije.
- Baza je jedan SQLite fajl na lokaciji po izboru (MacPass-style) — može u Dropbox za sync između mašina.

## Build & run

Potrebni su samo Command Line Tools (Swift 5.10+ / 6.x). Bez Xcode-a.

```sh
make run    # razvoj: swift run
make app    # release: dist/WorkHronos.app
make test   # unit testovi (swift test)
```

## Baza podataka

Na prvom startu biraš lokaciju `.sqlite` fajla: default (`~/Library/Application Support/WorkHronos/`), novi fajl bilo gde (npr. u Dropbox-u), ili otvaranje postojećeg.

SQLite radi u `journal_mode=DELETE` — na disku je uvek jedan fajl, bez `-wal`/`-shm` sidecar fajlova, što je bezbedno za Dropbox sync. Aplikacija detektuje kada Dropbox zameni fajl (novi inode) i automatski ponovo otvara bazu pri aktivaciji prozora.

**Ograničenje:** istovremeni rad na dve mašine nad istim fajlom može proizvesti Dropbox "conflicted copy" — koristi jednu mašinu u jednom trenutku.

## Unos trajanja

Polje za trajanje prihvata: `1:30:45` (h:mm:ss), `1:30` (h:mm), `90` (minuti), `1h 30m`, `45m`, `30s`.
