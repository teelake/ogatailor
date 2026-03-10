import 'dart:async';

import 'package:dio/dio.dart';

import '../domain/customer.dart';

class CustomersRepository {
  CustomersRepository(this._dio);

  final Dio _dio;

  Future<List<Customer>> listCustomers({required String ownerUserId}) async {
    final response = await _dio.get(
      '/api/customers',
      queryParameters: {'owner_user_id': ownerUserId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final rows = List<Map<String, dynamic>>.from(data['data'] as List<dynamic>);
    return rows.map(Customer.fromJson).toList();
  }
}
