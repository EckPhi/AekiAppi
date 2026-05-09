import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/scan_screen.dart';
import 'screens/unsupported_platform_screen.dart';
import 'services/scooter_service.dart';

/// Returns true on platforms where [flutter_blue_plus] has native BLE support:
/// Android, iOS, macOS, and Linux.
///
/// Web and Windows are not supported; those builds show
/// [UnsupportedPlatformScreen] instead.
bool get _isBleSupported {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;
}

void main() {
  runApp(const AekiAppi());
}

class AekiAppi extends StatelessWidget {
  const AekiAppi({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScooterService(),
      child: MaterialApp(
        title: 'AekiAppi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B1B2F),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: _isBleSupported
            ? const ScanScreen()
            : const UnsupportedPlatformScreen(),
      ),
    );
  }
}
