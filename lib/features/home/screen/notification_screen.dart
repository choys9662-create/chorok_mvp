import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/repositories/notification_repository.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;

// ─── 데이터 모델 ──────────────────────────────────────────────────────────

enum NotiType { follow, like, comment, overlap, system }

class NotiItem {
  final String? id; // 실데이터 알림 id (mock이면 null)
  final NotiType type;
  final String title;
  final String body;
  final String time;
  final bool isRead;

  const NotiItem({
    this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
  });

  NotiItem copyWith({bool? isRead}) => NotiItem(
    id: id,
    type: type,
    title: title,
    body: body,
    time: time,
    isRead: isRead ?? this.isRead,
  );
}

const _kNotifications = [
  NotiItem(
    type: NotiType.follow,
    title: 'reader_jin님이 팔로우를 신청했어요',
    body: '프로필을 확인하고 수락해보세요',
    time: '방금',
    isRead: false,
  ),
  NotiItem(
    type: NotiType.like,
    title: 'seoulreader님이 내 문장을 좋아해요',
    body: '"나는 채식주의자가 되기로 했다. 꿈 때문에."',
    time: '5분 전',
    isRead: false,
  ),
  NotiItem(
    type: NotiType.overlap,
    title: '내 문장을 3명이 함께 기록했어요',
    body: '"사람이 사람을 사랑한다는 것은..."',
    time: '12분 전',
    isRead: false,
  ),
  NotiItem(
    type: NotiType.follow,
    title: 'bookworm_su님이 팔로우를 신청했어요',
    body: '프로필을 확인하고 수락해보세요',
    time: '1시간 전',
    isRead: true,
  ),
  NotiItem(
    type: NotiType.like,
    title: 'minjae_reads님이 내 문장을 좋아해요',
    body: '"나는 괴물이 아니에요. 그냥 달라요."',
    time: '2시간 전',
    isRead: true,
  ),
  NotiItem(
    type: NotiType.system,
    title: '오늘 독서 목표까지 8분 남았어요',
    body: '조금만 더 읽으면 목표 달성이에요 🌿',
    time: '3시간 전',
    isRead: true,
  ),
];

// ─── 알림 화면 ────────────────────────────────────────────────────────────

class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  late List<NotiItem> _notifications = kUseMock
      ? List<NotiItem>.from(_kNotifications)
      : <NotiItem>[];
  bool _loading = !kUseMock;

  @override
  void initState() {
    super.initState();
    if (!kUseMock) _load();
  }

  /// 실데이터: 내 알림을 불러와 NotiItem으로 매핑.
  Future<void> _load() async {
    try {
      final list = await ref.read(notificationRepositoryProvider).fetch();
      if (!mounted) return;
      setState(() {
        _notifications = list.map(_toItem).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  NotiItem _toItem(AppNotification n) => NotiItem(
    id: n.id,
    type: _notiType(n.type),
    title: n.title,
    body: n.body,
    time: time_fmt.formatRelative(n.createdAt),
    isRead: n.isRead,
  );

  NotiType _notiType(NotificationType t) => switch (t) {
    NotificationType.follow => NotiType.follow,
    NotificationType.like => NotiType.like,
    NotificationType.comment => NotiType.comment,
    NotificationType.overlap => NotiType.overlap,
  };

  IconData _iconFor(NotiType type) => switch (type) {
    NotiType.follow => Icons.person_add_rounded,
    NotiType.like => Icons.favorite_rounded,
    NotiType.comment => Icons.chat_bubble_outline_rounded,
    NotiType.overlap => Icons.format_quote_rounded,
    NotiType.system => Icons.notifications_rounded,
  };

  Color _colorFor(NotiType type) => switch (type) {
    NotiType.follow => context.appAccentColor,
    NotiType.like => AppTheme.empathyColor,
    NotiType.comment => context.appPrimaryAccent,
    NotiType.overlap => context.appPrimaryAccent,
    NotiType.system => context.appTextSecondary,
  };

  void _markAllRead() {
    HapticFeedback.selectionClick();
    setState(() {
      _notifications.setAll(
        0,
        _notifications.map((n) => n.copyWith(isRead: true)),
      );
    });
    if (!kUseMock) {
      ref.read(notificationRepositoryProvider).markAllRead();
    }
  }

  void _markRead(int index) {
    final n = _notifications[index];
    setState(() {
      _notifications[index] = n.copyWith(isRead: true);
    });
    if (!kUseMock && n.id != null) {
      ref.read(notificationRepositoryProvider).markRead(n.id!);
    }
  }

  void _onNotiTap(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    _markRead(index);
    final n = _notifications[index];
    switch (n.type) {
      case NotiType.follow:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '프로필 페이지는 곧 지원돼요 🌿',
              style: AppTheme.bodySmall.copyWith(color: context.appTextPrimary),
            ),
            backgroundColor: context.appCardElevated,
            behavior: SnackBarBehavior.floating,
            shape: AppTheme.smoothShape(
              radius: 10,
              side: BorderSide.none,
            ),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            duration: const Duration(seconds: 2),
          ),
        );
      case NotiType.like:
      case NotiType.comment:
      case NotiType.overlap:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '문장 상세 페이지는 곧 지원돼요 🌿',
              style: AppTheme.bodySmall.copyWith(color: context.appTextPrimary),
            ),
            backgroundColor: context.appCardElevated,
            behavior: SnackBarBehavior.floating,
            shape: AppTheme.smoothShape(
              radius: 10,
              side: BorderSide.none,
            ),
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            duration: const Duration(seconds: 2),
          ),
        );
      case NotiType.system:
        // 시스템 알림은 읽음 처리만
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => !n.isRead).length;

    final topPad = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.appSurface,
      body: Column(
        children: [
          SizedBox(height: topPad),
          // ─── 앱바 ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 20, 0),
            child: Row(
              children: [
                // 뒤로가기
                Semantics(
                  label: '뒤로가기',
                  button: true,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: context.appTextPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                // 타이틀
                Text(
                  '알림',
                  style: AppTheme.headingLarge.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: AppTheme.smoothBox(
                      color: context.appPrimaryAccent.withValues(alpha: 0.15),
                      radius: 10,
                    ),
                    child: Text(
                      '$unread 새로운',
                      style: AppTheme.captionSmall.copyWith(
                        color: context.appPrimaryAccent,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // 모두 읽음
                if (unread > 0)
                  TextButton(
                    onPressed: _markAllRead,
                    child: Text(
                      '모두 읽음',
                      style: AppTheme.captionLarge.copyWith(
                        color: context.appTextTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ─── 알림 목록 (새로운 / 이전 그룹) ────────────────
          Expanded(
            child: Builder(
              builder: (context) {
                final newItems = _notifications
                    .asMap()
                    .entries
                    .where((e) => !e.value.isRead)
                    .toList();
                final oldItems = _notifications
                    .asMap()
                    .entries
                    .where((e) => e.value.isRead)
                    .toList();

                return CustomScrollView(
                  slivers: [
                    // 새로운 알림
                    if (newItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text(
                            '새로운',
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appPrimaryAccent,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((_, i) {
                          final entry = newItems[i];
                          final n = entry.value;
                          return _NotiTile(
                            item: n,
                            icon: _iconFor(n.type),
                            color: _colorFor(n.type),
                            onTap: () => _onNotiTap(context, entry.key),
                          );
                        }, childCount: newItems.length),
                      ),
                    ],

                    // 이전 알림
                    if (oldItems.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Text(
                            '이전',
                            style: AppTheme.captionLarge.copyWith(
                              color: context.appTextTertiary,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((_, i) {
                          final entry = oldItems[i];
                          final n = entry.value;
                          return _NotiTile(
                            item: n,
                            icon: _iconFor(n.type),
                            color: _colorFor(n.type),
                            onTap: () => _onNotiTap(context, entry.key),
                          );
                        }, childCount: oldItems.length),
                      ),
                    ],

                    // 알림 없음
                    if (newItems.isEmpty && oldItems.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: _loading
                              ? CircularProgressIndicator(
                                  color: context.appPrimaryAccent,
                                )
                              : Text(
                                  '알림이 없어요',
                                  style: TextStyle(
                                    color: context.appTextTertiary,
                                  ),
                                ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 알림 타일 ────────────────────────────────────────────────────────────

class _NotiTile extends StatelessWidget {
  final NotiItem item;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NotiTile({
    required this.item,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: item.isRead
            ? Colors.transparent
            : context.appPrimaryAccent.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 아이콘 배지
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: AppTheme.bodySmall.copyWith(
                      color: context.appTextPrimary,
                      fontWeight: item.isRead
                          ? FontWeight.w400
                          : FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextTertiary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.time,
                    style: AppTheme.captionSmall.copyWith(
                      color: context.appTextTertiary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            // 미읽음 dot
            if (!item.isRead)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.appPrimaryAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: context.appPrimaryAccent.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
