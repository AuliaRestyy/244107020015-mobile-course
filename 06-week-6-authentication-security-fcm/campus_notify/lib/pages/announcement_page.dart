import 'package:flutter/material.dart';

class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Pengumuman #$id')),
    body: Center(child: Text('Deep link masuk ke /pengumuman/$id')),
  );
}
