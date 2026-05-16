# 겹문장 매칭 및 교류 시스템 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 같은 문장을 수집한 유저들을 Supabase 정규화 exact-match로 찾아내고, 그 문장에 대한 서로 다른 생각을 SentenceDetailScreen에서 나란히 보여준다.

**Architecture:** 텍스트 정규화(`SentenceNormalizer`) → Supabase `sentences` 테이블에 `normalized_sentences TEXT[]` + `thought TEXT` 컬럼 추가 → `DbService.findOverlappingSentences()` 쿼리 → Riverpod provider → `SplitHighlightWidget` UI.

**Tech Stack:** Flutter 3.x, Riverpod 2.6.1, Supabase Flutter 2.8.4, sqflite (로컬), flutter_test

---

## 파일 구조

| 파일 | 상태 | 역할 |
|------|------|------|
| `lib/shared/utils/sentence_normalizer.dart` | 신규 | 토크나이저 + 정규화 유틸리티 |
| `lib/shared/models/sentence_record.dart` | 신규 | Supabase sentences row Dart 모델 |
| `supabase/migrations/20260514000000_add_normalized_sentences.sql` | 신규 | DB 마이그레이션 |
| `lib/features/feed/controller/overlap_provider.dart` | 신규 | OverlapMatch 모델 + Riverpod provider |
| `lib/features/feed/widget/split_highlight_widget.dart` | 신규 | 겹문장 UI 위젯 |
| `lib/core/services/db_service.dart` | 수정 | `saveSession()` 수정, `findOverlappingSentences()` 추가 |
| `lib/features/home/screen/session_recap_screen.dart` | 수정 | 세션 종료 시 Supabase 비동기 업로드 추가 |
| `lib/features/feed/screen/sentence_detail_screen.dart` | 수정 | `ConsumerStatefulWidget`으로 변환, 겹문장 섹션 추가 |
| `test/shared/utils/sentence_normalizer_test.dart` | 신규 | 정규화 유틸 단위 테스트 |

---

## Task 1: SentenceNormalizer 유틸리티

**Files:**
- Create: `lib/shared/utils/sentence_normalizer.dart`
- Create: `test/shared/utils/sentence_normalizer_test.dart`

- [ ] **Step 1: 테스트 파일 작성**

`test/shared/utils/sentence_normalizer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:chorok_app/shared/utils/sentence_normalizer.dart';

void main() {
  group('SentenceNormalizer.tokenize', () {
    test('마침표로 분리', () {
      expect(
        SentenceNormalizer.tokenize('첫 번째 문장. 두 번째 문장.'),
        ['첫 번째 문장', '두 번째 문장'],
      );
    });

    test('느낌표·물음표로 분리', () {
      expect(
        SentenceNormalizer.tokenize('놀랍다! 정말? 그렇구나.'),
        ['놀랍다', '정말', '그렇구나'],
      );
    });

    test('줄바꿈으로 분리', () {
      expect(
        SentenceNormalizer.tokenize('첫 줄\n둘째 줄'),
        ['첫 줄', '둘째 줄'],
      );
    });

    test('연속 구분자 중복 토큰 없음', () {
      expect(
        SentenceNormalizer.tokenize('문장!? 다음 문장.'),
        ['문장', '다음 문장'],
      );
    });

    test('빈 문자열 → 빈 배열', () {
      expect(SentenceNormalizer.tokenize(''), isEmpty);
    });
  });

  group('SentenceNormalizer.normalize', () {
    test('공백 제거', () {
      expect(SentenceNormalizer.normalize('나도 너를 사랑해'), '나도너를사랑해');
    });

    test('쉼표·특수문자 제거', () {
      expect(SentenceNormalizer.normalize('나도, 너를 사랑 해'), '나도너를사랑해');
    });

    test('영문 소문자 변환', () {
      expect(SentenceNormalizer.normalize('Hello World'), 'helloworld');
    });

    test('한영 혼합', () {
      expect(SentenceNormalizer.normalize('Hello 세계!'), 'hello세계');
    });

    test('빈 문자열', () {
      expect(SentenceNormalizer.normalize(''), '');
    });
  });

  group('SentenceNormalizer.tokenizeAndNormalize', () {
    test('전체 파이프라인', () {
      expect(
        SentenceNormalizer.tokenizeAndNormalize('나도, 너를 사랑해. 정말이야!'),
        ['나도너를사랑해', '정말이야'],
      );
    });

    test('정규화 후 빈 토큰 제거', () {
      expect(
        SentenceNormalizer.tokenizeAndNormalize('!!! ...'),
        isEmpty,
      );
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 — FAIL 확인**

```bash
cd /Users/joyongseong/Documents/dev/chorok_app
flutter test test/shared/utils/sentence_normalizer_test.dart
```

Expected: `Error: target not found` 또는 `import` 오류

- [ ] **Step 3: SentenceNormalizer 구현**

`lib/shared/utils/sentence_normalizer.dart`:

```dart
class SentenceNormalizer {
  SentenceNormalizer._();

  /// 마침표, 느낌표, 물음표, 줄바꿈 기준으로 문장 분리
  static List<String> tokenize(String text) {
    return text
        .split(RegExp(r'[.!?\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// 한글·영문·숫자만 남기고 나머지 제거, 영문 소문자 변환
  /// 예: "나도, 너를 사랑 해" → "나도너를사랑해"
  static String normalize(String sentence) {
    return sentence
        .replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '')
        .toLowerCase();
  }

  /// tokenize → normalize 합성
  static List<String> tokenizeAndNormalize(String text) {
    return tokenize(text)
        .map(normalize)
        .where((s) => s.isNotEmpty)
        .toList();
  }
}
```

- [ ] **Step 4: 테스트 실행 — PASS 확인**

```bash
flutter test test/shared/utils/sentence_normalizer_test.dart
```

Expected: `All tests passed!`

- [ ] **Step 5: 커밋**

```bash
git add lib/shared/utils/sentence_normalizer.dart test/shared/utils/sentence_normalizer_test.dart
git commit -m "feat: SentenceNormalizer 유틸리티 추가 (토크나이저 + 정규화)"
```

---

## Task 2: SentenceRecord 모델 + Supabase 마이그레이션

**Files:**
- Create: `lib/shared/models/sentence_record.dart`
- Create: `supabase/migrations/20260514000000_add_normalized_sentences.sql`

- [ ] **Step 1: Supabase 마이그레이션 SQL 작성**

`supabase/migrations/20260514000000_add_normalized_sentences.sql`:

```sql
-- sentences 테이블에 normalized_sentences 배열과 thought 컬럼 추가
ALTER TABLE sentences
  ADD COLUMN IF NOT EXISTS normalized_sentences TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS thought TEXT;

-- 배열 포함 검색을 위한 GIN 인덱스
CREATE INDEX IF NOT EXISTS sentences_normalized_gin
  ON sentences USING GIN(normalized_sentences);
```

- [ ] **Step 2: Supabase 대시보드에서 마이그레이션 적용**

Supabase 대시보드 → SQL Editor → 위 SQL 실행.
또는 Supabase CLI: `supabase db push`

확인:
- `sentences` 테이블에 `normalized_sentences text[]` 컬럼 존재
- `sentences` 테이블에 `thought text` 컬럼 존재
- `sentences_normalized_gin` 인덱스 존재

- [ ] **Step 3: SentenceRecord Dart 모델 작성**

`lib/shared/models/sentence_record.dart`:

```dart
/// Supabase sentences 테이블 row 모델
class SentenceRecord {
  final String id;
  final String userId;
  final String? bookId;
  final String? sessionId;
  final String content;
  final String? thought;
  final List<String> normalizedSentences;
  final DateTime createdAt;

  const SentenceRecord({
    required this.id,
    required this.userId,
    this.bookId,
    this.sessionId,
    required this.content,
    this.thought,
    required this.normalizedSentences,
    required this.createdAt,
  });

  factory SentenceRecord.fromMap(Map<String, dynamic> m) => SentenceRecord(
    id: m['id'] as String,
    userId: m['user_id'] as String,
    bookId: m['book_id'] as String?,
    sessionId: m['session_id'] as String?,
    content: m['content'] as String,
    thought: m['thought'] as String?,
    normalizedSentences: ((m['normalized_sentences'] as List?) ?? [])
        .map((s) => s.toString())
        .toList(),
    createdAt: DateTime.parse(m['created_at'] as String),
  );
}
```

- [ ] **Step 4: 커밋**

```bash
git add lib/shared/models/sentence_record.dart supabase/migrations/20260514000000_add_normalized_sentences.sql
git commit -m "feat: SentenceRecord 모델 및 Supabase normalized_sentences 마이그레이션"
```

---

## Task 3: DbService 수정

**Files:**
- Modify: `lib/core/services/db_service.dart`

- [ ] **Step 1: import 추가**

`lib/core/services/db_service.dart` 상단에:

```dart
import '../../shared/utils/sentence_normalizer.dart';
```

- [ ] **Step 2: `saveSession()` 시그니처에 `thoughts` 파라미터 추가**

기존:
```dart
Future<String> saveSession({
  String? bookId,
  required int durationSeconds,
  required List<String> sentences,
  int? score,
}) async {
```

변경:
```dart
Future<String> saveSession({
  String? bookId,
  required int durationSeconds,
  required List<String> sentences,
  List<String?>? thoughts,  // 추가 — nullable, 기존 호출부 변경 불필요
  int? score,
}) async {
```

- [ ] **Step 3: sentences insert payload에 `normalized_sentences`와 `thought` 추가**

기존 insert 부분:

```dart
if (sentences.isNotEmpty) {
  await supabase
      .from('sentences')
      .insert(
        sentences
            .map(
              (s) => {
                'user_id': _uid,
                'book_id': ?bookId,
                'session_id': sessionId,
                'content': s,
              },
            )
            .toList(),
      );
}
```

변경:

```dart
if (sentences.isNotEmpty) {
  await supabase
      .from('sentences')
      .insert(
        sentences.asMap().entries
            .map(
              (e) => {
                'user_id': _uid,
                'book_id': ?bookId,
                'session_id': sessionId,
                'content': e.value,
                'normalized_sentences':
                    SentenceNormalizer.tokenizeAndNormalize(e.value),
                'thought': thoughts != null && e.key < thoughts.length
                    ? thoughts[e.key]
                    : null,
              },
            )
            .toList(),
      );
}
```

- [ ] **Step 4: `findOverlappingSentences()` 메서드 추가**

`DbService` 클래스 내 `countSentenceOverlap` 메서드 아래에 추가:

```dart
/// 정규화된 문장과 exact-match되는 다른 유저들의 문장을 조회한다.
///
/// Supabase GIN 인덱스를 통해 normalized_sentences 배열 포함 검색.
/// 반환: [{ id, content, thought, created_at, profiles, books }]
Future<List<Map<String, dynamic>>> findOverlappingSentences(
  String normalizedText,
) async {
  if (normalizedText.isEmpty) return const [];
  final res = await supabase
      .from('sentences')
      .select(
        'id, content, thought, created_at, '
        'profiles(username, display_name, avatar_url), '
        'books(title)',
      )
      .filter('normalized_sentences', 'cs', '{"$normalizedText"}')
      .neq('user_id', _uid)
      .order('created_at', ascending: false)
      .limit(20);
  return List<Map<String, dynamic>>.from(res);
}
```

- [ ] **Step 5: 앱 빌드 확인**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 6: 커밋**

```bash
git add lib/core/services/db_service.dart
git commit -m "feat: DbService에 normalized_sentences 저장 및 findOverlappingSentences 쿼리 추가"
```

---

## Task 4: 모바일 세션에서 Supabase 비동기 업로드

세션 리캡 화면에서 로컬 저장 후 Supabase에 문장을 비동기 업로드한다.
실패해도 로컬 저장에 영향 없음 (fire-and-forget).

**Files:**
- Modify: `lib/features/home/screen/session_recap_screen.dart`

- [ ] **Step 1: DbService import 추가**

`session_recap_screen.dart` import 목록에:

```dart
import '../../../core/services/db_service.dart';
```

- [ ] **Step 2: `_uploadToSupabase` 헬퍼 메서드 추가**

`_SessionRecapScreenState` 클래스 내에 추가:

```dart
/// 로컬 저장 후 Supabase에 비동기 업로드 (fire-and-forget)
Future<void> _uploadToSupabase(
  String bookId,
  List<CollectedSentence> sentences,
) async {
  try {
    final dbService = ref.read(dbServiceProvider);
    await dbService.saveSession(
      bookId: bookId,
      durationSeconds: widget.data.seconds,
      sentences: sentences.map((e) => e.content).toList(),
      thoughts: sentences
          .map((e) => e.thought.isNotEmpty ? e.thought : null)
          .toList(),
    );
  } catch (_) {
    // 소셜 업로드 실패는 무시 — 로컬 저장이 우선
  }
}
```

- [ ] **Step 3: `_savePage()` 내 로컬 저장 완료 후 업로드 트리거**

기존 `_savePage()` 내에서 초서 병렬 저장이 끝나는 부분 (약 line 273) 직후에 추가:

```dart
// 기존 코드 (변경 없음):
await Future.wait(
  widget.data.sentences
      .where((entry) => entry.content.isNotEmpty)
      .map(
        (entry) => repo.saveChoseo(
          bookId: bookId,
          bookTitle: widget.data.bookTitle,
          bookAuthor: widget.data.bookAuthor,
          content: entry.content,
          myThought: entry.thought.isEmpty ? null : entry.thought,
        ),
      ),
);

// 추가:
unawaited(_uploadToSupabase(bookId, widget.data.sentences));
```

`unawaited`를 사용하려면 파일 상단 import에 추가:
```dart
import 'dart:async' show unawaited;
```

- [ ] **Step 4: 빌드 확인**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 5: 커밋**

```bash
git add lib/features/home/screen/session_recap_screen.dart
git commit -m "feat: 세션 리캡에서 Supabase 비동기 업로드 추가 (fire-and-forget)"
```

---

## Task 5: OverlapProvider

**Files:**
- Create: `lib/features/feed/controller/overlap_provider.dart`

- [ ] **Step 1: 파일 작성**

`lib/features/feed/controller/overlap_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/db_service.dart';

// ─── OverlapMatch 모델 ─────────────────────────────────────────────────────

class OverlapMatch {
  final String sentenceId;
  final String content;
  final String? thought;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bookTitle;
  final DateTime createdAt;

  const OverlapMatch({
    required this.sentenceId,
    required this.content,
    this.thought,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bookTitle,
    required this.createdAt,
  });

  factory OverlapMatch.fromMap(Map<String, dynamic> m) {
    final profile = m['profiles'] as Map<String, dynamic>?;
    final book = m['books'] as Map<String, dynamic>?;
    return OverlapMatch(
      sentenceId: m['id'] as String,
      content: m['content'] as String,
      thought: m['thought'] as String?,
      username: profile?['username'] as String? ?? '알 수 없음',
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      bookTitle: book?['title'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────

class OverlapNotifier
    extends FamilyAsyncNotifier<List<OverlapMatch>, String> {
  @override
  Future<List<OverlapMatch>> build(String normalizedText) async {
    if (normalizedText.isEmpty) return const [];
    final rows =
        await ref.read(dbServiceProvider).findOverlappingSentences(normalizedText);
    return rows.map(OverlapMatch.fromMap).toList();
  }
}

final overlappingSentencesProvider = AsyncNotifierProvider.family<
    OverlapNotifier, List<OverlapMatch>, String>(
  OverlapNotifier.new,
);
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 3: 커밋**

```bash
git add lib/features/feed/controller/overlap_provider.dart
git commit -m "feat: OverlapMatch 모델 및 overlappingSentencesProvider 추가"
```

---

## Task 6: SplitHighlightWidget

**Files:**
- Create: `lib/features/feed/widget/split_highlight_widget.dart`

- [ ] **Step 1: 위젯 파일 작성**

`lib/features/feed/widget/split_highlight_widget.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../controller/overlap_provider.dart';

/// 겹문장 UI — 상단에 기록자 카드, 하단에 다른 독자들 카드 목록
///
/// Anchor(공유 문장): Bold + appPrimaryAccent
/// Context(생각): FontWeight.w300 + appTextTertiary
class SplitHighlightWidget extends StatelessWidget {
  final String anchorText;
  final String collectorUsername;
  final String? collectorThought;
  final List<OverlapMatch> matches;

  const SplitHighlightWidget({
    super.key,
    required this.anchorText,
    required this.collectorUsername,
    this.collectorThought,
    required this.matches,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 기록자 카드 (상단)
        _OverlapCard(
          anchorText: anchorText,
          username: collectorUsername,
          thought: collectorThought,
          isCollector: true,
        ),
        const SizedBox(height: 12),
        // 구분선
        Row(
          children: [
            Expanded(child: Divider(color: context.appBorder, height: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '다른 독자들의 생각',
                style: AppTheme.captionSmall.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),
            Expanded(child: Divider(color: context.appBorder, height: 1)),
          ],
        ),
        const SizedBox(height: 12),
        // 타인 카드 목록 (하단 나열)
        ...matches.map(
          (m) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OverlapCard(
              anchorText: anchorText,
              username: m.displayName ?? m.username,
              thought: m.thought,
              isCollector: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlapCard extends StatelessWidget {
  final String anchorText;
  final String username;
  final String? thought;
  final bool isCollector;

  const _OverlapCard({
    required this.anchorText,
    required this.username,
    this.thought,
    required this.isCollector,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.cardPaddingMD),
      decoration: AppTheme.smoothBox(
        color: context.appCard,
        radius: AppTheme.radiusLG,
        side: isCollector
            ? BorderSide(
                color: context.appPrimaryAccent.withValues(alpha: 0.35),
              )
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Anchor — Bold + brand color
          RichText(
            text: TextSpan(
              text: '"$anchorText"',
              style: AppTheme.bodySmall.copyWith(
                color: context.appPrimaryAccent,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // 유저 정보
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isCollector
                    ? context.appPrimaryAccent.withValues(alpha: 0.15)
                    : context.appSurface,
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: AppTheme.captionSmall.copyWith(
                    color: isCollector
                        ? context.appPrimaryAccent
                        : context.appTextTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                username,
                style: AppTheme.captionLarge.copyWith(
                  color: isCollector
                      ? context.appPrimaryAccent
                      : context.appTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Context(생각) — Light + grey
          thought != null && thought!.isNotEmpty
              ? RichText(
                  text: TextSpan(
                    text: thought,
                    style: AppTheme.bodySmall.copyWith(
                      color: context.appTextTertiary,
                      fontWeight: FontWeight.w300,
                      height: 1.6,
                    ),
                  ),
                )
              : Text(
                  '아직 생각을 남기지 않았어요',
                  style: AppTheme.captionLarge.copyWith(
                    color: context.appTextTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 빌드 확인**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 3: 커밋**

```bash
git add lib/features/feed/widget/split_highlight_widget.dart
git commit -m "feat: SplitHighlightWidget 추가 (Anchor+Context RichText 위젯)"
```

---

## Task 7: SentenceDetailScreen 통합

**Files:**
- Modify: `lib/features/feed/screen/sentence_detail_screen.dart`

- [ ] **Step 1: ConsumerStatefulWidget으로 변환 + import 추가**

파일 상단 import 목록에 추가:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/sentence_normalizer.dart';
import '../controller/overlap_provider.dart';
import '../widget/split_highlight_widget.dart';
```

`SentenceDetailScreen` 클래스 선언 변경:

```dart
// 기존:
class SentenceDetailScreen extends StatefulWidget {
  final SentenceDetailExtra data;
  const SentenceDetailScreen({super.key, required this.data});

  @override
  State<SentenceDetailScreen> createState() => _SentenceDetailScreenState();
}

class _SentenceDetailScreenState extends State<SentenceDetailScreen> {
```

변경:

```dart
class SentenceDetailScreen extends ConsumerStatefulWidget {
  final SentenceDetailExtra data;
  const SentenceDetailScreen({super.key, required this.data});

  @override
  ConsumerState<SentenceDetailScreen> createState() =>
      _SentenceDetailScreenState();
}

class _SentenceDetailScreenState
    extends ConsumerState<SentenceDetailScreen> {
```

- [ ] **Step 2: 겹문장 섹션 추가**

`build()` 내 CustomScrollView의 sliver 목록에서 "수집 통계" SliverToBoxAdapter 다음, "다른 독자들의 생각 헤더" SliverToBoxAdapter **앞**에 삽입:

```dart
// ── 겹문장 섹션 ─────────────────────────────────
SliverToBoxAdapter(
  child: _buildOverlapSection(context, d),
),
```

- [ ] **Step 3: `_buildOverlapSection` 메서드 작성**

`_SentenceDetailScreenState` 클래스 내에 추가:

```dart
Widget _buildOverlapSection(BuildContext context, SentenceDetailExtra d) {
  if (kUseMock) return const SizedBox.shrink();

  final normalizedText = SentenceNormalizer.normalize(d.sentenceContent);
  final overlapsAsync = ref.watch(overlappingSentencesProvider(normalizedText));

  return overlapsAsync.when(
    loading: () => const SizedBox.shrink(),
    error: (_, __) => const SizedBox.shrink(), // 소셜 기능 실패 시 섹션 숨김
    data: (matches) {
      if (matches.isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.screenPadding,
          0,
          AppTheme.screenPadding,
          AppTheme.spaceLG,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 섹션 헤더
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '같은 문장, 다른 생각',
                style: AppTheme.headingSmall.copyWith(
                  color: context.appTextPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${matches.length}명이 이 문장을 함께 수집했어요',
                style: AppTheme.captionLarge.copyWith(
                  color: context.appTextTertiary,
                ),
              ),
            ),
            SplitHighlightWidget(
              anchorText: d.sentenceContent,
              collectorUsername: d.collectorUsername ?? '나',
              collectorThought: d.collectorThought,
              matches: matches,
            ),
          ],
        ),
      );
    },
  );
}
```

- [ ] **Step 4: `kUseMock` import 확인**

`app_flags.dart` import가 이미 있는지 확인:

```dart
import '../../../core/constants/app_flags.dart';
```

없으면 추가.

- [ ] **Step 5: 빌드 확인**

```bash
flutter build apk --debug 2>&1 | tail -5
```

Expected: `Built build/app/outputs/flutter-apk/app-debug.apk`

- [ ] **Step 6: 커밋**

```bash
git add lib/features/feed/screen/sentence_detail_screen.dart
git commit -m "feat: SentenceDetailScreen에 겹문장 '같은 문장, 다른 생각' 섹션 통합"
```

---

## 최종 검증

- [ ] 앱 실행 후 피드에서 문장 카드 탭 → SentenceDetailScreen 진입
- [ ] "같은 문장, 다른 생각" 섹션이 표시됨 (실데이터 환경, 겹치는 유저 있을 때)
- [ ] 겹치는 유저 없을 때 섹션 미표시 확인
- [ ] `kUseMock=true` 환경(디자인 앱)에서 섹션 미표시 확인
- [ ] 세션 종료 후 Supabase Dashboard `sentences` 테이블에 `normalized_sentences` 배열 확인
