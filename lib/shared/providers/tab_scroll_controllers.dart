import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 탭별 스크롤 컨트롤러 — 같은 탭 재탭 시 상단 복귀에 사용
/// index: 0=홈, 1=피드, 2=분석, 3=서재(그리드), 4=서재(캘린더)
final tabScrollControllersProvider = Provider<TabScrollControllers>((ref) {
  final c = TabScrollControllers();
  ref.onDispose(c.dispose);
  return c;
});

class TabScrollControllers {
  final List<ScrollController> _ctrls =
      List.generate(5, (_) => ScrollController());

  ScrollController operator [](int index) => _ctrls[index];

  /// tabIndex: 네비게이션 탭 인덱스 (0~3)
  /// 서재(3)는 그리드·캘린더 두 스크롤뷰를 모두 처리
  void scrollToTop(int tabIndex) {
    void animate(ScrollController c) {
      if (c.hasClients && c.offset > 0) {
        c.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    }

    if (tabIndex == 3) {
      animate(_ctrls[3]);
      animate(_ctrls[4]);
    } else {
      animate(_ctrls[tabIndex]);
    }
  }

  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
  }
}
