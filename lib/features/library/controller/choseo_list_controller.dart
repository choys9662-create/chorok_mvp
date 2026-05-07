import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/isar/isar_choseo.dart';
import '../../../shared/repositories/book_repository.dart';

const bool _useMock = bool.fromEnvironment('USE_MOCK', defaultValue: false);

// ─── 목업 데이터 (USE_MOCK=true 전용) ──────────────────────────────────────────
final _kMockChoseo = [
  IsarChoseo(
    choseoId: 'mock_1',
    bookId: '1',
    bookTitle: '채식주의자',
    bookAuthor: '한강',
    content: '나는 채식주의자가 되기로 했다. 꿈 때문에.',
    myThought: '이 짧은 문장에 얼마나 많은 결심이 담겨 있는지. 꿈이 현실을 바꿀 수 있다는 것.',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  IsarChoseo(
    choseoId: 'mock_2',
    bookId: '1',
    bookTitle: '채식주의자',
    bookAuthor: '한강',
    content: '인간은 모두 식물이 되고 싶어 한다. 그러나 아무도 뿌리를 내리려 하지 않는다.',
    createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
  ),
  IsarChoseo(
    choseoId: 'mock_3',
    bookId: '6',
    bookTitle: '파친코',
    bookAuthor: '이민진',
    content: '역사가 우리를 망쳐놨지만, 그래도 상관없다.',
    myThought: '패배와 희망이 공존하는 문장. 한국 근현대사 전체를 압축한 것 같다.',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  IsarChoseo(
    choseoId: 'mock_4',
    bookId: '6',
    bookTitle: '파친코',
    bookAuthor: '이민진',
    content: '선자는 살아남기 위해 태어난 것이 아니었다. 그녀는 삶을 위해 태어났다.',
    createdAt: DateTime.now().subtract(const Duration(days: 5, hours: 2)),
  ),
  IsarChoseo(
    choseoId: 'mock_5',
    bookId: '2',
    bookTitle: '82년생 김지영',
    bookAuthor: '조남주',
    content: '지영 씨는 아무 잘못이 없어요. 그냥 여자로 태어났을 뿐이에요.',
    myThought: '읽는 내내 화가 나면서도 슬펐다. 지영이 나일 수도 있었다.',
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
  ),
  IsarChoseo(
    choseoId: 'mock_6',
    bookId: '3',
    bookTitle: '아몬드',
    bookAuthor: '손원평',
    content: '감정은 배우는 것이다. 그리고 배움에는 시간이 필요하다.',
    myThought: '감정을 느끼지 못하는 주인공이 결국 가장 인간다운 이야기를 만들어낸다.',
    createdAt: DateTime.now().subtract(const Duration(days: 14)),
  ),
];

// ─── 상태 ────────────────────────────────────────────────────────────────────

class ChoseoListState {
  final List<IsarChoseo> items;   // DB 전체 (검색 전)
  final String query;
  final bool isLoading;

  const ChoseoListState({
    required this.items,
    this.query = '',
    this.isLoading = true,
  });

  /// 검색 필터 적용된 목록
  List<IsarChoseo> get filtered {
    if (query.trim().isEmpty) return items;
    final q = query.toLowerCase();
    return items.where((c) {
      return c.content.toLowerCase().contains(q) ||
          (c.myThought?.toLowerCase().contains(q) ?? false) ||
          c.bookTitle.toLowerCase().contains(q) ||
          c.bookAuthor.toLowerCase().contains(q);
    }).toList();
  }

  /// 책별 그룹 (책 제목 → 초서 목록)
  Map<String, List<IsarChoseo>> get byBook {
    final result = <String, List<IsarChoseo>>{};
    for (final c in filtered) {
      result.putIfAbsent(c.bookTitle, () => []).add(c);
    }
    return result;
  }

  ChoseoListState copyWith({
    List<IsarChoseo>? items,
    String? query,
    bool? isLoading,
  }) =>
      ChoseoListState(
        items: items ?? this.items,
        query: query ?? this.query,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ─── Notifier ────────────────────────────────────────────────────────────────

class ChoseoListNotifier extends Notifier<ChoseoListState> {
  @override
  ChoseoListState build() {
    // 빌드 직후 로드
    Future.microtask(load);
    return const ChoseoListState(items: [], isLoading: true);
  }

  Future<void> load() async {
    final repo = ref.read(bookRepositoryProvider);
    final rows = await repo?.getAllChoseo() ?? [];
    final items = (_useMock && rows.isEmpty) ? _kMockChoseo : rows;
    state = state.copyWith(items: items, isLoading: false);
  }

  void search(String query) {
    state = state.copyWith(query: query);
  }
}

final choseoListProvider =
    NotifierProvider<ChoseoListNotifier, ChoseoListState>(
  ChoseoListNotifier.new,
);

// ─── 초서 전체 개수 Provider ──────────────────────────────────────────────────

final choseoCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.read(bookRepositoryProvider);
  final count = await repo?.getChoseoCount() ?? 0;
  return (_useMock && count == 0) ? _kMockChoseo.length : count;
});
