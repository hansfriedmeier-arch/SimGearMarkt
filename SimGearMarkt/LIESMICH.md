# SimGear Markt 1.5.3

Eigenes Addon (eigener Code, eigenes Fenster): findet im Auktionshaus Ausrüstungs-Upgrades, die du tragen und bezahlen kannst - **bewertet von SimGear Forever** mit dessen Daten. Wird SimGear Forever aktualisiert, rechnet SimGear Markt automatisch mit den neuen Daten.

## Benutzung
- Auktionshaus öffnen, oben am Fenster **"SimGear Markt"** klicken (oder `/sgm`). Das Fenster öffnet sich rechts neben dem Auktionshaus.
- **Suchen**: durchsucht Waffen und Rüstung bis zu deinem Level (alle Seiten). SimGear bewertet jedes Angebot gegen das, was du trägst - genauso wie in seinem Tooltip.
- Liste: Name, Platz, Gewinn laut SimGear (z. B. "+4,2 %", "leerer Platz"), günstigster Preis.
- **Filter**: Höchstpreis in Gold (0 = egal), Mindestgewinn in %, Platz (Waffe, Kopf, ...). **Sortieren** nach Gewinn, Gewinn pro Gold oder Preis.
- **Klick** auf eine Zeile sucht das Item im Auktionshaus, kaufen tust du selbst. **Shift+Klick** = Link in den Chat. Maus drüber = Item-Tooltip mit SimGears Urteil.
- Sprache: Deutsch auf deutschem Client, sonst Englisch.

## Neu in 1.5.3
- Fix: Die grüne Zahl war 100-mal zu klein (SimGear liefert den Gewinn als Anteil, 12,68 = +1268 %). Jetzt steht in der Liste genau dieselbe Zahl wie im SimGear-Tooltip.
- Fix: "Upgrade mindestens 1 %" verlangte dadurch in Wahrheit +100 % - kleinere Upgrades fehlten. Jetzt gilt wirklich 1 %.

## Neu in 1.5.2
- "Bestes Set für X Gold" rechnet mit X statt mit deinem Gold in der Tasche (vorher blieben trotz 1500 g nur bezahlbare Teile übrig).
- Die Statuszeile zeigt in Orange, wie viele Upgrades nur wegen des Preises ausgeblendet sind ("+N zu teuer"). Abschalten: Einstellungen > "Nur bezahlbare".
- /sgm debug: zählt Upgrades, solche über deinem Level, wegen Preis ausgeblendete und dein Gold.

## Neu in 1.5.1
- Fix: Die dritte Reihe der Platz-Knöpfe lag über den ersten Item-Namen. Die Liste beginnt jetzt unter den Knöpfen, das Fenster ist etwas höher.

## Neu in 1.5
- Neues Aussehen im Stil des Spiels (Fenster mit Porträt, Titelleiste, Innenrahmen, Spielschriften; Kaufen-Box als Spiel-Dialog).
- Minimap-Knopf: Linksklick öffnet, Rechtsklick Einstellungen, ziehen verschiebt. Ausblenden in den Einstellungen oder mit /sgm minimap. Auch in der Addon-Liste an der Minimap.
- Einstellungen unter Spielmenü > Optionen > AddOns > SimGear Markt (auch /sgm options und der Knopf "Einstellungen" im Fenster): alle Filter + Minimap-Knopf.

## Neu in 1.4
- Level-Regler neben dem Titel: von deinem Level bis 60. Höher gestellt (gelb) zeigt die Liste auch Upgrades, die du erst mit diesem Level tragen kannst (Mindestlevel, Waffen ab Level X, noch nicht gelernte Waffen). Wird nicht gespeichert - nach /reload wieder dein Level.
- Weniger Text: Tooltip einer Zeile = Item + Preis (Quelle); Untertitel, Erklärzeilen im Filtermenü, Hinweis unten und Button-Tooltips entfernt.

## Neu in 1.3.2
- Der Tooltip einer Zeile zeigt keine eigene SimGear-Zeile (Gewinn / "ersetzt") mehr - die steht schon im Tooltip von SimGear Forever.

## Neu in 1.3.1
- Fix: Die Suche blieb kurz vor Ende stehen ("… bewertet") und zeigte keine Liste - die letzte Anzeige ging verloren. Jetzt wird das Ende immer gezeichnet.
- Items, auf die das Spiel nie antwortet (gelöschte Items in Auctionators Daten), beenden die Suche nach 8 s Stille statt sie aufzuhalten.

## Neu in 1.3
- **Kaufen mit Rückfrage** (Knopf "Kaufen" in jeder Zeile, nur am Auktionshaus): das Item wird sofort nachgeschlagen, dann zeigt ein Fenster SimGears Gewinn, den Sofortkaufpreis und die Nettokosten. Hat sich der Preis geändert, stehen alter und neuer Preis da; ist das günstigste weg, das nächste Angebot; gibt es keins mehr: "Nicht mehr im Angebot". Bezahlt wird nur mit dem Knopf in diesem Fenster. Gekauftes verschwindet aus der Liste.
- **Nur was du jetzt anlegen kannst**: Items mit höherem Mindestlevel (Itemdaten des Spiels) und Waffen, die deine Klasse noch nicht führen kann (SimGear), fallen raus.
- **Upgrade in Prozent** gegenüber dem Teil, das es ersetzt; **"Neu"** heißt: der Platz ist leer.
- **Zwei Markierungen pro Platz**: "Bestes Upgrade" (das stärkste) und "Bester Wert" (am günstigsten pro Prozent Verbesserung; mit "Wert nach Nettokosten" nach Nettokosten). Ein Teil kann beides sein.
- **Preise**: die Liste erscheint sofort aus deinen Scan-Daten; **grau** = noch nicht geprüft (kann ein Gebot sein), **weiß** = geprüfter Sofortkaufpreis. Am Auktionshaus prüft das Addon die angezeigten Preise gleich nacheinander (abschaltbar). Kaufen geht sofort, weil vor jedem Kauf neu geprüft wird.
- **Gelber Stern * nach dem Namen**: das Item hat Effekte (z. B. Procs), die SimGears Wertung nicht mitzählt.
- Rüstungsregeln aus den Spieldaten bestätigt (Fertigkeiten Platte: Krieger/Paladin; Kette: + Jäger/Schamane; Leder: + Schurke/Druide).

## Neu in 1.2: Preise aus Auctionator / Auctioneer
- **Kein eigener Auktionshaus-Scan mehr.** "Suchen" nimmt die Angebote aus deinem **Auctionator** (zuletzt gesehener Tiefstpreis je Item) und **Auctioneer** (Bild seines letzten Scans mit allen Auktionen, inkl. Zufallssuffix; Auktionen nur mit Gebot übersprungen) und lässt SimGear bewerten. Beides zusammen: pro Item zählt der niedrigere Preis.
- Funktioniert **überall**, auch ohne offenes Auktionshaus (`/sgm`). Das Fenster lässt sich verschieben, ESC schließt.
- **Auctionator-Preise höchstens X Tage alt** (Filter-Menü, Standard 7 Tage): ältere Preise bleiben weg.
- Tooltip einer Zeile zeigt, woher der Preis stammt ("Auctionator, vor 3 Tagen", "Auctioneer, letzter Scan", "live geprüft").
- **Live prüfen** (nur am Auktionshaus): schlägt jedes angezeigte Item einmal nach und nimmt den echten niedrigsten Sofortkaufpreis.
- Hinweis: Auctionator trennt auf Forever Items mit Zufallssuffix ("... des Adlers") nicht; die werden dann als Grund-Item bewertet. Auctioneer hat das Suffix.
- **Rüstungsfilter korrigiert**: "Nur die Rüstungsarten der Klasse" - Jäger und Schamanen Leder **und** Kette, Krieger und Paladine Kette und Platte, Schurken und Druiden Leder, Stoffklassen Stoff.

## Neu in 1.1
- **Bestes Set für ... Gold**: Betrag eintippen (leer = dein ganzes Gold), OK. Zeigt die Upgrades, die zusammen am meisten bringen und in das Budget passen: höchstens eins pro Platz, zwei Ringe, zwei Schmuckstücke, Zweihänder ODER Waffenhand + Nebenhand. "Zur Liste" geht zurück. (Die Gewinne werden addiert - zwei Ringe zusammen sind eine Näherung.)
- **Filter-Menü** (alles pro Charakter gespeichert, jede Option mit Erklärung):
  - *Nur was ich bezahlen kann* - blendet aus, was mehr kostet als dein Gold.
  - *Sofortkauf bis [Gold]* - eigener Höchstpreis.
  - *Nur die 5 besten pro Platz* - kurze Liste; aus = alle Upgrades (die Preisprüfung dauert dann länger).
  - *Nur die Rüstungsarten der Klasse* - siehe 1.2.
  - *Upgrade mindestens [%]* - kleinere Upgrades weg; ein Item für einen leeren Platz bleibt immer.
  - *Wert nach Nettokosten* - "Gewinn pro Gold" rechnet mit Preis minus Händlerwert des ersetzten Teils. Bezahlbar und Bestes Set nehmen weiter den Sofortkaufpreis.
- **Sofortkaufpreise prüfen**: seit 1.2 per Knopf "Live prüfen" am Auktionshaus (etwa 85 pro Minute). Ungeprüfte Preise stehen mit "~".

## Voraussetzung
- **SimGear Forever aus UIREWORK-Forever** (optimierte Kopie). Diese enthält eine kleine, nur lesende Schnittstelle `SimGearForeverAPI` (MIT-Lizenz erlaubt das). Das Update-Skript `sgf-update` baut sie bei jedem SimGear-Update automatisch wieder ein (`generators/sgf_patch.py`).
- Ohne diese Schnittstelle zeigt SimGear Markt einen Hinweis und sucht nicht.

## Wenig CPU und Speicher
- Nichts läuft, solange das Auktionshaus zu ist. Gesucht wird nur auf Knopfdruck; bewertet werden 4 Angebote pro Bild, das Fenster wird höchstens 4-mal pro Sekunde neu gezeichnet.
- Speicher im Test: etwa 110 KB nach dem Laden, etwa 250 KB nach einer Suche mit 50 Angeboten (inkl. Testattrappen).

## Noch nicht drin (Ideen für später)
- Verbrauchsgüter (Tränke, Essen) - UpgradeScout hat das, hier noch nicht.
- Andere Charaktere/Twinks bewerten.
