import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfGenerator {
  static Future<Uint8List> generateAttendancePdf({
    required String subjectName,
    required String groupName,
    required DateTime date,
    required List<Map<String, dynamic>> records,
  }) async {
    final pdf = pw.Document();
    final dateStr = DateFormat('MMMM dd, yyyy').format(date);
    final timeStr = DateFormat('HH:mm').format(date);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            _buildHeader(subjectName, groupName, dateStr, timeStr),
            pw.SizedBox(height: 20),
            _buildTable(records),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(
    String subject,
    String group,
    String date,
    String time,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            subject,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            group,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            '$date | $time',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
          ),
        ),
        pw.SizedBox(height: 20),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildTable(List<Map<String, dynamic>> records) {
    return pw.TableHelper.fromTextArray(
      headers: ['Roll Number', 'Student Name', 'Status', 'Time'],
      data: records.map((record) {
        final timestamp =
            (record['timestamp'] as dynamic); // Handle Timestamp or DateTime
        DateTime? dt;
        if (timestamp != null) {
          // If it's a Firestore Timestamp, it might need conversion, but here we expect dynamic map
          // In the provider we are passing the raw object.
          // Let's assume the caller passes DateTime or we handle it.
          // Actually, in the provider it's a Timestamp.
          try {
            dt = timestamp.toDate();
          } catch (_) {
            dt = timestamp as DateTime?;
          }
        }

        final timeStr = dt != null ? DateFormat('HH:mm').format(dt) : '--:--';

        return [
          record['rollNumber'] ?? 'N/A',
          record['studentName'] ?? 'Unknown',
          (record['status'] as String).toUpperCase(),
          timeStr,
        ];
      }).toList(),
      border: null,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    );
  }
}
