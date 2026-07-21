import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 섹션 헤더 — 제목 + 선택적 부제 + 개수 + 오른쪽 액션.
///
/// 개수와 액션은 자리가 정해져 있다. 개수는 "이 섹션에 몇 개가 있다"는 제목의
/// 일부이므로 제목 바로 옆에 붙고, 액션(추가·전체보기)은 조작이므로 오른쪽 끝에 간다.
/// 호출부가 자리를 고를 수 없게 해서 화면마다 배치가 갈리는 것을 막는다.
class ChorokSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// 제목 바로 옆에 붙는 개수. 정보이므로 오른쪽으로 보내지 않는다.
  final int? count;

  /// 오른쪽 끝 액션. 추가 버튼·전체보기처럼 누를 수 있는 것만 넣는다.
  final Widget? trailing;

  /// 현재 진행 중인 독서처럼 활성 상태를 나타낼 때만 쓰는 제목 색상이다.
  final Color? titleColor;

  const ChorokSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.count,
    this.trailing,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.sectionTitle.copyWith(
            color: titleColor ?? context.appTextPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppTheme.spaceXS),
          Text(
            subtitle!,
            style: AppTheme.supportingText.copyWith(
              color: context.appTextSecondary,
            ),
          ),
        ],
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 제목+개수가 남는 폭을 모두 차지해 trailing을 오른쪽 끝으로 민다.
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(fit: FlexFit.loose, child: titleBlock),
              if (count != null) ...[
                const SizedBox(width: AppTheme.spaceSM),
                Text(
                  '$count',
                  style: AppTheme.sectionTitle.copyWith(
                    color: context.appPrimaryAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppTheme.spaceSM),
          trailing!,
        ],
      ],
    );
  }
}
