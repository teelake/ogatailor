import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  return d != null ? DateFormat('dd MMM yyyy').format(d.toLocal()) : iso;
}

String _currencySymbol(String currency) {
  return switch (currency.toUpperCase()) {
    'NGN' => '₦',
    'USD' => '\$',
    'GBP' => '£',
    _ => currency,
  };
}

/// Renders invoice for preview and image capture.
/// [currencySymbols] optional map of currency code -> symbol from platform config.
class InvoicePreviewWidget extends StatelessWidget {
  const InvoicePreviewWidget({
    super.key,
    required this.invoice,
    this.width = 400,
    this.currencySymbols,
  });

  final Map<String, dynamic> invoice;
  final double width;
  final Map<String, String>? currencySymbols;

  @override
  Widget build(BuildContext context) {
    final businessName = (invoice['business_name'] ?? '').toString();
    final businessPhone = (invoice['business_phone'] ?? '').toString();
    final businessEmail = (invoice['business_email'] ?? '').toString();
    final businessAddress = (invoice['business_address'] ?? '').toString();
    final customerName = (invoice['customer_name'] ?? '').toString();
    final customerPhone = (invoice['customer_phone'] ?? '').toString();
    final invoiceNumber = (invoice['invoice_number'] ?? '').toString();
    final issuedAt = _formatDate(invoice['issued_at']?.toString());
    final dueAt = _formatDate(invoice['due_at']?.toString());
    final currency = (invoice['currency'] ?? 'NGN').toString();
    final symbol = currencySymbols?[currency.toUpperCase()] ?? _currencySymbol(currency);
    final totalAmount = (invoice['total_amount'] ?? 0) as num;
    final items = (invoice['items'] as List<dynamic>?) ?? [];
    final logoBase64 = (invoice['logo_data'] as String?)?.trim();
    final watermark = invoice['watermark'] as Map<String, dynamic>?;
    final wmWebsiteUrl = watermark != null
        ? (watermark['website_url'] ?? 'https://ogatailor.app').toString().replaceFirst(RegExp(r'^https?://'), '')
        : null;

    final content = Container(
      width: width,
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logoBase64 != null && logoBase64.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    base64Decode(logoBase64),
                    width: 56,
                    height: 56,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INVOICE', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(businessName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    if (businessAddress.isNotEmpty) Text(businessAddress, style: const TextStyle(fontSize: 10)),
                    if (businessPhone.isNotEmpty) Text(businessPhone, style: const TextStyle(fontSize: 10)),
                    if (businessEmail.isNotEmpty) Text(businessEmail, style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Invoice #$invoiceNumber', style: const TextStyle(fontSize: 12)),
                  Text('Issued: $issuedAt', style: const TextStyle(fontSize: 10)),
                  Text('Due: $dueAt', style: const TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('BILL TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(customerName, style: const TextStyle(fontSize: 12)),
          if (customerPhone.isNotEmpty) Text(customerPhone, style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 24),
          Table(
            border: TableBorder.all(color: Colors.grey.shade300),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                  Padding(padding: EdgeInsets.all(8), child: Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                  Padding(padding: EdgeInsets.all(8), child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                  Padding(padding: EdgeInsets.all(8), child: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
                ],
              ),
              ...items.map<TableRow>((item) {
                final desc = (item['description'] ?? '').toString();
                final price = (item['unit_price'] ?? 0) as num;
                final qty = (item['quantity'] ?? 1) as num;
                final amount = (item['amount'] ?? 0) as num;
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(desc, style: const TextStyle(fontSize: 10))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('$symbol${price.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(qty.toStringAsFixed(0), style: const TextStyle(fontSize: 10))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('$symbol${amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 10))),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total: $symbol${totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (wmWebsiteUrl != null && wmWebsiteUrl.isNotEmpty) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          content,
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Transform.rotate(
                  angle: -0.5,
                  child: Opacity(
                    opacity: 0.15,
                    child: Text(wmWebsiteUrl, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return content;
  }
}
