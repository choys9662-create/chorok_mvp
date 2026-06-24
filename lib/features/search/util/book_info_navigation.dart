import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/models/reading_session.dart';
import '../model/aladin_book.dart';

AladinBook bookInfoFromLibraryBook(Book book) {
  return AladinBook(
    title: book.title,
    author: book.author,
    publisher: '',
    coverUrl: book.coverUrl,
    isbn13: _bookInfoIsbn(book),
    description: book.description,
    totalPages: book.totalPages,
    genre: book.genre,
  );
}

void pushBookInfo(BuildContext context, Book book) {
  context.push(
    AppConstants.routeBookInfo,
    extra: bookInfoFromLibraryBook(book),
  );
}

String? _bookInfoIsbn(Book book) {
  final isbn = book.isbn?.trim();
  if (isbn != null && isbn.isNotEmpty) return isbn;

  final id = book.id.trim();
  if (RegExp(r'^(?:\d{10}|\d{13})$').hasMatch(id)) return id;
  return null;
}
