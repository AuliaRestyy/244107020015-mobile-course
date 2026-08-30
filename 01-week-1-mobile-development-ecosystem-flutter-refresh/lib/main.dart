import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Student Profile')),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children:[
            Icon(Icons.person, size: 80),
            SizedBox(height: 16),  
            Text('Aulia Resty Azizah ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('NIM: 244107020015', style: TextStyle(fontSize: 18)),
            SizedBox(height: 8),
            Text('D4 Teknik Informatika', style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Politeknik Negeri Malang', style: TextStyle(fontSize: 16)),
          ]),
        ),
      ),
    );
  }
}