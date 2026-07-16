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
- ASHATA-USB-Relaisplatine mit vier 12-V-Kanaelen
- 12-V-/5-A-Netzteil fuer Relaisplatine und 12-V-/180-kg-Magnetschloss
- DC-tauglicher manueller Entriegelungs-/Ausschalter und passende Sicherung im 12-V-Pluszweig
- Gehaeuse, Kabelverschraubungen und Zugentlastung fuer die fachgerechte Montage

### Anschluesse

Der NFC-Leser und die USB-Relaisplatine werden am OTG-Hub betrieben. Der Hub wird am Datenport des Raspberry Pi angeschlossen. Der Stromport des Pi wird ausschliesslich mit dem separaten 5-V-Netzteil versorgt.

Das Magnetschloss wird ueber Relaiskanal 1 mit dem normalerweise offenen Kontakt (`NO`) geschaltet:

```text
12-V-Netzteil Plus -> Sicherung -> manueller Schalter -> Verteilung
Verteilung -> Relaisplatine 12 V Plus
Verteilung -> Relais Kanal 1 COM

Relais Kanal 1 NO -> Magnetschloss Plus
12-V-Netzteil Minus -> Magnetschloss Minus
12-V-Netzteil Minus -> Relaisplatine 12 V Minus

Pi-OTG-Port -> USB-Hub -> NFC-Leser und USB-Relais
Pi-Stromport -> separates 5-V-Pi-Netzteil
```

Kanal 1 `AN` versorgt das Magnetschloss und verriegelt die Tuer. Kanal 1 `AUS` unterbricht die Schlossversorgung und entriegelt die Tuer. Der manuelle Schalter trennt die 12-V-Versorgung vor dem Relaiskontakt und entriegelt die Tuer daher unabhaengig von Pi, Software und USB-Status.

Die USB-Relaisplatine darf ihren letzten Schaltzustand bei USB-Ausfall behalten. Das ist fuer diese Version bewusst akzeptiert: Ein Pi-Ausfall kann die Tuer verriegelt lassen, bis der manuelle Schalter betaetigt wird.

## Steuerungssoftware

- Python-Dienst unter `/opt/kaffeetuer`, gestartet und ueberwacht durch `systemd`.
- `pcscd` und Python-PC/SC-Bindings erkennen Einstecken und Entfernen unterstuetzter NFC-Tokens.
- Jede erfolgreiche neue Token-Erkennung schaltet Relaiskanal 1 sofort aus, haelt ihn 30 Sekunden aus und schaltet ihn anschliessend wieder ein.
- Ein dauerhaft aufgelegter Token loest nur einmal aus. Erst nach Entfernen und erneutem Erkennen wird erneut entriegelt.
- Beim Start sendet der Dienst zuerst `Kanal 1 AUS`, damit die Tuer waehrend der Geraetepruefung entriegelt ist.
- Solange kein NFC-Leser erkannt wird oder der Leser zur Laufzeit verschwindet, bleibt Kanal 1 aus. Die Erkennung wird alle 5 Sekunden wiederholt.
- Wird der NFC-Leser fuenf Sekunden stabil erkannt, schaltet der Dienst Kanal 1 ein und verriegelt sofort.
- Der Dienst kapselt die USB-Relaissteuerung in einer kleinen Python-Schnittstelle. USB-Vendor/Product-ID und Kanalnummer stehen in einer lokalen Konfigurationsdatei; der konkrete Befehlssatz wird im Tischtest mit der vorhandenen Relaisplatine verifiziert.
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

- Tischtest ohne Tuer: Relais `AN/AUS`, manuelle Abschaltung, 30-Sekunden-Timer und Neustart des Pi.
- NFC-Test mit mehreren unterstuetzten Karten und Tags: genau eine Oeffnung pro Auflegen, keine Wiederholung bei aufgelegtem Token.
- Abziehen und erneutes Anstecken des NFC-Lesers: Tuer wird entriegelt, Leser wird im 5-Sekunden-Rhythmus gesucht, nach fuenf Sekunden stabiler Erkennung wird wieder verriegelt.
- USB-Relais und NFC-Leser gleichzeitig am OTG-Hub testen.
- Lasttest mit angeschlossenem Magnetschloss: Stromaufnahme, Erwaermung, 30-Sekunden-Entriegelung und manuellen Schalter pruefen.
- Logtest: alle relevanten Betriebs- und Fehlerereignisse erscheinen ohne NFC-Karten-ID im Debug-Log; nach einer simulierten 31-taegigen Rotation sind nur die letzten 30 Tagesdateien vorhanden.
- Feldabnahme durch die fachverantwortliche Person: Gehaeuse, Zugentlastung, Absicherung, Tuermechanik, Notentriegelung und gesetzlich erforderliche Massnahmen pruefen.

## Annahmen und Grenzen

- Das Magnetschloss arbeitet mit 12 V DC und ist fuer den vorgesehenen Einbau fachgerecht zugelassen und montiert.
- Der Kunde erhaelt die Hardware bereits korrekt verdrahtet oder eine Fachperson uebernimmt die Verdrahtung.
- Der manuelle Schalter ist die verbindliche direkt wirksame Freigabe bei Ausfall von Pi oder USB-Relaissteuerung.
- Die bewusste Oeffnung durch jeden lesbaren NFC-Token ist nur fuer den vorgesehenen, rechtlich und organisatorisch passenden Einsatz akzeptiert.
