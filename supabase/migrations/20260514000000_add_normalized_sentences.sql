-- sentences 테이블에 normalized_sentences 배열과 thought 컬럼 추가
ALTER TABLE sentences
  ADD COLUMN IF NOT EXISTS normalized_sentences TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS thought TEXT;

-- 배열 포함 검색을 위한 GIN 인덱스
CREATE INDEX IF NOT EXISTS sentences_normalized_gin
  ON sentences USING GIN(normalized_sentences);
