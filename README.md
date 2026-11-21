# Tankpreise NL (FuelPrices)

Android-WebView-App: tägliche Durchschnittspreise für Euro 95, Diesel und LPG in den Niederlanden (Quelle: CBS Open Data, Tabelle 80416ned, CC BY 4.0) plus Richtwerte für E-Auto-Ladestrom und Kostenrechner. Sprachen: DE / NL / EN.

- Web-Oberfläche: `app/src/main/assets/www/` (`index.html`, `ev.json` – Strompreise manuell pflegen, Feld `asOf` aktualisieren)
- Build: `gradle assembleRelease` (Signatur über `keystore.properties`, nicht im Repo)
