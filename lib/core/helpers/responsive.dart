import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A custom extension to safely use flutter_screenutil on mobile, 
/// but fallback to standard logical pixels on Web and Desktop.
/// This prevents ultra-wide web screens from blowing up `.w` and `.sp` scales to 500%.
extension ResponsiveExtension on num {
  double get resW => (kIsWeb || _isDesktop) ? toDouble() : w;
  double get resH => (kIsWeb || _isDesktop) ? toDouble() : h;
  double get resSp => (kIsWeb || _isDesktop) ? toDouble() : sp;
  double get resR => (kIsWeb || _isDesktop) ? toDouble() : r;

  bool get _isDesktop => 
    defaultTargetPlatform == TargetPlatform.windows || 
    defaultTargetPlatform == TargetPlatform.macOS || 
    defaultTargetPlatform == TargetPlatform.linux;
}
