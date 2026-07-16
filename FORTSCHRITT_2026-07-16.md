# Übergabe: Hardware- und NFC-Stand (2026-07-16)

Diese Datei dokumentiert den Stand nach dem ersten Tischtest. Sie ist für die Fortsetzung durch einen anderen Agenten gedacht.

## Projektziel

Offline-NFC-Türöffner auf Raspberry Pi Zero/Zero W. Jeder lesbare unterstützte NFC-Token soll Relaiskanal 1 für 30 Sekunden ausschalten. Keine Token-IDs oder personenbezogenen Daten speichern bzw. loggen.

Der ausführliche Ziel- und Sicherheitsplan steht in `projektplan_offline_nfc_tueroeffner.md`.

## Zugang zum Pi

- Host: `192.168.1.6`
- Benutzer: `pi`
- Zugangsdaten wurden außerhalb des Repositorys übergeben und dürfen **nicht** in Dateien, Commits oder Logs gespeichert werden.
- Pi: ARMv6, Raspberry Pi OS Bookworm, Kernel beim Test: `6.12.93+rpt-rpi-v6`.

## NFC-/Smartcard-Reader: erfolgreich

Der Reader ist über den vorhandenen Hub verbunden und wurde erkannt:

- USB-ID: `2ce3:9567`
- Linux-Name: `Generic EMV Smartcard Reader`
- PC/SC-Reader: `Alcor Link AK9567 [Contactless Card Reader]`

Auf dem Pi installiert:

```text
pcscd
pcsc-tools
libccid
python3-pyscard
```

`pcscd.socket` ist aktiv. Mit `pcsc_scan -n` wurde eine kontaktlose Karte/ein Tag erfolgreich erkannt. Der Test wurde absichtlich ohne Speichern oder Protokollieren einer Karten-ID durchgeführt.

## USB-Relais: identifiziert, aber am Pi-Hub nicht enumerierbar

Die gezeigte rote 4-Kanal-Relaisplatine hat einen USB-B-Anschluss und eine separate 12-V-Versorgung. Das vorhandene Kabel ist USB-A auf USB-B.

### Nachweis unter Windows

Am Windows-PC wird die Platine korrekt erkannt:

- USB-ID: `16c0:05df`
- Klasse: HID
- bekannte Produktfamilie: `USBRelay4` / DCTTECH-kompatibel
- keine Windows-Gerätefehler

Linux-Unterstützung für `16c0:05df` gibt es über das Paket/Projekt `usbrelay`.

### Pi-Hub und Fehlerbild

Der aktuell verwendete Hub meldet sich als:

```text
0a05:7211  Unknown Manufacturer hub
```

Er ist ein sehr einfacher USB-1.1/Full-Speed-Hub (12 Mbit/s), trotz möglicher "USB 2.0"-Beschriftung.

Das Relais wird am Pi als Low-Speed-Gerät erkannt, die USB-Enumeration bricht aber stets ab:

```text
usb 1-1.4: new low-speed USB device number ... using dwc_otg
usb 1-1-port4: attempt power cycle
```

Es erscheint danach nie in `lsusb`, nie als `16c0:05df`, und es wird kein `hidraw`-Gerät angelegt.

Wichtige Abgrenzungen:

- Durch Tauschen der Hub-Ports funktionierte der NFC-Reader an beiden getesteten Ports.
- Das Relais scheiterte an beiden getesteten Ports gleich.
- Am Windows-PC funktionieren Relais und vorhandenes USB-A-auf-USB-B-Kabel.
- Ohne angeschlossene 12 V erzeugt das Relais beim erneuten Einstecken trotzdem die Low-Speed-Erkennung. Es ist also USB-seitig aktiv, der Pi-Hub kann aber die Gerätebeschreibung nicht lesen.

## Strom-/Rückspeisungsbeobachtung

Bei angeschlossener 12-V-Relaisversorgung blieb der Pi an, nachdem sein separates 5-V-Netzteil entfernt wurde. Nach Trennen der 12-V-Relaisversorgung ging der Pi aus.

Das zeigt eine Rückspeisung über den USB-Pfad oder die Hub-Versorgung. Die genaue Stelle (Relais, Hub oder Zusammenspiel) wurde nicht zerstörungsfrei bestimmt.

Folgerung: Während weiterer Tests muss das Magnetschloss abgeklemmt bleiben. Vor Anschluss von 12 V an das Relais am Pi muss geprüft werden, ob der neue Aufbau den Pi rückspeist.

## Getestete reine Software-Workarounds

Beide Tests wurden ohne 12-V-Relaisversorgung durchgeführt und haben die Enumeration nicht verbessert:

1. `dwc_otg.speed=1` in `/boot/firmware/cmdline.txt` (Pi-USB auf Full-Speed begrenzt).
2. `usbcore.old_scheme_first=Y` zur alternativen Linux-Initialisierung für Low-/Full-Speed-USB-Geräte.

Beide Änderungen wurden zurückgenommen. Die originale `cmdline.txt` wurde wiederhergestellt; auf dem Pi liegt zusätzlich eine Sicherung unter:

```text
/boot/firmware/cmdline.txt.before-usb-speed-test
```

Die momentane Kernel-Kommandozeile enthält weder `dwc_otg.speed=1` noch die persistente `usbcore.old_scheme_first`-Option.

## Empfohlener nächster Hardwaretest

Der aktuelle `0a05:7211`-Hub ist die nachgewiesene Engstelle für die Low-Speed-Enumeration. Empfohlen wurde ein echter, extern versorgter USB-2.0-Hub:

- D-Link DUB-H4/E (4-Port USB 2.0, eigenes Netzteil, dokumentierte Unterstützung für Low-, Full- und High-Speed):
  <https://www.reichelt.de/de/de/shop/produkt/usb_2_0_4-port_hub_mit_netzteil_schwarz-131483>
- Für den Pi Zero zusätzlich ein Micro-USB-OTG-Adapter (Micro-B-Stecker auf USB-A-Buchse), falls keiner vorhanden ist:
  <https://www.reichelt.de/de/de/shop/produkt/usb_2_0_adapter_micro-b-stecker_a-buchse_otg_schwarz-314909>

Anschluss mit dem vorgeschlagenen Hub:

```text
Pi-Datenport -> Micro-USB-OTG-Adapter -> Hub-Upstream
Hub-Downstream -> NFC-Reader
Hub-Downstream -> vorhandenes USB-A-auf-USB-B-Kabel -> Relais
Pi-Power-Port -> separates 5-V-Netzteil
```

Zuerst ausschließlich mit Pi-5-V-Versorgung testen:

```bash
lsusb
lsusb -t
find /dev -maxdepth 1 -name 'hidraw*'
```

Erst wenn `16c0:05df` sichtbar ist, 12 V am Relais anschließen. Danach als Sicherheitsprüfung das Pi-5-V-Netzteil kurz trennen: Der Pi muss ausgehen. Bleibt er an, liegt weiter Rückspeisung vor; alles wieder trennen und keine Relaislast anschließen.

## Hinweis zum zuvor recherchierten Power Blocker

Ein PortaPow USB Power Blocker (`PP_PBC1`) trennt 5 V/VBUS und lässt Daten durch. Er könnte eine Rückspeisung verhindern, behebt aber den nachgewiesenen Enumerationsfehler des aktuellen Hubs nicht allein. Deshalb ist zunächst der Hubwechsel sinnvoll.

## Nächste Softwarearbeiten nach erfolgreicher Relais-Erkennung

1. Auf dem Pi `usbrelay` bzw. die HID-Steuerung für `16c0:05df` installieren und testen.
2. Ohne Magnetschloss Relaiskanal 1 schalten und den Befehlssatz verifizieren.
3. Die Python-Anwendung unter `/opt/kaffeetuer` implementieren:
   - PC/SC-Reader und Token-Ereignisse überwachen.
   - Keine Token-ID protokollieren.
   - Eine Öffnung pro Auflegen; erneute Öffnung erst nach Entfernen.
   - Relais für 30 Sekunden ausschalten, danach wieder einschalten.
   - Bei fehlendem Reader Relais aus und Wiederholungsprüfung alle 5 Sekunden.
4. `systemd`-Dienst, sichere Standardkonfiguration, lokale Logs und `logrotate` ergänzen.

## Sicherheitsstatus

- Es wurde kein Relais-Schaltbefehl an der Türlast ausgeführt.
- Das Magnetschloss soll bis zu erfolgreichen, lastfreien Relais- und Rückspeisungstests getrennt bleiben.
- Die Software darf bei Readerverlust nicht verriegeln; das entspricht dem Projektplan.
