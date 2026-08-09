# Offline-NFC-Tueroeffner als Kundenimage

## Zusammenfassung

Das Projekt liefert ein identisches, vollstaendig offline arbeitendes SD-Karten-Image fuer Raspberry Pi Zero und Zero W mit Legacy Raspberry Pi OS Lite 32-bit. Nach dem Flashen und Einschalten startet die Tuersteuerung automatisch.

Das System ist bewusst keine Zutrittskontrolle: Jeder vom USB-NFC-Leser erfolgreich erkannte, unterstuetzte NFC-Token entriegelt die Tuer fuer 30 Sekunden. Es werden keine Nutzer, Karten-IDs, Berechtigungen oder Netzwerkdaten gespeichert.

## Hardware und Verdrahtung

### Benoetigte Hardware

- Raspberry Pi Zero oder Zero W mit 40-poliger GPIO-Stiftleiste
- 5-V-Netzteil fuer den Raspberry Pi
- Micro-USB-OTG-Hub mit mindestens zwei Datenports
- USB-NFC-Chipkartenleser
- 4-Kanal-MOSFET-Schaltmodul fuer DC-Lasten
- 12-V-/5-A-Netzteil fuer MOSFET-Modul und 12-V-/180-kg-Magnetschloss
- DC-tauglicher manueller Entriegelungs-/Ausschalter und passende Sicherung im 12-V-Pluszweig
- Gehaeuse, Kabelverschraubungen und Zugentlastung fuer die fachgerechte Montage

### Anschluesse

Der NFC-Leser wird am OTG-Hub betrieben. Der Hub wird am Datenport des Raspberry Pi angeschlossen. Der Stromport des Pi wird ausschliesslich mit dem separaten 5-V-Netzteil versorgt.

Das Magnetschloss wird ueber Kanal 1 des MOSFET-Moduls geschaltet. Der Eingang wird bewusst aktiv-low verdrahtet, damit der Pi trotz seines 3,3-V-GPIOs die benoetigten 5 V am Moduleingang erzeugt:

```text
Pi Pin 2 (5 V) -> MOSFET PWM1
Pi GPIO27 (physischer Pin 13) -> MOSFET GND1

12-V-Netzteil Plus -> Sicherung -> manueller Schalter -> MOSFET DC+
12-V-Netzteil Minus -> MOSFET DC-
MOSFET OUT1+ -> Magnetschloss Plus
MOSFET OUT1- -> Magnetschloss Minus

Pi-OTG-Port -> USB-Hub -> NFC-Leser
Pi-Stromport -> separates 5-V-Pi-Netzteil
```

GPIO27 `LOW` schaltet den MOSFET ein, versorgt das Magnetschloss und verriegelt die Tuer. GPIO27 `HIGH` schaltet den MOSFET aus, macht das Schloss stromlos und entriegelt die Tuer. Der manuelle Schalter trennt die 12-V-Versorgung direkt und entriegelt die Tuer daher unabhaengig von Pi und Software.

## Steuerungssoftware

- Python-Dienst unter `/opt/kaffeetuer`, gestartet und ueberwacht durch `systemd`.
- `pcscd` und Python-PC/SC-Bindings erkennen Einstecken und Entfernen unterstuetzter NFC-Tokens.
- Jede erfolgreiche neue Token-Erkennung setzt GPIO27 sofort auf `HIGH`, haelt das Schloss 30 Sekunden stromlos und setzt GPIO27 anschliessend wieder auf `LOW`.
- Ein dauerhaft aufgelegter Token loest nur einmal aus. Erst nach Entfernen und erneutem Erkennen wird erneut entriegelt.
- Die Boot-Firmware, `systemd` und der Python-Dienst setzen GPIO27 auf `LOW`, damit die Tuer im normalen Betrieb verriegelt bleibt.
- Fehlt der NFC-Leser oder verschwindet er zur Laufzeit, bleibt GPIO27 auf `LOW` und die Tuer verriegelt. Der manuelle 12-V-Schalter bleibt die unabhaengige Notentriegelung.
- Die Anwendung steuert GPIO27 mit `pinctrl`; das inkompatible USB-Relais wird nicht mehr verwendet.
- Programmfehler werden von `systemd` automatisch neu gestartet. Ein Watchdog ueberwacht die Prozesslebendigkeit, ist aber kein Ersatz fuer den manuellen Schalter.
- WLAN, Bluetooth, SSH und sonstige Netzwerkdienste bleiben deaktiviert.

## Debug-Protokollierung

- Die Anwendung schreibt strukturierte, lokale Debug-Logs nach `/var/log/kaffeetuer/app.log`.
- Protokolliert werden Dienststarts und Neustarts, erkannte oder verlorene NFC-Leser, Leser-Wiederholversuche, Token-Erkennungen ohne Karten-ID, Entriegelungsbeginn und -ende, Relaisbefehle sowie USB- und Programmfehler.
- NFC-Karten-IDs, persoenliche Daten und Token-Inhalte werden nicht protokolliert.
- `logrotate` rotiert die Logdatei taeglich, behaelt 30 Tagesdateien und loescht Eintraege, die aelter als 30 Tage sind. Alte Tagesdateien werden komprimiert, solange sie innerhalb der 30 Tage liegen.
- Der `systemd`-Journalzugriff bleibt fuer zusaetzliche Dienstdiagnosen aktiv, seine Groesse wird begrenzt, damit die SD-Karte nicht unnoetig beschrieben wird.

## Kundenfaehiges Image und Uebergabe

- Build-Basis: Raspberry Pi OS Legacy Lite 32-bit, kompatibel mit ARMv6 auf Pi Zero und Pi Zero W.
- Ein reproduzierbarer Image-Build installiert alle benoetigten Pakete, kopiert den Code, aktiviert den `systemd`-Dienst, deaktiviert Netzwerkdienste und setzt die Standardkonfiguration ohne Kundeneingaben.
- Release-Artefakte: `kaffeetuer-vX.Y.Z.img.xz`, SHA-256-Pruefsumme, kurze Flash-Anleitung sowie ein ZIP mit Quellcode, Build-Skript und Verdrahtungsplan.
- Der Kunde flasht ausschliesslich das Image auf eine microSD-Karte, steckt sie ein und versorgt Pi sowie 12-V-Tuertechnik mit Strom. Es gibt keine Ersteinrichtung und keine Internetverbindung.
- Updates erfolgen durch ein neues, versioniertes SD-Image. Eine alte SD-Karte bleibt als funktionierender Rueckfall erhalten.

## Tests und Abnahme

- Tischtest ohne Tuer: MOSFET `AN/AUS`, manuelle Abschaltung, 30-Sekunden-Timer und Neustart des Pi.
- NFC-Test mit mehreren unterstuetzten Karten und Tags: genau eine Oeffnung pro Auflegen, keine Wiederholung bei aufgelegtem Token.
- Abziehen und erneutes Anstecken des NFC-Lesers: Tuer bleibt verriegelt; nach erneuter Erkennung muss die NFC-Oeffnung wieder funktionieren.
- Lasttest mit angeschlossenem Magnetschloss: Stromaufnahme, Erwaermung, 30-Sekunden-Entriegelung und manuellen Schalter pruefen.
- Logtest: alle relevanten Betriebs- und Fehlerereignisse erscheinen ohne NFC-Karten-ID im Debug-Log; nach einer simulierten 31-taegigen Rotation sind nur die letzten 30 Tagesdateien vorhanden.
- Feldabnahme durch die fachverantwortliche Person: Gehaeuse, Zugentlastung, Absicherung, Tuermechanik, Notentriegelung und gesetzlich erforderliche Massnahmen pruefen.

## Annahmen und Grenzen

- Das Magnetschloss arbeitet mit 12 V DC und ist fuer den vorgesehenen Einbau fachgerecht zugelassen und montiert.
- Der Kunde erhaelt die Hardware bereits korrekt verdrahtet oder eine Fachperson uebernimmt die Verdrahtung.
- Der manuelle Schalter ist die verbindliche direkt wirksame Freigabe bei Ausfall von Pi oder USB-Relaissteuerung.
- Die bewusste Oeffnung durch jeden lesbaren NFC-Token ist nur fuer den vorgesehenen, rechtlich und organisatorisch passenden Einsatz akzeptiert.
