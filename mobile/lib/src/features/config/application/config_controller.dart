import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/config_repository.dart';

final appConfigProvider = FutureProvider<AppConfig?>((ref) async {
  try {
    return await ref.read(configRepositoryProvider).fetchConfig();
  } catch (_) {
    return null;
  }
});
