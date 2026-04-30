import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/user_profile.dart';
import '../../../shared/repositories/profile_repository.dart';
import '../../../shared/repositories/follow_repository.dart';

enum UserSearchScope { all, following, followers }

class UserSearchNotifier extends AsyncNotifier<List<UserProfile>> {
  UserSearchScope _scope = UserSearchScope.all;
  String _lastQuery = '';

  @override
  Future<List<UserProfile>> build() async => const [];

  Future<void> search(String query, {UserSearchScope? scope}) async {
    final q = query.trim();
    _lastQuery = q;
    if (scope != null) _scope = scope;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_run);
  }

  void setScope(UserSearchScope scope) {
    if (_scope == scope) return;
    _scope = scope;
    state = const AsyncValue.loading();
    state = AsyncValue.data(const []);
    if (_lastQuery.isNotEmpty) {
      search(_lastQuery, scope: scope);
    } else if (scope != UserSearchScope.all) {
      // 빈 쿼리여도 팔로잉/팔로워 목록은 바로 보여줌
      search('', scope: scope);
    }
  }

  void clear() {
    _lastQuery = '';
    state = const AsyncValue.data([]);
  }

  Future<List<UserProfile>> _run() async {
    final repo = ref.read(profileRepositoryProvider);
    final follows = ref.read(followRepositoryProvider);
    return switch (_scope) {
      UserSearchScope.all => _lastQuery.isEmpty
          ? const []
          : repo.searchUsers(_lastQuery),
      UserSearchScope.following => follows.searchFollowing(_lastQuery),
      UserSearchScope.followers => follows.searchFollowers(_lastQuery),
    };
  }
}

final userSearchProvider =
    AsyncNotifierProvider<UserSearchNotifier, List<UserProfile>>(
      UserSearchNotifier.new,
    );
