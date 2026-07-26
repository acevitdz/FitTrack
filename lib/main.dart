import 'package:flutter/material.dart';

void main() {
  runApp(const FitTrackApp());
}

class FitTrackApp extends StatelessWidget {
  const FitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FitTrack',
      home: Scaffold(
        body: Center(child: Text('FitTrack project structure is ready.')),
      ),
    );
  }
}
