import 'package:geolocator/geolocator.dart';

class GeoException implements Exception {
  GeoException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// When-in-use position with GPS-off and timeout handling.
Future<Position> currentPosition({Duration timeout = const Duration(seconds: 12)}) async {
  final on = await Geolocator.isLocationServiceEnabled();
  if (!on) {
    throw GeoException('location_off');
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
    throw GeoException('location_denied');
  }
  return Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
  ).timeout(timeout);
}

String geoMessage(Object e, String lang) {
  final code = e is GeoException ? e.message : '';
  if (code == 'location_off') {
    return lang == 'ar' ? 'شغّلي خدمات الموقع من إعدادات الجهاز.' : 'Turn on Location Services in Settings.';
  }
  if (code == 'location_denied') {
    return lang == 'ar' ? 'محتاجين إذن الموقع عشان نكمّل.' : 'We need location permission to continue.';
  }
  return lang == 'ar' ? 'ما قدرناش نحدد موقعك. جرّبي تاني.' : 'We could not read your location. Try again.';
}
