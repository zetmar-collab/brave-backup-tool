# Brave Backup Tool v2.2.0

## Poprawki bezpieczeństwa danych
- **Przywracanie haseł i ciasteczek** — plik `Local State` (klucz szyfrowania `os_crypt`) jest teraz odtwarzany zawsze, także przy przywracaniu pojedynczego profilu. Wcześniej selektywne przywracanie powodowało, że zapisane hasła i ciasteczka się nie odszyfrowywały.

## Nowe funkcje
- **Czyszczenie cache przed pełną kopią** — przed pełnym backupem program usuwa katalogi cache z żywego profilu Brave (Cache, Code Cache, GPUCache, ShaderCache itd.). Cache i tak nie trafiał do kopii — czyszczenie zwalnia miejsce na dysku i przyspiesza backup. W logu pojawia się informacja o zwolnionym miejscu.
- **Kontrola wolnego miejsca** — przed pełną kopią sprawdzane jest dostępne miejsce na dysku docelowym (szacowany rozmiar + 10% zapasu). Brak miejsca przerywa operację z czytelnym komunikatem.

## Wydajność
- Rozmiar kopii jest zapisywany w `backup-meta.json` i odczytywany przy wyświetlaniu listy — koniec rekursywnego skanowania każdego katalogu przy każdym odświeżeniu.

## Poprawki techniczne i porządki
- Pojedyncze źródło numeru wersji w kodzie.
- Wspólna lista plików roota oraz wspólny logger konsoli (mniej duplikacji).
- Uporządkowane pliki repozytorium.

---
Pobierz `BraveBackup.exe` z sekcji Assets poniżej. Uruchom — nie wymaga instalacji.
