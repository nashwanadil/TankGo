# TankGo

Fuel prices for the EU (27 countries) and the USA. Flutter app (Android/iOS/Web), 24 languages.

- **Data:** `scripts/aggregate.py` runs twice daily (GitHub Actions) and publishes JSON to the `data` branch, served by GitHub Pages at `https://tankgo.nashwanadil.com/v1/latest.json`.
- **Sources:** EU Weekly Oil Bulletin (European Commission), CBS Netherlands (CC BY 4.0), U.S. EIA.
- **Build:** `flutter build apk --release` / `flutter build appbundle --release`. Signing via `android/keystore.properties` (not in the repo).
