import 'package:material_ui/material_ui.dart';

// Yarnaz Labs brand palette (see BRAND.md in nashwanadil/releases). The only place colour values live.
/// A colour theme the user can pick (like AzanKurd). Burgundy is the brand default; gold stays the accent in all.
class Palette {
  const Palette(this.id, this.brand, this.dark, this.light, this.deep, this.selDark);
  final String id;
  final Color brand, dark, light, deep, selDark; // primary, hero edge, hero centre, deepest text, dark-mode selection
}

const palettes = <Palette>[
  Palette('burgundy', Color(0xFF8F2A39), Color(0xFF6B1A2E), Color(0xFF9E2F42), Color(0xFF3B0C15), Color(0xFF4A2029)),
  Palette('emerald', Color(0xFF1F7A5A), Color(0xFF145C43), Color(0xFF26906A), Color(0xFF08291D), Color(0xFF163D30)),
  Palette('night', Color(0xFF2F4A8A), Color(0xFF22366A), Color(0xFF3A589F), Color(0xFF0E1834), Color(0xFF1E2A4A)),
  Palette('royal', Color(0xFF5B3A8C), Color(0xFF43296B), Color(0xFF6A45A0), Color(0xFF1E1033), Color(0xFF2F2247)),
  Palette('onyx', Color(0xFF4A4A4A), Color(0xFF2E2E2E), Color(0xFF5C5C5C), Color(0xFF161616), Color(0xFF333333)),
];

/// The active palette; set from settings before the theme is built.
Palette pal = palettes.first;
Palette paletteById(String? id) => palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);

Color get brand => pal.brand;
Color get brandDark => pal.dark;
Color get brandLight => pal.light; // hero/icon gradient centre
Color get brandDeep => pal.deep;
const gold = Color(0xFFE0B860);
const ivory = Color(0xFFFAF7F0); // light background: milky white (TankGo; was the pinkish #F5F1F0)
const darkBrown = Color(0xFF2A1D17); // text on gold
const bgDark = Color(0xFF121212); // dark background: neutral near-black (was the brown #2A1D17)
const cardDark = Color(0xFF1E1E1E);
const cream = Color(0xFFF5ECE0); // light text on dark
const borderDark = Color(0xFF303030);
const borderLight = Color(0xFFE6DDCC);
const errorLight = Color(0xFFB3261E);
const errorDark = Color(0xFFFF8A80);

// Functional colours (allowed by BRAND.md for states and charts).
const riseSoft = Color(0xFFFFB4AB);
const fallSoft = Color(0xFFA5E8C0);
const positive = Color(0xFF2E8B6A);
const negative = Color(0xFFD9534F);
const fuelE95Light = Color(0xFFB98A24);
const fuelLpgDark = Color(0xFF7FC4A5);
const lpgAltLight = Color(0xFF2F6F9F); // LPG under the emerald theme
const lpgAltDark = Color(0xFF8DB5E0);

// Theme surfaces.
const errorContainerLight = Color(0xFFF9DEDC);
const errorContainerDark = Color(0xFF5A2A2A);
const primaryContainerLight = Color(0xFFF1E4C6); // selected chips/segments: milky gold, not pink
Color get primaryContainerDark => pal.selDark; // selection in dark mode: deep tint of the palette
const surfaceHighLight = Color(0xFFE9E1D2);
const surfaceLowLight = Color(0xFFF6F1E7);
const surfaceMidLight = Color(0xFFF2ECE0);
const surfaceHigherLight = Color(0xFFEEE7DA);
const surfaceHighDark = Color(0xFF2C2C2C);
const surfaceLowDark = Color(0xFF181818);
const surfaceMidDark = Color(0xFF1C1C1C);
const surfaceHigherDark = Color(0xFF242424);
const chipBorderLight = Color(0xFFDDD2BF);

// Radii (BRAND.md): cards 18, elements 12–14, hero 28.
const rCard = 18.0;
const rElement = 14.0;
const rHero = 28.0;
