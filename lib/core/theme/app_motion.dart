import 'package:flutter/animation.dart';

/// One easing everywhere, same as the web `--ease`.
abstract final class AppMotion {
  static const ease = Cubic(0.2, 0.8, 0.2, 1);

  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const page = Duration(milliseconds: 380);
}
