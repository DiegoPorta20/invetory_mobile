import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../models/models.dart';
import 'app_button.dart';
import 'reveal.dart';
import 'states.dart';

/// Loads a paginated endpoint page by page and exposes the accumulated items.
class PagedController<T> extends ChangeNotifier {
  PagedController({required this.fetch});

  final Future<PagedResult<T>> Function(int page) fetch;

  List<T> items = [];
  int total = 0;
  int _page = 0;
  bool loading = false;
  bool loadingMore = false;
  Object? error;
  Object? moreError;
  bool _disposed = false;
  int _generation = 0;
  final Map<Object, DateTime> _seen = {};

  bool get hasMore => items.length < total;
  bool get initialLoadDone => _page > 0 || error != null;

  /// First load or a filter change: clears the list and shows the skeleton.
  Future<void> reset() {
    items = [];
    total = 0;
    _page = 0;
    _seen.clear();
    return _load(keepItems: false);
  }

  /// Pull to refresh: keeps showing the current items until the new ones arrive.
  Future<void> refresh() => _load(keepItems: true);

  Future<void> _load({required bool keepItems}) async {
    final generation = ++_generation;
    loading = true;
    loadingMore = false;
    error = null;
    moreError = null;
    if (!keepItems) items = [];
    _notify();
    try {
      final result = await fetch(1);
      if (generation != _generation) return;
      items = result.items;
      total = result.total;
      _page = 1;
    } catch (e) {
      if (generation != _generation) return;
      error = e;
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || _page == 0) return;
    final generation = _generation;
    loadingMore = true;
    moreError = null;
    _notify();
    try {
      final result = await fetch(_page + 1);
      if (generation != _generation) return;
      items = [...items, ...result.items];
      total = result.total;
      _page += 1;
    } catch (e) {
      if (generation != _generation) return;
      moreError = e;
    } finally {
      if (generation == _generation) {
        loadingMore = false;
        _notify();
      }
    }
  }

  /// Items stay animated only during their first moments on screen.
  bool shouldReveal(Object key) {
    final first = _seen.putIfAbsent(key, DateTime.now);
    return DateTime.now().difference(first) < const Duration(milliseconds: 1400);
  }

  void removeWhere(bool Function(T item) test) {
    final before = items.length;
    items = items.where((item) => !test(item)).toList();
    total -= before - items.length;
    _notify();
  }

  void replaceWhere(bool Function(T item) test, T replacement) {
    items = [for (final item in items) test(item) ? replacement : item];
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Sliver that renders a [PagedController]: skeleton, error, empty, items and a footer loader.
class PagedSliver<T> extends StatelessWidget {
  const PagedSliver({
    super.key,
    required this.controller,
    required this.itemBuilder,
    required this.keyOf,
    required this.empty,
    this.skeletonCount = 6,
    this.skeletonHeight = 96,
    this.gap = 12,
  });

  final PagedController<T> controller;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Object Function(T item) keyOf;
  final Widget empty;
  final int skeletonCount;
  final double skeletonHeight;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final items = controller.items;

        if (items.isEmpty && (controller.loading || !controller.initialLoadDone)) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SkeletonList(count: skeletonCount, height: skeletonHeight),
            ),
          );
        }
        if (items.isEmpty && controller.error != null) {
          return SliverToBoxAdapter(
            child: ErrorState(
              message: errorText(controller.error, 'No se pudo cargar la lista.'),
              onRetry: controller.reset,
            ),
          );
        }
        if (items.isEmpty) return SliverToBoxAdapter(child: empty);

        final footer = controller.hasMore || controller.moreError != null ? 1 : 0;
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: items.length + footer,
            itemBuilder: (context, index) {
              if (index >= items.length) return _Footer(controller: controller);
              if (index >= items.length - 4) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => controller.loadMore());
              }
              final item = items[index];
              final key = keyOf(item);
              Widget child = Padding(
                padding: EdgeInsets.only(bottom: gap),
                child: itemBuilder(context, item, index),
              );
              if (controller.shouldReveal(key)) {
                child = Reveal(key: ValueKey(key), index: index, child: child);
              } else {
                child = KeyedSubtree(key: ValueKey(key), child: child);
              }
              return child;
            },
          ),
        );
      },
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.controller});

  final PagedController<dynamic> controller;

  @override
  Widget build(BuildContext context) {
    if (controller.moreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: AppButton(
            label: 'Reintentar',
            icon: Icons.refresh_rounded,
            small: true,
            variant: ButtonVariant.secondary,
            onPressed: controller.loadMore,
          ),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}
