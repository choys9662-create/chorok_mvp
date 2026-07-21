import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_flags.dart';

/// 내 표시 이름. 없으면 null.
///
/// 홈·탐색의 "OO님 맞춤 추천 책" 헤더가 공유한다.
final myDisplayNameProvider = FutureProvider.autoDispose<String?>((ref) async {
  if (kUseMock) return '준돌돔';

  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return null;
  final res = await Supabase.instance.client
      .from('profiles')
      .select('display_name')
      .eq('id', uid)
      .maybeSingle();
  final name = res?['display_name'] as String?;
  return (name != null && name.isNotEmpty) ? name : null;
});
