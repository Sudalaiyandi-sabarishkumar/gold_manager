import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'format.dart';

final DateFormat _fileStamp = DateFormat('yyyy-MM-dd');
final DateFormat _cellDate = DateFormat('yyyy-MM-dd');

/// One RFC-4180 field: quote it whenever it holds a comma, quote or newline.
String csvField(Object? value) {
  final s = value?.toString() ?? '';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

String csvRow(List<Object?> cells) => cells.map(csvField).join(',');

/// Builds a CSV document (header + rows), CRLF-terminated per RFC 4180.
String buildCsv(List<String> header, List<List<Object?>> rows) {
  final buffer = StringBuffer()
    ..write(csvRow(header))
    ..write('\r\n');
  for (final r in rows) {
    buffer
      ..write(csvRow(r))
      ..write('\r\n');
  }
  return buffer.toString();
}

String csvDate(DateTime d) => _cellDate.format(toIst(d));

/// Writes [csv] to a temp file named "avs_<label>_<today>.csv" and opens the
/// share sheet so the user can save it to Files, email it, etc.
Future<void> shareCsv({required String label, required String csv}) async {
  final dir = await getTemporaryDirectory();
  final stamp = _fileStamp.format(DateTime.now());
  final file = File('${dir.path}/avs_${label}_$stamp.csv');
  await file.writeAsString(csv);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: 'AVS $label — $stamp',
  );
}
