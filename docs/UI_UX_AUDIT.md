# Flosted – UI-/UX-Prüfung vom 19.10.2026

## Gesamturteil

**Die App funktioniert in wesentlichen Abläufen, ist für Endnutzer aber noch nicht durchgehend reibungslos.** Konvertierung, Bildexport und der geprüfte PDF-Export funktionieren. Mehrere Fehler liegen in der Verbindung zwischen Oberfläche und Verarbeitung und werden von den vorhandenen Modelltests nicht erfasst.

Die drei zuerst zu behebenden Probleme:

1. **F01: „Abbrechen“ löscht bereits vorhandenen Text.** Im Annotationseditor tritt tatsächlicher Verlust einer Bearbeitung auf; „Rückgängig“ stellt sie wieder her.
2. **F02: Die Elementauswahl erreicht die Eigenschaftsleiste nicht.** Farbe, Drehung und andere zugesagte Bearbeitungsmöglichkeiten sind dadurch nicht zuverlässig erreichbar.
3. **F03: Übliche Mac-Tastenkürzel funktionieren nicht vollständig.** Alles auswählen, Einfügen und die beworbenen Rückgängig-/Wiederherstellen-Kürzel blieben in den beschriebenen Prüfungen wirkungslos.

Der Bericht beschreibt den Stand vor der Behebung; der Audit selbst änderte weder Produktcode noch Nutzereinstellungen. Den späteren Behebungsstand zeigt der folgende Nachtrag. Die unten genannten Prüflücken sind keine bestandenen Tests.

Insgesamt sind **13 priorisierte Befunde** dokumentiert. Davon ist die fehlende Bedienlogik der Zuschnittgriffe ein Codebefund mit noch offener Mausabnahme; die Pfeilrichtung ist durch eine gesonderte Geometrieprobe belegt. Die übrigen Befunde haben zusätzlich praktische GUI-Belege.

## Behebungsstand (Nachtrag 19.10.2026)

Nach dem Audit wurden alle 13 Befunde im Code behoben. Release-Build ohne Warnung; **70 Tests ohne Fehler**, darunter `UXRegressionTests` (Core) und `CanvasBehaviorTests` (neues Target `FlostedAppTests`, AppKit-Views offscreen mit synthetischen Ereignissen). „Offen“ bedeutet: noch keine praktische Mausabnahme in der laufenden App.

| Befund | Behebung | Nachweis |
| --- | --- | --- |
| F01 | Eigenes Text-Sheet mit eigenem Entwurf; `AnnotationEdits.text` stellt beim Abbrechen den übernommenen Stand wieder her | Test; GUI offen |
| F02 | `selectionChanged`-Callback vom Canvas zurück an das Binding; Eigenschaftsleiste übernimmt Stil der Auswahl | Test; GUI offen |
| F03 | Bearbeiten-Menü (Responder-Kette); `ReferenceWindow.performKeyEquivalent` leitet ⌘Z/⇧⌘Z/⌘0/⌘+/⌘− an den aktiven Editor, nicht bei Textfeld oder Sheet | Test; GUI offen |
| F04 | Umschalter erscheint, sobald es für die Auswahl Werkzeuge gibt (auch PDF) | GUI offen |
| F05 | Glasfläche des Rads bei leerem Aktionskatalog ausgeblendet; Drop-Ziel bleibt | Test; GUI offen |
| F06 | `WheelIllustration`: gleicher Zeichner, ohne Tracking, Drop-Typen und Accessibility-Buttons | Test; GUI offen |
| F07 | `CropGeometry`: Griffe vor Innenfläche, Verschieben, Gegenecke, Seitenverhältnis, Grenzen | Test; GUI offen |
| F08 | Text-/Signaturrahmen gelangen erst nach erfolgreichem Dialog in den Verlauf; `commitIfChanged` | Test; GUI offen |
| F09 | `AnnotationRenderer.draw(logicalSize:)` skaliert Vorschau inkl. Schrift und Linien aus dem Quellraum | Test; GUI offen |
| F10 | `DashboardLayout.size` (420 × 550) an Fenster und Root-View; Hinweis umbricht | GUI offen |
| F11 | 0 Bilder → `unreadable` | Test |
| F12 | `JPEGCompression.encode` gemeinsam für Vorschau und Speichern; wirksame Qualität angezeigt | Test; GUI offen |
| F13 | `arrowReversed` und geordnete `arrowHandles`; Neuanlage übernimmt Zugrichtung | Test; GUI offen |

Aus den weiteren Risiken ebenfalls umgesetzt: `PageDragSource` räumt den Drag-Zustand bei jedem Ende auf und stellt die Reihenfolge bei Abbruch wieder her; Import und Miniaturen blockieren den Hauptthread nicht mehr; Eingaben sind während Speichern/Import gesperrt; Fenster werden neben dem aktiven Fenster platziert und geschlossene Controller freigegeben; leerer Werkzeug-Zusatz wird in den Einstellungen erklärt.

## Prüfbasis und Methode

- Lokaler Apple-Silicon-Mac, macOS 26.5. Keine Aussage zur praktischen Kompatibilität auf allen Versionen ab macOS 13.
- README, Projektbrief, Validierungsprotokoll sowie sämtliche Swift-Dateien von App/UI und Core wurden in die Prüfung einbezogen.
- Ausgangspunkt war der Arbeitsstand einschließlich bereits vorhandener Änderungen. Während der Prüfung entstanden außerhalb des Audits weitere Änderungen und die Commits `a288a88` und `7071928`. Der abschließende unveränderte Build-Snapshot basiert auf `7071928`; die beschriebenen Ursachen sind darin weiterhin vorhanden.
- Die ersten 54 Tests bestanden. Nach den zwischenzeitlichen Ergänzungen bestanden **56 Tests ohne Fehler**. Zusätzlich bestanden **30 gesonderte Core-Proben** mit erzeugten Dateien. „Bestanden“ bedeutet bei diesen Proben das jeweils geprüfte Verhalten, keine vollständige Inhaltsprüfung jedes Dokumentformats.
- GUI-Prüfungen erfolgten über getrennte, ad hoc signierte Testbundles mit eigenen Bundle-IDs und eigenen Einstellungen. Die globale Finder-Erkennung war dort deaktiviert. Die reguläre Nutzerinstanz wurde nicht ersetzt oder beendet.
- Für PDF-Editoren und ergänzende Integrationsproben wurde nur im temporären Quell-Snapshot ein Start-Hook ergänzt: Er wählt Testdateien aus und ruft die unveränderten `select`-/`perform`-Handler auf. Der Signaturspeicher wurde dort auf einen separaten Testordner umgeleitet. Kein Bearbeitungs-, Export- oder Konvertierungsalgorithmus wurde dafür geändert.
- Ein Bild ließ sich zunächst über den normalen Dateidialog auswählen. Weitere Dialogbestätigungen und Maus-Drags waren über die Fernsteuerung nicht zuverlässig: unter anderem `noWindowsAvailable` und `frontmostApplicationChanged`. Deshalb werden echte Finder-Drags und nicht abgeschlossene Importabläufe ausdrücklich nicht als praktisch bestanden bewertet.
- Visuelle Belege und Accessibility-Zustände wurden während der Sitzung kontrolliert. Dauerhaft lesbare Belege stehen hier als Nachstellschritte, Codeverweise und Dateiprüfergebnisse; die Sitzungs-Screenshots werden nicht als separat gespeicherte Bilddateien ausgegeben.

### Testdateien und nachgeprüfte Ergebnisse

Erzeugt wurden unter anderem ein 960 × 600 Pixel großes Bild mit Transparenz, ein EXIF-gedrehtes JPG, ein TIFF mit zwei Bildern, ein beschädigtes PNG, ein verschlüsseltes PDF, ein dreiseitiges PDF mit nummerierten Seiten und gedrehter zweiter Seite, ein Scan-PDF sowie TXT, Markdown, RTF und DOCX.

| Tatsächlich ausgeführter Export | Ergebnisprüfung |
| --- | --- |
| Hauptfenster: Bild → JPG | Neue Datei, Hauptfenster bleibt sichtbar; vorhandene Ausgabe erhält einen anderen Namen |
| Zuschnitt: 1:1 und Breite 300 | Ausgabedatei exakt **300 × 300 Pixel** |
| Hintergrund: Verlauf 2, 1:1, Rand 128 | Neue PNG-Datei exakt **1216 × 1216 Pixel** |
| Kompression: 20 KB | JPG mit **19.972 Bytes**, also unter dem gewählten Limit |
| Kompression: 1 KB | Verständliche Fehlermeldung; anschließend ließ sich mit höherem Limit speichern |
| Annotationseditor: Rechteck und Text | Neue PNG-Datei mit **960 × 600 Pixeln**, Rechteck und Text vorhanden; Größenabweichung siehe F09 |
| Hauptfenster: dreiseitiges PDF → PNG | Drei zusätzliche Dateien; Original und bereits vorhandene Ausgaben bleiben erhalten |
| Seitenverwaltung: erste Seite um 90° drehen, zweite löschen, sichern | Zwei Seiten: **ursprüngliche Seite 1 mit Rotation 90°, danach ursprüngliche Seite 3 mit Rotation 0°**; Text beider Seiten erhalten |
| PDF-Editor: erste Seite schwärzen, Seitenwechsel, sichern | Drei Seiten; `page.string` auf Seite 1 ist `nil`, auf Seiten 2 und 3 sind deren ursprüngliche Texte weiterhin vorhanden |

Alle **41 vor den GUI-Exporten erfassten Testdateien** waren anschließend bytegleich zu ihren gespeicherten SHA-256-Werten. Dies umfasst auch die bereits vorhandenen Core-Ausgaben. Eigene Nutzerdateien wurden nicht verwendet.

## Bestätigte Befunde

Prioritäten: **P1** = erheblicher Bedienfehler oder Verlust einer Bearbeitung; **P2** = störender Funktions-/Verständlichkeitsfehler. „Code“ bezeichnet eine direkt sichtbare Ursache, nicht einen erfolgreich durchgeführten Mausablauf.

### F01 – P1 – Abbrechen einer bestehenden Textbearbeitung löscht den Text

**Nachstellen:** Text anlegen und übernehmen. Zum Auswahlwerkzeug wechseln, den vorhandenen Text doppelklicken und im Dialog „Abbrechen“ wählen.

**Erwartet:** Der vorhandene Text bleibt unverändert. **Tatsächlich:** Er verschwindet. Die Rückgängig-Schaltfläche stellt ihn wieder her. Praktisch am erzeugten Bild geprüft; der Dialog zeigte vor dem Abbrechen ausdrücklich „Audittext bleibt erhalten“.

**Ursache:** `Sources/Flosted/AnnotationEditor.swift:92` leert `textDraft` und ruft auch beim Abbrechen `commitText()` auf. Dieser entfernt bei leerem Entwurf das vorhandene Element.

**Lösung:** Zwischen neu angelegtem, noch leerem Element und Bearbeitung eines vorhandenen Elements unterscheiden. Beim Abbrechen eines vorhandenen Textes nur den Dialog schließen; dessen Inhalt und Undo-Zustand unverändert lassen.

### F02 – P1 – Auswahlzustand des Canvas wird nicht an SwiftUI zurückgegeben

**Nachstellen:** Im Bildeditor ein Rechteck zeichnen, dann „Auswählen“ und das Rechteck anklicken.

**Erwartet:** Auswahlgriffe und die Eigenschaftsleiste mit passenden Aktionen bleiben sichtbar. **Tatsächlich:** Die Eigenschaftsleiste erscheint nicht. Die in der Dokumentation zugesagten Eigenschaften sind nicht erreichbar. Praktisch geprüft.

**Ursache:** `Sources/Flosted/AnnotationCanvas.swift:247` überträgt `selected` nur von SwiftUI in die AppKit-View. Die View verändert ihren eigenen Zustand, meldet aber keine Auswahländerung an das `@Binding` zurück. Ein folgendes Update kann die Auswahl wieder auf `nil` setzen. `selectedAnnotation` im Editor bleibt leer.

**Lösung:** Einen ausdrücklichen Auswahl-Callback vorsehen und beide Zustände synchron halten, ohne während `updateNSView` eine neue Aktualisierungsschleife zu erzeugen. Danach Auswahl, Griffe, Tastatur-Löschen, Farbe, Textgröße und Drehung erneut praktisch prüfen.

### F03 – P1 – Standard-Tastenkürzel bleiben wirkungslos

**Nachstellen:** Im englischen Textdialog „Original audit text“ eintragen, ⌘A drücken und per ⌘V einen anderen Text einfügen. Separat im Editor einen Pfeil anlegen und ⌘Z sowie nach Rücknahme per Button ⇧⌘Z prüfen.

**Erwartet:** Alles auswählen/Einfügen und Undo/Redo funktionieren. **Tatsächlich:** Im Textfeld bleibt der alte Text unmarkiert und unverändert. Die Undo-/Redo-Kürzel änderten den Editorzustand nicht; die entsprechenden Schaltflächen funktionierten. Das einfache Werkzeugkürzel P und das Beenden mit ⌘Q funktionierten in derselben Testinstanz.

**Codehinweis:** `Sources/Flosted/FlostedApp.swift:166` installiert nur App- und Datei-Menü. Ein Bearbeiten-Menü mit den üblichen Responder-Aktionen fehlt. Die SwiftUI-`keyboardShortcut`-Deklarationen allein stellten den beobachteten Betrieb im manuell gehosteten Fenster nicht sicher.

**Lösung:** Standard-Bearbeitungsaktionen über die Responder-Kette bereitstellen und Undo/Redo für den aktiven Editor korrekt anbinden. In Textfeldern muss das Text-Undo Vorrang haben; im Canvas das Annotationen-Undo. Danach auch Zahlen- und Pfadfelder prüfen. Das Verhalten des nativen Dateidialogs bleibt zusätzlich eine gesonderte Prüflücke.

### F04 – P1 – Bei PDFs fehlt der Wechsel zwischen Formaten und Werkzeugen

**Nachstellen:** Frisch gestartete App, PDF auswählen. Danach alternativ mit zuvor aktiviertem Werkzeugmodus ein PDF auswählen.

**Erwartet:** Konvertierung, Bearbeiten und Seitenverwaltung sind über das Hauptfenster auffindbar. **Tatsächlich:** Bei `tools = false` erscheinen nur DOCX/JPG/PNG/TXT, bei `tools = true` nur Bearbeiten/Seiten. In beiden PDF-Zuständen fehlt der Umschalter. Beide Zustände wurden an getrennten Testinstanzen geprüft.

**Ursache:** `Sources/Flosted/FlostedApp.swift:330` zeigt den Umschalter ausschließlich für ein einzelnes Bild. Der gespeicherte Laufzeitzustand `tools` gilt jedoch auch für PDFs.

**Lösung:** Den Moduswechsel für ein einzelnes PDF ebenfalls anbieten. Die Verfügbarkeit und Statusmeldung aus demselben Aktionskatalog ableiten. Auswahlwechsel von Bild → PDF → Dokument → Mehrfachauswahl prüfen.

### F05 – P2 – Die leere Startansicht verdeckt ihre eigenen Anweisungen

**Nachstellen:** App ohne ausgewählte Datei öffnen.

**Erwartet:** Symbol und verständliche Anleitung im Drop-Bereich. **Tatsächlich:** Im Screenshot bleibt eine große leere helle Kreisfläche; die Hinweise sind nur noch im Accessibility-Baum vorhanden. In regulärem Bundle und isolierter deutscher Testinstanz beobachtet.

**Ursache:** `Dashboard` legt die Hinweise hinter `EmbeddedWheel`. Dessen `RadialMenuView.layout()` zeigt die kreisförmige Glasfläche auch bei leerem Aktionskatalog. Nur das Zeichnen der Sektoren wird bei fehlenden Aktionen übersprungen.

**Lösung:** Für den Leerzustand die Glasfläche passend ausblenden oder Hinweise sichtbar darüberlegen. Den echten Drop-Empfänger dabei erhalten.

### F06 – P2 – Das Erklärungsrad wirkt bedienbar, führt aber keine Aktion aus

**Nachstellen:** Einleitung, zweite Karte, JPG anklicken.

**Erwartet:** Eine klar erkennbare Illustration oder eine funktionierende Beispielaktion. **Tatsächlich:** JPG wird orange und erscheint in der Mitte, sonst passiert nichts. Auch Bedienungshilfen melden die Formate als Buttons. Praktisch geprüft.

**Ursache:** `Sources/Flosted/IntroView.swift:56` verwendet das echte `EmbeddedWheel` mit leeren Callbacks. `.allowsHitTesting(false)` deaktiviert weder dessen AppKit-Tracking noch die selbst erzeugten Accessibility-Aktionen.

**Lösung:** Ein ausdrücklich nicht interaktiver Darstellungsmodus mit deaktivierten AppKit-Ereignissen und ohne Aktions-Buttons im Accessibility-Baum. Dieselbe Zeichenquelle verwenden; keine zweite Menügestaltung einführen.

### F07 – P2 – Gezeichnete Zuschnittgriffe haben keine eigene Bedienfunktion

**Nachstellen für die Reparaturabnahme:** Kleineren Zuschnitt einstellen, dann Ecke, Kantenmittelpunkt und die Innenfläche ziehen.

**Erwartet:** Griff skaliert die entsprechende Kante; Innenfläche verschiebt den bestehenden Ausschnitt. **Codebefund:** `Sources/Flosted/ImageEditor.swift:300` setzt bei jedem Mouse-down lediglich einen neuen Startpunkt. `mouseDragged` baut daraus ein neues Rechteck. Die unten gezeichneten acht Griffe werden nie getroffen oder unterschieden. Eine bestehende Auswahl kann damit nicht über diese Griffe nachjustiert werden.

**Lösung:** Griffe vor der Innenfläche testen, Griff-/Verschiebe-/Neuanlage-Modus unterscheiden, Gegenecke und Seitenverhältnis erhalten und Grenzen beachten. Die gezeichneten Griffe wurden visuell geprüft; der vollständige Mausablauf konnte wegen der Fernsteuerungsfehler nicht zuverlässig abgeschlossen werden.

### F08 – P2 – Undo erzeugt nach abgebrochener Textanlage einen leeren Rahmen

**Nachstellen:** In einem frischen PDF-Editor Textrahmen anlegen, ohne Eingabe abbrechen, anschließend „Rückgängig“ klicken.

**Erwartet:** Kein abgebrochener Zwischenzustand erscheint. **Tatsächlich:** Der Zähler steigt von 0 auf 1, ein gestrichelter leerer Textrahmen erscheint und der Hinweis auf unfertige Elemente wird eingeblendet. „Sichern“ bleibt bei ausschließlich diesem Element gesperrt. Praktisch geprüft.

**Ursache:** `AnnotationCanvasView.mouseUp` legt bereits den leeren Rahmen in den Undo-Stack. Inhaltseingabe oder Abbrechen erzeugen danach weitere Zustände.

**Lösung:** Das Einfügen von Rahmen und Inhalt als eine abgeschlossene Benutzeraktion behandeln. Abbrechen darf keinen wiederherstellbaren Platzhalter hinterlassen. Signaturabbruch und Undo/Redo nach Textübernahme mitprüfen.

### F09 – P2 – Textgröße skaliert nicht mit Vorschau und Zoom

**Nachstellen:** Text auf Bild oder PDF hinzufügen und zwischen Einpassen und 150 % wechseln; anschließend exportieren und mit der Vorschau vergleichen.

**Erwartet:** Text und sein Rahmen bleiben relativ zum Inhalt gleich groß; die exportierte Darstellung entspricht der Vorschau. **Tatsächlich:** In der GUI wächst der Dokumentinhalt beim Zoomen, der Annotationstext behält seine Bildschirmgröße. Der erzeugte Bildexport zeigt entsprechend andere relative Textmaße.

**Zusätzlicher Messbeleg:** Derselbe Annotationstext mit Schriftgröße 36 erzeugt über den tatsächlichen Renderer auf 500 × 500 und 1000 × 1000 Pixel großen Flächen jeweils **115 × 27 Pixel** Text. Seine relative Breite halbiert sich von 0,23 auf 0,115.

**Ursache:** `Annotation.rect(in:)` skaliert den Rahmen, `AnnotationRenderer.drawText` verwendet `style.fontSize` jedoch unverändert im jeweiligen Kontext. Die Vorschau in `AnnotationCanvasView.draw` wendet keine passende Transformation aus dem Quellkoordinatenraum an. Strichstärken sind ebenfalls zu prüfen.

**Lösung:** Einen gemeinsamen logischen Koordinatenraum für Vorschau und Export verwenden und den Vorschaukontext einschließlich Schrift und Linien skalieren. Den gemeinsamen Renderer erhalten; keine abweichenden Export-Sonderfälle hinzufügen.

### F10 – P2 – Hauptfenster übernimmt die intrinsische Größe und kürzt den PDF-Hinweis

**Nachstellen:** Hauptfenster mit PDF öffnen und den DOCX-Hinweis lesen.

**Erwartet:** Die angeforderte Fenstergröße und vollständig lesbarer Hinweis. **Tatsächlich:** Das Hauptfenster ist sichtbar schmaler als die angeforderten 420 Punkte; der Screenshot ist 672 Pixel breit, während beispielsweise das 360-Punkte-Einstellungsfenster 720 Pixel breit dargestellt wird. Der DOCX-Hinweis läuft mit Auslassungspunkten aus. Die zusätzliche Zustandsprobe misst das Hauptfenster mit **336 × 486 Punkten** statt 420 × 530.

**Ursache:** `showMain()` fordert 420 × 530 an, die oberste `Dashboard`-View hat aber keine entsprechende feste `.frame`. Das 336-Punkte-Rad beeinflusst die intrinsische Breite. Der PDF-Hinweis bekommt keine ausreichende Höhe/Breite für seinen Text.

**Lösung:** Fenster und oberste View auf dieselbe Größe abstimmen. Den vollständigen Hinweis in Deutsch und Englisch innerhalb der verfügbaren Fläche lesbar machen; lange Dateinamen weiterhin kontrolliert kürzen.

### F11 – P2 – Beschädigtes PNG erhält eine irreführende Fehlermeldung

**Nachstellen:** Eine Datei `corrupt.png` mit dem Inhalt „not an image“ als JPG konvertieren.

**Erwartet:** Hinweis auf eine beschädigte/nicht lesbare Bilddatei. **Tatsächlich:** „Animierte oder mehrseitige Bilddateien werden nicht in ein Einzelbild umgewandelt.“ Keine Ausgabe wird erstellt. Praktisch und über den Core geprüft.

**Ursache:** `Sources/FlostedCore/ImageConverter.swift:58` behandelt jede Bildanzahl ungleich 1 als Animation/Mehrseitigkeit; das schließt eine Quelle mit 0 Bildern ein.

**Lösung:** 0 Bilder als unlesbar ablehnen; erst mehr als 1 Bild als Animation/Mehrseitigkeit melden.

### F12 – P2 – Das Größenlimit wird in der Kompressionsvorschau nicht berücksichtigt

**Nachstellen:** Testbild im Kompressionseditor öffnen, Qualität 80 %, Limit von 0 auf 20 KB ändern.

**Erwartet:** Vorschau und geschätzte Größe beziehen sich auf die tatsächlich zu speichernden Einstellungen. **Tatsächlich:** Die Anzeige bleibt bei geschätzt 31 KB und die Vorschau bei der gewählten Qualität; gespeichert werden nach automatischer Qualitätsreduktion 19.972 Bytes.

**Ursache:** `ImageEditor.previewKey` und `updatePreview()` berücksichtigen `targetKB` nicht. Die Suche nach passender Qualität findet ausschließlich in `save()` statt.

**Lösung:** Dieselbe begrenzte Kompressionsberechnung für Vorschau und Export verwenden oder die Anzeige ausdrücklich als Größe vor der Limitanpassung kennzeichnen. Die tatsächlich wirksame Qualität muss vor dem Speichern beurteilbar sein.

### F13 – P2 – Pfeilrichtung nach links geht im Modell verloren

**Nachstellen:** Pfeil von rechts oben nach links unten bzw. von rechts unten nach links oben ziehen oder ein entsprechendes Ende verschieben.

**Erwartet:** Die Spitze liegt am gewünschten Endpunkt. **Automatischer Befund:** `AnnotationGeometry.arrow(from:to:)` speichert nur Rechteck und Diagonale. Beim Zurücklesen setzt `arrowPoints` das Ende immer auf die rechte Rechteckseite. Zwei von vier geprüften Richtungen sind falsch: aus Start (50, 50) und Ende (−50, −50) wird ein gerenderter Endpunkt (50, 50), also die ursprüngliche Startposition. Dasselbe Problem besteht für die linke obere Richtung.

**Weitere Codegrundlage:** Die Neuanlage in `AnnotationCanvasView.mouseUp` übernimmt die Zugrichtung überhaupt nicht in `arrowFlipped`. Außerdem bleiben die angebotenen Pfeilgriffe auf unten links/oben rechts beschränkt, auch wenn die tatsächliche Diagonale anders verläuft. Die GUI-Drag-Abnahme blieb wegen der Fernsteuerungsgrenzen offen; der Verlust der Richtung ist mit dem tatsächlichen Geometriecode reproduziert.

**Warum bestehende Tests grün sind:** `testArrowCoversAllFourDirections` akzeptiert den ursprünglichen Startpunkt an *einem beliebigen* der beiden Enden. Er verlangt nicht, dass die Spitze dem eingegebenen Ende entspricht.

**Lösung:** Start und Ende bzw. Diagonale und Richtung getrennt und eindeutig speichern. Neuanlage, Griffpositionen, Verschieben beider Enden und Renderer gemeinsam abgleichen. Regressionstests müssen ausdrücklich den gerenderten Endpunkt für jede Richtung prüfen; auch exakt horizontale und vertikale Pfeile abnehmen.

### Ergänzende Integrationsproben

Zwei gültige Bilder wurden über den tatsächlichen Konvertierungshandler zusammen verarbeitet: zwei Ausgaben, `busy = false`, keine Fehlermeldung. Bei einem gültigen und einem beschädigten Bild blieb die gültige Ausgabe erhalten; Fehlerdialog und Finder-Schaltfläche waren verfügbar. Die zugehörigen Abschlussprotokolle tragen `completed = true`.

Bei der Fehlerprobe mit `origin = .floatingMenu` und zuvor verborgenem Hauptfenster wurde nach Abschluss der Fehlerdialog sichtbar. Das Zustandsprotokoll enthält `busy = false`, eine konkrete Fehlermeldung, keine Ausgaben und `mainVisible = true`. Der zunächst aus dem fehlenden ausdrücklichen `showMain()` abgeleitete Verdacht wurde damit **nicht bestätigt**. Dies ist ein Handler-/Fenster-Integrationstest mit synthetischer Eingabe, kein echter Finder-Drag.


## Weitere Risiken aus der Codeprüfung

Diese Punkte sind nicht als praktisch reproduzierte Fehler ausgegeben. Sie brauchen gezielte Abnahme bzw. sind beim Beheben der bestätigten Fehler mitzuprüfen.

| Risiko | Konkrete Grundlage und nächste Prüfung |
| --- | --- |
| Veralteter Drag-Zustand in der Seitenverwaltung | `PageManager.swift:242`: `dropExited` ist leer; `dragging` wird nur bei `performDrop` auf einer Miniatur geleert. Abbruch bzw. Loslassen auf freier Fläche, danach externer Datei-Drag, auf unbeabsichtigtes Umsortieren prüfen. Das Aufräumen muss die gesamte Drag-Sitzung abdecken und darf den Wechsel zwischen Miniaturen nicht vorzeitig abbrechen. |
| Eigenschaften fehlen im Undo-Verlauf | Farbe/Schriftgröße sowie Slider/Reset für Drehung verändern `annotations` ohne `history.commit`. Nach F02 sichtbar werdende Eigenschaften auf genau einen Undo-Schritt pro abgeschlossener Änderung prüfen. Auswahl einer bestehenden Annotation muss außerdem deren Stil in den Controls anzeigen. |
| PDF-Import und Miniaturen können die Oberfläche blockieren | `PageManager.insert` lädt/decodiert Eingaben synchron, `refreshPreviews` erzeugt alle Miniaturen auf dem Hauptthread. Große Bilddateien und PDFs mit vielen Seiten mit gemessener Reaktionszeit prüfen. |
| Schließen während Speichern/Import | Die oberen X-Buttons sind während laufender Aufgaben weiter verfügbar; es gibt keine Abbruchweitergabe an den Task. Prüfen, ob später unerwartet doch eine Datei oder Finder-Aktivierung entsteht. Abbrechen vor dem Speicherstart wurde geprüft; laufende Speicherjobs nicht. |
| Überlappung/Platzmangel mehrerer Fenster | Neue Editoren werden zunächst neben dem Hauptfenster platziert, danach ggf. kaskadiert; geschlossene Controller bleiben im Array. Mehrere Editoren, verstecktes Hauptfenster, Bildschirmränder und kleine Displays praktisch prüfen. Modelltests der Platzierung ersetzen diese Prüfung nicht. |
| Nicht eindeutig erklärter leerer Werkzeug-Zusatz | Leerer `toolsExtra` ist gültig, `ModifierCombo.isSatisfied` liefert für eine leere Kombination aber immer `false`. Die globale Werkzeugansicht ist dann nicht auslösbar. UI sollte das bewusst als deaktivierte Werkzeuge erklären oder eine andere eindeutig definierte Bedienung anbieten. |

## Vollständige Prüfmatrix

„Automatisch“ bezeichnet Core-/Modelltests oder gesonderte Dateiproben. Es bestätigt keine Bedienbarkeit der betreffenden GUI.

| Bereich / Szenario | Status | Beleg oder Grenze |
| --- | --- | --- |
| Release-Build des anfänglichen Snapshots | Bestanden – Build | `bash scripts/build-app.sh`, einschließlich Sprach-Lint und Signierung |
| Release-Build des aktuellen unveränderten Snapshots | Bestanden – Build und Signatur | Basis `7071928`, eigener Buildordner |
| Vorhandene XCTest-Suite | Bestanden – automatisch | Anfänglich 54, abschließend 56 Tests; jeweils 0 Fehler |
| Zusätzliche Dateiproben | Bestanden – automatisch | 30 Proben; Details unten |
| Originale / vorhandene Ausgaben bleiben unverändert | Bestanden – automatisch und GUI-Ausgaben | 41 SHA-256-Vergleiche unverändert; kollisionsfreie weitere Ausgaben |
| Deutsche Einleitung: alle vier Karten und Beispieldatei | Bestanden – GUI, mit F06 | Beispiel erscheint im Hauptfenster; Darstellungsrad reagiert irreführend |
| Einleitung erscheint nach Abschluss/Neustart nicht erneut | Bestanden – GUI | Deutsche Testinstanz regulär beendet und neu gestartet |
| Einleitung erneut über Menüleiste öffnen | Nicht geprüft – GUI | Implementierung und Übersetzungen gelesen, kein gesonderter praktischer Durchlauf |
| Leeres Hauptfenster | Fehlgeschlagen – GUI | F05; Hinweise verdeckt |
| Hauptfenstergröße und PDF-Hinweis | Fehlgeschlagen – GUI und Code | F10 |
| Menüleisten-Icon und Dock-Icon im tatsächlichen Desktop | Nicht geprüft – GUI | Kein vollständiger neuer visueller Durchlauf beider Stellen |
| Hauptfenster schließen, Hintergrundbetrieb, Dock-Wiederöffnung | Nicht vollständig geprüft – GUI | `orderOut`, Statusitem und Reopen-Handler im Code vorhanden; vollständiger Desktop-Ablauf offen |
| Dateiauswahl eines Bilds | Bestanden – GUI | Native Auswahl des erzeugten `audit-image.png` gelang |
| Weitere Datei-/Foto-/PDF-Dialoge | Nicht zuverlässig abschließbar – GUI | Ausgewählte Datei, aber teils deaktivierter Öffnen-Button/Fensterbindungsfehler; keine sichere Zuordnung zu App oder Fernsteuerung |
| Hauptfenster: JPG-Konvertierung | Bestanden – GUI | Ausgabe vorhanden, Hauptfenster bleibt sichtbar |
| Hauptfenster: PDF-Seiten als PNG | Bestanden – GUI | Drei Seiten, neue kollisionsfreie Dateinamen |
| PDF-Formate/Werkzeuge im Hauptfenster wechseln | Fehlgeschlagen – GUI | F04 |
| Bild → PNG/JPG/HEIC/TIFF/BMP/PDF | Bestanden – automatisch | Jede auf diesem Mac angebotene Kodierung erzeugt wieder lesbare Ausgabe; Rastermaße 960 × 600 |
| PDF → JPG/PNG/TXT/DOCX | Bestanden – automatisch | Drei Bildausgaben, Drehung berücksichtigt, Text vorhanden |
| TXT/MD/RTF/DOCX → PDF/TXT/DOCX | Bestanden – automatisch | Alle zwölf Kombinationen erzeugten Ausgaben; keine Prüfung auf exakte Layoutrekonstruktion |
| OCR eines erzeugten Scan-PDFs | Bestanden – automatisch | „FLOSTED UX AUDIT“ wird erkannt; echte Handyfotos/Scans offen |
| EXIF-gedrehtes JPG | Bestanden – automatisch | 600 × 960 statt 960 × 600 nach Decode |
| Mehrseitiges TIFF / verschlüsseltes PDF / fehlende Datei | Bestanden – automatisch | Explizite Ablehnung statt stiller falscher Ausgabe |
| Beschädigtes PNG | Fehlgeschlagen – Meldung; Ablehnung funktioniert | F11 |
| Mehrfachkonvertierung / Teilerfolg | Bestanden – Integration und GUI-Status | Zwei gültige Bilder → zwei Ausgaben; gültig + beschädigt → eine Ausgabe plus Fehlerdialog; Start per Test-Hook |
| Gemischte und unbekannte Auswahl | Bestanden – automatisch | Aktionskatalog lehnt sie ab; vollständige GUI-Meldungsprüfung offen |
| Nicht beschreibbarer Zielordner | Nicht geprüft | Keine separate Rechte-/Fehlermeldungsprobe durchgeführt |
| Finder: Öffnen/Hover/echter Drop | Nicht praktisch geprüft | Globale Erkennung in Testbundles deaktiviert; keine Bewertung als live bestanden |
| Finder: Escape, Mitte, außerhalb loslassen, erneutes Öffnen im selben Drag | Nur Modelltests bestanden | TriggerLatch, DragSessionTracker und Geometrie getestet; reale Sitzung offen |
| Finder: minimale Deckkraft und tatsächliches Drop-Ziel | Nur Modell-/Codeprüfung | Panel-Alpha korrekt im Code; realer Drop bei 35 % offen |
| Fehlermeldung bei verstecktem Hauptfenster | Bestanden – Integration und GUI | Fehlerdialog sichtbar; busy=false, mainVisible=true; kein realer Finder-Drag |
| Zuschnitt: Verhältnis, Zahlenfelder, Export | Bestanden – GUI | 300 × 300 Pixel |
| Zuschnitt: Griffe / Verschieben | Fehlgeschlagen – Code; Mausabnahme offen | F07 |
| Hintergrund: Verlauf, Rand, Format, Export | Bestanden – GUI | 1216 × 1216; Vorschau reagiert auf Änderungen |
| Hintergrund: Vollfarbe / freie Farbe / eigenes Bild | Nicht vollständig geprüft – GUI | Controls und Code gelesen; Importdialog nicht zuverlässig abschließbar |
| Kompression: unerreichbares und erreichbares Limit | Bestanden – GUI | 1 KB: Meldung; 20 KB: 19.972 Bytes |
| Kompression: Vorschau mit aktivem Limit | Fehlgeschlagen – GUI und Code | F12 |
| Annotationseditor: Text, Rechteck, Pfeil und Export | Bestanden – GUI, mit F01/F02/F09 | Neue Bilddatei visuell geprüft; P wählt Pfeil |
| Annotationseditor: bestehender Text → Abbrechen | Fehlgeschlagen – GUI | F01 |
| Annotationseditor: Auswahl/Eigenschaftsleiste | Fehlgeschlagen – GUI | F02 |
| Annotationseditor: Rückgängig/Wiederherstellen per Button | Bestanden – GUI, mit F08 | Textverlust per Button wiederhergestellt; zurückgenommener Pfeil deaktiviert Sichern |
| Annotationseditor: Standard-Tastenkürzel | Fehlgeschlagen – GUI | F03; Buttons funktionieren, geprüfte Command-Kürzel nicht |
| Annotationseditor: Textabbruch und Undo | Fehlgeschlagen – GUI | F08 |
| Annotationseditor: Reset mit Nachfrage | Nur Codeprüfung | Alert und Undo-Anbindung vorhanden; Bestätigungsablauf nicht gesondert durchgespielt |
| Annotationseditor: Einpassen / 150 % / Bildlauf | Teilweise bestanden – GUI | Zoom und Scrollbereiche erscheinen; Text skalierte falsch, F09; 400 % und Resize offen |
| Annotationseditor: Hervorheben / alle Pfeilrichtungen / Griffe / Drehung | Fehlgeschlagen – Richtung; übrige Mausabnahme offen | F13; bisherige Renderer-/Geometrietests bestehen trotz Richtungslücke; zusätzlich F02 |
| Signatur: Rahmen vor Picker / Picker abbrechen | Bestanden – GUI | Kein Picker beim reinen Werkzeugklick; Picker nach Rahmen; Abbruch möglich |
| Signatur: Zeichnen, Fotoimport, Übernehmen, Wiederverwenden | Nicht end-to-end geprüft – GUI | Maus-/Dialogprobleme; Speicher und Weißentfernung nur automatisch geprüft; kein Nutzer-Signaturspeicher beschrieben |
| Nur unvollständige Annotation → Speichern gesperrt | Bestanden – GUI und automatisch | Leerrahmen aus F08 zeigt Warnung und deaktiviert Sichern |
| PDF-Editor: Seitenwechsel und Export | Bestanden – GUI | Seitenzählung/Elementzählung reagieren; Export hat drei Seiten |
| PDF-Schwärzung entfernt Text tatsächlich | Bestanden – GUI-Export und Dateiprüfung | Seite 1 ohne Textebene; andere Seiten behalten ihren Text |
| PDF ohne Schwärzung behält Textebene | Bestanden – automatisch | Bestehende AnnotationTests |
| Seitenverwaltung: Auswählen, Drehen, Löschen, Export | Bestanden – GUI | Ursprüngliche Seiten 1/3 in korrekter Folge, erste Rotation 90° |
| Seitenverwaltung: alle Seiten löschen verhindern | Bestanden – GUI | Nach „Alle auswählen“ ist Löschen deaktiviert |
| Seitenverwaltung: Umschalt-/Befehl-Mehrfachauswahl | Nicht zuverlässig bestätigt – GUI | Einzel- und Alle-Auswahl geprüft; Modifier-Klick nicht eindeutig auswertbar |
| Seitenverwaltung: Umordnen und Drag-Abbruch | Nicht praktisch geprüft | Code-Risiko beim Aufräumen von `dragging`, siehe Risiken |
| Seitenverwaltung: PDF/Bild einfügen, mehrere Dateien, Einfügeposition | Nur automatisch/Code geprüft | PageOperations-Tests bestehen; Drop-/Picker-End-to-End offen |
| Einstellungen: leere / überlappende Tastenkombination | Bestanden – GUI | Hinweise erscheinen; Übernehmen deaktiviert |
| Einstellungen: Schließen verwirft Entwurf | Bestanden – GUI | Wiederöffnen zeigt gespeichertes Shift/85 % |
| Einstellungen: Übernehmen und Neustart | Bestanden – GUI | ⌃⇧ und Deckkraft 0,785 bleiben erhalten; Einleitung bleibt abgeschlossen |
| Einstellungen: Reset | Nur Code-/Modellprüfung | Reset ändert ausschließlich Entwurf; kein separater GUI-Abnahmelauf |
| Deutsch/Englisch: Hauptfenster, Settings, Editor, Meldungen | Bestanden – geprüfte GUI-Ansichten | Keine rohen Übersetzungsschlüssel in diesen Ansichten; Layoutfehler separat aufgeführt |
| Deutsch/Englisch: sämtliche weiteren Views und Hilfetexte | Nur Ressourcen-/Codeprüfung | Sprachdateien parsebar, Schlüssel-/Formatargument-Tests bestehen; kein vollständiger zweisprachiger GUI-Durchlauf aller Zustände |
| Tastatur / Accessibility / Kontrast | Teilweise geprüft, keine vollständige Freigabe | Beschriftungen vorhanden; F03/F06; vollständiger VoiceOver-/Fokus-/Kontrasttest offen |
| Sehr lange Dateinamen / Sonderzeichen | Nicht vollständig geprüft – GUI | Testdatei erzeugt; kontrollierte Kürzung im Code vorhanden, Darstellung und Dialoge mit dieser Datei nicht vollständig durchgespielt |
| Mehrere Bildschirme, kleine Displays, Vollbild/Spaces | Nicht praktisch geprüft | Nur Geometrie-/WindowPlacement-Tests; Hardware-/Desktop-Abnahme offen |
| Große Dateien, schnelle Mehrfachklicks, Schließen während Verarbeitung | Nicht praktisch geprüft | Codeprüfung von Guards und Aufgaben; keine gemessenen Last-/Abbruchtests |
| Visueller Vergleich mit ursprünglichem Video | Nicht geprüft | Aufnahme/Referenzbilder in Projekt und angrenzendem Referenzordner nicht vorhanden |

### Umfang der 30 zusätzlichen Core-Proben

Sechs Bild-Ausgabeformate, vier PDF-Ausgabeformate, zwölf Dokument-Konvertierungen, eine Scan-OCR, vier Fehlerablehnungen, eine EXIF-Drehung, eine Zuschnitt-Dimensionsprüfung und eine Prüfung der tatsächlichen Textentfernung bei Schwärzung. Die beschädigte PNG-Datei wurde zwar erfolgreich abgelehnt, aber die dabei falsche Fehlerkategorie ist ausdrücklich als F11 erfasst.

## Nachweise und empfohlene Reihenfolge

Temporäre lokale Audit-Artefakte liegen unter `.build/ux-audit/` und gehören nicht in einen Commit:

- `baseline.json`, `current-head.txt`: ursprüngliche Dateihashes/Arbeitsänderungen und abschließende Commitbasis.
- `source/`, `current-source/`, `instrumentation.txt`: tatsächlich verwendete Snapshots und genaue Eingrenzung der Testinstrumentierung.
- `final-tests.log`, `current-build.log`, `core-probe-results.json`, `font-probe-results.txt`, `arrow-probe-results.txt`: Prüfprotokolle.
- `integration-batchfinal.json`, `integration-partialfinal.json`, `integration-floaterrorfinal.json`: Zustände der abschließenden Handler-/Fensterproben. Frühe Timer-Stichproben mit `busy = true` sind kein Abschlussnachweis.
- `fixture-original-hashes.json`, `fixtures/`, `ui-pdf-export-inspection.txt`: Originalschutz und nachprüfbare GUI-Ausgaben.

Alle Audit-Testinstanzen wurden abschließend beendet. Eine ältere, fensterlose Testinstanz musste nach Prüfung ihres exakten Prozesspfads per SIGTERM beendet werden. Die reguläre Instanz `dev.flosted.prototype` blieb gestartet. Testdateien und getrennte Testeinstellungen bleiben zur Nachvollziehbarkeit erhalten.

Die nächsten Schritte nach diesem Bericht sind: zuerst F01–F03 beheben, danach den PDF-Moduswechsel und die übrigen bestätigten Darstellungs-/Bedienfehler. Anschließend die betreffenden Abläufe erneut prüfen und die ausdrücklich offenen Finder-, Import-, Last- und Mehrbildschirmtests durchführen. Erst danach wäre eine Aussage „für Endnutzer durchgehend reibungslos“ angemessen.
