import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

// ─── 비동기 상태 3종 공용 위젯 ─────────────────────────────────────────────
//
// 사용법:
//   if (isLoading) return const AsyncStateView.loading();
//   if (hasError)  return AsyncStateView.error(onRetry: _reload);
//   if (isEmpty)   return const AsyncStateView.empty(message: '아직 데이터가 없어요');
//

enum _AsyncStateType { loading, empty, error }

class AsyncStateView extends StatelessWidget {
  final _AsyncStateType _type;
  final String? message;
  final VoidCallback? onRetry;

  const AsyncStateView.loading({super.key})
    : _type = _AsyncStateType.loading,
      message = null,
      onRetry = null;

  const AsyncStateView.empty({super.key, this.message})
    : _type = _AsyncStateType.empty,
      onRetry = null;

  const AsyncStateView.error({super.key, this.message, this.onRetry})
    : _type = _AsyncStateType.error;

  @override
  Widget build(BuildContext context) {
    return switch (_type) {
      _AsyncStateType.loading => const _LoadingShimmer(),
      _AsyncStateType.empty => _EmptyState(message: message),
      _AsyncStateType.error => _ErrorState(message: message, onRetry: onRetry),
    };
  }
}

// ─── 로딩: 시머 ──────────────────────────────────────────────────────────
class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final shimmerColor = Color.lerp(
          context.appCard,
          context.appCardElevated,
          _animation.value,
        )!;
        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.screenPadding,
            vertical: AppTheme.spaceLG,
          ),
          itemCount: 4,
          separatorBuilder: (_, i) => const SizedBox(height: AppTheme.spaceMD),
          itemBuilder: (_, i) => _ShimmerCard(color: shimmerColor),
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final Color color;
  const _ShimmerCard({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      decoration: AppTheme.smoothBox(
        color: color,
        radius: AppTheme.radiusOuter,
        side: BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 줄
          Container(
            height: 14,
            width: double.infinity,
            decoration: AppTheme.smoothBox(
              color: context.appBorder,
              radius: AppTheme.radiusInner,
            ),
          ),
          const SizedBox(height: AppTheme.spaceSM),
          // 본문 줄 1
          Container(
            height: 12,
            width: MediaQuery.sizeOf(context).width * 0.75,
            decoration: AppTheme.smoothBox(
              color: context.appBorder,
              radius: AppTheme.radiusInner,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXS),
          // 본문 줄 2
          Container(
            height: 12,
            width: MediaQuery.sizeOf(context).width * 0.55,
            decoration: AppTheme.smoothBox(
              color: context.appBorder,
              radius: AppTheme.radiusInner,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 데이터 없음 ──────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final String? message;
  const _EmptyState({this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space3XL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 32,
                color: context.appTextTertiary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              message ?? '아직 데이터가 없어요',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 에러 + 재시도 ────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const _ErrorState({this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space3XL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 32,
                color: AppTheme.warningColor,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              message ?? '불러오는 중 오류가 발생했어요',
              textAlign: TextAlign.center,
              style: AppTheme.bodyMedium.copyWith(
                color: context.appTextSecondary,
                height: 1.5,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.space2XL),
              Semantics(
                label: '다시 시도',
                button: true,
                child: SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.space2XL,
                      ),
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.3),
                      shape: AppTheme.smoothShape(
                        radius: AppTheme.radiusOuter,
                        side: BorderSide.none,
                      ),
                    ),
                    child: Text(
                      '다시 시도',
                      style: AppTheme.bodySmall.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
