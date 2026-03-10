import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/plan_repository.dart';
import '../domain/plan_summary.dart';

final planSummaryProvider = FutureProvider<PlanSummary?>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return null;
  }
  return ref.watch(planRepositoryProvider).fetchSummary();
});
