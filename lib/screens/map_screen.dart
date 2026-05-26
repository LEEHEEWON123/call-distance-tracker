import 'package:flutter/material.dart';
import '../models/location_request.dart';

class MapScreen extends StatelessWidget {
  final LocationRequest locationRequest;

  const MapScreen({super.key, required this.locationRequest});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: Text('Map')),
      );
}
