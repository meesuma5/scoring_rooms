import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget wrapWithApp(Widget child) {
  return ProviderScope(child: MaterialApp(home: child));
}
