
import 'package:flutter/material.dart';

final Color primaryAccent = Color(0xFF00AEEF);

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: primaryAccent),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: primaryAccent, brightness: Brightness.dark),
  scaffoldBackgroundColor: Color(0xFF0F0F12),
  textTheme: TextTheme(bodyMedium: TextStyle(color: Colors.white70)),
);
