import 'package:flutter/material.dart';

/// Full-screen, zoomable photo (e.g. the picture of a scanned paper card).
class PhotoScreen extends StatelessWidget {
  const PhotoScreen({super.key, required this.image});
  final ImageProvider image;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: InteractiveViewer(
      maxScale: 5,
      child: Center(child: Image(image: image)),
    ),
  );
}
