# Übergabe an Codex in Cursor

## Ziel
Muhammet möchte den in einer kurzen Tangerine-Bildschirmaufnahme gezeigten Ablauf
auf seinem Mac nachbauen: Datei ziehen, Shift drücken, Format im schwebenden
Kreis-Menü wählen und loslassen. Außerdem zeigt das Video PDF-/Text-/DOCX-Ausgabe,
Bildzuschnitt und dekorative Hintergründe. Eigenständiger Code, keine fremden Assets.
Später soll die App auf GitHub an Freunde verteilt werden. Nichts wurde publiziert.

## Implementierter Stand 0.3
- Manueller AppKit-App-Lebenszyklus, SwiftUI-Dashboard, Menüleisten-App.
- GlobalDragController beobachtet den öffentlichen Drag-Pasteboard-Generationszähler,
  gedrückte Maustaste und die Modifier-Tasten, ohne globale Tastatur-Hooks.
- Auslöse- und Werkzeug-Tastenkombination sind frei aus ⇧ ⌃ ⌥ ⌘ wählbar
  (Preferences in FLowmoCore, gespeichert in UserDefaults). Bewusst keine
  Buchstabentasten: Polling funktioniert mitten im Drag und braucht keine
  Berechtigung, ein registrierter Hotkey würde dort nicht zuverlässig feuern.
- Deckkraft von Kreis-Menü und Fenstern per Regler 35–100 %, über
  NSWindow.alphaValue, damit das Rad auch durchsichtig ein Drop-Ziel bleibt.
- Nach einem erfolgreichen Drop aus dem schwebenden Rad blendet sich das
  Dashboard aus; die Bestätigungsleiste bleibt. Fehler holen das Fenster zurück.
- Ein neues Drag-Pasteboard während der Maustaste schaltet die Erkennung scharf.
  Alte Pasteboard-Inhalte dürfen nicht durch gewöhnliche Klicks aktiviert werden.
- Nicht aktivierendes NSPanel auf dem aktuellen Bildschirm; NSDraggingDestination
  übernimmt den echten Drop und startet die Aktion. Kein Konvertieren allein beim
  Polling des Mouse-up, damit ein abgebrochener Drop nicht verarbeitet wird.
- Orange Ringsegmente, passende Aktionen pro Dateityp; Mitte als Abbruchzone.
- ImageIO für PNG/JPG/HEIC/TIFF/BMP, PDFKit für PDF-Seiten, Vision für lokale OCR,
  NSAttributedString für DOCX und CoreText für mehrseitige Text-PDFs.
- Bildeditor für Zuschnitt, Hintergründe und JPG-Kompression mit Vorschau.
- Sichere neue Dateinamen bei Konflikten; Originaldateien bleiben unverändert.

## Praktisch bestätigt
Der Nutzer hat den vollständigen Ablauf mit „funktioniert top“ bestätigt.
JPG-Konvertierung im überarbeiteten Menü wurde zusätzlich in der laufenden App geprüft.
Die Fernsteuerung meldete gelegentlich parallele Nutzerinteraktion; deren aktive
Editorfenster nicht schließen. Für UI-Vergleiche kann eine temporäre Kopie des App-
Bundles mit FLowmoPreviewOnly=true und eigener Bundle-ID erstellt werden;
diese Kopie startet keine globale Drag-Erkennung.

## Aktueller UI-Auftrag
Nutzer wollte explizit die Oberfläche 1:1 zur gelieferten Google-Drive-Aufnahme.
Die Aufnahme zeigt vier bzw. acht abgerundete Ringsegmente auf frosted glass,
eine zentrale Format-Pille, orangefarbene Auswahl und keine Hilfszeile am Ring.
Crop Image und Add BG sind schmale vertikale Glasfenster: Close-X und Titel,
große Vorschau, kompakte Steuerungen unten, kleine orangefarbene Abschlussbuttons.
Kein dunkles Dashboard und keine seitliche Editorleiste.
Fensterfarbe hängt von dem Desktop hinter der Glasfläche ab.

## Nächste Schritte

**Gebaut, aber noch nicht im Alltag bestätigt** — die Abnahmeschritte stehen in
docs/VALIDATION.md:
1. Bildwerkzeuge und Annotations-Editor mit echten Dateien durchspielen.
2. Escape, Verlassen des Menüs, mehrere Bildschirme und Mehrfachauswahl prüfen.
3. HEIC-Kodierung und Texterkennung auf echten Scans prüfen.

**Noch offen:**
4. WebP/AVIF als Ausgabeformate; Metadaten (Aufnahmedatum, Ort) gehen beim
   Umwandeln derzeit verloren.
5. Developer ID und Notarisierung, damit die App sich bei Empfängern ohne
   Rechtsklick-Umweg öffnet. Kostet 99 $/Jahr und braucht Muhammets Apple-ID.
6. Veröffentlichung auf GitHub. Das Repository liegt bislang nur lokal; ein
   Push erfolgt ausschließlich auf ausdrückliche Anweisung.



Die App ist keine vollständige Kopie sämtlicher Tangerine-Funktionen. Es gibt
keine verlustfreie PDF→DOCX-Layoutrekonstruktion und keine Audio-/Videokonvertierung.
