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

## Update: MOSFET-Eingang benoetigt 5 V (2026-08-02)

Die 12-V-Seite wurde inzwischen erfolgreich aufgebaut und getestet. Verwendet werden die passende DC-Buchse, das vorhandene 12-V-/5-A-Netzteil und Kanal 1 des MOSFET-Moduls.

### Bestaetigte 12-V-Verdrahtung

```text
12-V-Netzteil Plus -> DC+
12-V-Netzteil Minus -> DC-

Magnetschloss Plus -> OUT1+
Magnetschloss Minus -> OUT1-
```

Ein direkter Test des Magnetschlosses an DC+/DC- war erfolgreich: Netzteil, DC-Adapter, Leitungen und Magnetschloss funktionieren. Auch ueber OUT1 zog das Schloss an, sobald der MOSFET-Eingang mit festen 5 V angesteuert wurde.

### Eindeutige Diagnose des Steuereingangs

Folgende Eingangstests wurden durchgefuehrt:

| Steuersignal an PWM1 | Ergebnis |
| --- | --- |
| Pi Pin 2, feste 5 V | IN1 und OUT1 aktiv; Magnetschloss zieht an |
| Pi Pin 1, feste 3,3 V | IN1 nur sehr schwach; OUT1 aus; Schloss bleibt aus |
| GPIO17, 3,3 V | IN1 nur sehr schwach; OUT1 aus; Schloss bleibt aus |
| GPIO27, 3,3 V | IN1 nur sehr schwach; OUT1 aus; Schloss bleibt aus |

Damit sind ein defekter GPIO, ein Fehler am MOSFET-Ausgang sowie ein Fehler an Netzteil oder Schloss ausgeschlossen. Der Eingang dieses konkreten MOSFET-Moduls benoetigt praktisch etwa 5 V. Die beworbene Untergrenze von 3 V ist bei diesem Exemplar nicht nutzbar. Ein Pi-GPIO darf keinesfalls direkt mit 5 V verbunden werden.

Die vorherige Annahme, das MOSFET-Modul koenne direkt ueber GPIO17 angesteuert werden, ist damit widerlegt. Bis zum Einbau eines Treibers ist GPIO27 als Ausgang auf LOW gesetzt; dadurch bleibt der MOSFET-Kanal aus.

### Bestelltes Treibermodul

Bestellt wird ein fertiges, Raspberry-Pi-kompatibles 5-V-Relaismodul mit Low-Level-Trigger:

- Produkt: `AZDelivery 1-Relais 5V KF-301 Modul Low-Level-Trigger`
- Amazon-ASIN: `B07V1YQQGL`
- Link: <https://www.amazon.de/dp/B07V1YQQGL>
- Anschluesse: Jumper-Pins fuer `VCC`, `GND`, `IN`; Schraubklemmen fuer `COM`, `NO`, `NC`
- Es ist kein Loeten erforderlich.

Das neue Relais schaltet nicht direkt den hohen Schlossstrom. Es erzeugt nur das bereits erfolgreich getestete 5-V-Steuersignal fuer `PWM1`. Das vorhandene MOSFET-Modul bleibt das eigentliche Schaltglied fuer das Magnetschloss.

### Geplante Verdrahtung nach Lieferung

Nur Kanal 1 wird verwendet:

```text
Pi GPIO27 (physischer Pin 13) -> Relais IN
Pi Pin 2 (5 V)                -> Relais VCC
Pi GND                        -> Relais GND

Pi Pin 2 (5 V)                -> Relais COM
Relais NO                     -> MOSFET PWM1
Pi GND                        -> MOSFET GND1

12-V-Netzteil Plus            -> MOSFET DC+
12-V-Netzteil Minus           -> MOSFET DC-
Magnetschloss Plus            -> MOSFET OUT1+
Magnetschloss Minus           -> MOSFET OUT1-
```

Das KF-301 ist ein Low-Level-Trigger. Mit der geplanten Verbindung ueber `COM` und `NO` gilt deshalb:

```text
GPIO27 LOW  -> Relais zieht an -> 5 V an PWM1 -> Schloss bestromt/verriegelt
GPIO27 HIGH -> Relais faellt ab -> PWM1 aus    -> Schloss stromlos/entriegelt
Pi stromlos -> Relais aus      -> Schloss stromlos/entriegelt (Fail-Safe)
```

Vor dem ersten Test mit dem neuen Modul muessen 12 V getrennt und der Pi sauber heruntergefahren werden. Zuerst wird ausschliesslich die 5-V-Steuerseite verdrahtet und ohne Magnetschloss getestet. Erst danach werden MOSFET-Ausgang und Schloss wieder zugeschaltet.

## Update: Endgueltige relaislose Loesung und Bootdienst (2026-08-08)

Das zusaetzlich getestete KF-301-Relais ist funktionsfaehig, kann in diesem Aufbau aber nicht direkt sicher vom 3,3-V-GPIO gesteuert werden. Bei 3,3-V-Versorgung leuchtete zwar die Eingangs-LED, die 5-V-Spule bewegte den Kontakt jedoch nicht. Mit echten 5 V und manuell gegen GND gezogenem Eingang schalteten Relais, `COM`/`NC` und MOSFET korrekt. Das Relais wird fuer die endgueltige Loesung nicht benoetigt.

### Bestaetigte endgueltige Verdrahtung

Der galvanisch getrennte MOSFET-Eingang wird aktiv-low betrieben:

```text
Pi Pin 2 (5 V)                 -> MOSFET PWM1
Pi GPIO27 (physischer Pin 13) -> MOSFET GND1

12-V-Netzteil Plus  -> MOSFET DC+
12-V-Netzteil Minus -> MOSFET DC-
Magnetschloss Plus  -> MOSFET OUT1+
Magnetschloss Minus -> MOSFET OUT1-
```

Es besteht keine zusaetzliche Verbindung von Pi-GND zu `GND1`. GPIO27 bildet die strombegrenzte Minus-Seite des optisch getrennten Eingangs.

```text
GPIO27 LOW  -> volle Eingangsspannung -> MOSFET an  -> Schloss bestromt/verriegelt
GPIO27 HIGH -> Eingang aus            -> MOSFET aus -> Schloss stromlos/entriegelt
```

Zehn lastfreie EIN/AUS-Zyklen im Sekundentakt liefen sauber. Ein 3-Sekunden-Test mit angeschlossenem 12-V-Magnetschloss war erfolgreich. Anschliessend erkannte ein einmaliger PC/SC-Test einen NFC-Token, entriegelte 10 Sekunden und verriegelte wieder; dabei wurde keine Karten-ID gelesen oder protokolliert.

### Installierter Bootdienst

Im Repository liegen jetzt:

- `src/door_controller.py`: NFC-Ereignissteuerung, 30-Sekunden-Entriegelung, erneute Ausloesung erst nach Entfernen des Tokens.
- `systemd/kaffeetuer.service`: automatischer Start und Neustart; setzt GPIO27 vor Start und nach Stop auf LOW/verriegelt.
- `install.sh`: reproduzierbare Installation der Pakete, Anwendung, systemd-Unit und Bootvorgabe.

Auf dem Test-Pi ist `kaffeetuer.service` installiert, aktiviert und nach einem Neustart automatisch gestartet. `/boot/firmware/config.txt` enthaelt unter `[all]`:

```text
gpio=27=op,dl
```

Die vorherige Datei wurde auf dem Pi als `/boot/firmware/config.txt.before-nexor-door` gesichert. Nach dem Neustart waren der Dienst `active` und GPIO27 `LOW`. Die abschliessende physische Beobachtung des 30-Sekunden-NFC-Zyklus nach Boot steht noch aus.

## Update: Flashbares Release-Image v0.1.0 (2026-08-08)

Mit dem offiziellen `RPi-Distro/pi-gen`-Projekt, Bookworm-Zweig und Commit `4be6bbd0933c900517cb309d4f4f44267d2c2cac` wurde ein frisches Raspberry Pi OS Lite 32-bit fuer `armhf` gebaut. Das Image ist damit mit Raspberry Pi Zero und Zero W (ARMv6) kompatibel und basiert nicht auf einem unsauberen Klon der 64-GB-Testkarte.

Release-Artefakte:

```text
deploy/nexor-pi-door-v0.1.0-2026-08-08.img.xz
deploy/nexor-pi-door-v0.1.0-2026-08-08.img.xz.sha256
```

SHA-256:

```text
a89bc36e5a96a65847b6356952c76bb918cb9259d45d5c279444af93d4fea28a
```

Das komprimierte Image ist 580.456.284 Byte gross. Es enthaelt den aktivierten NFC-Bootdienst, PC/SC und `libccid`, die 30-Sekunden-Entriegelung sowie `gpio=27=op,dl`. WLAN, Bluetooth, NetworkManager und SSH sind im Release deaktiviert bzw. maskiert; das angelegte lokale Konto besitzt keinen nutzbaren Passworthash.

Durchgefuehrte Offline-Pruefungen:

- XZ-Integritaet erfolgreich.
- Boot- und Root-Partition read-only eingebunden und Inhalte kontrolliert.
- Python-Syntax, 30-Sekunden-Wert, systemd-Aktivierung, PC/SC-Socket und `pinctrl` kontrolliert.
- GPIO-Bootvorgabe und deaktivierte Netzwerkdienste kontrolliert.
- FAT-Dateisystem mit `fsck.vfat -n` und ext4-Dateisystem mit `e2fsck -f -n` ohne Fehler geprueft.
- SHA-256 unter Linux erzeugt und unter Windows unabhaengig bestaetigt.

Noch offen ist der reale Erstboot dieses neu gebauten Images auf einer separaten microSD-Karte mit abschliessendem NFC-/30-Sekunden-Abnahmetest. Die bisherige Test-SD bleibt als Rueckfall erhalten.

## Korrektur: Flashbares Release-Image v0.1.1 (2026-08-08)

Beim Abgleich mit der funktionierenden Test-SD wurde festgestellt, dass der eingesetzte Pi `over_voltage=1` benoetigt. Diese Einstellung fehlte im Release v0.1.0. v0.1.0 ist deshalb ersetzt worden und darf nicht geflasht werden.

Die Einstellung ist nun sowohl im Installer und im reproduzierbaren `pi-gen`-Build als auch direkt in der Boot-Partition des korrigierten Images enthalten:

```text
gpio=27=op,dl
over_voltage=1
```

Korrigierte Release-Artefakte:

```text
deploy/nexor-pi-door-v0.1.1-2026-08-08.img.xz
deploy/nexor-pi-door-v0.1.1-2026-08-08.img.xz.sha256
```

SHA-256:

```text
01a0edf74fc491a46411595a6fe67124f580b47a9f0b13b6a5bc774566c41bc0
```

Das komprimierte Image ist 580.456.240 Byte gross. XZ-Integritaet, FAT- und ext4-Dateisystem sowie der Inhalt der Boot-Partition wurden erneut geprueft. Die Pruefung bestaetigt exakt eine aktive Zeile `over_voltage=1`. Der reale Erstboot und NFC-/30-Sekunden-Abnahmetest dieses korrigierten Images bleiben offen.
