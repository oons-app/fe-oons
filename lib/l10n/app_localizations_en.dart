// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Oons';

  @override
  String get amana => 'Amana';

  @override
  String get escrowHeld => 'Held in escrow';

  @override
  String get timelineBooked => 'Booked';

  @override
  String get timelineConfirmed => 'Confirmed';

  @override
  String get timelineOnTheWay => 'On the way';

  @override
  String get timelineCheckedIn => 'Checked in';

  @override
  String get timelineCheckedOut => 'Checked out';
}
