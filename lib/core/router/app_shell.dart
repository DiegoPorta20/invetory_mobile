import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/client_config.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_theme.dart';
import 'tab_bar_visibility.dart';

class _TabSpec {
  const _TabSpec(this.label, this.icon, this.activeIcon, [this.module]);
  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// The module that must be usable for this tab to appear; null means always shown.
  final String? module;
}

const _tabs = [
  _TabSpec('Panel', Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'dashboard'),
  _TabSpec('Productos', Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'products'),
  _TabSpec('Movimientos', Icons.swap_horiz_rounded, Icons.swap_horiz_rounded, 'movements'),
  _TabSpec('Conteos', Icons.fact_check_outlined, Icons.fact_check_rounded, 'counts'),
  _TabSpec('Más', Icons.grid_view_outlined, Icons.grid_view_rounded),
];

/// Branch indexes of the tabs this user may open ("More" is always there).
List<int> _visibleTabs(ClientConfig? config) => [
      for (var i = 0; i < _tabs.length; i++)
        if (_tabs[i].module == null || (config?.allows(_tabs[i].module!) ?? false)) i,
    ];

/// Tab container: cross-fades branches and floats the dark tab bar over them.
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hideBar = MediaQuery.viewInsetsOf(context).bottom > 0 ||
        ref.watch(tabBarHiddenProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final visible = _visibleTabs(ref.watch(clientConfigProvider));
    final home = visible.first;

    return PopScope(
      // Back from any other tab returns to the first tab first, like most tabbed apps.
      canPop: navigationShell.currentIndex == home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !ref.read(tabBarHiddenProvider)) navigationShell.goBranch(home);
      },
      child: Scaffold(
        backgroundColor: AppColors.page,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  for (var i = 0; i < children.length; i++)
                    _BranchPage(
                      key: ValueKey(i),
                      active: i == navigationShell.currentIndex,
                      child: children[i],
                    ),
                ],
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: bottom + 12,
              child: AnimatedSlide(
                duration: AppMotion.normal,
                curve: AppMotion.ease,
                offset: hideBar ? const Offset(0, 1.6) : Offset.zero,
                child: AnimatedOpacity(
                  duration: AppMotion.fast,
                  opacity: hideBar ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: hideBar,
                    child: _FloatingTabBar(
                      index: navigationShell.currentIndex,
                      visible: visible,
                      onSelected: (index) => navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchPage extends StatefulWidget {
  const _BranchPage({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_BranchPage> createState() => _BranchPageState();
}

class _BranchPageState extends State<_BranchPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: widget.active ? 1 : 0,
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: AppMotion.ease);

  @override
  void didUpdateWidget(_BranchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      widget.active ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final visible = widget.active || _controller.value > 0;
        return Offstage(
          offstage: !visible,
          child: TickerMode(
            enabled: visible,
            child: IgnorePointer(
              ignoring: !widget.active,
              child: Opacity(
                opacity: _curve.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - _curve.value) * 10),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.index,
    required this.visible,
    required this.onSelected,
  });

  final int index;
  final List<int> visible;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.brand900,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99081026),
            blurRadius: 40,
            spreadRadius: -12,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / visible.length;
          final position = visible.indexOf(index).clamp(0, visible.length - 1);
          return Stack(
            children: [
              // A single pill slides behind the active item (web `.nav-pill`).
              AnimatedPositioned(
                duration: const Duration(milliseconds: 520),
                curve: AppMotion.ease,
                left: width * position,
                width: width,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.brand100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final i in visible)
                    Expanded(
                      child: _TabItem(
                        spec: _tabs[i],
                        selected: i == index,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onSelected(i);
                        },
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand900 : AppColors.sideDim;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1,
              duration: AppMotion.normal,
              curve: AppMotion.ease,
              child: Icon(
                selected ? spec.activeIcon : spec.icon,
                size: 23,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: AppMotion.normal,
              curve: AppMotion.ease,
              style: TextStyle(
                fontFamily: 'Urbanist',
                fontSize: 10.5,
                color: color,
              ).w(selected ? 700 : 600),
              child: Text(spec.label, maxLines: 1, overflow: TextOverflow.fade),
            ),
          ],
        ),
      ),
    );
  }
}
