import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/time_format.dart';
import '../controller/book_search_controller.dart';
import '../model/aladin_book.dart';

/// 도서 원본 메타데이터(제목·저자·출판사·출판일)와 전체 소개글을 보여주는 화면.
/// [BookInfoScreen]의 요약 카드와 달리 잘림 없이 전체 정보를 보여주는 용도.
class BookDetailInfoScreen extends StatefulWidget {
  final AladinBook book;

  const BookDetailInfoScreen({super.key, required this.book});

  @override
  State<BookDetailInfoScreen> createState() => _BookDetailInfoScreenState();
}

class _BookDetailInfoScreenState extends State<BookDetailInfoScreen> {
  late AladinBook book = widget.book;

  @override
  void initState() {
    super.initState();
    _enrichIfNeeded();
  }

  /// 메타(출판사)나 전체 줄거리가 비어 있으면 ISBN으로 알라딘 ItemLookUp 보강.
  /// 검색 결과 책은 fullDescription이 없으므로 상세 화면에서 한 번 더 조회한다.
  Future<void> _enrichIfNeeded() async {
    final needsMeta = book.publisher.isEmpty;
    final needsFullDesc = (book.fullDescription?.trim().isEmpty ?? true);
    if (!needsMeta && !needsFullDesc) return;
    final isbn = book.isbn13?.trim();
    if (isbn == null || isbn.isEmpty) return;
    try {
      final results = await BookSearchNotifier.searchByIsbn(isbn);
      if (mounted && results.isNotEmpty) setState(() => book = results.first);
    } catch (_) {
      // ponytail: 보강 실패해도 기존 정보로 화면은 뜬다
    }
  }

  @override
  Widget build(BuildContext context) {
    final pubDate = DateTime.tryParse(book.pubDate ?? '');
    // 전체 줄거리(fullDescription) 우선, 없으면 짧은 소개(description).
    final description =
        (book.fullDescription?.trim().isNotEmpty == true
                ? book.fullDescription
                : book.description)
            ?.trim();

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
          style: AppTheme.sectionTitle.copyWith(color: context.appTextPrimary),
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
              style: AppTheme.body.copyWith(
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
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppTheme.spaceSM,
        children: [
          Text(
            label,
            style: AppTheme.supportingText.copyWith(
              color: context.appTextTertiary,
            ),
          ),
          Text(
            value,
            style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
          ),
        ],
      ),
    );
  }
}
