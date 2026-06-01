import 'dart:math';

/// 수동공격(passive-aggressive) 트리거 유형
///
/// [ReadingInsightEngine]가 "격려" 톤이라면, 이 엔진은 그 반대편 —
/// 유저가 읽지 않을 때 죄책감을 자극하는 "능청스럽고 짓궂은" 톤을 담당한다.
enum AggroTrigger {
  sessionEscape, // 독서 세션 중 이탈
  idleDays, // 며칠째 안 읽음
  streakRisk, // 연속 독서일이 끊기기 직전
  neighborCompare, // 숲벗은 읽었는데 나는 안 읽음
}

/// 수동공격 판정·문구 생성을 위한 입력 컨텍스트
class AggroContext {
  /// 오늘 한 번이라도 독서했는지
  final bool readToday;

  /// 마지막 독서일로부터 경과한 일수 (0이면 오늘/어제 읽음)
  final int idleDays;

  /// 현재 연속 독서 일수
  final int streakDays;

  /// 오늘 읽은 숲벗(이웃)의 닉네임. 없으면 null
  final String? neighborName;

  const AggroContext({
    this.readToday = false,
    this.idleDays = 0,
    this.streakDays = 0,
    this.neighborName,
  });
}

/// 수동공격 메시지 엔진
///
/// 톤 가드레일: 듀오링고 부엉이처럼 "능청스럽게 콕 찌르는" 정도까지만 허용한다.
/// 진짜 비난·모욕·수치심 유발은 금지 — 핵심 타겟(종인이: 읽고 싶지만 실천 못 하는
/// 사람)을 떠나게 만들기 때문이다. 강도는 단계가 있되 상한선을 둔다.
class PassiveAggroEngine {
  PassiveAggroEngine._();

  /// 같은 트리거를 다시 띄우기까지의 최소 간격 (스팸 방지)
  static const Duration cooldown = Duration(hours: 24);

  /// streakRisk가 발동하기 위한 최소 연속 일수 (1일은 지킬 게 약하므로 제외)
  static const int _minStreakForRisk = 2;

  /// idleDays가 발동하기 위한 최소 방치 일수
  static const int _minIdleDays = 2;

  // ─── 메시지 풀 ──────────────────────────────────────────────────
  // 듀오링고 톤: 가볍게 콕 찌르되, 떠나게 만들지 않는다.

  static const _escapeMessages = [
    '조금만 더 읽어봐요.\n지금 멈추기엔 너무 아까워요.',
    '지금 함께 읽고 있는 사람들이 있어요.\n혼자 나갈 건가요?',
    '오늘 기록이 완성되지 않아요.\n여기서 멈추면 안 돼요.',
    '5분만요. 딱 5분만 더 있어봐요.',
    '책장이 닫히려 해요.\n다시 펼쳐줄 사람은 당신뿐이에요.',
  ];

  // idleDays — 가벼운 단계 (1~2일)
  static const _idleSoftMessages = [
    '하루 쉬는 거예요, 아니면 그만두는 거예요?',
    '책이 당신을 기다리고 있어요. 잠깐 들여다볼까요?',
    '어제 못 읽은 페이지가 아직 그대로예요.',
    '딱 한 문장만 읽어도 괜찮아요. 시작이 어려울 뿐이죠.',
  ];

  // idleDays — 진한 단계 (3일+)
  static const _idleHardMessages = [
    '책이 {days}일째 같은 페이지에 멈춰 있어요.',
    '{days}일 동안 한 줄도 안 읽었네요. 책이 삐졌을지도 몰라요.',
    '{days}일째 책장이 그대로예요. 우리, 아직 친구 맞죠?',
    '솔직히 말할게요. {days}일이면 슬슬 잊고 있는 거예요.',
  ];

  static const _streakRiskMessages = [
    '{streak}일 연속이 오늘 끊겨요. 5분이면 지켜요.',
    '{streak}일 동안 쌓은 기록, 오늘 하루로 무너뜨릴 건가요?',
    '오늘 안 읽으면 {streak}일 연속이 0이 돼요. 정말 괜찮아요?',
    '{streak}일을 지켜온 당신이에요. 오늘도 할 수 있어요.',
  ];

  static const _neighborMessages = [
    '숲벗 {name}님은 오늘 읽었어요. 당신은요?',
    '{name}님의 숲은 오늘도 자랐어요. 당신의 숲은 그대로네요.',
    '{name}님이 방금 초서를 남겼어요. 당신 차례 아닐까요?',
    '{name}님은 읽는 중이에요. 혼자 두지 말아요.',
  ];

  /// 트리거와 컨텍스트로 수동공격 문구를 생성한다.
  ///
  /// [rng]를 주입하면 메시지 선택을 결정적으로 만들 수 있다 (테스트용).
  static String messageFor(
    AggroTrigger trigger,
    AggroContext ctx, {
    Random? rng,
  }) {
    final r = rng ?? Random();
    String pick(List<String> pool) => pool[r.nextInt(pool.length)];

    switch (trigger) {
      case AggroTrigger.sessionEscape:
        return pick(_escapeMessages);

      case AggroTrigger.idleDays:
        if (ctx.idleDays >= 3) {
          return pick(_idleHardMessages).replaceAll('{days}', '${ctx.idleDays}');
        }
        return pick(_idleSoftMessages);

      case AggroTrigger.streakRisk:
        return pick(_streakRiskMessages).replaceAll('{streak}', '${ctx.streakDays}');

      case AggroTrigger.neighborCompare:
        final name = ctx.neighborName ?? '숲벗';
        return pick(_neighborMessages).replaceAll('{name}', name);
    }
  }

  /// 지금 어떤 수동공격을 띄울지 판정한다. 띄우지 않으면 null.
  ///
  /// 우선순위: streakRisk > idleDays > neighborCompare
  /// (지킬 게 가장 임박한 것부터)
  ///
  /// [lastShownAt]이 [cooldown] 안이면 스팸 방지를 위해 무조건 null.
  static AggroTrigger? selectTrigger(
    AggroContext ctx, {
    required DateTime? lastShownAt,
    required DateTime now,
  }) {
    // 오늘 이미 읽었으면 공격 불필요
    if (ctx.readToday) return null;

    // 빈도 제한 — 마지막 공격 이후 쿨다운이 안 지났으면 침묵
    if (lastShownAt != null && now.difference(lastShownAt) < cooldown) {
      return null;
    }

    // ① 스트릭 끊기기 직전 (가장 잃을 게 큼)
    if (ctx.streakDays >= _minStreakForRisk) {
      return AggroTrigger.streakRisk;
    }

    // ② N일 방치
    if (ctx.idleDays >= _minIdleDays) {
      return AggroTrigger.idleDays;
    }

    // ③ 오늘 읽은 이웃이 있음
    if (ctx.neighborName != null) {
      return AggroTrigger.neighborCompare;
    }

    return null;
  }
}
