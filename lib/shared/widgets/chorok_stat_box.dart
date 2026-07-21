import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'chorok_card.dart';

/// 작은 통계 박스 — 라벨(위) + 숫자(아래), 가운데 정렬.
///
/// 화면 배경 위에 직접 놓이므로 바깥 박스 규칙을 따라 모서리는 10이다(design.md §5).
/// 곡률은 박스 크기가 아니라 중첩 위치로 정한다 — 작다고 6을 쓰지 않는다.
///
/// 값을 강조하는 [ChorokStatCell]과는 다르다. 그쪽은 박스 없이 숫자가 먼저 오고
/// 왼쪽 정렬이며, 이쪽은 박스 안에 라벨이 먼저 오고 가운데 정렬이다.
class ChorokStatBox extends StatelessWidget {
  final String label;
  final String value;

  /// 강조가 필요할 때만 지정한다. 기본은 본문 색이다.
  final Color? valueColor;

  const ChorokStatBox({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
  });

  /// 여러 개를 가로로 나열한다. 칸 나눔과 사이 간격을 이 함수가 책임진다
  /// — 호출부가 SizedBox로 간격을 박지 않게 하기 위함이다(design.md §4).
  static Widget row(List<ChorokStatBox> boxes) => Row(
    spacing: AppTheme.spaceSM,
    children: [for (final box in boxes) Expanded(child: box)],
  );

  @override
  Widget build(BuildContext context) {
    return ChorokCard(
      showBorder: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXS,
        vertical: AppTheme.spaceSM,
      ),
      child: Column(
        spacing: AppTheme.spaceSM,
        children: [
          Text(
            label,
            style: AppTheme.caption.copyWith(color: context.appTextTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            value,
            style: AppTheme.sectionTitle.copyWith(
              color: valueColor ?? context.appTextPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
