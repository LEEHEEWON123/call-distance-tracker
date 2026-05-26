import 'package:flutter/material.dart';

class WaitingScreen extends StatelessWidget {
  final String token;

  const WaitingScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('Waiting: $token')),
      );
}
