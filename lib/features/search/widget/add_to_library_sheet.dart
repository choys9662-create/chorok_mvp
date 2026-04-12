import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../model/aladin_book.dart';

/// 서재 추가 바텀 시트 표시 헬퍼
///
/// 반환값: ReadingStatus? (사용자가 취소하면 null)
Future<ReadingStatus?> showAddToLibrarySheet(
  BuildContext context,
  AladinBook book,
) {
  return showModalBottomSheet<ReadingStatus>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _AddToLibrarySheet(book: book),
  );
}

class _AddToLibrarySheet extends StatelessWidget {
  final AladinBook book;

  const _AddToLibrarySheet({required this.book});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: AppTheme.smoothBox(
          color: AppTheme.darkCard,
          radius: AppTheme.radiusXL,
          side: BorderSide(
            color: AppTheme.darkBorder,
            width: 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 드래그 핸들
            Container(
              width: 36,
              height: 4,
              decoration: const ShapeDecoration(
                color: AppTheme.textTertiary,
                shape: StadiumBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // 헤더
            const Text(
              '서재에 추가',
              style: TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              book.title,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 읽는 중
            _StatusTile(
              icon: Icons.auto_stories_rounded,
              label: '읽는 중',
              sublabel: '지금 이 책을 읽고 있어요',
              status: ReadingStatus.reading,
            ),
            const SizedBox(height: 12),

            // 읽고 싶어요
            _StatusTile(
              icon: Icons.bookmark_rounded,
              label: '읽고 싶어요',
              sublabel: '나중에 읽을 책으로 저장할게요',
              status: ReadingStatus.wantToRead,
            ),
            const SizedBox(height: 16),

            // 취소
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textTertiary,
                  textStyle: const TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('취소'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 상태 선택 타일 ──────────────────────────────────────────────────────────

class _StatusTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final ReadingStatus status;

  const _StatusTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.status,
  });

  @override
  State<_StatusTile> createState() => _StatusTileState();
}

class _StatusTileState extends State<_StatusTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          HapticFeedback.mediumImpact();
          Navigator.of(context).pop(widget.status);
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: AppTheme.smoothBox(
              color: AppTheme.darkCardElevated,
              radius: AppTheme.radiusMD,
              side: BorderSide(
                color: AppTheme.darkBorder,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // 아이콘 뱃지
                Container(
                  width: 40,
                  height: 40,
                  decoration: AppTheme.smoothBox(
                    gradient: AppTheme.greenGradient,
                    radius: AppTheme.radiusSM,
                  ),
                  child: Icon(widget.icon, color: AppTheme.darkBg, size: 20),
                ),
                const SizedBox(width: 16),

                // 레이블
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                          height: 1.4,
                        ),
                      ),
                      Text(
                        widget.sublabel,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
