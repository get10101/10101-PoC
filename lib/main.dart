import 'package:flutter/material.dart' hide Size;

export 'ffi.io.dart' if (dart.library.html) 'ffi.web.dart' show api;

void main() => runApp(const TenTenOneApp());

class TenTenOneApp extends StatelessWidget {
  const TenTenOneApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TenTenOne',
      theme: ThemeData(primarySwatch: Colors.teal),
    );
  }
}
