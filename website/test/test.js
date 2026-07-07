// 독서 유형 테스트 — 퀴즈 로직
// 점수 규칙: 축별 4문항, 동점 시 S / L / C / N (Obsidian Vault wiki/analyses/독서-MBTI-설문.md 참조)

const QUESTIONS = [
  // 축 0: R / S — 시작 방식
  {
    axis: 0,
    text: '책을 읽기 시작할 때 나는 보통…',
    a: '정해둔 시간이나 루틴이 있어야 시작하기 쉽다.',
    b: '어떤 문장, 추천, 분위기에 꽂히면 바로 시작한다.',
  },
  {
    axis: 0,
    text: '한동안 책을 못 읽다가 다시 읽게 되는 계기는…',
    a: '일정표, 목표, 독서모임 날짜처럼 외부 약속이 생길 때다.',
    b: '갑자기 읽고 싶은 책이나 주제가 생길 때다.',
  },
  {
    axis: 0,
    text: '책을 읽기 좋은 환경은…',
    a: '같은 장소, 같은 시간, 같은 방식이 반복되는 환경이다.',
    b: '그날 기분에 맞는 장소나 책을 자유롭게 고르는 환경이다.',
  },
  {
    axis: 0,
    text: '독서 앱이 나를 도와준다면 더 필요한 것은…',
    a: '"오늘 읽을 시간"을 잡아주고 반복하게 해주는 기능이다.',
    b: '지금 끌릴 만한 책·문장·주제를 던져주는 기능이다.',
  },
  // 축 1: L / F — 집중 장벽
  {
    axis: 1,
    text: '책을 읽다가 가장 자주 끊기는 이유는…',
    a: '스마트폰, 알림, 숏폼 같은 방해 때문이다.',
    b: '책 자체가 안 맞거나 몰입 포인트를 못 찾기 때문이다.',
  },
  {
    axis: 1,
    text: '읽는 동안 휴대폰은…',
    a: '멀리 두거나 잠가야 마음이 편하다.',
    b: '옆에 있어도 필요할 때만 보고 다시 읽을 수 있다.',
  },
  {
    axis: 1,
    text: '타이머나 집중 모드가 있으면…',
    a: '시작하고 버티는 데 실제로 도움이 된다.',
    b: '있으면 좋지만 독서의 핵심은 책에 빠지는 느낌이다.',
  },
  {
    axis: 1,
    text: '독서가 끊긴 뒤 다시 돌아오기 어려운 순간은…',
    a: '폰을 한 번 보기 시작해서 시간이 사라질 때다.',
    b: '책이 재미없거나 지금 나에게 의미가 없다고 느낄 때다.',
  },
  // 축 2: C / T — 기록 방식
  {
    axis: 2,
    text: '좋은 문장을 만나면 나는…',
    a: '문장 자체를 정확히 저장해두고 싶다.',
    b: '그 문장 때문에 든 생각이나 해석을 남기고 싶다.',
  },
  {
    axis: 2,
    text: '나중에 다시 보고 싶은 기록은…',
    a: '내가 밑줄 친 문장 모음이다.',
    b: '그때 내가 무슨 생각을 했는지 남긴 메모다.',
  },
  {
    axis: 2,
    text: '책을 다 읽지 못해도 남는 게 있다면…',
    a: '좋은 문장 몇 개만 건져도 충분하다.',
    b: '내 생각이 조금이라도 정리돼야 읽은 느낌이 난다.',
  },
  {
    axis: 2,
    text: '독서 앱의 기록 기능에서 더 끌리는 것은…',
    a: '사진으로 문장을 빠르게 저장하고 모아보는 기능이다.',
    b: '문장에 생각을 붙이고 나중에 확장하는 기능이다.',
  },
  // 축 3: I / N — 연결 욕구
  {
    axis: 3,
    text: '독서는 나에게 더 가깝게는…',
    a: '혼자 조용히 깊어지는 시간이다.',
    b: '다른 사람과 생각이 이어질 때 더 재밌는 활동이다.',
  },
  {
    axis: 3,
    text: '내가 고른 문장을 다른 사람도 골랐다는 걸 알면…',
    a: '흥미롭지만 굳이 대화까지 이어지지 않아도 된다.',
    b: '그 사람이 왜 골랐는지, 어떤 사람인지 궁금해진다.',
  },
  {
    axis: 3,
    text: '독서모임이나 책 커뮤니티에 대해 나는…',
    a: '부담이 더 커서 조용히 보는 쪽이 좋다.',
    b: '좋은 사람과 주제만 있으면 참여해보고 싶다.',
  },
  {
    axis: 3,
    text: '독서 앱에서 타인의 존재가 보인다면…',
    a: '방해되지 않게 은은하게만 보였으면 좋겠다.',
    b: '나와 비슷한 사람의 반응이나 생각을 더 보고 싶다.',
  },
];

const AXES = window.READING_AXES;
const TYPES = window.READING_TYPES;

const state = {
  current: 0,
  answers: [], // 'A' | 'B'
};

const $ = (id) => document.getElementById(id);
const views = document.querySelectorAll('.view');

function showView(name) {
  views.forEach((v) => v.classList.toggle('hidden', v.dataset.view !== name));
  window.scrollTo({ top: 0 });
}

function renderQuestion() {
  const q = QUESTIONS[state.current];
  $('qCount').textContent = `${state.current + 1} / ${QUESTIONS.length}`;
  $('qText').textContent = q.text;
  $('optA').textContent = q.a;
  $('optB').textContent = q.b;
  $('progressFill').style.width = `${(state.current / QUESTIONS.length) * 100}%`;
  $('backBtn').style.visibility = state.current === 0 ? 'hidden' : 'visible';
}

function answer(choice) {
  state.answers[state.current] = choice;
  if (state.current < QUESTIONS.length - 1) {
    state.current += 1;
    renderQuestion();
  } else {
    finish();
  }
}

function computeCode() {
  // 축별 A 선택 수 집계
  const counts = [0, 0, 0, 0];
  QUESTIONS.forEach((q, i) => {
    if (state.answers[i] === 'A') counts[q.axis] += 1;
  });
  // 동점(2:2) 처리: R/S→S, L/F→L, C/T→C, I/N→N
  const tieWinner = { 0: 'B', 1: 'A', 2: 'A', 3: 'B' };
  let code = '';
  for (let axis = 0; axis < 4; axis += 1) {
    const aCount = counts[axis];
    let pick;
    if (aCount > 2) pick = 'A';
    else if (aCount < 2) pick = 'B';
    else pick = tieWinner[axis];
    code += pick === 'A' ? AXES[axis].A : AXES[axis].B;
  }
  return { code, counts };
}

function renderAxisBars(counts) {
  const wrap = $('axisBars');
  wrap.innerHTML = '';
  for (let axis = 0; axis < 4; axis += 1) {
    const aCount = counts[axis];
    const pct = (aCount / 4) * 100;
    const row = document.createElement('div');
    row.className = 'axis-row';
    const aActive = aCount >= 2;
    row.innerHTML = `
      <span class="${aActive ? 'label-active' : ''}">${AXES[axis].A} ${AXES[axis].aLabel}</span>
      <div class="bar"><span style="left:0;width:${pct}%"></span></div>
      <span style="text-align:right" class="${!aActive ? 'label-active' : ''}">${AXES[axis].B} ${AXES[axis].bLabel}</span>
    `;
    wrap.appendChild(row);
  }
}

function renderResult(code, counts) {
  const t = TYPES[code];
  if (!t) return;
  $('resultCode').textContent = code;
  $('resultName').textContent = t.name;
  $('resultTagline').textContent = t.tagline;
  $('resultDesc').textContent = t.desc;

  const tips = $('resultTips');
  tips.innerHTML = '';
  t.tips.forEach((tip) => {
    const li = document.createElement('li');
    li.textContent = tip;
    tips.appendChild(li);
  });

  const mate = TYPES[t.mate];
  $('resultMate').innerHTML =
    `<strong>${t.mate} ${mate.name}</strong> — 서로 다른 방식이 균형을 만들어요. ` +
    `친구에게 테스트를 보내서 확인해 보세요.`;

  if (counts) renderAxisBars(counts);
  else $('axisBars').classList.add('hidden');
}

function finish() {
  const { code, counts } = computeCode();
  renderResult(code, counts);
  showView('result');
  // 공유 URL 갱신 (결과 정적 페이지)
  state.shareUrl = new URL(`./r/${code}/?from=share`, window.location.href).href;
  history.replaceState(null, '', `?r=${code}`);
}

function toast(msg) {
  const el = $('toast');
  el.textContent = msg;
  el.classList.add('show');
  setTimeout(() => el.classList.remove('show'), 2200);
}

async function share() {
  const url = state.shareUrl || window.location.href;
  const t = TYPES[new URLSearchParams(location.search).get('r')] || {};
  const text = t.name
    ? `나의 독서 유형은 "${t.name}"! 너는 어떤 독서가야?`
    : '나는 어떤 독서가일까? 1분 독서 유형 테스트';
  if (navigator.share) {
    try {
      await navigator.share({ title: '독서 유형 테스트', text, url });
      return;
    } catch (_) {
      /* 사용자가 취소한 경우 등 — 클립보드로 폴백하지 않고 종료 */
      return;
    }
  }
  await navigator.clipboard.writeText(url);
  toast('링크가 복사됐어요. 친구에게 보내보세요!');
}

function reset() {
  state.current = 0;
  state.answers = [];
  history.replaceState(null, '', location.pathname);
  renderQuestion();
  showView('quiz');
}

// ---- 이벤트 바인딩 ----
$('startBtn').addEventListener('click', () => {
  renderQuestion();
  showView('quiz');
});
$('optA').addEventListener('click', () => answer('A'));
$('optB').addEventListener('click', () => answer('B'));
$('backBtn').addEventListener('click', () => {
  if (state.current > 0) {
    state.current -= 1;
    renderQuestion();
  }
});
$('shareBtn').addEventListener('click', share);
$('retryBtn').addEventListener('click', reset);

// ?r=CODE 로 직접 진입한 경우 결과 바로 표시 (축 바 없이)
(function initFromUrl() {
  const code = new URLSearchParams(location.search).get('r');
  if (code && TYPES[code]) {
    state.shareUrl = new URL(`./r/${code}/?from=share`, window.location.href).href;
    renderResult(code, null);
    showView('result');
  }
})();
