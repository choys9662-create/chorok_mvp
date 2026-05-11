import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../features/timer/controller/timer_controller.dart';
import '../../shared/models/session_goal.dart';
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
    context.push(
      AppConstants.routeSession,
      extra: SessionExtra(
        bookId: '1',
        bookTitle: '채식주의자',
        bookAuthor: '한강',
        startPage: 186,
        totalPages: 300,
      ),
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
      elevation: 4,
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
    final color = isActive ? context.appPrimaryAccent : context.appTextTertiary;

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
                Icon(isActive ? activeIcon : icon, color: color, size: 24),
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

class _ForestOrbFab extends StatefulWidget {
  final bool isInSession;
  final VoidCallback onTap;

  const _ForestOrbFab({required this.isInSession, required this.onTap});

  @override
  State<_ForestOrbFab> createState() => _ForestOrbFabState();
}

class _ForestOrbFabState extends State<_ForestOrbFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimaryAccent;
    return Semantics(
      label: widget.isInSession ? '독서 이어하기' : '독서 시작',
      button: true,
      child: FloatingActionButton(
        onPressed: widget.onTap,
        backgroundColor: Colors.transparent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: const CircleBorder(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final t = _ctrl.value;
            final glow = 0.5 + 0.5 * sin(t * 2 * pi);
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.25, -0.3),
                  colors: [
                    accent.withValues(alpha: 0.85),
                    accent,
                    AppTheme.accent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28 + glow * 0.32),
                    blurRadius: 10 + glow * 18,
                    spreadRadius: glow * 3,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  _firefly(t, 0.00, 40.0, 12.0),
                  _firefly(t, 0.35, 8.0, 20.0),
                  _firefly(t, 0.68, 30.0, 44.0),
                  Center(
                    child: Icon(
                      Icons.timer_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _firefly(double t, double phase, double left, double top) {
    final alpha = (0.25 + 0.75 * sin((t + phase) * 2 * pi)).clamp(0.0, 1.0);
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 4,
        height: 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.fireflyColor.withValues(alpha: alpha),
          boxShadow: [
            BoxShadow(
              color: AppTheme.fireflyColor.withValues(alpha: alpha * 0.6),
              blurRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}
