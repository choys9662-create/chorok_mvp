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

// ─── 오브 FAB 위치 — centerDocked보다 12px 낮게 (네비바에 더 눌려있는 느낌) ───────

class _OrbDockedLocation extends FloatingActionButtonLocation {
  const _OrbDockedLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final fabSize = scaffoldGeometry.floatingActionButtonSize;
    return Offset(
      (scaffoldGeometry.scaffoldSize.width - fabSize.width) / 2.0,
      scaffoldGeometry.contentBottom - fabSize.height / 2.0 + 12.0,
    );
  }
}

// ─── 하단 네비게이션 바 ────────────────────────────────────────────────────────

class _ChorokBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _ChorokBottomBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: context.appSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.black.withValues(alpha: 0.22),
      elevation: 10,
      child: Row(
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
            icon: Icons.auto_stories_outlined,
            activeIcon: Icons.auto_stories,
            label: '피드',
            index: 1,
            currentIndex: currentIndex,
            onTap: onTap,
          ),
          const Spacer(),
          _NavItem(
            icon: Icons.bar_chart_outlined,
            activeIcon: Icons.bar_chart_rounded,
            label: '분석',
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

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: isActive,
        child: InkWell(
          onTap: () => onTap(index),
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          child: SizedBox(
            height: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: 36,
                  height: 26,
                  decoration: AppTheme.smoothPill(
                    color: isActive
                        ? context.appPrimaryAccent.withValues(alpha: 0.14)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
      child: FloatingActionButton(
        onPressed: onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent, accent],
            ),
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
    );
  }
}
