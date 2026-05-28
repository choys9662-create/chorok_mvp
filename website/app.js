import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const config = window.CHOROK_CONFIG;
const supabase = createClient(config.supabaseUrl, config.supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
  },
});

const state = {
  user: null,
  profile: null,
  books: [],
  sessions: [],
  sentences: [],
  activeSection: 'overview',
  authMode: 'login',
};

const $ = (selector) => document.querySelector(selector);
const $$ = (selector) => Array.from(document.querySelectorAll(selector));

const views = {
  auth: $('[data-view="auth"]'),
  dashboard: $('[data-view="dashboard"]'),
};

const formatDate = (value) => {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return new Intl.DateTimeFormat('ko-KR', {
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date);
};

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));

const progressOf = (book) => {
  const total = Number(book.total_pages ?? 0);
  const current = Number(book.current_page ?? 0);
  if (!total) return 0;
  return clamp(Math.round((current / total) * 100), 0, 100);
};

const escapeHtml = (value = '') =>
  String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');

const normalizeSentence = (value = '') =>
  value
    .trim()
    .replace(/\s+/g, ' ')
    .replace(/[“”"'‘’.,!?;:()[\]{}<>《》「」『』]/g, '')
    .toLowerCase();

function toast(message) {
  const node = $('#toast');
  node.textContent = message;
  node.classList.add('visible');
  window.setTimeout(() => node.classList.remove('visible'), 2600);
}

function showAuthMessage(message) {
  $('#authMessage').textContent = message;
}

function showView(name) {
  views.auth.classList.toggle('hidden', name !== 'auth');
  views.dashboard.classList.toggle('hidden', name !== 'dashboard');
}

function setAuthMode(mode) {
  state.authMode = mode;
  const copy = {
    login: ['로그인', '초록 계정으로 계속하기', '이메일로 로그인'],
    signup: ['가입', '새 계정 만들기', '계정 만들기'],
    reset: ['재설정', '비밀번호 재설정', '재설정 메일 보내기'],
  };
  const [kicker, title, submit] = copy[mode];
  $('#authKicker').textContent = kicker;
  $('#authTitle').textContent = title;
  $('#authSubmit').textContent = submit;
  $('#password').required = mode !== 'reset';
  $('.signup-only').classList.toggle('hidden', mode !== 'signup');
  $('.oauth-only').classList.toggle('hidden', mode === 'reset');
  $$('.auth-tab').forEach((button) => {
    button.classList.toggle('active', button.dataset.authMode === mode);
  });
  showAuthMessage('');
}

async function loadProfile() {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, username, display_name, avatar_url')
    .eq('id', state.user.id)
    .maybeSingle();
  if (error) throw error;
  state.profile = data;
}

async function loadBooks() {
  const { data, error } = await supabase
    .from('books')
    .select('*')
    .eq('user_id', state.user.id)
    .order('updated_at', { ascending: false });
  if (error) throw error;
  state.books = data ?? [];
}

async function loadSessions() {
  const weekStart = new Date();
  weekStart.setHours(0, 0, 0, 0);
  weekStart.setDate(weekStart.getDate() - ((weekStart.getDay() + 6) % 7));

  const { data, error } = await supabase
    .from('reading_sessions')
    .select('id, duration_seconds, ended_at, started_at, books(title, author)')
    .eq('user_id', state.user.id)
    .gte('ended_at', weekStart.toISOString())
    .order('ended_at', { ascending: false });
  if (error) throw error;
  state.sessions = data ?? [];
}

async function loadSentences() {
  const { data, error } = await supabase
    .from('sentences')
    .select(
      'id, content, thought, page_number, created_at, book_id, books(title, author, cover_url)'
    )
    .eq('user_id', state.user.id)
    .order('created_at', { ascending: false })
    .limit(80);
  if (error) throw error;
  state.sentences = data ?? [];
}

async function refreshData() {
  await Promise.all([loadProfile(), loadBooks(), loadSessions(), loadSentences()]);
  render();
}

function render() {
  const displayName =
    state.profile?.display_name || state.profile?.username || state.user?.email || '독자';
  $('#profileName').textContent = displayName;

  const reading = state.books.filter((book) => book.status === 'reading');
  const completed = state.books.filter((book) => book.status === 'completed');
  const weeklyMinutes = state.sessions.reduce(
    (sum, session) => sum + Math.round(Number(session.duration_seconds ?? 0) / 60),
    0
  );

  $('#readingCount').textContent = reading.length;
  $('#completedCount').textContent = completed.length;
  $('#weeklyMinutes').textContent = `${weeklyMinutes}분`;
  $('#sentenceCount').textContent = state.sentences.length;

  renderFocusBook(reading[0] ?? state.books[0]);
  renderBooks();
  renderSentences('#recentSentences', state.sentences.slice(0, 4));
  renderSentences('#sentenceList', state.sentences);
  switchSection(state.activeSection);
}

function renderFocusBook(book) {
  const node = $('#focusBook');
  if (!book) {
    node.className = 'focus-book empty-state';
    node.textContent = '읽는 중인 책이 없습니다.';
    return;
  }

  const progress = progressOf(book);
  node.className = 'focus-book';
  node.innerHTML = `
    <div class="focus-book-content">
      <div class="cover" style="${book.cover_url ? `background-image:url('${escapeHtml(book.cover_url)}')` : ''}"></div>
      <div>
        <h3 class="book-title">${escapeHtml(book.title)}</h3>
        <p class="muted">${escapeHtml(book.author ?? '')}</p>
        <div class="progress-track"><div class="progress-fill" style="width:${progress}%"></div></div>
        <p class="muted">${Number(book.current_page ?? 0)} / ${Number(book.total_pages ?? 0)}쪽 · ${progress}%</p>
        <div class="book-actions">
          <button class="ghost-action" data-progress="${escapeHtml(book.book_id)}">페이지 수정</button>
          <button class="primary-action" data-sentence="${escapeHtml(book.book_id)}">문장 저장</button>
        </div>
      </div>
    </div>
  `;
}

function renderBooks() {
  const node = $('#bookGrid');
  if (!state.books.length) {
    node.innerHTML = '<div class="empty-state">아직 서재에 책이 없습니다.</div>';
    return;
  }

  node.innerHTML = state.books
    .map((book) => {
      const progress = progressOf(book);
      return `
        <article class="book-card">
          <div class="cover" style="${book.cover_url ? `background-image:url('${escapeHtml(book.cover_url)}')` : ''}"></div>
          <div>
            <h3>${escapeHtml(book.title)}</h3>
            <p class="muted">${escapeHtml(book.author ?? '')}</p>
            <div class="progress-track"><div class="progress-fill" style="width:${progress}%"></div></div>
            <p class="muted">${Number(book.current_page ?? 0)} / ${Number(book.total_pages ?? 0)}쪽</p>
            <div class="book-actions">
              <button class="ghost-action" data-progress="${escapeHtml(book.book_id)}">페이지 수정</button>
              <button class="primary-action" data-sentence="${escapeHtml(book.book_id)}">문장 저장</button>
            </div>
          </div>
        </article>
      `;
    })
    .join('');
}

function renderSessionBookOptions() {
  const select = $('#sessionBookSelect');
  if (!state.books.length) {
    select.innerHTML = '<option value="">책 없음</option>';
    select.disabled = true;
    return;
  }
  select.disabled = false;
  select.innerHTML = state.books
    .map(
      (book) =>
        `<option value="${escapeHtml(book.book_id)}">${escapeHtml(book.title)}</option>`
    )
    .join('');
}

function renderSentences(selector, sentences) {
  const node = $(selector);
  if (!sentences.length) {
    node.innerHTML = '<div class="empty-state">아직 저장된 문장이 없습니다.</div>';
    return;
  }

  node.innerHTML = sentences
    .map((sentence) => {
      const book = sentence.books;
      return `
        <article class="sentence-card">
          <blockquote>${escapeHtml(sentence.content)}</blockquote>
          ${
            sentence.thought
              ? `<p class="muted">${escapeHtml(sentence.thought)}</p>`
              : ''
          }
          <footer>
            ${escapeHtml(book?.title ?? '알 수 없는 책')}
            ${sentence.page_number ? ` · ${sentence.page_number}쪽` : ''}
            · ${formatDate(sentence.created_at)}
          </footer>
        </article>
      `;
    })
    .join('');
}

function switchSection(section) {
  state.activeSection = section;
  const titles = {
    overview: '오늘의 독서 흐름',
    library: '데스크톱 서재',
    sentences: '수집한 문장',
  };

  $('#pageTitle').textContent = titles[section];
  $$('.nav-item').forEach((button) => {
    button.classList.toggle('active', button.dataset.section === section);
  });
  $('#overviewSection').classList.toggle('hidden', section !== 'overview');
  $('#librarySection').classList.toggle('hidden', section !== 'library');
  $('#sentencesSection').classList.toggle('hidden', section !== 'sentences');
}

async function signIn(email, password) {
  const { error } = await supabase.auth.signInWithPassword({ email, password });
  if (error) throw error;
}

async function signUp(email, password, username) {
  const trimmedUsername = username.trim();
  if (trimmedUsername.length < 2) {
    throw new Error('닉네임은 2자 이상 입력해주세요.');
  }

  const { data: available, error: rpcError } = await supabase.rpc(
    'is_username_available',
    { p_username: trimmedUsername }
  );
  if (rpcError) throw rpcError;
  if (!available) throw new Error('이미 사용 중인 닉네임입니다.');

  const { error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: window.location.origin,
      data: {
        username: trimmedUsername,
        display_name: trimmedUsername,
      },
    },
  });
  if (error) throw error;
}

async function resetPassword(email) {
  const { error } = await supabase.auth.resetPasswordForEmail(email, {
    redirectTo: window.location.origin,
  });
  if (error) throw error;
}

async function createBook(values) {
  const bookId =
    window.crypto?.randomUUID?.() ?? `web_${Date.now()}_${Math.random().toString(16).slice(2)}`;
  const { error } = await supabase.from('books').insert({
    user_id: state.user.id,
    book_id: bookId,
    title: values.get('title').trim(),
    author: values.get('author').trim(),
    total_pages: Number(values.get('total_pages')) || 0,
    current_page: 0,
    cover_url: values.get('cover_url').trim() || null,
    status: 'reading',
    updated_at: new Date().toISOString(),
  });
  if (error) throw error;
}

async function saveProgress(values) {
  const bookId = values.get('book_id');
  const book = state.books.find((item) => item.book_id === bookId);
  if (!book) return;
  const currentPage = clamp(
    Number(values.get('current_page')) || 0,
    0,
    Number(book.total_pages ?? 0) || 99999
  );
  const status =
    Number(book.total_pages ?? 0) > 0 && currentPage >= Number(book.total_pages)
      ? 'completed'
      : 'reading';

  const { error } = await supabase
    .from('books')
    .update({
      current_page: currentPage,
      status,
      completed_at: status === 'completed' ? new Date().toISOString() : null,
      updated_at: new Date().toISOString(),
    })
    .eq('user_id', state.user.id)
    .eq('book_id', bookId);
  if (error) throw error;
}

async function createSentence(values) {
  const book = state.books.find((item) => item.book_id === values.get('book_id'));
  const content = values.get('content').trim();
  const { error } = await supabase.from('sentences').insert({
    user_id: state.user.id,
    book_id: book?.id ?? null,
    global_book_id: book?.global_book_id ?? null,
    content,
    thought: values.get('thought').trim() || null,
    page_number: Number(values.get('page_number')) || null,
    normalized_sentences: [normalizeSentence(content)],
  });
  if (error) throw error;
}

async function createSession(values) {
  const book = state.books.find((item) => item.book_id === values.get('book_id'));
  const minutes = Number(values.get('minutes')) || 0;
  if (!book) throw new Error('기록할 책을 먼저 추가해주세요.');
  if (minutes <= 0) throw new Error('읽은 시간을 입력해주세요.');

  const endedAt = new Date();
  const startedAt = new Date(endedAt.getTime() - minutes * 60 * 1000);
  const { error } = await supabase.from('reading_sessions').insert({
    user_id: state.user.id,
    book_id: book.id,
    duration_seconds: minutes * 60,
    sentence_count: 0,
    pages_read: Number(values.get('pages_read')) || 0,
    started_at: startedAt.toISOString(),
    ended_at: endedAt.toISOString(),
  });
  if (error) throw error;
}

function openSentenceDialog(bookId) {
  const book = state.books.find((item) => item.book_id === bookId);
  if (!book) return;
  $('#sentenceBookTitle').textContent = book.title;
  $('#sentenceForm').elements.book_id.value = bookId;
  $('#sentenceDialog').showModal();
}

function openProgressDialog(bookId) {
  const book = state.books.find((item) => item.book_id === bookId);
  if (!book) return;
  $('#progressBookTitle').textContent = book.title;
  $('#progressForm').elements.book_id.value = bookId;
  $('#progressForm').elements.current_page.value = book.current_page ?? 0;
  $('#progressDialog').showModal();
}

function bindEvents() {
  $('#authForm').addEventListener('submit', async (event) => {
    event.preventDefault();
    showAuthMessage('');
    try {
      const email = $('#email').value.trim();
      const password = $('#password').value;
      if (state.authMode === 'login') {
        await signIn(email, password);
      } else if (state.authMode === 'signup') {
        await signUp(email, password, $('#username').value);
        showAuthMessage('확인 메일을 보냈습니다. 메일함을 확인해주세요.');
      } else {
        await resetPassword(email);
        showAuthMessage('비밀번호 재설정 메일을 보냈습니다.');
      }
    } catch (error) {
      showAuthMessage(error.message ?? '처리에 실패했습니다.');
    }
  });

  $$('.auth-tab').forEach((button) => {
    button.addEventListener('click', () => setAuthMode(button.dataset.authMode));
  });

  $('#googleLogin').addEventListener('click', async () => {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: window.location.origin },
    });
    if (error) showAuthMessage(error.message);
  });

  $('#signOut').addEventListener('click', () => supabase.auth.signOut());
  $('#refreshData').addEventListener('click', async () => {
    await refreshData();
    toast('최신 데이터로 갱신했습니다.');
  });

  $$('.nav-item').forEach((button) => {
    button.addEventListener('click', () => switchSection(button.dataset.section));
  });

  $$('[data-section-shortcut]').forEach((button) => {
    button.addEventListener('click', () => switchSection(button.dataset.sectionShortcut));
  });

  $('#openBookDialog').addEventListener('click', () => $('#bookDialog').showModal());
  $('#openSessionDialog').addEventListener('click', () => {
    renderSessionBookOptions();
    $('#sessionDialog').showModal();
  });
  $('#closeBookDialog').addEventListener('click', () => $('#bookDialog').close());
  $('#closeSentenceDialog').addEventListener('click', () => $('#sentenceDialog').close());
  $('#closeProgressDialog').addEventListener('click', () => $('#progressDialog').close());
  $('#closeSessionDialog').addEventListener('click', () => $('#sessionDialog').close());

  $('#bookForm').addEventListener('submit', async (event) => {
    event.preventDefault();
    try {
      await createBook(new FormData(event.currentTarget));
      $('#bookDialog').close();
      event.currentTarget.reset();
      await refreshData();
      toast('책을 추가했습니다.');
    } catch (error) {
      toast(error.message ?? '책 저장에 실패했습니다.');
    }
  });

  $('#sentenceForm').addEventListener('submit', async (event) => {
    event.preventDefault();
    try {
      await createSentence(new FormData(event.currentTarget));
      $('#sentenceDialog').close();
      event.currentTarget.reset();
      await refreshData();
      toast('문장을 저장했습니다.');
    } catch (error) {
      toast(error.message ?? '문장 저장에 실패했습니다.');
    }
  });

  $('#progressForm').addEventListener('submit', async (event) => {
    event.preventDefault();
    try {
      await saveProgress(new FormData(event.currentTarget));
      $('#progressDialog').close();
      await refreshData();
      toast('페이지를 수정했습니다.');
    } catch (error) {
      toast(error.message ?? '페이지 수정에 실패했습니다.');
    }
  });

  $('#sessionForm').addEventListener('submit', async (event) => {
    event.preventDefault();
    try {
      await createSession(new FormData(event.currentTarget));
      $('#sessionDialog').close();
      event.currentTarget.reset();
      await refreshData();
      toast('독서 기록을 추가했습니다.');
    } catch (error) {
      toast(error.message ?? '독서 기록 저장에 실패했습니다.');
    }
  });

  document.body.addEventListener('click', async (event) => {
    const progressButton = event.target.closest('[data-progress]');
    const sentenceButton = event.target.closest('[data-sentence]');

    try {
      if (progressButton) {
        openProgressDialog(progressButton.dataset.progress);
      }
      if (sentenceButton) {
        openSentenceDialog(sentenceButton.dataset.sentence);
      }
    } catch (error) {
      toast(error.message ?? '처리 중 오류가 발생했습니다.');
    }
  });
}

async function boot() {
  bindEvents();
  setAuthMode('login');
  const { data } = await supabase.auth.getSession();
  state.user = data.session?.user ?? null;
  if (state.user) {
    showView('dashboard');
    await refreshData();
  } else {
    showView('auth');
  }

  supabase.auth.onAuthStateChange(async (_event, session) => {
    state.user = session?.user ?? null;
    if (!state.user) {
      showView('auth');
      return;
    }
    showView('dashboard');
    await refreshData();
  });
}

boot().catch((error) => {
  console.error(error);
  toast(error.message ?? '초기화에 실패했습니다.');
});
