import 'package:flutter/material.dart';

/// Supabase Auth 에러 → 한국어 사용자 메시지
String localizeAuthError(String msg) {
  final lower = msg.toLowerCase();
  if (lower.contains('invalid login credentials')) {
    return '이메일 또는 비밀번호가 올바르지 않아요.';
  }
  if (lower.contains('email not confirmed')) {
    return '이메일 인증이 필요해요. 받은 편지함을 확인해주세요.';
  }
  if (lower.contains('user already registered')) return '이미 가입된 이메일이에요.';
  if (lower.contains('password should be')) return '비밀번호는 6자 이상이어야 해요.';
  if (lower.contains('network')) return '네트워크 연결을 확인해주세요.';
  return '로그인 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.';
}

/// 인증 화면 전용 에러 스낵바 — 다크 테마 고정 (인증 화면이 다크-only)
void showAuthError(BuildContext context, String rawMessage) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Text(
          localizeAuthError(rawMessage),
          style: const TextStyle(
            fontFamily: 'ChosunGu',
            color: Colors.white,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        backgroundColor: const Color(0xFFB00020),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
}
