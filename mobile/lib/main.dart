import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://eudampfeempprbplgsfl.supabase.co',
    anonKey: 'sb_publishable_2BgyWzU1mTY5mzFWgqUAPA_X74zi-b1', // As we have Row Level Security enabled, these keys can be published safely
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
