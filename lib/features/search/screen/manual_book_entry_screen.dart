import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/reading_session.dart';
import '../../../shared/providers/library_provider.dart';
import '../../../shared/widgets/chorok_back_button.dart';
import '../../../shared/widgets/chorok_button.dart';
import '../../../shared/widgets/chorok_snackbar.dart';
import '../widget/add_to_library_sheet.dart';

class ManualBookEntryScreen extends ConsumerStatefulWidget {
  const ManualBookEntryScreen({super.key});

  @override
  ConsumerState<ManualBookEntryScreen> createState() =>
      _ManualBookEntryScreenState();
}

class _ManualBookEntryScreenState extends ConsumerState<ManualBookEntryScreen> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _pagesController = TextEditingController();
  bool _submitting = false;

  int? get _pages => int.tryParse(_pagesController.text);

  bool get _canSubmit =>
      !_submitting &&
      _titleController.text.trim().isNotEmpty &&
      _authorController.text.trim().isNotEmpty &&
      (_pages ?? 0) > 0;

  String? get _pageError {
    if (_pagesController.text.isEmpty || (_pages ?? 0) > 0) return null;
    return '1쪽 이상 입력해 주세요';
  }

  @override
  void initState() {
    super.initState();
    _titleController.addListener(_refresh);
    _authorController.addListener(_refresh);
    _pagesController.addListener(_refresh);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_refresh)
      ..dispose();
    _authorController
      ..removeListener(_refresh)
      ..dispose();
    _pagesController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;

    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final pages = _pages!;
    final status = await showReadingStatusSheet(context, title);
    if (status == null || !mounted) return;

    final notifier = ref.read(libraryProvider.notifier);
    if (notifier.containsByTitleAuthor(title, author)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '이미 서재에 있는 책이에요', success: false));
      return;
    }

    setState(() => _submitting = true);
    final book = Book(
      id: 'manual_${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      author: author,
      totalPages: pages,
      status: status,
    );
    final added = notifier.addBook(book);
    if (!mounted) return;
    if (!added) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(chorokSnackBar(context, '이미 서재에 있는 책이에요', success: false));
      return;
    }
    Navigator.of(context).pop(book);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      appBar: AppBar(
        leading: ChorokBackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('책 직접 입력'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppTheme.screenPadding,
            AppTheme.spaceLG,
            AppTheme.screenPadding,
            MediaQuery.viewInsetsOf(context).bottom + AppTheme.sectionGap,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppTheme.spaceLG,
            children: [
              Text(
                '검색이나 바코드로 찾을 수 없는 책만 직접 입력해 주세요.',
                style: AppTheme.body.copyWith(color: context.appTextSecondary),
              ),
              TextField(
                key: const ValueKey('manual-title-field'),
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
                decoration: const InputDecoration(labelText: '제목'),
              ),
              TextField(
                key: const ValueKey('manual-author-field'),
                controller: _authorController,
                textInputAction: TextInputAction.next,
                style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
                decoration: const InputDecoration(labelText: '작가'),
              ),
              TextField(
                key: const ValueKey('manual-pages-field'),
                controller: _pagesController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _submit(),
                style: AppTheme.rowText.copyWith(color: context.appTextPrimary),
                decoration: InputDecoration(
                  labelText: '페이지 수',
                  suffixText: '쪽',
                  errorText: _pageError,
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),
              ChorokButton(
                label: '서재에 추가',
                onPressed: _canSubmit ? _submit : null,
                expand: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
