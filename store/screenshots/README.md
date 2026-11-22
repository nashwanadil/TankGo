# Store screenshots

1. Live data for the app screens:
   `mkdir -p store/screenshots/.data/v1/history store/screenshots/.data/v1/stations && for f in v1/latest.json v1/signal.json v1/history/DE.json v1/stations/index.json v1/stations/FR.json; do curl -s -o store/screenshots/.data/$f https://tankgo.nashwanadil.com/$f; done`
2. App screens in every store language (real app code and fonts): `flutter test --update-goldens store/screenshots/app_shots_test.dart` → `src/{en,de,ar}/*.png`
3. Store images (titles in `texts.json`): `node store/screenshots/make.js` → `{en,de,ar}/0N_*.png`
