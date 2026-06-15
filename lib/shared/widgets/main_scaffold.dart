import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../features/timer/controller/timer_controller.dart';
import '../../features/timer/widget/book_picker_sheet.dart';
import '../providers/tab_scroll_controllers.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  Future<void> _handleOrbTap(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final timer = ref.read(timerProvider);
    if (!timer.isIdle) {
      context.push(AppConstants.routeSession);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const BookPickerSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scrollCtrls = ref.read(tabScrollControllersProvider);
    final isInSession = !ref.watch(timerProvider).isIdle;

    void onNavTap(int index) {
      HapticFeedback.selectionClick();
      if (index == navigationShell.currentIndex) {
        scrollCtrls.scrollToTop(index);
      }
      navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      );
    }

    return Scaffold(
      body: navigationShell,
      floatingActionButtonLocation: const _OrbDockedLocation(),
      floatingActionButton: _ForestOrbFab(
        isInSession: isInSession,
        onTap: () => _handleOrbTap(context, ref),
      ),
      bottomNavigationBar: _ChorokBottomBar(
        currentIndex: navigationShell.currentIndex,
        onTap: onNavTap,
      ),
    );
  }
}

// ─── 오브 FAB 위치 — 하단 바에 묻히지 않도록 살짝 위로 올린다 ───────────────────

class _OrbDockedLocation extends FloatingActionButtonLocation {
  const _OrbDockedLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    final w = scaffoldGeometry.scaffoldSize.width;
    final h = scaffoldGeometry.scaffoldSize.height;
    return Offset((w - fabSize.width) / 2.0, h - 44 - fabSize.height);
  }
}

// ─── 하단 네비게이션 바 ────────────────────────────────────────────────────────

class _ChorokBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ChorokBottomBar({required this.currentIndex, required this.onTap});

  static const double _centerOrbGap = 104;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        color: context.appSurface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.22),
        elevation: 10,
        height: 92,
        padding: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: '홈',
                      index: 0,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                    _NavItem(
                      icon: Icons.search_rounded,
                      activeIcon: Icons.search_rounded,
                      label: '검색',
                      index: 1,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: _centerOrbGap),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.auto_stories_outlined,
                      activeIcon: Icons.auto_stories,
                      label: '피드',
                      index: 2,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                    _NavItem(
                      icon: Icons.menu_book_outlined,
                      activeIcon: Icons.menu_book_rounded,
                      label: '서재',
                      index: 3,
                      currentIndex: currentIndex,
                      onTap: onTap,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == currentIndex;
    final color = isActive
        ? context.appPrimaryAccent
        : context.appTextSecondary;

    return SizedBox(
      width: 64,
      child: Semantics(
        label: label,
        button: true,
        selected: isActive,
        child: GestureDetector(
          onTap: () => onTap(index),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 34,
                  height: 24,
                  decoration: AppTheme.smoothPill(
                    color: isActive
                        ? context.appPrimaryAccent.withValues(alpha: 0.14)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: color,
                    size: 21,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 반딧불 오브 FAB ──────────────────────────────────────────────────────────

class _ForestOrbFab extends StatelessWidget {
  final bool isInSession;
  final VoidCallback onTap;

  const _ForestOrbFab({required this.isInSession, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimaryAccent;
    return Semantics(
      label: isInSession ? '독서 이어하기' : '독서 시작',
      button: true,
      child: SizedBox(
        width: 62,
        height: 62,
        child: FloatingActionButton(
          onPressed: onTap,
          backgroundColor: Colors.transparent,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          shape: const CircleBorder(),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.34),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isInSession ? Icons.play_arrow_rounded : Icons.timer_rounded,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.black
                    : Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
