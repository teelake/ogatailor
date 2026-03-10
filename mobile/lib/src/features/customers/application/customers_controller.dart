import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/application/auth_controller.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.watch(dioProvider));
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return [];
  }
  return ref.watch(customersRepositoryProvider).listCustomers(ownerUserId: session.userId);
});
