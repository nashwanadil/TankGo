// Pure trip-planning logic (no Flutter): optimal fuel purchases across countries.

class Leg {
  const Leg(this.cc, this.km);
  final String cc;
  final double km;
}

class Stop {
  const Stop(this.cc, this.litres, this.price, this.km);
  final String cc;
  final double litres, price, km;
  double get cost => litres * price;
}

class TripPlan {
  const TripPlan(this.stops, this.total, this.baseline);
  final List<Stop> stops;
  final double total;

  /// Cost if all fuel were bought at the first country's price.
  final double baseline;
  double get saved => baseline - total;
}

/// Neighbouring countries for the free comparison view (EU land borders).
const neighbours = <String, List<String>>{
  'AT': ['DE', 'CZ', 'SK', 'HU', 'SI', 'IT'],
  'BE': ['NL', 'DE', 'LU', 'FR'],
  'BG': ['RO', 'GR'],
  'HR': ['SI', 'HU'],
  'CY': [],
  'CZ': ['DE', 'AT', 'SK', 'PL'],
  'DK': ['DE'],
  'EE': ['LV'],
  'FI': ['SE', 'EE'],
  'FR': ['BE', 'LU', 'DE', 'IT', 'ES'],
  'DE': ['DK', 'NL', 'BE', 'LU', 'FR', 'CZ', 'AT', 'PL'],
  'GR': ['BG'],
  'HU': ['AT', 'SK', 'RO', 'HR', 'SI'],
  'IE': [],
  'IT': ['FR', 'AT', 'SI'],
  'LV': ['EE', 'LT'],
  'LT': ['LV', 'PL'],
  'LU': ['BE', 'DE', 'FR'],
  'MT': [],
  'NL': ['BE', 'DE'],
  'PL': ['DE', 'CZ', 'SK', 'LT'],
  'PT': ['ES'],
  'RO': ['BG', 'HU'],
  'SK': ['CZ', 'AT', 'PL', 'HU'],
  'SI': ['AT', 'IT', 'HR', 'HU'],
  'ES': ['PT', 'FR'],
  'SE': ['DK', 'FI'],
};

/// Popular, high-traffic destinations: their prices are Premium in the comparison.
/// Less-visited countries stay free so the free view is useful but incomplete.
const premiumCountries = {'FR', 'DE', 'IT', 'ES', 'AT', 'HR', 'GR', 'PT', 'NL'};

/// Example route shown to free users in the trip planner (classic summer drive).
const demoRoute = [Leg('DE', 300), Leg('AT', 350), Leg('SI', 150), Leg('HR', 400)];

/// Approximate short-stay road-charge (vignette) cost in EUR for a passenger car.
/// Indicative only; the app tells users to verify (values from 2025).
const vignetteEur = <String, double>{
  'AT': 12.4, // 10-day
  'CZ': 11.0, // 10-day, ~270 CZK
  'SK': 12.0, // 10-day
  'SI': 16.0, // 7-day
  'HU': 8.0, // 10-day, ~HUF
  'BG': 8.0, // 7-day
  'RO': 3.0, // 7-day
};

/// Greedy optimal plan (classic gas-station problem, uniform price per country).
/// [prices] price per litre by country code. Fuel is bought when entering a country.
/// Returns null if a price is missing.
TripPlan? planTrip(List<Leg> legs, Map<String, double> prices, {required double tank, required double consumption, bool startFull = true}) {
  if (legs.isEmpty || tank <= 0 || consumption <= 0) return null;
  for (final l in legs) {
    if (prices[l.cc] == null) return null;
  }
  final need = [for (final l in legs) l.km * consumption / 100];
  var fuel = startFull ? tank : 0.0;
  final bought = List<double>.filled(legs.length, 0);
  // Fuel in tank is "free" (bought before the trip); remaining needs are priced at the leg's country.
  final startFuel = fuel;
  for (var i = 0; i < legs.length; i++) {
    final p = prices[legs[i].cc]!;
    var reach = 0.0; // litres needed to arrive at the entrance of country j
    var target = -1;
    for (var j = i + 1; j < legs.length; j++) {
      reach += need[j - 1];
      if (reach > tank) break;
      if (prices[legs[j].cc]! < p) {
        target = j;
        break;
      }
    }
    double goal;
    if (target > 0) {
      goal = need.sublist(i, target).fold(0.0, (a, b) => a + b);
    } else {
      final rest = need.sublist(i).fold(0.0, (a, b) => a + b);
      goal = rest < tank ? rest : tank;
    }
    var buy = goal > fuel ? goal - fuel : 0.0;
    fuel += buy;
    if (fuel < need[i]) {
      buy += need[i] - fuel; // leg longer than the tank: refuel inside the country at the same price
      fuel = need[i];
    }
    bought[i] = buy;
    fuel -= need[i];
  }
  final stops = [for (var i = 0; i < legs.length; i++) Stop(legs[i].cc, bought[i], prices[legs[i].cc]!, legs[i].km)];
  final total = stops.fold(0.0, (a, s) => a + s.cost);
  final totalNeed = need.fold(0.0, (a, b) => a + b);
  final baseline = (totalNeed - startFuel).clamp(0.0, double.infinity) * prices[legs.first.cc]!;
  return TripPlan(stops, total, baseline);
}
