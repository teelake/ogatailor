import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/format_amount.dart';

/// A4 content width in logical pixels (matches PDF layout).
const double kInvoiceDocumentWidth = 531;

String _formatDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  return d != null ? DateFormat('dd MMM yyyy').format(d.toLocal()) : iso;
}

String _formatInvoiceStatus(String status) {
  return switch (status.toLowerCase()) {
    'paid' => 'Paid',
    'partially_paid' => 'Partially paid',
    'overdue' => 'Overdue',
    'draft' => 'Draft',
    _ => 'Unpaid',
  };
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
/// Layout matches PDF format for consistent appearance.
/// [currencySymbols] optional map of currency code -> symbol from platform config.
class InvoicePreviewWidget extends StatelessWidget {
  const InvoicePreviewWidget({
    super.key,
    required this.invoice,
    this.width = kInvoiceDocumentWidth,
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
    final totalAmount = parseAmount(invoice['total_amount']);
    final subtotalAmount = parseAmount(invoice['subtotal_amount']);
    final vatEnabled = (invoice['vat_enabled'] ?? false) == true;
    final vatRate = (invoice['default_vat_rate'] as num?)?.toDouble() ?? 0;
    final vatAmount = vatEnabled ? totalAmount - subtotalAmount : 0.0;
    final status = (invoice['status'] ?? 'issued').toString();
    final items = (invoice['items'] as List<dynamic>?) ?? [];
    final logoBase64 = (invoice['logo_data'] as String?)?.trim();
    final watermark = invoice['watermark'] as Map<String, dynamic>?;
    final wmType = (watermark?['type'] ?? 'both').toString();
    final wmLogoUrl = (watermark?['logo_url'] as String?)?.trim();
    final wmWebsiteUrl = watermark != null
        ? (watermark['website_url'] ?? 'https://ogatailor.app').toString().replaceFirst(RegExp(r'^https?://'), '')
        : null;
    final hasWatermark = watermark != null && ((wmType == 'url' || wmType == 'both') && (wmWebsiteUrl?.isNotEmpty ?? false) || (wmType == 'logo' || wmType == 'both') && (wmLogoUrl?.isNotEmpty ?? false));

    Widget? wmLogoImage;
    if ((wmType == 'logo' || wmType == 'both') && wmLogoUrl != null && wmLogoUrl.isNotEmpty && wmLogoUrl.startsWith('data:image/')) {
      try {
        final base64 = wmLogoUrl.contains(',') ? wmLogoUrl.split(',').last : wmLogoUrl;
        wmLogoImage = Image.memory(
          base64Decode(base64.replaceAll(RegExp(r'\s'), '')),
          width: 80,
          height: 80,
          fit: BoxFit.contain,
        );
      } catch (_) {}
    }

    final content = Container(
      width: width,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (logoBase64 != null && logoBase64.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
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
                    Text('INVOICE', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(businessName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                    if (businessAddress.isNotEmpty) Text(businessAddress, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    if (businessPhone.isNotEmpty) Text(businessPhone, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    if (businessEmail.isNotEmpty) Text(businessEmail, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Invoice #$invoiceNumber', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('Issued: $issuedAt', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                  Text('Due: $dueAt', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('BILL TO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 4),
          Text(customerName, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          if (customerPhone.isNotEmpty) Text('Phone: $customerPhone', style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 24),
          Table(
            border: TableBorder.all(color: Colors.grey.shade400),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(0.6),
              3: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey.shade200),
                children: const [
                  Padding(padding: EdgeInsets.all(8), child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87))),
                  Padding(padding: EdgeInsets.all(8), child: Text('PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87))),
                  Padding(padding: EdgeInsets.all(8), child: Text('QTY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87))),
                  Padding(padding: EdgeInsets.all(8), child: Text('AMOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87))),
                ],
              ),
              ...items.map<TableRow>((item) {
                final desc = (item['description'] ?? '').toString();
                final price = parseAmount(item['unit_price']);
                final qty = parseAmount(item['quantity']);
                final qtyDisplay = qty > 0 ? qty : 1;
                final amount = parseAmount(item['amount']);
                return TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.all(8), child: Text(desc, style: const TextStyle(fontSize: 10, color: Colors.black87))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('$symbol${formatAmount(price)}', style: const TextStyle(fontSize: 10, color: Colors.black87))),
                    Padding(padding: const EdgeInsets.all(8), child: Text(qtyDisplay.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: Colors.black87))),
                    Padding(padding: const EdgeInsets.all(8), child: Text('$symbol${formatAmount(amount)}', style: const TextStyle(fontSize: 10, color: Colors.black87))),
                  ],
                );
              }),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (vatEnabled) ...[
                  Text('Subtotal: $symbol${formatAmount(subtotalAmount)} $currency', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('VAT (${vatRate.toStringAsFixed(1)}%): $symbol${formatAmount(vatAmount)} $currency', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                  const SizedBox(height: 4),
                ],
                Text('Total: $symbol${formatAmount(totalAmount)} $currency', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text('Status: ${_formatInvoiceStatus(status)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );

    if (hasWatermark) {
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (wmLogoImage != null) wmLogoImage,
                        if ((wmType == 'url' || wmType == 'both') && (wmWebsiteUrl?.isNotEmpty ?? false))
                          Text(wmWebsiteUrl!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
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
