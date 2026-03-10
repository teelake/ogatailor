import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../../auth/application/auth_controller.dart';
import '../data/customers_repository.dart';
import '../domain/customer.dart';
import '../domain/measurement_entry.dart';

final customersRepositoryProvider = Provider<CustomersRepository>((ref) {
  return CustomersRepository(ref.watch(dioProvider), ref.watch(offlineSyncServiceProvider));
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final session = ref.watch(authControllerProvider).valueOrNull;
  if (session == null) {
    return [];
  }
  return ref.watch(customersRepositoryProvider).listCustomers();
});

final customerMeasurementsProvider =
    FutureProvider.family<List<MeasurementEntry>, String>((ref, customerId) async {
  return ref.watch(customersRepositoryProvider).listMeasurements(customerId: customerId);
});
