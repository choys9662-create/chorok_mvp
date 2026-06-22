/// 책 장르를 표준 분류 규칙으로 정규화한다.
///
/// 원본 문자열(book.genre 혹은 알라딘 categoryName 경로)을 키워드 규칙으로
/// 단일 레벨 표준 장르 라벨에 매핑한다. 매칭 안 되면 [unclassifiedGenre].
///
/// 규칙은 위에서부터 우선 적용되므로 **더 구체적인 장르를 먼저** 둔다.
/// (예: '역사소설'·'SF'를 '소설'·'역사'보다 위에 둬서 뭉개지지 않게 함)
library;

const String unclassifiedGenre = '미분류';

/// (표준 라벨, 매칭 키워드). 모든 키워드/입력은 소문자로 비교한다.
const List<({String label, List<String> keywords})> _genreRules = [
  // ── 문학: 세부 소설 장르를 '소설'보다 먼저 ──
  (label: 'SF', keywords: ['sf', '에스에프', '공상과학', '과학소설']),
  (label: '판타지', keywords: ['판타지', 'fantasy']),
  (label: '추리·미스터리', keywords: ['추리', '미스터리', '스릴러', 'mystery', 'thriller']),
  (label: '로맨스', keywords: ['로맨스', 'romance']),
  (label: '역사소설', keywords: ['역사소설', '대하소설']),
  (label: '시', keywords: ['시집', '운문', '현대시', '한국시', '외국시', '시·']),
  (label: '희곡', keywords: ['희곡', '시나리오']),
  (label: '에세이', keywords: ['에세이', '산문', 'essay']),
  (label: '소설', keywords: ['소설', 'novel', 'fiction']),

  // ── 비문학 ──
  (label: '자기계발', keywords: ['자기계발', '자기관리', '성공학']),
  (label: '경제·경영', keywords: ['경제', '경영', '재테크', '투자', '주식', '부동산']),
  (label: '사회·정치', keywords: ['사회', '정치', '시사', '법학', '법률']),
  (label: '역사', keywords: ['역사', '한국사', '세계사']),
  (label: '과학', keywords: ['과학', '수학', '물리', '생물', '화학', '천문', '자연']),
  (label: 'IT·컴퓨터', keywords: ['컴퓨터', '프로그래밍', '개발', '코딩', 'it']),
  (label: '예술', keywords: ['예술', '미술', '음악', '디자인', '사진', '대중문화', '영화']),
  (label: '철학·종교', keywords: ['철학', '종교', '심리', '명상', '불교', '기독교']),
  (label: '인문', keywords: ['인문', '교양']),
  (label: '건강', keywords: ['건강', '의학', '다이어트', '운동']),
  (label: '여행', keywords: ['여행', '기행']),
  (label: '요리', keywords: ['요리', '음식', '레시피']),
  (label: '어린이·청소년', keywords: ['어린이', '아동', '청소년', '유아']),
  (label: '외국어', keywords: ['외국어', '영어', '일본어', '중국어', '언어']),
];

/// [raw]를 표준 장르 라벨로 정규화한다.
///
/// [raw]는 짧은 라벨('SF', '역사소설')이거나 알라딘 카테고리 경로
/// ('국내도서>소설/시/희곡>한국현대소설')일 수 있다. null/빈 문자열은 [unclassifiedGenre].
String classifyBookGenre(String? raw) {
  final t = raw?.trim().toLowerCase();
  if (t == null || t.isEmpty) return unclassifiedGenre;
  for (final rule in _genreRules) {
    for (final k in rule.keywords) {
      if (t.contains(k)) return rule.label;
    }
  }
  return unclassifiedGenre;
}
