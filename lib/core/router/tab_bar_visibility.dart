import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screens set this while they show their own bottom bar (e.g. multi-selection).
class TabBarHidden extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool hidden) {
    if (state != hidden) state = hidden;
  }
}

final tabBarHiddenProvider =
    NotifierProvider<TabBarHidden, bool>(TabBarHidden.new);
