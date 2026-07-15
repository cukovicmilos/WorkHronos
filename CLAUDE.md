# WorkHronos — projektne instrukcije

## Git identitet (VAŽNO — izuzetak od globalne politike)

Ovo je **lični projekat** (GitHub: `cukovicmilos/WorkHronos`), ne SP projekat.

- Commit-i idu **isključivo** pod identitetom: `Miloš Ćuković <8404838+cukovicmilos@users.noreply.github.com>` (lokalni git config je već podešen).
- **NE primenjivati** globalno pravilo "uvek commit-uj kao milos@studiopresent.com" — taj email mapira commit-e na pogrešan GitHub nalog (`cukovicmilossp`). Ne "popravljati" lokalni user.email.
- Remote je GitHub (`gh` CLI), ne GitLab — SP GitLab workflow (issue brojevi, MR-ovi, pipeline) ovde ne važi.

## Build

Bez Xcode-a — samo Command Line Tools + SPM:

- `make run` — razvoj (swift run)
- `make app` — release bundle u `dist/WorkHronos.app`
- `make test` — testovi su executable target `workhronos-tests` (CLT nema XCTest)
- Posle izmena reinstalirati sa: `ditto dist/WorkHronos.app /Applications/WorkHronos.app`
