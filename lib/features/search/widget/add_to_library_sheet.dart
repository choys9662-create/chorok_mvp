import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/widgets/chorok_card.dart';
import '../../../shared/widgets/sheet_handle.dart';
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
    backgroundColor: context.appBg.withValues(alpha: 0),
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
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spaceMD,
          right: AppTheme.spaceMD,
          bottom: AppTheme.spaceMD,
        ),
        child: ChorokCard(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceXL,
            AppTheme.spaceMD,
            AppTheme.spaceXL,
            AppTheme.spaceLG,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ChorokSheetHandle(),
              const SizedBox(height: AppTheme.spaceXL),

              // 헤더
              Text(
                '서재에 추가',
                style: AppTheme.sectionTitle.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                book.title,
                style: AppTheme.rowText.copyWith(
                  color: context.appTextSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceXL),

              // 읽는 중
              _StatusTile(
                icon: Icons.auto_stories_rounded,
                label: '읽는 중',
                sublabel: '지금 이 책을 읽고 있어요',
                status: ReadingStatus.reading,
              ),
              const SizedBox(height: AppTheme.spaceMD),

              // 읽고 싶어요
              _StatusTile(
                icon: Icons.bookmark_rounded,
                label: '읽고 싶어요',
                sublabel: '나중에 읽을 책으로 저장할게요',
                status: ReadingStatus.wantToRead,
              ),
              const SizedBox(height: AppTheme.spaceMD),

              // 읽었어요
              _StatusTile(
                icon: Icons.check_circle_rounded,
                label: '읽었어요',
                sublabel: '이미 읽은 책으로 기록할게요',
                status: ReadingStatus.completed,
              ),
              const SizedBox(height: AppTheme.spaceLG),

              // 취소
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: context.appTextTertiary,
                    textStyle: AppTheme.rowText,
                  ),
                  child: const Text('취소'),
                ),
              ),
            ],
          ),
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
          child: SizedBox(
            height: 68,
            child: ChorokCard(
              inner: true,
              showBorder: false,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
              child: Row(
                children: [
                  // 아이콘 뱃지
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: ChorokCard(
                      inner: true,
                      showBorder: false,
                      padding: EdgeInsets.zero,
                      gradient: context.appReadingGradient,
                      child: Icon(
                        widget.icon,
                        color: AppTheme.darkBg,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceLG),

                  // 레이블
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: AppTheme.rowText.copyWith(
                            color: context.appTextPrimary,
                          ),
                        ),
                        Text(
                          widget.sublabel,
                          style: AppTheme.supportingText.copyWith(
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.appTextTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
