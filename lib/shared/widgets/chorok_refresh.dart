import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 당겨서 새로고침 공통 래퍼. 색만 앱 토큰으로 맞춘 [RefreshIndicator] 다.
///
/// [edgeOffset] 은 인디케이터가 나타나는 위치를 화면 위에서부터 얼마나 내릴지다.
/// - 스크롤 뷰 위에 헤더/앱바가 있으면 0 (기본값) — 헤더 바로 아래에 뜬다.
/// - 스크롤 뷰가 화면 최상단까지 차오르면 `MediaQuery.paddingOf(context).top`
///   을 넘겨 다이나믹 아일랜드·노치 아래로 내린다. iOS 가 기기별 실제 인셋을
///   주므로 기종별 하드코딩은 필요 없다.
///
/// child 스크롤 뷰에는 `physics: AlwaysScrollableScrollPhysics()` 가 있어야
/// 내용이 짧을 때도 당길 수 있다.
class ChorokRefresh extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double edgeOffset;

  const ChorokRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.edgeOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: context.appPrimaryAccent,
      backgroundColor: context.appCard,
      edgeOffset: edgeOffset,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
