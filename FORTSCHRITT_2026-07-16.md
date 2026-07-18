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

## Update: MOSFET-Alternative statt USB-Relais (2026-07-18)

Der weitere Tischtest verwendet nicht mehr das USB-Relais als Schaltglied. Das vorhandene 4-Kanal-MOSFET-Modul ist eine geeignete Alternative fuer die 12-V-DC-Last und umgeht die nachgewiesene Low-Speed-USB-Inkompatibilitaet des vorhandenen Hubs vollstaendig.

### Bestaetigte MOSFET-Anschluesse

Am Modul wird ausschliesslich Kanal 1 verwendet:

```text
Pi GPIO17 (physischer Pin 11) -> PWM1
Pi GND (physischer Pin 9) -> GND1

12-V-Netzteil Plus -> DC+
12-V-Netzteil Minus -> DC-

Magnetschloss Plus -> OUT1+
Magnetschloss Minus -> OUT1-
```

`OUT1-` ist der per MOSFET geschaltete Minuspol; `OUT1+` ist mit dem positiven 12-V-Versorgungszweig verbunden. Das Magnetschloss darf erst nach einem lastfreien Funktionstest angeschlossen werden. Jumper-Kabel sind nur fuer `PWM1` und `GND1` zulaessig, nicht fuer den 12-V- oder Schlossstromkreis.

GPIO17 ist auf dem Pi als Ausgang mit LOW-Pegel gesetzt. Kanal 1 ist damit softwareseitig aus. Die GPIO-Steuerung ist angeschlossen; die 12-V-Seite bleibt bis zum naechsten Test getrennt.

### Fehlendes Teil vor dem 12-V-Test

Das vorhandene 12-V-/5-A-Netzteil hat einen Hohlstecker (Plus innen). Fuer die Verbindung zum MOSFET-Modul wird eine passende weibliche DC-Buchse mit offenen, ausreichend dimensionierten Leitungen benoetigt:

```text
DC-Buchse (female), 5,5 x 2,1 mm, 18 AWG, mindestens 5 A
```

Der Adapter darf erst verwendet werden, nachdem die tatsaechliche Steckerabmessung des Netzteils bestaetigt ist. Das Netzteilkabel wird nicht abgeschnitten. Vor dem Anschluss des Magnetschlosses sind DC+/DC- ohne Last zu verdrahten und Kanal 1 getrennt zu testen.

### USB-Relais: abschliessender Diagnose-Stand

Das Projekt `darrylb123/usbrelay` wurde auf dem Pi aus der Quelle gebaut und nach `/usr/bin/usbrelay` installiert. Zusaetzlich sind `git` und `libhidapi-dev` installiert. Der Befehl `sudo usbrelay -d` meldet erwartungsgemaess `Found 0 devices`, weil das Relais nicht enumeriert wird.

Das USB-Relais bleibt am vorhandenen Hub nicht nutzbar. Nach dem Wiedereinstecken erschien erneut nur:

```text
usb 1-1.4: new low-speed USB device number ... using dwc_otg
usb 1-1-port4: attempt power cycle
```

Es gibt weiterhin weder `16c0:05df` in `lsusb` noch ein `/dev/hidraw*`. Die bereits getesteten Kernel-Optionen `dwc_otg.speed=1` und `usbcore.old_scheme_first=Y` haben das Problem nicht geloest und sind nicht aktiv. Der NFC-Leser funktioniert weiter am Hub.

### Angepasste naechste Schritte

1. Passende DC-Buchse mit 18-AWG-Leitung beschaffen und die Steckerabmessung pruefen.
2. MOSFET-Modul ohne Magnetschloss mit 12 V versorgen und Kanal 1 per GPIO17 ein-/ausschalten.
3. Erst nach erfolgreichem lastfreien Test Magnetschloss sowie manuellen Abschalter und Sicherung im 12-V-Pluszweig verdrahten.
4. Die Anwendungssoftware verwendet GPIO17 statt `usbrelay`; die geforderte Sicherheitslogik bleibt: LOW = entriegelt, HIGH = verriegelt.
