# Flosted 0.3

Native Mac-App mit schwebendem Kreis-Menü für lokale Dateikonvertierung.
Eigenständige Implementierung nach der bereitgestellten Tangerine-Videovorlage.

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

Die bereits gebaute App liegt in **dist/Flosted.app**. Per Doppelklick öffnen.
Das Fenster darf geschlossen werden: Flosted bleibt in der Menüleiste aktiv.

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
  nichts nützen: Der Text bliebe im PDF und wäre weiterhin kopierbar. Flosted
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
Quellen: Sources/Flosted (App/UI) und Sources/FlostedCore (Verarbeitung).

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

## Weitergabe

Die lokale App ist ad hoc signiert, noch nicht mit einer Developer ID signiert
oder von Apple notarisiert. Für komfortable Downloads anderer Nutzer sind diese
Schritte sowie Tests auf deren Macs noch erforderlich. Es wurde nichts auf GitHub
veröffentlicht. Eine Windows-Version ist nicht enthalten.
