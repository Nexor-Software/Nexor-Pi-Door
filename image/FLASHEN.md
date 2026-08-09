# Nexor-Pi-Door auf eine SD-Karte flashen

## Benoetigt

- microSD-Karte mit mindestens 16 GB
- Raspberry Pi Imager
- Release-Datei `nexor-pi-door-*.img.xz`

## Ablauf

1. Raspberry Pi Imager starten.
2. Unter Betriebssystem `Eigenes Image verwenden` auswaehlen.
3. Die Datei `nexor-pi-door-*.img.xz` auswaehlen.
4. Die richtige microSD-Karte auswaehlen und schreiben.
5. Keine WLAN-, Benutzer- oder SSH-Anpassungen im Imager aktivieren.
6. Karte in den ausgeschalteten Pi einsetzen und die Hardware gemaess Verdrahtungsplan anschliessen.
7. Zuerst den Pi, danach die abgesicherte 12-V-Versorgung einschalten.

Das Image arbeitet offline. Es gibt keine Ersteinrichtung. Das Schloss bleibt im normalen Betrieb bestromt und verriegelt. Ein erkannter NFC-Token unterbricht die Schlossversorgung fuer 30 Sekunden.
