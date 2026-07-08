import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/time_format.dart';
import '../model/aladin_book.dart';

/// 도서 원본 메타데이터(제목·저자·출판사·출판일)와 전체 소개글을 보여주는 화면.
/// [BookInfoScreen]의 요약 카드와 달리 잘림 없이 전체 정보를 보여주는 용도.
class BookDetailInfoScreen extends StatelessWidget {
  final AladinBook book;

  const BookDetailInfoScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final pubDate = DateTime.tryParse(book.pubDate ?? '');
    final description = book.description?.trim();

    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        backgroundColor: context.appBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: context.appTextPrimary,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            context.pop();
          },
        ),
        title: Text(
          '도서 정보',
          style: AppTheme.headingSmall.copyWith(color: context.appTextPrimary),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.screenPadding,
          vertical: AppTheme.spaceMD,
        ),
        children: [
          _InfoRow(label: '제목', value: book.title),
          Divider(height: 1, color: context.appBorder),
          _InfoRow(label: '저자', value: book.author),
          Divider(height: 1, color: context.appBorder),
          _InfoRow(
            label: '출판사',
            value: book.publisher.isNotEmpty ? book.publisher : '-',
          ),
          Divider(height: 1, color: context.appBorder),
          _InfoRow(
            label: '출판일',
            value: pubDate != null ? formatKoreanDate(pubDate) : '-',
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: context.appTextSecondary,
                height: 1.7,
              ),
            ),
          ],
          const SizedBox(height: AppTheme.space2XL),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: context.appTextTertiary),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: context.appTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
