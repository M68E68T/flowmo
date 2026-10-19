# Prüfung der Version 0.3

Datum: 18.10.2026. Apple-Silicon-Mac, Swift 6.3.2, Sprachmodus Swift 5.

## Automatisch erfolgreich
- Release-Build inklusive startbarem .app-Bundle, keine Compiler-Warnungen.
- 76 XCTest-Fälle, null Fehler (Stand 19.10.2026, siehe unten).
- PNG/JPG/TIFF-Ausgaben werden erneut als Bilder gelesen, mit korrekten Abmessungen.
- Originalbytes unverändert; Namenskollisionen erzeugen getrennte neue Dateien.
- Ungültiger Bildeingang erzeugt keine Ausgabe.
- Text wird in mehrseitiges PDF geschrieben. Alle PDF-Seiten werden als PNG
  exportiert. TXT und DOCX enthalten den Text; DOCX lässt sich wieder als Text lesen.
- Zuschnitt berücksichtigt die Umrechnung von Bottom-left-Auswahl zu Bildkoordinaten;
  Pixeltest prüft die richtige Bildhälfte. Hintergrundformat und Skalierung stimmen.
- Ring-Geometrie: alle vier Richtungen, Abbruchzone und Bildschirm mit negativem Ursprung.
- Veraltete Drag-Pasteboard-Inhalte aktivieren das Menü nicht; neue Inhalte werden erkannt.
- Menüeinträge lehnen gemischte/unbekannte Dateitypen ab.
- Tastenkombination: Zusatztasten brechen die Bedingung nicht, fehlende Tasten
  lösen nicht aus, eine leere Kombination niemals.
- Leere Öffnen-Kombination und Überschneidung mit den Werkzeug-Tasten werden als
  Fehler erkannt; ein leerer Werkzeug-Zusatz ist erlaubt.
- Deckkraft des Kreis-Menüs wird auf 0,35–1,0 begrenzt, auch bei NaN oder
  negativen Werten.
- Einstellungen überstehen Speichern/Laden; ungültig gespeicherte Werte fallen
  auf die Werkseinstellung zurück, damit nie ein unbenutzbarer Auslöser entsteht.
- Fensterplatzierung: bevorzugt rechts mit eingehaltenem Abstand, weicht nach
  links aus, bleibt bei Platzmangel vollständig auf dem Bildschirm und
  funktioniert auf einem Monitor mit negativem Ursprung.

## Praktischer Stand
- Neue App wurde gestartet und Dashboard visuell geprüft.
- Nutzer hat den funktionierenden Finder-Ablauf ausdrücklich bestätigt („funktioniert top“).
- JPG-Konvertierung über das überarbeitete Menü in der laufenden App erfolgreich.
- Gerundete Kreissegmente, aktive Auswahlfarbe und Glasdarstellung visuell geprüft.
- Werkzeugfenster auf vertikale Anordnung mit festen Vorschauabmessungen umgestellt.
- Dateidialog- und weitere UI-Tests konnten wegen wiederholter verlorener
  Fensterbindung/paralleler Nutzerinteraktion nicht zuverlässig abgeschlossen werden.
- **HEIC-Kodierung und Texterkennung sind jetzt belegt**, nicht mehr nur
  angenommen: PipelineTests wandelt in jedes angebotene Format und liest das
  Ergebnis zurück, und erkennt Text auf einer Seite, die ihn nur als Bild
  trägt. Auf diesem Mac sind PNG, JPG, HEIC, TIFF, BMP und AVIF als Encoder
  vorhanden; WebP kann macOS nur lesen, nicht schreiben.
- Zusätzlich einmalig gegen echte Dateien in ~/Documents/flowmo-Abnahme
  gefahren (Vertrag.pdf mit ALPHA/BETA/GAMMA, Foto.png, Gross.jpg, Scan.pdf):
  Schwärzen entfernte BETA und ließ ALPHA und GAMMA stehen, Annotieren erhielt
  die Textebene, Seiten ließen sich umsortieren/drehen/löschen, das
  4000-Pixel-Bild wurde beim Seitenimport korrekt begrenzt, Originale blieben
  unverändert und ein zweiter Lauf überschrieb nichts.
- Editor-Bedienung, Escape und Multi-Monitor-Verhalten sind weiterhin nur
  implementiert, nicht praktisch abgenommen.
- Einstellungsfenster, Deckkraft-Regler, eigene Tastenkombination und das
  Ausblenden nach dem Drop sind gebaut und durch Tests des Modells abgedeckt,
  aber noch nicht vom Nutzer im Alltag bestätigt (Schritte 8–15 unten).
- Zwei Fehler der ersten Fassung sind behoben: Das Einstellungsfenster hatte
  keine feste Größe auf der obersten View, wodurch AppKit die intrinsische Größe
  des NSHostingController übernahm und Beschriftungen umbrachen. Außerdem
  zentrierte ReferenceWindow jedes Fenster, sodass Dashboard, Einstellungen und
  Editoren deckungsgleich lagen und bei aktiver Transparenz durcheinander
  schienen. Die Platzierung entscheidet jetzt der Aufrufer.
- Annotieren: Normalisierte Koordinaten, Zeichnen trifft nur den markierten
  Bereich, PDF ohne Schwärzung behält seine Textebene.
- Sicherheitseigenschaft automatisch geprüft: Nach dem Schwärzen enthält
  page.string das geschwärzte Wort nicht mehr, während andere Seiten ihren Text
  behalten.
- Signaturen: Speichern/Laden/Löschen und das Transparentmachen von Papierweiß.
- Rückgängig: Frischer Stapel geht nirgendwohin; mehrere Schritte laufen
  einzeln vor und zurück; eine Änderung nach dem Zurücknehmen verwirft den
  Wiederherstellen-Zweig; am Limit fällt der älteste Zustand heraus.
- Übersetzungsdateien werden beim Bauen mit plutil geprüft; eine fehlerhafte
  Datei bricht den Build ab, statt im Bundle zu landen.
- Seiten aus Dateien: Ein PDF liefert alle Seiten in Reihenfolge und bleibt
  selbst unverändert; ein Bild ergibt genau eine Seite im richtigen
  Seitenverhältnis; übergroße Bilder werden auf die Maximalkante begrenzt;
  nicht unterstützte Dateien werfen einen Fehler statt einer leeren Seite.
- Griffe: Jede Ecke wird innerhalb der Toleranz getroffen, die Mitte nicht,
  Pfeile bieten nur ihre beiden Enden an. Beim Ziehen bleibt die
  gegenüberliegende Ecke stehen, das Rechteck wird nie negativ und die
  Mindestgröße gilt.
- Pfeilrichtung: Alle vier Diagonalen werden korrekt erkannt und erreichen
  nachweislich die Ausgabedatei — ein steigender und ein fallender Pfeil
  schwärzen unterschiedliche Bildpunkte.
- Vollständigkeit: Leerer Text und nicht zugewiesene Signaturen gelten als
  unfertig; Pfeil, Rechteck, Hervorhebung und Schwärzung immer als fertig.
  Werden nur unfertige Elemente übergeben, bleibt das Bild unverändert.
- Auslöser: Gehaltene Taste öffnet genau einmal; Loslassen und erneutes Drücken
  öffnet wieder; eine schon vor dem Ziehen gehaltene Taste erzeugt beim
  Scharfwerden eine Flanke; das Sitzungsende stellt den Ausgangszustand her.
- Einleitung: Frischer Speicher meldet „noch nicht gesehen"; Speichern und
  Laden der Einstellungen lässt den Merker unberührt, damit „Zurücksetzen" die
  Einleitung nicht erneut auslöst.
- Seiten: Drehen bleibt im Bereich 0–270 und trifft nach dem Umsortieren noch
  die richtige Seite; Löschen erhält die Reihenfolge und lehnt das Leeren des
  Dokuments ab; Anhängen verändert die Quelle nicht.
- Alle Bedienelemente haben Erklärungen beim Daraufzeigen. Die „Höchstgröße“
  beim Komprimieren war praktisch unbenutzbar: Das Feld hatte nur einen
  Platzhaltertext, der wegen des immer vorhandenen Werts 0 nie erschien. Es hat
  jetzt eine feste Beschriftung und einen Hinweis. Foto-Knopf und Farbwähler im
  Hintergrund-Werkzeug zeigen ihre Auswahl jetzt ebenfalls an.
- Beim Lokalisieren zunächst übersehen und nachgezogen: Editor-Fenstertitel,
  die Regler Rand/Ecken/Schatten/Qualität/Größe, „Frei“/„Auto“, der Alert-Titel
  beim Speicherfehler und die Meldung zur nicht erreichbaren Zielgröße.
- Vorschau und Speichern sind getrennt: Der Regler schreibt nichts in die
  Einstellungen. Erst Apply speichert und schließt, das X verwirft.
- Behoben: Die deutsche Übersetzungsdatei war syntaktisch kaputt (ein
  typografisches Anführungszeichen schloss einen String vorzeitig), wodurch
  macOS sie komplett verwarf und die Oberfläche nur noch Schlüssel anzeigte.
  Der Build lintet die Dateien jetzt und bricht bei einem Fehler ab.
- Ergänzt: Rückgängig/Wiederherstellen, Zoom mit Bildlauf, ein frei
  skalierbares Fenster, beschriftete Werkzeuge mit Tastenkürzeln, eine nur bei
  Auswahl sichtbare Eigenschaftsleiste und eine Nachfrage vor dem Zurücksetzen.
- Behoben: Eingefügte Signaturen landeten nie in der Datei. Der Auswahl-Sheet
  öffnete sich schon beim Anklicken des Werkzeugs, also bevor ein Rahmen
  existierte; die gewählte Signatur hatte kein Ziel und wurde verworfen. Jetzt
  wird erst der Rahmen gezogen und dann gefragt. Zusätzlich behoben: Die
  Zuweisung traf die aktuelle Auswahl statt des Rahmens und konnte so ein
  Textfeld in eine Signatur verwandeln; ein abgebrochener Textdialog ließ ein
  unsichtbares Element zurück; und „Sichern" war auch dann möglich, wenn nichts
  Zeichenbares vorhanden war.
- Behoben: Nach dem Schließen des Rads ließ es sich im selben Drag nicht wieder
  öffnen. `hide()` setzte ein Unterdrückungs-Flag, das erst beim Loslassen der
  Maustaste zurückging, und `onExit` feuerte bei jedem Verlassen des Rads. Jetzt
  entscheidet die steigende Flanke der Tastenkombination; das Flag ist dadurch
  überflüssig geworden und entfernt.
- Der Schalter „Finder-Menü" ist entfallen. Die Erkennung ist dauerhaft aktiv,
  solange die App läuft; zum Abschalten beendet man sie. Das spart einen
  Schalter, dessen Name auf Apples Finder-Menüleiste hindeutete und der zudem
  doppelt vorhanden war.
- Das Vorschau-Rad im Einstellungsfenster ist wieder entfernt: Es war nicht als
  Vorschau erkennbar und färbte sich beim Darüberfahren ein, weil die
  AppKit-Tracking-Bereiche von allowsHitTesting(false) unberührt bleiben — also
  ein Element, das wie ein Knopf aussah und nichts tat.
- Transparenz gilt nur noch für das schwebende Kreis-Menü. Der frühere Regler
  für die Fenster ist entfernt; Fenster sind immer deckend, weil das
  Durchscheinen nur die Lesbarkeit gekostet hat.

## Kurzer manueller Abnahmetest
1. dist/flowmo.app öffnen. Die Finder-Erkennung läuft ab dem Start.
2. PNG im Finder ziehen, Shift drücken, auf JPG ziehen und loslassen.
3. Neue Datei neben Original öffnen; Original darf sich nicht ändern.
4. Wiederholen: bestehende Ausgabe bleibt erhalten, neue erhält Nummer im Namen.
5. Erneut ziehen, Shift und dann Escape: keine Ausgabedatei darf entstehen.
5a. Innerhalb eines Drags: Rad öffnen, Taste loslassen, Zeiger wegziehen, bis
    das Rad verschwindet — Maustaste dabei gedrückt halten. Taste erneut
    drücken: Das Rad muss wieder erscheinen, beliebig oft wiederholbar.
5b. Taste durchgehend halten und die Maus bewegen: Das Rad bleibt an seiner
    Position und klebt nicht am Zeiger.
6. Option+Shift auf einem Bild → Hintergrund oder Zuschnitt; Vorschau ändern, speichern.
7. Zweitseitiges PDF auf PNG ziehen: zwei getrennte Bilder entstehen.
8. Einstellungen öffnen, den Deckkraft-Regler auf ca. 50 % ziehen.
   Öffnen-Kombination auf ⌃⌥ stellen, „Apply".
9. Ziehen und ⌃⌥ drücken: Rad erscheint und ist durchsichtiger. ⇧ löst nicht mehr aus.
10. Nach dem Drop: Dashboard ist ausgeblendet, Bestätigungsleiste erscheint kurz.
11. ⇧ gleichzeitig bei „öffnen" und „Werkzeuge" setzen: Hinweis erscheint,
    „Apply" bleibt gesperrt.
12. App beenden und neu starten: Deckkraft und Kombination sind erhalten.
13. Deckkraft auf 35 %: Rad bleibt sichtbar und nimmt den Drop weiter an.
14. Zahnrad anklicken: Einstellungen erscheinen neben dem Dashboard, kein Fenster
    scheint durch das andere. Alle Beschriftungen stehen ohne Umbruch.
15. Dashboard an den rechten Bildschirmrand schieben, Einstellungen erneut
    öffnen: Fenster weicht nach links aus und bleibt vollständig sichtbar.
16. Regler bewegen, dann X: Fenster zu, und beim erneuten Öffnen steht der alte
    Wert wieder da. Eine Vorschau darf nichts speichern.
17. Regler bewegen, dann Apply: Fenster schließt sich, der Wert bleibt auch nach
    einem Neustart der App erhalten.
17a. Haupt- und Einstellungsfenster überlappen lassen sowie Editor und
    Seitenverwaltung öffnen: Alle Fenster sind vollständig deckend, keines
    scheint durch ein anderes hindurch.
18. Tastenkombination ändern und mit X schließen: der alte Auslöser gilt weiter.
19. Bild → Werkzeuge → Komprimieren: „Höchstgröße“ hat eine sichtbare
    Beschriftung und eine Erklärzeile; bei 0 steht „aus“ daneben.
20. Hintergrund-Werkzeug: eigenes Bild wählen → der Foto-Knopf bekommt denselben
    orangen Auswahlrahmen wie die Farbverläufe. Dasselbe beim Farbwähler.
21. Mauszeiger auf Reglern, Schaltern und dem Kreis stehen lassen: überall
    erscheint eine kurze Erklärung.
21a. Signatur-Werkzeug anklicken: Es öffnet sich noch kein Fenster. Erst beim
    Aufziehen des Rahmens erscheint die Auswahl. Nach „Übernehmen" steht die
    Signatur im Rahmen und ist nach dem Sichern auch in der Datei.
21b. Textfeld aufziehen und im Dialog „Abbrechen": Es bleibt kein unsichtbares
    Element zurück, der Zähler „Elemente auf dieser Seite" steigt nicht.
21c. Textfeld anlegen, dann Signatur setzen: Der Text bleibt Text.
21d. Nur einen leeren Rahmen anlegen: „Sichern" ist gesperrt und eine
    Hinweiszeile erklärt, dass unfertige Elemente nicht gespeichert werden.
21e. Bestehende Signatur bei aktivem Signatur-Werkzeug anklicken: Die Auswahl
    öffnet sich erneut und ersetzt das Bild.
21j. Editor öffnen: Alle Beschriftungen sind deutsch, keine Schlüssel wie
    „editor.save". Werkzeuge tragen Namen, nicht nur Symbole.
21k. Fenster an einer Ecke größer ziehen: Der Inhalt wächst mit.
21l. Auf 200 % zoomen: Bildlauf in beide Richtungen, Elemente bleiben an ihrer
    Stelle. Dort verschieben und skalieren, dann „Einpassen" — sitzt weiterhin.
21m. Drei Elemente setzen, dreimal ⌘Z: Sie verschwinden einzeln, ⇧⌘Z holt sie
    zurück. Ein Element verschieben, ⌘Z: Es springt an die alte Stelle.
21n. „Zurücksetzen": Nachfrage erscheint; nach Bestätigung holt ⌘Z alles zurück.
21o. Tasten T und P wählen Text und Pfeil. Die Eigenschaftsleiste erscheint nur
    bei Auswahl.
21f. Rechteck aufziehen, anklicken und an allen vier Ecken ziehen: Die Größe
    ändert sich, die Gegenecke bleibt stehen, und sehr klein gezogen bleibt es
    auf Mindestgröße sichtbar.
21g. Pfeil aufziehen, ein Ende nach links unten ziehen: Die Spitze zeigt
    dorthin — auch in der gespeicherten Datei.
21h. Element auswählen, Drehung auf etwa 30 Grad: Vorschau dreht sich, „Gerade"
    stellt es zurück. Nach dem Sichern sitzt es genau wie in der Vorschau.
21i. Textfeld doppelklicken: Der bisherige Text steht im Dialog.
22. PDF ziehen, Werkzeugtaste → „EDIT": Textrahmen aufziehen, Text eingeben,
    verschieben, speichern. Ergebnis öffnen: Originaltext bleibt markierbar.
23. Signatur zeichnen, übernehmen, in einem zweiten Dokument wiederverwenden.
24. Foto einer Unterschrift laden, Regler „Weiß entfernen" bewegen: der Papier-
    hintergrund verschwindet, die Striche bleiben.
25. Eine Stelle schwärzen, speichern, Ergebnis öffnen: dort darf kein Text mehr
    markierbar sein und die PDF-Suche darf das Wort nicht finden.
26. `defaults delete dev.flowmo.prototype flowmoIntroSeen`, App starten:
    Einleitung erscheint neben dem Hauptfenster. Durchklicken, auf Karte 2 und 3
    ist das echte Rad zu sehen. „Beispiel laden" schließt sie und legt die Datei
    im Hauptfenster bereit.
27. App neu starten: Die Einleitung erscheint nicht mehr. Über das
    Menüleisten-Symbol → „Einleitung" lässt sie sich erneut öffnen.
28. Auslösetaste auf ⌃⌥ ändern, Einleitung erneut öffnen: Karte 2 zeigt ⌃⌥.
29. PDF ziehen, Werkzeugtaste → „PAGES": Seite auswählen, drehen, weitere mit
    Umschalt dazunehmen, eine löschen, per Ziehen umsortieren, zweites PDF
    anhängen und speichern. Das Ergebnis muss genau die gezeigte Folge haben.

SwiftPM benötigte in der eingeschränkten Ausführungsumgebung `--disable-sandbox`,
weil seine verschachtelte Sandbox nicht starten konnte. Die äußeren
Dateizugriffsgrenzen blieben aktiv. Das lokale Bundle ist nur ad hoc signiert.

## Sprachkorrekturen vom 19.10.2026

- Ursache der sichtbaren Schlüssel wie `dashboard.chooseFiles`: Ein ASCII-
  Anführungszeichen in `help.rotation` machte die gesamte deutsche Sprachdatei
  ungültig. Korrigiert; Deutsch und Englisch bestehen wieder `plutil -lint`.
- Auch dynamische Buttons in Einleitung und Bildeditor sowie die Tastennamen
  für Bedienungshilfen werden ausdrücklich lokalisiert. Die Werkzeugnamen im
  Kreis-Menü und die dazugehörige Einleitung folgen ebenfalls der Sprache.
- `LocalizationTests` prüfen das vollständige Einlesen beider Tabellen,
  identische und nicht leere Schlüssel, die Auflösung mit Foundation, passende
  Formatargumente sowie fehlende Übersetzungen für im Quelltext verwendete Schlüssel.
- Der App-Build prüft beide Sprachdateien vor dem Kompilieren. Der ursprüngliche
  Fehler wurde in einer temporären Projektkopie absichtlich nachgestellt: Der
  Build bricht mit Erklärung ab, bevor Swift gestartet oder ein Bundle ersetzt wird.
- Sprachkorrektur zunächst erfolgreich gebaut und mit 50 Tests ohne Fehler geprüft.
  Separat gestartete Preview-only-Bundles mit eigener Bundle-ID und Sprachargumenten
  zeigen deutsche bzw. englische Texte im Hauptfenster, in allen vier
  Einleitungskarten, in den Einstellungen und in allen drei Bildwerkzeugen.
  Buttons, Statusmeldungen, Hilfetexte und Tastennamen wurden dabei ausgelesen;
  Hauptfenster, Werkzeugrad und deutsche Bildwerkzeuge zusätzlich visuell geprüft.
- Deutsches Bearbeitungsfenster und Signaturauswahl ebenfalls geprüft. Es wurden
  keine Signaturen gespeichert und keine eigenen Dateien des Nutzers verändert.
  Der PDF-Dateidialog ließ sich per Fernsteuerung nicht zuverlässig bestätigen;
  die Seitenverwaltung ist daher in diesem Durchlauf nur über ihre Sprachressourcen
  und die bestehenden Modelltests abgedeckt.
- Die Beschriftung „Seitenverhältnis“ im Zuschnitt bekommt ihre natürliche Breite,
  damit das deutsche Wort nicht mitten im Wort umbricht.
- Abschlussprüfung nach den parallelen Editorergänzungen: Release-Build erfolgreich,
  54 Tests ohne Fehler. Deutsch und Englisch enthalten je 203 eindeutige Schlüssel;
  die Dateien im fertigen Bundle sind mit den Quellen identisch. Die Ad-hoc-Signatur
  besteht `codesign --verify --deep --strict`. Die finale deutsche App zeigt
  „Seitenverhältnis“ ohne Wortumbruch und die ergänzten Editorbedienelemente
  einschließlich „Einpassen“ mit aufgelösten Hilfetexten. Testinstanzen beendet;
  die laufende Nutzerinstanz wurde nicht neu gestartet.

## Eigenes Logo vom 19.10.2026

- Gemeinsame AppKit-Zeichenquelle für App-Icon, Willkommenszeichen und
  einfarbiges Template-Menüleistensymbol; kein interaktives Rad als Dekoration.
- Release-Build erfolgreich; alle 54 bestehenden Tests bestehen auch nach
  der abschließenden Korrektur der Schatten-Skalierung.
- Zehn PNG-Repräsentationen von 16 bis 1024 Pixeln mit korrekten Abmessungen
  erzeugt und als `flowmo.icns` im Bundle hinterlegt. `CFBundleIconFile`
  verweist darauf; die finale Ad-hoc-Signatur besteht die strenge Prüfung.
- App-Icon im Finder visuell bestätigt. Größenvergleich für 128, 64, 32 und
  16 Pixel sowie Willkommenszeichen und 18-/36-Pixel-Template auf hellen und
  dunklen Testflächen kontrolliert. Template-Eigenschaft zusätzlich geprüft.
- Willkommenskarte in einem separat signierten Preview-only-Bundle geprüft.
  Quartz skaliert Schatten nicht mit der Zeichenmatrix: Schattenabstand und
  Unschärfe werden deshalb ausdrücklich auf die Ausgabegröße umgerechnet.
- JPG-Konvertierung einer frisch erzeugten Beispieldatei über das vorhandene
  Dashboard-Rad erfolgreich; Ergebnis im Finder vorhanden. Ein erneuter echter
  Finder-Drag mit währenddessen gedrückter Auslösetaste sowie eine Sichtprüfung
  im Dock und in der tatsächlichen Menüleiste sind hier nicht separat erfolgt.

## Korrektur des Dock-Symbols vom 19.10.2026

- Doppelten `CFBundleIconFile`-Eintrag entfernt; der verbleibende verweist
  eindeutig auf `flowmo.icns`. Beim Start setzt die App ihr Symbol ausdrücklich
  aus derselben `BrandMark`-Zeichenquelle wie das gebündelte Icon.
- Der Build liest den Icon-Dateinamen aus der Plist und dekodiert sowohl die
  Quelldatei als auch die fertige Bundle-Datei. Fehlendes und beschädigtes Icon
  in temporären Projektkopien geprüft: verständlicher Abbruch vor dem Kompilieren.
- Release-Build, alle 54 bestehenden Tests, Plist-Prüfung und strenge
  Ad-hoc-Signaturprüfung erfolgreich.
- Nur das leere Hauptfenster war offen. Die Nutzerinstanz regulär beendet und
  aus `dist/flowmo.app` neu gestartet; das von `NSRunningApplication.icon`
  gelieferte Bild zeigt das orange-weiße Logo. Die direkte Sichtprüfung im Dock
  und App-Umschalter bleibt offen: Der Fernsteuerungszugriff auf das Dock lief
  in ein Timeout. Es wurden keine Dock-Einstellungen oder System-Caches verändert.

## Behebung der UI-/UX-Befunde vom 19.10.2026

- Alle 13 Befunde aus `docs/UI_UX_AUDIT.md` sind im Code behoben; Einzelheiten
  stehen dort im Abschnitt „Behebungsstand“.
- Release-Build mit Sprach-Lint und Signatur erfolgreich, ohne Compiler-Warnung.
- 70 Tests, 0 Fehler. Neu: `UXRegressionTests` (Core, 7 Tests) und das Target
  `FlowmoAppTests` mit `CanvasBehaviorTests` (7 Tests, AppKit-Views offscreen
  mit synthetischen Ereignissen).
- Die Nutzerinstanz wurde regulär beendet und aus `dist/flowmo.app` neu gestartet.
  Die Sichtprüfung am Bildschirm ist offen: Screenshots waren ohne
  Bildschirmaufnahme-Berechtigung nicht möglich, Systemeinstellungen wurden nicht verändert.

## Praxisabnahme der UI-Korrekturen vom 19.10.2026

- Alle 13 Audit-Befunde in der laufenden App mit echter Maus/Tastatur geprüft und
  bestanden, inklusive Finder-Drag mit ⇧ auf das schwebende Rad und Escape.
- Dabei 11 neue Fehler gefunden und behoben (N1–N11 in `docs/UI_UX_AUDIT.md`),
  am wichtigsten: Zeichnen verschob das Fenster; neue Fenster überdeckten das
  Hauptfenster oder ragten aus dem Bildschirm.
- 76 Tests, 0 Fehler; Release-Build ohne Warnung. Original-Testbild bytegleich.
- Offen: Signatur, Hintergrund-Werkzeug, Einstellungen, mehrere Bildschirme,
  große Dateien, Schließen während des Speicherns.

## PDF-Bildexport: Skalierungskorrektur vom 19.10.2026

- Behoben: Bei 150 DPI entstand eine große Bildfläche, während der PDF-Inhalt
  unskaliert in ihrer Mitte stand. Der zusätzliche weiße Rand war Bestandteil
  der Ausgabe, kein Finder-Vorschaufehler.
- `FileConverter.render` bildet PDF-Punkte jetzt ausdrücklich über `dpi / 72`
  auf Pixel ab und berücksichtigt Seitendrehung sowie verschobene Seitenursprünge.
  Tatsächliche PDF-Ränder bleiben erhalten. Dieselbe Korrektur gilt für die
  Editorvorschau, OCR und das Rasterisieren geschwärzter Seiten.
- Vier neue `PDFRenderingTests`: Inhalt bis zum Seitenrand bei 36/72/110/150/200
  DPI und allen vier Seitendrehungen, einschließlich verschobenem Ursprung;
  Erhalt echter Ränder; mehrseitiger JPG-/PNG-Export einschließlich gespeicherter
  Drehung und Originalschutz; partielle Schwärzung mit entferntem Text und
  unverändert positioniertem Inhalt außerhalb des Balkens. Farbpixel werden
  ausdrücklich in sRGB verglichen, unabhängig vom Geräteprofil.
- Vollständige Tests: 82 Fälle, 0 Fehler, einschließlich OCR und bestehender
  Schwärzungstests. Release-App mit Sprach-Lint erfolgreich gebaut.
- Die gemeldete PDF ausschließlich aus einer Kopie in `.build` nach JPG und PNG
  konvertiert (je 2338 × 2921 Pixel). JPG visuell geprüft: Der Inhalt füllt die
  Seite wieder aus. Die Quelldatei auf dem Schreibtisch blieb bytegleich;
  vorhandene Nutzer-Ausgaben wurden nicht überschrieben.
- Die laufende Nutzerinstanz wurde nicht neu gestartet. Für den erneuten
  Finder-Drag muss die frisch gebaute App aus `dist/flowmo.app` gestartet werden.

## Fortlaufende Textbearbeitung vom 19.10.2026

- „Bearbeiten“ startet mit direkt editierbarem Text. PDF-Textebene bevorzugt,
  lokale Vision-OCR für Bildseiten und Bilder; TXT/MD/RTF/DOCX ebenfalls als
  bearbeitbare Dokumente erreichbar. Der Textmodus rekonstruiert Grundformatierung,
  nicht Bilder, Tabellen oder das ursprüngliche Seitenlayout.
- Native, verbundene NSTextViews für A4-Seiten, Schrift/Farbe/Fett/Kursiv/
  Unterstrichen, Absatzausrichtung und Listen. Start bei 100 %, zusätzlich
  Einpassen und Zoom. TextKit-Geometrie und Glyphenlayout werden für Vorschau und
  PDF-Ausgabe gemeinsam verwendet. Der Export arbeitet mit einer eigenen Kopie.
- Text und Originalmarkierungen bleiben beim Umschalten getrennt erhalten.
  Beide Ansichten behalten eigene Snapshot-Verläufe. PDF/DOCX werden erst beim
  Sichern als neue Dateien geschrieben; der Editor bleibt danach geöffnet.
  Schließen und Beenden schützen ungesicherte Änderungen und laufendes Speichern.
- 15 neue Tests in `DocumentTests` und `DocumentEditingTests`: mehrseitiges
  Layout und PDF-Textebene, DOCX-Rücklesen inklusive Schrift/Absatz/Unterstreichen,
  Listen ohne doppelte Marker, Unicode, Snapshot-Verlauf, nativer Textimport und
  OCR in gemischten PDFs, Abbruch/Leertext/gesperrte PDFs, Original- und
  Kollisionsschutz, Eingabe/Formatierung/Listenfortsetzung, Zoom, Seitenwachstum
  und -abbau, Tastaturweiterleitung sowie aktive und inaktive Befehlsbrücken.
- Vollständige Prüfung im Hauptbaum: **99 Tests, 0 Fehler**. Release-Build mit
  Sprach- und Plist-Prüfung ohne Compiler-Warnungen erfolgreich; Ad-hoc-Signatur
  besteht `codesign --verify --deep --strict`.
- Deutsche Oberfläche in einer getrennten Preview-App mit eigener Bundle-ID,
  deaktivierter Finder-Erkennung und ausschließlich synthetischen Testdateien
  geprüft: direkte Texteingabe, Rückgängig-Schaltfläche und Bearbeiten-Menü,
  PDF-/DOCX-Speichern bei offenbleibendem Editor, Originalansicht, Erhalt eines
  ungesicherten Textentwurfs beim Ansichtswechsel und der Schließdialog mit
  „Weiterbearbeiten“/„Änderungen verwerfen“. Die finale 720 × 560-Punkte-Ansicht
  visuell geprüft; Formatierung, Ansichtswechsel und Speichern bleiben sichtbar.
- Gefunden und behoben: Ein leerer NSRange verlor bei NSIntersectionRange seine
  Einfügeposition und entfernte beim Beenden einer Liste den ersten Listenpunkt.
  Außerdem brauchten rahmenlose Fenster eine ausdrückliche Weiterleitung von
  Textbefehlen, inaktive Ansichten durften keine Befehlsbrücke löschen, und die
  Ansichtsbuttons benötigen eigene Beschriftungen für Bedienungshilfen.
- Tastenkürzel sind mit synthetischen Ereignissen über das tatsächliche
  ReferenceWindow und NSTextView geprüft. Die Fernsteuerungs-Tastendrücke im
  sichtbaren Fenster waren nicht zuverlässig nachweisbar; sie gelten deshalb
  nicht als zusätzliche praktische Tastaturabnahme. Menübefehle und sichtbare
  Schaltflächen wurden separat erfolgreich bedient.
- Die gemeldete Bild-PDF zusätzlich lokal per OCR übernommen, mit einem
  Testzusatz verändert, als PDF und DOCX geschrieben und beide erneut gelesen.
  Der Zusatz ist in der PDF-Textebene vorhanden. Die Ausgangsdatei blieb
  bytegleich; sämtliche Prüfausgaben liegen ausschließlich unter `.build`.
- Deutsch und Englisch bestehen Syntax-, Schlüssel- und Formatargumentprüfungen.
  Keine neuen Berechtigungen, Bibliotheken oder Uploads. Die normale Nutzerinstanz
  wurde nicht beendet oder neu gestartet; mehrere Bildschirme und eine echte
  Benutzer-Tastatur bleiben manuelle Abnahmepunkte.



## Umbenennung in flowmo vom 19.10.2026

- Oberfläche in Deutsch und Englisch, App-Bundle und ausführbare Datei,
  Bundle-ID, Swift-Module, Test-Targets, Icon-Dateiname, Start-/Build-/Paket-
  skripte, Editor-Aufgaben und Dokumentation verwenden flowmo.
- Neue Einstellungen und der Einleitungsstatus verwenden flowmo-Schlüssel.
  Frühere Namen bleiben ausschließlich für die Übernahme vorhandener Daten
  lesbar; aktuelle Einstellungen haben Vorrang. Ein zurückgesetzter
  Einleitungsstatus wird durch die Übernahme nicht erneut überschrieben.
- Gespeicherte Unterschriften werden einmalig in den neuen Support-Ordner
  kopiert. Der bisherige Ordner bleibt unverändert; vorhandene neue Daten
  werden nicht ersetzt, gelöschte Unterschriften nicht erneut übernommen.
- Vollständiger Testlauf: **106 Tests, 0 Fehler**, einschließlich vier neuer
  Prüfungen zur Datenübernahme.
- Release-Build, Sprach-/Plist-Prüfung und strenge Ad-hoc-Signaturprüfung
  erfolgreich. Das Paket `dist/flowmo-0.5.0.zip` enthält das neue App-Bundle.
- Reguläre bisherige Instanz ohne offene Editoren beendet; neue App gestartet.
  Fenstername, sichtbarer App-Name, Formatmenü und App-Menü einschließlich
  „flowmo beenden“ über die laufende Oberfläche geprüft.
- Bisherige App-/ZIP-Builds liegen als Sicherung ausschließlich unter `.build`.
