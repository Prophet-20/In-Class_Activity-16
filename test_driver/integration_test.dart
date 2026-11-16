import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await Directory('evidence/screenshots').create(recursive: true);
      await File('evidence/screenshots/$name.png').writeAsBytes(bytes);
      return true;
    },
    responseDataCallback: (data) async {
      if (data != null) {
        await File('evidence/device-results.json').writeAsString(
          const JsonEncoder.withIndent('  ')
              .convert(Map<String, dynamic>.from(data)..remove('screenshots')),
        );
      }
    },
  );
}
