import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

final DateFormat _fileStamp = DateFormat('yyyy-MM-dd');
final DateFormat _pdfDate = DateFormat('dd MMM yyyy');
final NumberFormat _pdfAmount =
    NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

/// Date formatted for a PDF cell.
String pdfDate(DateTime d) => _pdfDate.format(d.toLocal());

/// Amount formatted for a PDF cell. Uses "Rs." rather than "₹" — the PDF's
/// base font has no glyph for the rupee sign.
String pdfAmount(num n) => _pdfAmount.format(n);

/// Builds a landscape table PDF and lets the user save it to device storage
/// via the native "Save As" picker — not a share sheet, so there's no list
/// of apps to send it through, just a location to save the file.
Future<void> downloadPdf({
  required String title,
  required List<String> headers,
  required List<List<String>> rows,
}) async {
  final doc = pw.Document();
  final generated = _pdfDate.format(DateTime.now());

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'AVS · $title',
                style:
                    pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Generated $generated',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey700)),
            ],
          ),
          pw.SizedBox(height: 10),
        ],
      ),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.amber100),
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    ),
  );

  final bytes = await doc.save();
  final stamp = _fileStamp.format(DateTime.now());
  final safeTitle = title.toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  await FileSaver.instance.saveAs(
    name: 'avs_${safeTitle}_$stamp',
    bytes: Uint8List.fromList(bytes),
    ext: 'pdf',
    mimeType: MimeType.pdf,
  );
}
