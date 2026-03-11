import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/error_message.dart';
import '../../customers/application/customers_controller.dart';

class ExportReportsScreen extends ConsumerStatefulWidget {
  const ExportReportsScreen({super.key});

  @override
  ConsumerState<ExportReportsScreen> createState() => _ExportReportsScreenState();
}

class _ExportReportsScreenState extends ConsumerState<ExportReportsScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedCustomerId;
  bool _loading = false;
  List<Map<String, dynamic>> _rows = const [];

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Export Reports')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Measurement Report Filters', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 10),
                    customersAsync.when(
                      data: (customers) => DropdownButtonFormField<String>(
                        value: _selectedCustomerId,
                        decoration: const InputDecoration(labelText: 'Customer (optional)'),
                        items: [
                          const DropdownMenuItem(value: '', child: Text('All customers')),
                          ...customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.fullName))),
                        ],
                        onChanged: (v) => setState(() => _selectedCustomerId = (v == '' ? null : v)),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => const Text('Could not load customers'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(start: true),
                            icon: const Icon(Icons.event_rounded),
                            label: Text(_startDate == null
                                ? 'Start date'
                                : DateFormat('dd MMM yyyy').format(_startDate!)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(start: false),
                            icon: const Icon(Icons.event_available_rounded),
                            label:
                                Text(_endDate == null ? 'End date' : DateFormat('dd MMM yyyy').format(_endDate!)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _loadReport,
                        icon: const Icon(Icons.download_rounded),
                        label: Text(_loading ? 'Loading...' : 'Generate Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_rows.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareSummary,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share Summary'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareCsv,
                      icon: const Icon(Icons.table_chart_rounded),
                      label: const Text('Share CSV'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('No report generated yet'))
                  : ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final row = _rows[i];
                        return Card(
                          child: ListTile(
                            title: Text((row['customer_name'] ?? '-').toString()),
                            subtitle: Text((row['taken_at'] ?? '-').toString()),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => _showPayload(row),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: start ? (_startDate ?? now) : (_endDate ?? now),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        '/api/export/measurements',
        queryParameters: {
          if (_selectedCustomerId != null) 'customer_id': _selectedCustomerId,
          if (_startDate != null) 'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
          if (_endDate != null) 'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
        },
      );
      final map = Map<String, dynamic>.from(response.data as Map);
      final rows = List<Map<String, dynamic>>.from((map['data'] ?? const <dynamic>[]) as List);
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userFriendlyError(error, fallback: 'Could not generate report. Please try again.'))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showPayload(Map<String, dynamic> row) {
    final payloadRaw = (row['payload_json'] ?? '{}').toString();
    final payload = jsonDecode(payloadRaw);
    final map = payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{};
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text((row['customer_name'] ?? 'Measurement').toString()),
        content: SizedBox(
          width: 360,
          child: ListView(
            shrinkWrap: true,
            children: map.entries.map((e) => ListTile(dense: true, title: Text(e.key), trailing: Text('${e.value}'))).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _shareSummary() async {
    final lines = <String>[
      'Oga Tailor Measurement Report',
      'Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}',
      '',
    ];
    for (final row in _rows) {
      lines.add('- ${row['customer_name']} | ${row['taken_at']}');
    }
    await Share.share(lines.join('\n'));
  }

  Future<void> _shareCsv() async {
    final buffer = StringBuffer();
    buffer.writeln('customer_name,taken_at,payload_json');
    for (final row in _rows) {
      final customer = _csv(row['customer_name']);
      final taken = _csv(row['taken_at']);
      final payload = _csv(row['payload_json']);
      buffer.writeln('$customer,$taken,$payload');
    }
    await Share.share(buffer.toString());
  }

  String _csv(Object? value) {
    final raw = (value ?? '').toString().replaceAll('"', '""');
    return '"$raw"';
  }
}
