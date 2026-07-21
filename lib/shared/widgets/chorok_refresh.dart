import 'package:flutter/cupertino.dart';
import '../../core/theme/app_theme.dart';

/// 홈과 같은 스크롤 영역 점유형 새로고침 컨트롤.
///
/// 화면 상단 헤더가 있으면 헤더는 [CustomScrollView] 밖에 고정하고, 이
/// 컨트롤은 그 아래 콘텐츠 스크롤의 첫 sliver로 둔다.
///
/// 새로고침 [Future]가 끝날 때까지 자신의 높이를 유지하므로, 인디케이터가
/// 본문과 겹치지 않고 완료된 뒤에만 화면이 제자리로 돌아간다.
class ChorokSliverRefreshControl extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const ChorokSliverRefreshControl({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return CupertinoSliverRefreshControl(
      builder: _buildIndicator,
      onRefresh: onRefresh,
    );
  }

  static Widget _buildIndicator(
    BuildContext context,
    RefreshIndicatorMode refreshState,
    double pulledExtent,
    double refreshTriggerPullDistance,
    double refreshIndicatorExtent,
  ) {
    final progress = (pulledExtent / refreshTriggerPullDistance).clamp(
      0.0,
      1.0,
    );
    final indicator = switch (refreshState) {
      RefreshIndicatorMode.drag => CupertinoActivityIndicator.partiallyRevealed(
        color: context.appPrimaryAccent,
        radius: AppTheme.spaceMD,
        progress: progress,
      ),
      RefreshIndicatorMode.armed ||
      RefreshIndicatorMode.refresh => CupertinoActivityIndicator(
        color: context.appPrimaryAccent,
        radius: AppTheme.spaceMD,
      ),
      RefreshIndicatorMode.done => Transform.scale(
        scale: progress,
        child: CupertinoActivityIndicator(
          color: context.appPrimaryAccent,
          radius: AppTheme.spaceMD,
        ),
      ),
      RefreshIndicatorMode.inactive => const SizedBox.shrink(),
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceLG),
        child: indicator,
      ),
    );
  }
}
