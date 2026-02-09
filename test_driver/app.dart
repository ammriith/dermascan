import 'package:flutter_driver/driver_extension.dart';
import 'package:dermascan/main.dart' as app;

/// Entry point for Flutter Driver integration tests
/// 
/// This file enables the Flutter Driver extension and starts the app.
/// Run tests with: flutter drive --target=test_driver/app.dart
void main() {
  enableFlutterDriverExtension();
  app.main();
}
