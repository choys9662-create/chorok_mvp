# 겹문장 매칭 및 교류 시스템 설계

**날짜:** 2026-05-14
**상태:** 승인됨

---

## 개요

같은 문장을 수집한 유저들을 찾아내고, 그 문장에 대해 각자가 기록한 **생각의 차이**를 대비시켜 보여주는 소셜 기능이다.

### 핵심 원칙

- AI 기반 의미 유사도 분석 **절대 배제**
- **텍스트 정규화 기반 정확도 매칭(exact match)만 사용**
- 매칭 단위: Supabase `sentences` 테이블의 개별 문장 row

---

## 아키텍처

### 레이어 구조

```
① Utility          sentence_normalizer.dart
② Data Model       Supabase sentences + SentenceRecord Dart 모델
③ Business Logic   DbService + overlappingSentencesProvider
④ UI               SplitHighlightWidget + SentenceDetailScreen 수정
```

### 데이터 흐름

```
유저가 문장 수집
  → tokenizeAndNormalize(content)
  → Supabase INSERT sentences (content, normalized_sentences, thought)

SentenceDetailScreen 진입
  → normalize(myContent) → normalizedText
  → overlappingSentencesProvider(normalizedText) 호출
  → WHERE normalizedText = ANY(normalized_sentences) AND user_id != me
  → SplitHighlightWidget 렌더링
```

---

## Step 1 — Utility: SentenceNormalizer

**파일:** `lib/shared/utils/sentence_normalizer.dart`

```dart
class SentenceNormalizer {
  // 마침표, !, ?, 줄바꿈 기준으로 문장 분리
  static List<String> tokenize(String text)

  // 공백·기호·특수문자 제거, 한글·영문·숫자만 남김
  // 예: "나도, 너를 사랑 해" → "나도너를사랑해"
  // RegExp: [^가-힣a-zA-Z0-9] 제거 + lowercase
  static String normalize(String sentence)

  // tokenize → normalize 합성
  static List<String> tokenizeAndNormalize(String text)
}
```

**기존 `OverlapDetector.normalize()`와 역할 구분:**
- `OverlapDetector.normalize()` → 퍼지 비교(LCS, Jaccard)용. 구두점 일부 보존
- `SentenceNormalizer.normalize()` → 저장/검색용 exact match. 모든 비문자 제거

---

## Step 2 — Data Model

### Supabase Migration

```sql
-- sentences 테이블에 컬럼 추가
ALTER TABLE sentences
  ADD COLUMN normalized_sentences TEXT[] DEFAULT '{}',
  ADD COLUMN thought TEXT;

-- GIN 인덱스 (배열 포함 검색 최적화)
CREATE INDEX sentences_normalized_gin
  ON sentences USING GIN(normalized_sentences);
```

### Dart 모델: SentenceRecord

**파일:** `lib/shared/models/sentence_record.dart`

```dart
class SentenceRecord {
  final String id;
  final String userId;
  final String? bookId;
  final String? sessionId;
  final String content;
  final String? thought;
  final List<String> normalizedSentences;
  final DateTime createdAt;
}
```

---

## Step 3 — Business Logic

### DbService 수정

**파일:** `lib/core/services/db_service.dart`

#### `saveSession()` 수정

파라미터에 `List<String>? thoughts` 추가 (nullable — 기존 호출부 변경 불필요). 각 sentence를 insert할 때 `normalized_sentences` 함께 저장:

```dart
Future<String> saveSession({
  String? bookId,
  required int durationSeconds,
  required List<String> sentences,
  List<String>? thoughts,   // 추가 (nullable, 기존 호출부 호환)
  int? score,
})
```

insert payload에 추가:
```dart
'normalized_sentences': SentenceNormalizer.tokenizeAndNormalize(s),
'thought': thoughts != null && i < thoughts.length ? thoughts[i] : null,
```

#### `findOverlappingSentences()` 신규

```dart
Future<List<Map<String, dynamic>>> findOverlappingSentences(
  String normalizedText,
) async {
  // WHERE normalizedText = ANY(normalized_sentences)
  // AND user_id != _uid
  // JOIN profiles (username, display_name, avatar_url)
  // JOIN books (title)
  // ORDER BY created_at DESC
  // LIMIT 20
}
```

반환: `[{ id, content, thought, username, display_name, avatar_url, book_title, created_at }]`

### Provider

**파일:** `lib/features/feed/controller/overlap_provider.dart`

```dart
final overlappingSentencesProvider = AsyncNotifierProvider
  .family<OverlapNotifier, List<OverlapMatch>, String>(
    OverlapNotifier.new,
  );
```

**`OverlapMatch` 모델 (provider 파일 내 정의):**
```dart
class OverlapMatch {
  final String sentenceId;
  final String content;
  final String? thought;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bookTitle;
  final DateTime createdAt;
}
```

---

## Step 4 — UI

### SplitHighlightWidget

**파일:** `lib/features/feed/widget/split_highlight_widget.dart`

**레이아웃 구조:**
```
┌──────────────────────────────────────────┐
│ [내 카드] — 브랜드 컬러 border            │
│   RichText:                               │
│     anchor: Bold + appPrimaryAccent       │  ← "거부의 시작은 꿈이었다"
│   내 생각 (myThought): 일반 색상           │
└──────────────────────────────────────────┘

──────── 다른 독자들의 생각 ────────

┌──────────────────────────────────────────┐
│ [타인 카드] per OverlapMatch             │
│   RichText:                               │
│     anchor: Bold + appPrimaryAccent       │
│   그들의 생각: Light + appTextTertiary    │  ← FontWeight.w300 + grey
│   (thought 없으면: "아직 생각을 남기지 않았어요", 흐리게) │
└──────────────────────────────────────────┘
┌──────────────────────────────────────────┐
│ [타인 카드 2]                             │
└──────────────────────────────────────────┘
...
```

**RichText 사용 규칙:**
- Anchor 문장: `TextSpan(text: anchorText, style: TextStyle(fontWeight: FontWeight.w700, color: appPrimaryAccent))`
- Context(생각): `TextSpan(text: thought, style: TextStyle(fontWeight: FontWeight.w300, color: appTextTertiary))`

**Props:**
```dart
class SplitHighlightWidget extends ConsumerWidget {
  final String anchorText;        // 공유된 정규화 이전 원문
  final String? myThought;        // 나의 생각
  final List<OverlapMatch> matches;
}
```

### SentenceDetailScreen 수정

**파일:** `lib/features/feed/screen/sentence_detail_screen.dart`

1. `SentenceDetailExtra`에 `myThought` 필드 추가
   - 로컬 초서에서 진입 시: `IsarChoseo.myThought`
   - Supabase 피드에서 진입 시: `sentences.thought`
2. Hero 섹션 아래에 "같은 문장, 다른 생각" 섹션 추가
3. `normalizedText`는 화면 내에서 계산: `SentenceNormalizer.normalize(data.sentenceContent)`
4. `overlappingSentencesProvider(normalizedText)` watch
5. 상태별 처리:
   - **loading**: `CircularProgressIndicator`
   - **empty**: 섹션 숨김 (겹치는 유저 없으면 표시 안 함)
   - **error**: 무시 (소셜 기능 실패가 전체 화면에 영향 주면 안 됨)
   - **data**: `SplitHighlightWidget` 렌더링

---

## 새로 생기는 파일

| 파일 | 역할 |
|------|------|
| `lib/shared/utils/sentence_normalizer.dart` | 토크나이저 + 정규화 유틸리티 |
| `lib/shared/models/sentence_record.dart` | Supabase sentences row Dart 모델 |
| `lib/features/feed/controller/overlap_provider.dart` | Riverpod provider + OverlapMatch 모델 |
| `lib/features/feed/widget/split_highlight_widget.dart` | UI 위젯 |

## 수정되는 파일

| 파일 | 변경 내용 |
|------|-----------|
| `lib/core/services/db_service.dart` | `saveSession()` 수정, `findOverlappingSentences()` 추가 |
| `lib/features/feed/screen/sentence_detail_screen.dart` | "같은 문장, 다른 생각" 섹션 추가 |

## 추가되는 DB 마이그레이션

```
supabase/migrations/YYYYMMDDHHMMSS_add_normalized_sentences.sql
```

---

## 결정 사항

| 항목 | 결정 | 이유 |
|------|------|------|
| 저장 방식 | `TEXT[]` 배열 컬럼 | 스펙 구조 준수, 다중 문장 확장 가능 |
| 인덱스 | GIN | 배열 포함 검색에 B-tree 대비 효율적 |
| 매칭 방식 | exact match only | AI/유사도 배제, 오탐 방지 |
| UI 진입점 | SentenceDetailScreen | 기존 화면에 자연스러운 통합 |
| 레이아웃 | 수직 — 내 생각 상단 / 타인 하단 나열 | 생각의 차이를 읽는 흐름에 최적 |
| error handling | 무시 (섹션 미표시) | 소셜 기능 실패가 핵심 기능 방해 금지 |
