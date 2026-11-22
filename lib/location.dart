import 'package:geolocator/geolocator.dart';

enum LocStatus { ok, denied, deniedForever, serviceOff, error }

class LocResult {
  final LocStatus status;
  final double lat, lon;
  const LocResult(this.status, [this.lat = 0, this.lon = 0]);
}

/// Where the device is. The position stays on the device: it is only used for local filtering.
abstract class LocationSource {
  Future<LocResult> locate();
  Future<void> openSettings(LocStatus why);
}

/// Trial builds only: `--dart-define=TEST_LOCATION=48.8566,2.3522` replaces the device position (e.g. Paris).
const _testLocation = String.fromEnvironment('TEST_LOCATION');

(double, double)? _testPosition() {
  final p = _testLocation.split(',');
  if (p.length != 2) return null;
  final la = double.tryParse(p[0].trim()), lo = double.tryParse(p[1].trim());
  return la == null || lo == null ? null : (la, lo);
}

/// Coarse (approximate) location only; no fine and no background access.
class DeviceLocation implements LocationSource {
  const DeviceLocation();

  @override
  Future<LocResult> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const LocResult(LocStatus.serviceOff);
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) return const LocResult(LocStatus.deniedForever);
      if (perm == LocationPermission.denied || perm == LocationPermission.unableToDetermine) return const LocResult(LocStatus.denied);
      final t = _testPosition();
      if (t != null) return LocResult(LocStatus.ok, t.$1, t.$2);
      final p =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
          );
      return LocResult(LocStatus.ok, p.latitude, p.longitude);
    } catch (_) {
      return const LocResult(LocStatus.error);
    }
  }

  @override
  Future<void> openSettings(LocStatus why) async {
    if (why == LocStatus.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
