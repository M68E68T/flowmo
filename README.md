# flowmo 0.5

Native Mac-App mit schwebendem Kreis-Menü für lokale Dateikonvertierung.
Eigenständige Implementierung nach der bereitgestellten Tangerine-Videovorlage.

Das eigene Logo zeigt vier abgerundete Ringsegmente, eines davon orange.
App-Icon und Willkommenszeichen haben eine helle Milchglasoptik; die Menüleiste
verwendet eine einfarbige, an helle und dunkle Hintergründe angepasste Variante.
Alle Varianten entstehen aus derselben skalierbaren Zeichenquelle. Der App-Build
erzeugt die macOS-Icondatei automatisch; generierte Grafiken bleiben in `.build`
und `dist`.

## Download

**Neueste Version: [github.com/M68E68T/flowmo/releases/latest](https://github.com/M68E68T/flowmo/releases/latest)**

1. `flowmo-….zip` herunterladen und per Doppelklick entpacken.
2. `flowmo.app` in den Ordner **Programme** ziehen.
3. Beim ersten Start einmal freigeben: Warnung mit **„Fertig“** schließen, dann
   **Systemeinstellungen → Datenschutz & Sicherheit → „Dennoch öffnen“**
   (Details unter [„Was beim Empfänger passiert“](#was-beim-empfänger-passiert)).

Läuft ab macOS 13 auf Apple-Silicon- und Intel-Macs.

## Oberfläche nach der Videovorlage

- Schwebender Glasring mit abgerundeten Kreissegmenten, schmalem Außenrand,
  orangefarbener Auswahl und einer pillenförmigen Formatbeschriftung in der Mitte.
- Transparenz und Hintergrundunschärfe kommen vom tatsächlichen Desktop hinter
  dem Menü. Der im Video orangefarbene Desktop beeinflusst dort die Glasfarbe.
- Schmale Werkzeugfenster „Crop Image“ und „Add BG“ mit großer Vorschau oben,
  kompakten Reglern darunter sowie „Reset“/„Apply“ bzw. „Save with Background“.
- Zuschnitt mit orangefarbenem Rahmen, Griffen, Seitenverhältnis-Leiste und W/H-Feldern.
- Zwei Reihen mit Hintergrundverläufen bzw. Vollfarben, eigener Hintergrundgrafik,
  Padding/Corners/Shadow und Ratio-Schaltern wie in der Vorlage.
- Die zusätzliche Startansicht ist ein kleines Glasfenster statt einer dunklen Vollansicht.

## Einleitung

Beim ersten Start öffnet sich eine kurze Einleitung mit vier Karten: was die App
macht, wie der Ablauf mit Ziehen und Taste funktioniert, wie Bearbeiten und
Unterschreiben gehen und wo die Einstellungen sitzen. Auf den mittleren Karten
ist das **echte Kreismenü** zu sehen, damit man es später wiedererkennt. Am Ende
lässt sich eine Beispieldatei laden und der Ablauf sofort ausprobieren.

Danach erscheint sie nicht mehr von selbst. Über das Menüleisten-Symbol →
„Einleitung" lässt sie sich jederzeit wieder öffnen.

## Schnellstart

Die bereits gebaute App liegt in **dist/flowmo.app**. Per Doppelklick öffnen.
Das Fenster darf geschlossen werden: flowmo bleibt in der Menüleiste aktiv.
Beim ersten Start werden Einstellungen, Einleitungsstatus und gespeicherte
Unterschriften aus der bisherigen App automatisch übernommen.

**Autostart:** Beim ersten Start trägt sich flowmo als Anmeldeobjekt ein und
startet ab dann nach jedem Hochfahren still in der Menüleiste, ohne Fenster.
Abschalten lässt sich das in den Einstellungen („Beim Anmelden starten“) oder
unter Systemeinstellungen → Allgemein → Anmeldeobjekte; danach schaltet flowmo
es nie wieder von selbst ein.

1. Im Finder eine Bild- oder PDF-Datei mit gedrückter Maustaste ziehen.
2. Währenddessen die Auslösetaste drücken (ab Werk **Shift**). Das orange
   Kreis-Menü erscheint am Mauszeiger.
3. Auf ein Format ziehen und die Maustaste loslassen.
4. Die neue Datei wird neben dem Original gespeichert. Originale und bestehende
   Ergebnisse werden niemals überschrieben. Das App-Fenster blendet sich aus;
   eine kurze Bestätigungsleiste unten am Bildschirm meldet das Ergebnis.

Die Auslösetaste darf nach dem Öffnen wieder losgelassen werden. Zusätzlich
**Option** öffnet die Bildwerkzeuge. Beides ist in den Einstellungen änderbar.
Abbrechen: Escape oder außerhalb des Kreis-Menüs loslassen.

Alternativ im App-Fenster Dateien auswählen oder hineinziehen und auf ein
Kreissegment klicken. Mit „Mit Beispiel testen“ lässt sich eine erzeugte
Beispieldatei ausprobieren, ohne eigene Dateien auszuwählen.

## Einstellungen

Erreichbar über das Menüleisten-Symbol → „Einstellungen …" oder das Zahnrad im
App-Fenster.

- **Tastenkombination**: ⇧ ⌃ ⌥ ⌘ frei kombinierbar — getrennt für „Menü öffnen"
  und „Werkzeuge zusätzlich". Beide Gruppen müssen verschiedene Tasten nutzen,
  sonst bleibt „Apply" gesperrt. Nur Modifier-Tasten, keine Buchstaben: die
  Erkennung liest den Tastenzustand während des laufenden Drags, wo ein normaler
  Kurzbefehl nicht zuverlässig auslöst. Dadurch ist auch keine zusätzliche
  Systemberechtigung nötig.
- **Deckkraft**: ein Regler für das schwebende Kreis-Menü, 35–100 %,
  Werkseinstellung 85 %. Die Wirkung siehst du beim nächsten Ziehen. Die
  Fenster selbst bleiben immer vollständig deckend.
- **Apply** speichert und schließt das Fenster. Das **X** verwirft alles:
  Tastenkombination und Deckkraft springen auf den zuletzt gespeicherten Stand
  zurück. „Reset" füllt nur die Werkseinstellung ein und braucht ebenfalls ein
  Apply.
- Hinweis: ⌘ beim Ziehen bedeutet im Finder „Bewegen" statt „Kopieren".

## Funktionsumfang

| Eingabe | Ausgabe / Werkzeuge |
| --- | --- |
| Standbild | PNG, JPG, HEIC, TIFF, BMP, PDF |
| PDF | Alle Seiten einzeln als JPG/PNG; TXT und DOCX |
| TXT, Markdown, RTF, DOCX | PDF, TXT, DOCX |
| Einzelnes Textdokument, Werkzeugtaste | Fortlaufend bearbeiten, PDF und DOCX sichern |
| Einzelnes Bild, Werkzeugtaste | Zuschnitt, Hintergrund, Kompression, Bearbeiten |
| Einzelnes PDF, Werkzeugtaste | Bearbeiten (Text, Signatur, Schwärzen), Seiten verwalten |

Nur verfügbare System-Bildencoder werden angeboten. Bei HEIC kann die tatsächliche
Kodierung je nach Mac scheitern; Fehler werden angezeigt. Animierte oder mehrseitige
Bilddateien werden abgelehnt statt still auf das erste Bild reduziert.

- PDF-Seitenexport berücksichtigt die Seitendrehung und exportiert mit 150 DPI.
- PDF-Textexport nutzt bei bildbasierten Seiten lokale Texterkennung.
- DOCX übernimmt Text und Grundformatierung; komplexe PDF-Layouts, Tabellen und
  eingebettete Abbildungen werden **nicht originalgetreu rekonstruiert**.
- Zuschnitt: Rechteck aufziehen, feste Seitenverhältnisse und Pixelanzeige.
- Hintergrund: Farbverläufe, eigene Farben, Format, Abstand, Rundung und Schatten;
  Vorschau und PNG-Export.
- Kompression: JPG-Qualität, Skalierung, geschätzte Dateigröße und optionales
  Größenlimit. Nicht erreichbare Limits erzeugen eine verständliche Fehlermeldung.
- Mehrere Dateien desselben Typs lassen sich gemeinsam konvertieren. Bildeditoren
  arbeiten auf einer einzelnen Datei.
- Metadaten werden derzeit nicht übernommen. JPG-Transparenz wird weiß hinterlegt.

## Bearbeiten und Signieren

„Bearbeiten“ öffnet zuerst eine fortlaufende Textansicht. PDF-Text wird übernommen;
bei Scans und Bildern erkennt flowmo den Text lokal. Du schreibst direkt auf den
Dokumentseiten und kannst Schriftart, Größe, Farbe, Fett/Kursiv/Unterstreichen,
Absatzausrichtung und Listen ändern. Der Text fließt automatisch auf weitere
A4-Seiten. Die Textansicht startet bei lesbaren 100 %. Einpassen zeigt die ganze
Seite; Einpassen und Zoom ändern nur die Ansicht.

Die Textansicht vereinfacht das ursprüngliche Layout. Abbildungen, Diagramme und
Tabellen werden nicht nachgebaut; OCR-Ergebnisse bitte auf Fehler prüfen. Über
„Original markieren“ wechselst du zur unveränderten Seitenansicht mit den unten
beschriebenen Werkzeugen. Beide Ansichten behalten ihre eigenen Entwürfe und
Rückgängig-Verläufe. Gesichert wird die gerade sichtbare Ansicht; Markierungen
werden nicht automatisch auf den neu umbrochenen Text übertragen.

In der Textansicht wählst du unten PDF oder DOCX und klickst auf „Sichern“ (⌘S).
Es entsteht eine neue Datei neben dem Original; der Editor bleibt offen. DOCX
lässt sich in flowmo wieder bearbeiten. Schließen oder Beenden fragt bei
ungesicherten Änderungen nach. Ohne Sichern wird keine Ausgabedatei angelegt.

Einzelne Bilder und PDFs lassen sich mit der Werkzeugtaste unter „Bearbeiten"
mit Text, Unterschrift, Pfeilen, Rahmen, Hervorhebungen und Schwärzungen
versehen. Alles wird **fest eingebrannt**; das Original bleibt unverändert.

- **Signatur**: mit Maus oder Trackpad unterschreiben, oder ein Foto einer
  Unterschrift auf Papier laden — der weiße Hintergrund wird entfernt.
  Einmal gespeicherte Signaturen stehen für weitere Dokumente bereit.
- **Arbeiten im Editor**: Das Fenster lässt sich frei vergrößern. Mit
  „Einpassen" siehst du die ganze Seite, mit − und + zoomst du bis 400 % heran,
  um genau zu platzieren. Jeder Schritt lässt sich mit ⌘Z zurücknehmen und mit
  ⇧⌘Z wiederherstellen. Die Werkzeuge erreichst du auch über Tasten:
  V Auswählen, T Text, U Unterschrift, P Pfeil, R Rahmen, M Marker,
  S Schwärzen. ⌘0 passt ein, ⌘+ und ⌘− zoomen.
- **Nachträglich ändern**: Ein gesetztes Element anklicken und an den
  orangefarbenen Griffen die Größe ziehen. Pfeile haben zwei Griffe an den
  Enden — zieht man ein Ende, zeigt die Spitze dorthin. Über der Vorschau
  erscheint bei Auswahl ein Regler zum Drehen. Ein Doppelklick auf ein
  Textfeld öffnet den Text erneut, ein Klick auf eine Signatur bei aktivem
  Signatur-Werkzeug tauscht sie aus. Was in der Vorschau steht, wird beim
  Sichern genau so geschrieben.
- **Schwärzen entfernt Text wirklich.** Ein schwarzer Balken allein würde
  nichts nützen: Der Text bliebe im PDF und wäre weiterhin kopierbar. flowmo
  rechnet eine geschwärzte Seite deshalb zu einem Bild um. Diese Seite ist
  danach nicht mehr durchsuchbar — darauf wird im Editor hingewiesen.
- Seiten **ohne** Schwärzung behalten ihre Textebene: Text bleibt scharf,
  auswählbar und durchsuchbar.

## Seiten verwalten

Bei einem einzelnen PDF bietet die Werkzeugtaste zusätzlich „PAGES". Dort lassen
sich Seiten auswählen (mit Umschalt mehrere), um 90 Grad drehen, löschen und per
Ziehen neu sortieren.

**Seiten hinzufügen** geht per Ziehen direkt aus dem Finder oder vom
Schreibtisch ins Fenster: PDFs steuern alle ihre Seiten bei, ein Bild wird zu
einer einzelnen Seite. Lässt du die Datei über einer vorhandenen Miniatur los,
landen die neuen Seiten davor; auf der freien Fläche werden sie angehängt.
Sehr große Bilder werden dabei auf ein vernünftiges Seitenmaß gebracht.

Gespeichert wird als neue Datei; mindestens eine Seite muss übrig bleiben.

Eine gezeichnete Unterschrift ist eine **einfache elektronische Signatur**, also
ein Bild im Dokument. Sie ist keine kryptografisch geprüfte digitale Signatur;
für qualifizierte Signaturen braucht es ein Zertifikat und einen
Vertrauensdiensteanbieter.

## Stand der Prüfung

Der Nutzer hat den funktionierenden Finder-Ablauf bestätigt („funktioniert top“).
Eine JPG-Konvertierung über das überarbeitete Kreis-Menü wurde zusätzlich direkt
in der App geprüft. Automatische Tests prüfen unter anderem Konvertierung,
Originalschutz, PDF-Seitenzahl, DOCX-Rücklesen, Zuschnitt, Menü-Geometrie sowie
Tastenkombinationen und das Speichern der Einstellungen.
Details: docs/VALIDATION.md.

## In Cursor weiterarbeiten

Diesen Ordner öffnen. Codex liest AGENTS.md und docs/PROJECT_BRIEF.md.
Quellen: Sources/Flowmo (App/UI) und Sources/FlowmoCore (Verarbeitung).

```bash
bash scripts/build-app.sh
swift test --cache-path .build/cache --config-path .build/config --security-path .build/security
```

Bei eingeschränkten Entwicklungsumgebungen, in denen SwiftPM seine eigene
verschachtelte Sandbox nicht starten kann:

```bash
bash scripts/build-app.sh --disable-sandbox
swift test --disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security
```

Auf einem normalen Mac startet `Starten.command` die frisch gebaute App.
Voraussetzung zum Bauen: Xcode oder passende Apple Command Line Tools, Swift 5.9+.
Die App nutzt öffentliche AppKit-APIs, keine Bildschirmaufnahme und keinen
Tastatur-Hook. Es werden keine Dateien hochgeladen oder Telemetriedaten gesendet.

## An Freunde weitergeben

Paket erstellen:

```bash
bash scripts/package.sh
```

Das erzeugt `dist/flowmo-0.5.0.zip`. Verpackt wird mit `ditto`, nicht mit
`zip` — ein gewöhnliches `zip` zerstört die Bundle-Struktur und die Signatur.

### Was beim Empfänger passiert

Die App ist **ad hoc signiert**, also nicht mit einer Developer ID von Apple.
Beim ersten Doppelklick zeigt macOS deshalb „„flowmo“ nicht geöffnet – Apple
konnte nicht überprüfen, ob „flowmo“ frei von Schadsoftware ist" mit den
Knöpfen „In den Papierkorb legen“ und „Fertig“.

Der funktionierende Weg, einmal pro Mac (macOS 15 Sequoia und neuer):

1. In der Warnung **„Fertig“** klicken – **nicht** „In den Papierkorb legen“.
2. **Systemeinstellungen → Datenschutz & Sicherheit** öffnen und ganz nach
   unten scrollen. Dort steht „„flowmo“ wurde blockiert …“ mit dem Knopf
   **„Dennoch öffnen“**.
3. flowmo erneut öffnen, im Dialog nochmals **„Dennoch öffnen“** wählen und mit
   Passwort oder Touch ID bestätigen.

Unter macOS 13 und 14 geht es auch kürzer: **Rechtsklick** auf flowmo.app →
**„Öffnen“** → im Dialog nochmals **„Öffnen“**. Ab macOS 15 gibt es diesen
Knopf nicht mehr.

Wer das Terminal kennt, kann die Sperre stattdessen direkt entfernen:

```bash
xattr -dr com.apple.quarantine /Applications/flowmo.app
```

### Ehrlich dazu

Das ist für Laien eine Zumutung — die Warnung klingt nach Schadsoftware, und
genau das soll sie ja auch, wenn man die Herkunft nicht kennt. Weg geht sie
nur so:

| Schritt | Aufwand |
| --- | --- |
| Apple Developer Program | 99 $ pro Jahr |
| Mit **Developer ID** signieren statt ad hoc | einmalig einrichten |
| Von Apple **notarisieren** lassen (`notarytool`) | pro Version ein paar Minuten |
| Ticket ans Bundle heften (`stapler`) | ein Befehl |

Danach öffnet die App sich beim Empfänger mit einem normalen Doppelklick. Für
den Kreis von Freunden ist der Weg über die Systemeinstellungen meist die
pragmatischere Wahl.

Veröffentlicht wird über GitHub Releases: <https://github.com/M68E68T/flowmo/releases>.
Eine Windows-Version ist nicht enthalten.
