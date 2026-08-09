# Nexor-Pi-Door

Offline-NFC-Tueroeffner fuer Raspberry Pi Zero/Zero W.

## Betriebslogik

- GPIO27 `LOW`: MOSFET und Magnetschloss an, Tuer verriegelt.
- NFC-Token erkannt: GPIO27 fuer 30 Sekunden `HIGH`, Schloss stromlos, Tuer entriegelt.
- Danach automatisch wieder GPIO27 `LOW` und verriegelt.
- Ein aufgelegter Token loest nur einmal aus; fuer eine weitere Oeffnung muss er entfernt und erneut aufgelegt werden.
- Es werden keine Karten-ID und keine Karteninhalte gelesen oder protokolliert.

## Installation auf Raspberry Pi OS

```sh
sudo sh install.sh
sudo reboot
```

Der Installer richtet `kaffeetuer.service`, PC/SC und die fruehe GPIO27-Bootvorgabe ein. Die aktuelle Verdrahtung und der Hardwarestand stehen in `FORTSCHRITT_2026-07-16.md`.

## Flashbares Image

Das gebaute Release-Image liegt unter:

```text
deploy/nexor-pi-door-v0.1.1-2026-08-08.img.xz
```

Version v0.1.1 enthaelt zusaetzlich die fuer den eingesetzten Pi erforderliche Boot-Einstellung `over_voltage=1`. Die zugehoerige SHA-256-Pruefsumme steht in der gleichnamigen Datei mit der Endung `.sha256`. Die Flash-Anleitung steht unter `image/FLASHEN.md`.

## Kundenuebergabe

Die vollstaendige deutschsprachige Kundenanleitung liegt als Word- und PDF-Datei vor:

```text
output/documents/Kundenanleitung_Nexor_Pi_Door.docx
output/pdf/Kundenanleitung_Nexor_Pi_Door.pdf
```

Sie enthaelt Materialliste, Sicherheitsregeln, finale relaislose Verdrahtung, GPIO-Pinplan, Flash-Anleitung mit Raspberry Pi Imager, Erstinbetriebnahme, Bedienung, Fehlerhilfe und Abnahmeprotokoll.
