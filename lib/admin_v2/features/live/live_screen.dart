import 'package:flutter/material.dart';
import 'package:oons/admin_v2/features/bookings/bookings_screen.dart';

class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BookingsScreen(live: true);
  }
}
