import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_flags.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/db_service.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/repositories/notification_repository.dart';
import '../../../shared/repositories/profile_repository.dart';
import '../../../shared/utils/time_format.dart' as time_fmt;
import '../../feed/screen/sentence_detail_screen.dart';
import '../../../shared/widgets/chorok_refresh.dart';

// ─── 데이터 모델 ──────────────────────────────────────────────────────────

enum NotiType { follow, like, comment, overlap, system }

class NotiItem {
  final String? id; // 실데이터 알림 id (mock이면 null)
  final String? actorId; // 알림을 일으킨 유저 id (mock이면 null)
  final String? sentenceId; // 연결된 문장 id (like/comment/overlap)
  final NotiType type;
  final String title;
  final String body;
  final String time;
  final bool isRead;

  const NotiItem({
    this.id,
    this.actorId,
    this.sentenceId,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
  });

  NotiItem copyWith({bool? isRead}) => NotiItem(
    id: id,
    actorId: actorId,
    sentenceId: sentenceId,
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
    actorId: n.actorId,
    sentenceId: n.sentenceId,
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
        if (n.actorId != null) {
          _openProfile(n.actorId!);
        } else {
          _showToast('프로필 페이지는 곧 지원돼요 🌿');
        }
      case NotiType.like:
      case NotiType.comment:
      case NotiType.overlap:
        if (n.sentenceId != null) {
          _openSentence(n.sentenceId!);
        } else {
          _showToast('문장을 찾을 수 없어요');
        }
      case NotiType.system:
        // 시스템 알림은 읽음 처리만
        break;
    }
  }

  /// 팔로우 알림 → 해당 유저 프로필로 이동.
  /// 알림은 actorId만 들고 있어, 프로필 화면이 요구하는 UserProfile을 먼저 조회한다.
  bool _openingProfile = false;
  Future<void> _openProfile(String userId) async {
    if (_openingProfile) return;
    _openingProfile = true;
    try {
      final profile = await ref.read(profileRepositoryProvider).getById(userId);
      if (!mounted) return;
      if (profile == null) {
        _showToast('프로필을 찾을 수 없어요');
        return;
      }
      context.push(AppConstants.routeUserProfile, extra: profile);
    } catch (_) {
      if (mounted) _showToast('프로필을 불러오지 못했어요');
    } finally {
      _openingProfile = false;
    }
  }

  /// 좋아요·생각·겹문장 알림 → 해당 문장 상세로 이동.
  /// 알림은 sentenceId만 들고 있어, 화면이 요구하는 본문·책 정보를 먼저 조회한다.
  bool _openingSentence = false;
  Future<void> _openSentence(String sentenceId) async {
    if (_openingSentence) return;
    _openingSentence = true;
    try {
      final row = await ref
          .read(dbServiceProvider)
          .fetchSentenceDetailById(sentenceId);
      if (!mounted) return;
      if (row == null) {
        _showToast('문장을 찾을 수 없어요');
        return;
      }
      context.push(
        AppConstants.routeSentenceDetail,
        extra: SentenceDetailExtra(
          sentenceContent: row['content'] as String? ?? '',
          bookTitle: row['book_title'] as String? ?? '알 수 없는 책',
          bookAuthor: row['book_author'] as String? ?? '',
          collectorUsername: row['username'] as String?,
          collectorUserHandle: row['handle'] as String?,
          collectorThought: row['thought'] as String?,
          sentenceId: sentenceId,
        ),
      );
    } catch (_) {
      if (mounted) _showToast('문장을 불러오지 못했어요');
    } finally {
      _openingSentence = false;
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.bodySmall.copyWith(color: context.appTextPrimary),
        ),
        backgroundColor: context.appCardElevated,
        behavior: SnackBarBehavior.floating,
        shape: AppTheme.smoothShape(
          radius: AppTheme.radiusOuter,
          side: BorderSide.none,
        ),
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        duration: const Duration(seconds: 2),
      ),
    );
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
                  const SizedBox(width: AppTheme.spaceSM),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceSM,
                      vertical: AppTheme.spaceXS,
                    ),
                    decoration: AppTheme.smoothBox(
                      color: context.appPrimaryAccent.withValues(alpha: 0.15),
                      radius: AppTheme.radiusOuter,
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
          const SizedBox(height: AppTheme.spaceSM),

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

                return ChorokRefresh(
                  onRefresh: _load,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                  ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: AppTheme.spaceLG,
        ),
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
            const SizedBox(width: AppTheme.spaceMD),
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppTheme.spaceXS,
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
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.captionLarge.copyWith(
                      color: context.appTextTertiary,
                      height: 1.5,
                    ),
                  ),
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
