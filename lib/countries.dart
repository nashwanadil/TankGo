class Country {
  final String code, name, lang;
  const Country(this.code, this.name, this.lang);
  String get flag => String.fromCharCodes(code.codeUnits.map((c) => 0x1F1E6 + c - 65));
}

const countries = <Country>[
  Country('AT', 'Österreich', 'de'),
  Country('BE', 'België / Belgique', 'nl'),
  Country('BG', 'България', 'bg'),
  Country('HR', 'Hrvatska', 'hr'),
  Country('CY', 'Κύπρος', 'el'),
  Country('CZ', 'Česko', 'cs'),
  Country('DK', 'Danmark', 'da'),
  Country('EE', 'Eesti', 'et'),
  Country('FI', 'Suomi', 'fi'),
  Country('FR', 'France', 'fr'),
  Country('DE', 'Deutschland', 'de'),
  Country('GR', 'Ελλάδα', 'el'),
  Country('HU', 'Magyarország', 'hu'),
  Country('IE', 'Ireland / Éire', 'en'),
  Country('IT', 'Italia', 'it'),
  Country('LV', 'Latvija', 'lv'),
  Country('LT', 'Lietuva', 'lt'),
  Country('LU', 'Luxembourg', 'fr'),
  Country('MT', 'Malta', 'mt'),
  Country('NL', 'Nederland', 'nl'),
  Country('PL', 'Polska', 'pl'),
  Country('PT', 'Portugal', 'pt'),
  Country('RO', 'România', 'ro'),
  Country('SK', 'Slovensko', 'sk'),
  Country('SI', 'Slovenija', 'sl'),
  Country('ES', 'España', 'es'),
  Country('SE', 'Sverige', 'sv'),
  Country('US', 'United States', 'en'),
];

Country? countryByCode(String? c) {
  for (final x in countries) {
    if (x.code == c) return x;
  }
  return null;
}

/// Suggest a country from the device region, else from the chosen language.
Country suggestCountry(String? deviceRegion, String lang) =>
    countryByCode(deviceRegion?.toUpperCase()) ?? countries.firstWhere((c) => c.lang == lang, orElse: () => countries.firstWhere((c) => c.code == 'NL'));
