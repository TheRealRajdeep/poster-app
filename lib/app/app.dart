import 'package:flutter/material.dart';

/// Root widget. Routing (2 tabs) and theme land here once the UI is
/// designed with the owner (see issues labelled `ui`).
class PosterApp extends StatelessWidget {
  const PosterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('poster-app'))),
    );
  }
}
