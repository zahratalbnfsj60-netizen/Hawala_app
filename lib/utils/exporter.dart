import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transfer.dart';
import 'formatters.dart';

class Exporter {
  static Future<void> exportCSV(List<Transfer> transfers, String accountName) async {
    List<List<dynamic>> rows = [['التاريخ', 'النوع', 'الاسم', 'المبلغ', 'العمولة', 'رقم الدفعة']];
    for (var t in transfers) {
      rows.add([fmtDate(t.date), t.type == TransferType.paid ? 'مدفوع' : 'مستلم', t.recipientName, t.amount, t.commission, t.paidNumber ?? '']);
    }
    String csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/transfers_$accountName.csv';
    final file = File(path);
    await file.writeAsString('\uFEFF$csvData'); // BOM for Arabic Excel support
    await Share.shareXFiles([XFile(path)], text: 'كشف حساب $accountName');
  }

  static Future<void> exportPDF(List<Transfer> transfers, String accountName, double balance) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Header(level: 0, child: pw.Text('سجل الحوالات - $accountName', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 10),
          pw.Text('الرصيد الحالي: ${fmtNum(balance)}', style: pw.TextStyle(fontSize: 16)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['التاريخ', 'النوع', 'الاسم', 'المبلغ', 'العمولة'],
            data: transfers.map((t) => [fmtDate(t.date), t.type == TransferType.paid ? 'مدفوع' : 'مستلم', t.recipientName, fmtNum(t.amount), fmtNum(t.commission)]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
            cellAlignment: pw.Alignment.center,
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }

  static Future<void> backupJSON(String jsonData) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/backup_transfers.json';
    final file = File(path);
    await file.writeAsString(jsonData);
    await Share.shareXFiles([XFile(path)], text: 'نسخة احتياطية للتطبيق');
  }
}
