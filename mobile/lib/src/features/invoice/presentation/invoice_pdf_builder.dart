import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

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

Future<Uint8List> buildInvoicePdf(Map<String, dynamic> invoice) async {
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
  final symbol = _currencySymbol(currency);
  final totalAmount = (invoice['total_amount'] ?? 0) as num;
  final items = (invoice['items'] as List<dynamic>?) ?? [];

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('INVOICE', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
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
            if (customerPhone.isNotEmpty) pw.Text(customerPhone, style: const pw.TextStyle(fontSize: 10)),
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
                  final price = (item['unit_price'] ?? 0) as num;
                  final qty = (item['quantity'] ?? 1) as num;
                  final amount = (item['amount'] ?? 0) as num;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(desc, style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$symbol${price.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(qty.toStringAsFixed(0), style: const pw.TextStyle(fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('$symbol${amount.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10))),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total: $symbol${totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}
