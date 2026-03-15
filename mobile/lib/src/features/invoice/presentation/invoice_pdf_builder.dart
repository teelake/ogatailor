import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/format_amount.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

Future<Uint8List> buildInvoicePdf(
  Map<String, dynamic> invoice, {
  Dio? dio,
  Map<String, String>? currencySymbols,
}) async {
  final pdf = pw.Document();
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
  pw.ImageProvider? logoImage;
  if (logoBase64 != null && logoBase64.isNotEmpty) {
    try {
      final bytes = base64Decode(logoBase64.replaceAll(RegExp(r'\s'), ''));
      logoImage = pw.MemoryImage(bytes);
    } catch (_) {}
  }

  final watermark = invoice['watermark'] as Map<String, dynamic>?;
  pw.Widget? watermarkOverlay;
  if (watermark != null) {
    final wmType = (watermark['type'] ?? 'both').toString();
    final wmLogoUrl = (watermark['logo_url'] as String?)?.trim();
    final wmWebsiteUrl = (watermark['website_url'] ?? 'https://ogatailor.app').toString();
    pw.ImageProvider? wmLogoImage;
    if ((wmType == 'logo' || wmType == 'both') && wmLogoUrl != null && wmLogoUrl.isNotEmpty) {
      if (wmLogoUrl.startsWith('data:image/')) {
        try {
          final base64 = wmLogoUrl.contains(',') ? wmLogoUrl.split(',').last : wmLogoUrl;
          final bytes = base64Decode(base64.replaceAll(RegExp(r'\s'), ''));
          wmLogoImage = pw.MemoryImage(bytes);
        } catch (_) {}
      } else if (dio != null && (wmLogoUrl.startsWith('http://') || wmLogoUrl.startsWith('https://'))) {
        try {
          final res = await dio.get<List<int>>(wmLogoUrl, options: Options(responseType: ResponseType.bytes));
          if (res.data != null && res.data!.isNotEmpty) {
            wmLogoImage = pw.MemoryImage(Uint8List.fromList(res.data!));
          }
        } catch (_) {}
      }
    }
    watermarkOverlay = pw.Transform.rotate(
      angle: -0.5,
      child: pw.Opacity(
        opacity: 0.15,
        child: pw.Center(
          child: pw.Column(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              if (wmLogoImage != null)
                pw.Container(
                  width: 80,
                  height: 80,
                  child: pw.Image(wmLogoImage, fit: pw.BoxFit.contain),
                ),
              if ((wmType == 'url' || wmType == 'both') && wmWebsiteUrl.isNotEmpty)
                pw.Text(wmWebsiteUrl.replaceFirst(RegExp(r'^https?://'), ''), style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        final content = pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 56,
                    height: 56,
                    margin: const pw.EdgeInsets.only(right: 16),
                    child: pw.Image(logoImage!, fit: pw.BoxFit.contain),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 4),
                      pw.Text(businessName, style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      if (businessAddress.isNotEmpty) pw.Text(businessAddress, style: const pw.TextStyle(fontSize: 10)),
                      if (businessPhone.isNotEmpty) pw.Text(businessPhone, style: const pw.TextStyle(fontSize: 10)),
                      if (businessEmail.isNotEmpty) pw.Text(businessEmail, style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Invoice #$invoiceNumber', style: const pw.TextStyle(fontSize: 12)),
                      pw.SizedBox(height: 4),
                      pw.Text('Issued: $issuedAt', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Due: $dueAt', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Text('BILL TO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(customerName, style: const pw.TextStyle(fontSize: 12)),
            if (customerPhone.isNotEmpty) pw.Text('Phone: $customerPhone', style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 24),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('ITEM', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('PRICE', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('QTY', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('AMOUNT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                  ],
                ),
                ...items.map<pw.TableRow>((item) {
                  final desc = (item['description'] ?? '').toString();
                  final price = parseAmount(item['unit_price']);
                  final qty = parseAmount(item['quantity']);
                  final qtyDisplay = qty > 0 ? qty : 1;
                  final amount = parseAmount(item['amount']);
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(desc, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$symbol${formatAmount(price)}', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(qtyDisplay.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$symbol${formatAmount(amount)}', style: const pw.TextStyle(fontSize: 10))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  if (vatEnabled) ...[
                    pw.Text('Subtotal: $symbol${formatAmount(subtotalAmount)} $currency', style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 4),
                    pw.Text('VAT (${vatRate.toStringAsFixed(1)}%): $symbol${formatAmount(vatAmount)} $currency', style: const pw.TextStyle(fontSize: 11)),
                    pw.SizedBox(height: 4),
                  ],
                  pw.Text('Total: $symbol${formatAmount(totalAmount)} $currency', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text('Status: ${_formatInvoiceStatus(status)}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
                ],
              ),
            ),
          ],
        );
        if (watermarkOverlay != null) {
          return pw.Stack(
            children: [
              content,
              pw.Positioned.fill(child: watermarkOverlay!),
            ],
          );
        }
        return content;
      },
    ),
  );

  return pdf.save();
}
