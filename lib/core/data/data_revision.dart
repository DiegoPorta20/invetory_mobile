import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bumped after any write so list screens and the dashboard know to reload.
class DataRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final dataRevisionProvider =
    NotifierProvider<DataRevision, int>(DataRevision.new);
