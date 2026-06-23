import 'package:flutter_test/flutter_test.dart';

import 'package:chorok_app/shared/utils/overlap_detector.dart';
import 'package:chorok_app/shared/utils/overlap_text_merger.dart';

void main() {
  test('양쪽 문맥을 합치고 공통 연속 문장만 강조한다', () {
    const neighbor = '나는 디자이너다. 나는 산업디자이너다. 나는 시각디자이너다.';
    const mine = '나는 산업디자이너다. 나는 시각디자이너다. 나는 기획자다.';
    final result = OverlapDetector.compare(mine, neighbor);

    final merged = mergeOverlapText(
      mine: mine,
      neighbor: neighbor,
      result: result,
    );

    expect(merged.content, '나는 디자이너다. 나는 산업디자이너다. 나는 시각디자이너다. 나는 기획자다.');
    expect(
      merged.content.substring(merged.highlight.start, merged.highlight.end),
      '나는 산업디자이너다. 나는 시각디자이너다.',
    );
  });

  test('완전히 같은 기록은 한 번만 표시한다', () {
    const content = '같은 문장을 기록했다.';
    final result = OverlapDetector.compare(content, content);

    final merged = mergeOverlapText(
      mine: content,
      neighbor: content,
      result: result,
    );

    expect(merged.content, content);
    expect(merged.highlight.start, 0);
    expect(merged.highlight.end, content.length);
  });
}
