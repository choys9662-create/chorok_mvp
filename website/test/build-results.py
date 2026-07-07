#!/usr/bin/env python3
"""r/{CODE}/index.html 16개 정적 결과 페이지 생성.

OG 크롤러(카톡/인스타/트위터)는 JS를 실행하지 않으므로,
공유 미리보기용 메타 태그는 정적 HTML에 박혀 있어야 한다.
types.js의 유형 데이터를 파싱해 페이지를 만든다.

사용법: python3 build-results.py
"""

import json
import re
from pathlib import Path

ROOT = Path(__file__).parent
TYPES_JS = (ROOT / "types.js").read_text(encoding="utf-8")

# types.js에서 유형 객체 추출 (name/tagline/desc/tips/mate)
pattern = re.compile(
    r"(\w{4}):\s*\{\s*"
    r"name:\s*'([^']*)',\s*"
    r"tagline:\s*'([^']*)',\s*"
    r"desc:\s*'([^']*)',\s*"
    r"tips:\s*\[(.*?)\],\s*"
    r"mate:\s*'(\w{4})',",
    re.S,
)

types = {}
for m in pattern.finditer(TYPES_JS):
    code, name, tagline, desc, tips_raw, mate = m.groups()
    tips = re.findall(r"'([^']*)'", tips_raw)
    types[code] = {
        "name": name,
        "tagline": tagline,
        "desc": desc,
        "tips": tips,
        "mate": mate,
    }

assert len(types) == 16, f"유형이 16개가 아님: {len(types)}개 파싱됨"

TEMPLATE = """<!doctype html>
<html lang="ko">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>{name} — 독서 유형 테스트</title>
    <meta name="description" content="{tagline}" />
    <meta property="og:type" content="website" />
    <meta property="og:title" content="나의 독서 유형은 {name} ({code})" />
    <meta property="og:description" content="{tagline} 너는 어떤 독서가야? 1분 테스트" />
    <meta property="og:image" content="../../og/{code}.png" />
    <meta name="twitter:card" content="summary_large_image" />
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link
      href="https://fonts.googleapis.com/css2?family=Gowun+Batang:wght@400;700&family=IBM+Plex+Sans+KR:wght@400;500;600;700&display=swap"
      rel="stylesheet"
    />
    <link rel="stylesheet" href="../../test.css" />
  </head>
  <body>
    <main class="quiz-shell">
      <section class="view view-result">
        <p class="eyebrow">READING TYPE</p>
        <p class="result-code">{code}</p>
        <h2 class="result-name">{name}</h2>
        <p class="result-tagline">{tagline}</p>
        <p class="result-desc">{desc}</p>

        <div class="result-block">
          <h3>이 유형에게 잘 맞는 독서법</h3>
          <ol>
{tips_html}
          </ol>
        </div>

        <div class="result-block mate-block">
          <h3>잘 맞는 독서메이트</h3>
          <p><strong>{mate} {mate_name}</strong> — 서로 다른 방식이 균형을 만들어요.</p>
        </div>

        <div class="result-actions">
          <a class="primary-btn" style="display:block;text-align:center;text-decoration:none" href="../../">
            나도 테스트하기
          </a>
        </div>

        <a class="cta-card" href="https://instagram.com/" target="_blank" rel="noopener">
          <p class="cta-kicker">🌱 곧 만나요</p>
          <strong>문장을 모으는 독서 앱, 초록</strong>
          <span>방해 없는 독서 시간과 겹치는 문장의 발견. 출시 소식 받아보기 →</span>
        </a>
      </section>
    </main>
  </body>
</html>
"""

for code, t in types.items():
    out_dir = ROOT / "r" / code
    out_dir.mkdir(parents=True, exist_ok=True)
    tips_html = "\n".join(
        f"            <li>{tip}</li>" for tip in t["tips"]
    )
    html = TEMPLATE.format(
        code=code,
        name=t["name"],
        tagline=t["tagline"],
        desc=t["desc"],
        tips_html=tips_html,
        mate=t["mate"],
        mate_name=types[t["mate"]]["name"],
    )
    (out_dir / "index.html").write_text(html, encoding="utf-8")

print(f"OK — {len(types)}개 결과 페이지 생성 완료 (r/CODE/index.html)")
print(json.dumps(sorted(types.keys()), ensure_ascii=False))
