import 'package:flutter/cupertino.dart';

import 'package:wood_cft/domain/app_info.dart';
import 'package:wood_cft/presentation/settings/app_shell.dart';
import 'package:wood_cft/presentation/theme/app_theme.dart';

/// Root widget for the Wood CFT app.
///
/// Builds the top-level [CupertinoApp] with the restrained neutral theme and
/// single accent, resolving the light or dark [CupertinoThemeData] from the
/// current platform brightness (Requirement 17.1, 17.7). Its home is the
/// [AppShell], which gates first-run setup and then presents the four bottom
/// tabs (Stock / Sell / Bills / Settings).
class WoodCftApp extends StatelessWidget {
  /// Creates the root app widget.
  const WoodCftApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.maybePlatformBrightnessOf(context);
    return CupertinoApp(
      title: kAppName,
      theme: AppTheme.forBrightness(brightness),
      home: const AppShell(),
    );
  }
}