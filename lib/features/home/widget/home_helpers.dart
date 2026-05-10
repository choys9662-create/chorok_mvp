const kGoalMessages = [
  '오늘 목표 완료! 멈추라고는 안 했어요',
  '30분 달성! 이 기세 계속 가요',
  '오늘의 독서 완료. 내일도 이 기세로요',
  '훌륭해요. 이게 쌓이면 습관이 돼요',
];

const kStreakSuffix = ['오늘 빠지면 너무 아깝잖아요', '이 기록, 오늘도 이어가요', '여기서 멈추실 건 아니죠?'];

const kSlackMessages = [
  '요즘 바쁘신가봐요?',
  '채식주의자가 186페이지에서 기다리고 있어요',
  '책이 먼지 쌓이기 시작했어요',
  '독서는 하루 건너뛰면 이틀 잊어요',
  '오늘 딱 5분만요. 딱 5분',
];

const kNudgeMessages = ['오늘 첫 독서를 시작해볼까요?', '딱 10분만 읽어볼까요?', '책이 기다리고 있어요'];

int calcReadStreak(int todayIndex) {
  int streak = 0;
  for (int i = todayIndex - 1; i >= 0; i--) {
    if (kWeeklyMinutes[i] >= 30) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}

int daysSinceLastRead(int todayIndex) {
  for (int i = todayIndex - 1; i >= 0; i--) {
    if (kWeeklyMinutes[i] > 0) return todayIndex - i;
  }
  return todayIndex + 1;
}

const List<int> kWeeklyMinutes = [42, 28, 55, 0, 35, 18, 0];

String todayInsightText(int todayMinutes, int exitCount, int goalMinutes) {
  if (todayMinutes <= 0) return '';
  if (todayMinutes >= goalMinutes) {
    if (exitCount == 0) return '한 번도 안 나가셨어요. 완전한 몰입이었어요';
    return '오늘 목표를 달성했어요! 내일도 이 기세로요';
  }
  
  final remaining = goalMinutes - todayMinutes;
  return '오늘 $remaining분만 더 읽어볼까요?';
}