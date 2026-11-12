import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_theme.dart';
import 'app_button.dart';
import 'pressable.dart';

const kGutter = 20.0;

/// Height reserved below tab-bar screens so content clears the floating tab bar.
const kTabBarClearance = 112.0;

SliverPadding gutterSliver(Widget sliver) => SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      sliver: sliver,
    );

SliverToBoxAdapter boxSliver(Widget child, {EdgeInsets? padding}) =>
    SliverToBoxAdapter(
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: kGutter),
        child: child,
      ),
    );

/// Page chrome: large title (tab roots) or back button + title (pushed pages), pull to
/// refresh, optional pinned bottom bar and extended floating action.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = false,
    this.actions = const [],
    required this.slivers,
    this.onRefresh,
    this.fab,
    this.bottomBar,
    this.hasTabBar = false,
    this.controller,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final Widget? fab;
  final Widget? bottomBar;
  final bool hasTabBar;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final bottomPad = hasTabBar ? kTabBarClearance : (fab != null ? 104.0 : 28.0);

    Widget scroll = CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            title: title,
            subtitle: subtitle,
            showBack: showBack,
            actions: actions,
          ),
        ),
        ...slivers,
        SliverToBoxAdapter(child: SizedBox(height: bottomPad)),
      ],
    );

    if (onRefresh != null) {
      scroll = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.brand600,
        backgroundColor: AppColors.surface,
        edgeOffset: 8,
        child: scroll,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(bottom: bottomBar == null && !hasTabBar, child: scroll),
      floatingActionButton: fab == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: hasTabBar ? 84 : 0),
              child: _FabEntrance(child: fab!),
            ),
      bottomNavigationBar: bottomBar == null
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(kGutter, 12, kGutter, 12),
                  child: bottomBar,
                ),
              ),
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.showBack,
    required this.actions,
  });

  final String title;
  final String? subtitle;
  final bool showBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: showBack ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: showBack ? textTheme.headlineSmall : textTheme.displaySmall,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(kGutter, 14, kGutter, 14),
      child: Row(
        crossAxisAlignment:
            showBack ? CrossAxisAlignment.center : CrossAxisAlignment.end,
        children: [
          if (showBack) ...[
            AppIconButton(
              icon: Icons.arrow_back_rounded,
              tooltip: 'Volver',
              onPressed: () {
                final router = GoRouter.of(context);
                if (router.canPop()) {
                  router.pop();
                } else {
                  router.go('/dashboard');
                }
              },
            ),
            const SizedBox(width: 14),
          ],
          Expanded(child: titleBlock),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 10),
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              actions[i],
            ],
          ],
        ],
      ),
    );
  }
}

class _FabEntrance extends StatelessWidget {
  const _FabEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: AppMotion.ease,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 24),
          child: Transform.scale(scale: 0.9 + 0.1 * value, child: child),
        ),
      ),
      child: child,
    );
  }
}

/// Extended pill floating action (primary header actions on the web).
class AppFab extends StatelessWidget {
  const AppFab({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      haptic: true,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.brand600,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59273F85),
              blurRadius: 24,
              spreadRadius: -4,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Urbanist',
                fontSize: 15,
                color: Colors.white,
              ).w(650),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uppercase section label (web `.section-title`).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.slate500),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Key/value line used in detail cards.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.valueStyle});

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.slate500),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: valueStyle ??
                  textTheme.bodyMedium?.copyWith(
                    color: AppColors.slate900,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sticky bar for a search box and quick filters under the page title.
class PinnedBar extends StatelessWidget {
  const PinnedBar({super.key, required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _PinnedBarDelegate(height: height, child: child),
    );
  }
}

class _PinnedBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedBarDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.page.withValues(alpha: overlaps ? 0.96 : 1),
        boxShadow: overlaps
            ? const [
                BoxShadow(
                  color: Color(0x14101A38),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_PinnedBarDelegate oldDelegate) =>
      oldDelegate.child != child || oldDelegate.height != height;
}
