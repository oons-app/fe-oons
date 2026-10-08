import 'dart:io';

/// OS version reported by a phone or desktop build (`Version 18.1 …`).
String deviceOsLabel() {
  final v = Platform.operatingSystemVersion.trim();
  if (v.length > 80) return v.substring(0, 80);
  return v;
}
