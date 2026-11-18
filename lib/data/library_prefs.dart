import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/library_view.dart';
import 'settings.dart';

const _kView = 'library_view_v1';

class LibraryView {
  final LibraryFilter filter;
  final LibrarySort sort;
  const LibraryView({this.filter = LibraryFilter.todos, this.sort = LibrarySort.ultimoLeido});

  LibraryView copyWith({LibraryFilter? filter, LibrarySort? sort}) =>
      LibraryView(filter: filter ?? this.filter, sort: sort ?? this.sort);
}

final libraryViewProvider =
    NotifierProvider<LibraryViewNotifier, LibraryView>(LibraryViewNotifier.new);

class LibraryViewNotifier extends Notifier<LibraryView> {
  @override
  LibraryView build() {
    try {
      final raw = ref.read(prefsProvider).getString(_kView);
      if (raw == null) return const LibraryView();
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return LibraryView(
        filter: LibraryFilter.values.asNameMap()[m['filter']] ?? LibraryFilter.todos,
        sort: LibrarySort.values.asNameMap()[m['sort']] ?? LibrarySort.ultimoLeido,
      );
    } catch (_) {
      return const LibraryView();
    }
  }

  void update(LibraryView v) {
    state = v;
    ref.read(prefsProvider).setString(
        _kView, jsonEncode({'filter': v.filter.name, 'sort': v.sort.name}));
  }
}
