import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/orders_repository.dart';
import '../domain/order_entry.dart';

final ordersProvider = FutureProvider<List<OrderEntry>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return [];
  }
  return ref.watch(ordersRepositoryProvider).listOrders();
});
