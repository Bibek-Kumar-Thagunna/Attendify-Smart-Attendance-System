import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'file_download_helper.dart';

/// Service for exporting data to various formats (CSV, Excel, PDF)
/// All exports are created dynamically and downloaded as blobs - nothing is stored to Firebase
class ExportService {
  /// Export data as CSV
  static Future<void> exportToCSV({
    required String fileName,
    required List<Map<String, dynamic>> data,
    List<String>? headers,
  }) async {
    try {
      // Generate CSV content
      final csvContent = _generateCSV(data, headers);
      final bytes = Uint8List.fromList(csvContent.codeUnits);

      // Save file using download helper
      await downloadFile(
        filename: '$fileName.csv',
        bytes: bytes,
        mimeType: 'text/csv',
      );
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  /// Export data as Excel
  static Future<void> exportToExcel({
    required String fileName,
    required List<Map<String, dynamic>> data,
    List<String>? headers,
    String? sheetName,
  }) async {
    try {
      // Create Excel workbook
      final excel = Excel.createExcel();
      excel.delete('Sheet1'); // Delete default sheet
      final sheet = excel[sheetName ?? 'Sheet1'];

      // Get headers from data if not provided
      final columnHeaders = headers ?? _extractHeaders(data);

      // Write headers
      for (int i = 0; i < columnHeaders.length; i++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = TextCellValue(columnHeaders[i]);
        cell.cellStyle = CellStyle(bold: true);
      }

      // Write data rows
      for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
        final row = data[rowIndex];
        for (int colIndex = 0; colIndex < columnHeaders.length; colIndex++) {
          final header = columnHeaders[colIndex];
          final value = _formatCellValue(row[header]);
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex + 1,
            ),
          );
          cell.value = value;
        }
      }

      // Auto-size columns
      for (int i = 0; i < columnHeaders.length; i++) {
        sheet.setColumnWidth(i, 20);
      }

      // Convert to bytes
      final bytesList = excel.encode();
      if (bytesList == null) {
        throw Exception('Failed to encode Excel file');
      }
      final bytes = Uint8List.fromList(bytesList);

      // Save file
      await downloadFile(
        filename: '$fileName.xlsx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  /// Export data as PDF
  static Future<void> exportToPDF({
    required String fileName,
    required String title,
    required List<Map<String, dynamic>> data,
    List<String>? headers,
    String? description,
  }) async {
    try {
      // Load font
      final font = await PdfGoogleFonts.openSansRegular();
      final fontBold = await PdfGoogleFonts.openSansBold();

      // Create PDF document
      final pdf = pw.Document();

      // Get headers from data if not provided
      final columnHeaders = headers ?? _extractHeaders(data);

      // Build PDF content
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          build: (pw.Context context) {
            return [
              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              // Description
              if (description != null)
                pw.Text(
                  description,
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              if (description != null) pw.SizedBox(height: 20),
              // Generated date
              pw.Text(
                'Generated: ${DateFormat('MMM dd, yyyy at hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 20),
              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey200,
                    ),
                    children: columnHeaders.map((header) {
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          header,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Data rows
                  ...data.map((row) {
                    return pw.TableRow(
                      children: columnHeaders.map((header) {
                        final value = _formatValueForPDF(row[header]);
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            value,
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        );
                      }).toList(),
                    );
                  }),
                ],
              ),
            ];
          },
        ),
      );

      // Convert to bytes
      final bytes = await pdf.save();

      // Save file
      await downloadFile(
        filename: '$fileName.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// Export report data (key-value pairs) as PDF
  static Future<void> exportReportToPDF({
    required String fileName,
    required String title,
    required Map<String, dynamic> reportData,
    String? description,
  }) async {
    try {
      // Load font
      final font = await PdfGoogleFonts.openSansRegular();
      final fontBold = await PdfGoogleFonts.openSansBold();

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          build: (pw.Context context) {
            return [
              // Title
              pw.Header(
                level: 0,
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              // Description
              if (description != null)
                pw.Text(
                  description,
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                ),
              if (description != null) pw.SizedBox(height: 20),
              // Generated date
              pw.Text(
                'Generated: ${DateFormat('MMM dd, yyyy at hh:mm a').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 30),
              // Report data
              ...reportData.entries.map((entry) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 15),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          entry.key,
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      pw.Expanded(
                        flex: 3,
                        child: pw.Text(
                          entry.value.toString(),
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ];
          },
        ),
      );

      final bytes = await pdf.save();

      await downloadFile(
        filename: '$fileName.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  // Helper methods

  static String _generateCSV(
    List<Map<String, dynamic>> data,
    List<String>? headers,
  ) {
    if (data.isEmpty) return '';

    final columnHeaders = headers ?? _extractHeaders(data);
    final buffer = StringBuffer();

    // Write headers
    buffer.writeln(columnHeaders.map((h) => _escapeCSV(h)).join(','));

    // Write data rows
    for (final row in data) {
      final values = columnHeaders.map((header) {
        final value = row[header];
        return _escapeCSV(_formatValue(value));
      });
      buffer.writeln(values.join(','));
    }

    return buffer.toString();
  }

  static List<String> _extractHeaders(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];
    return data.first.keys.toList();
  }

  static String _escapeCSV(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _formatValue(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return DateFormat('MMM dd, yyyy hh:mm a').format(value.toDate());
    }
    if (value is DateTime) {
      return DateFormat('MMM dd, yyyy hh:mm a').format(value);
    }
    return value.toString();
  }

  static String _formatValueForPDF(dynamic value) {
    if (value == null) return '';
    if (value is Timestamp) {
      return DateFormat('MMM dd, yyyy\nhh:mm a').format(value.toDate());
    }
    if (value is DateTime) {
      return DateFormat('MMM dd, yyyy\nhh:mm a').format(value);
    }
    final str = value.toString();
    // Truncate long values for PDF
    return str.length > 30 ? '${str.substring(0, 27)}...' : str;
  }

  static CellValue _formatCellValue(dynamic value) {
    if (value == null) return TextCellValue('');
    if (value is Timestamp) {
      return TextCellValue(
        DateFormat('MMM dd, yyyy hh:mm a').format(value.toDate()),
      );
    }
    if (value is DateTime) {
      return TextCellValue(DateFormat('MMM dd, yyyy hh:mm a').format(value));
    }
    if (value is num) {
      return DoubleCellValue(value.toDouble());
    }
    return TextCellValue(value.toString());
  }

  /// Export all data to a multi-sheet Excel file
  static Future<void> exportAllDataToExcel({
    required String fileName,
    required Map<String, List<Map<String, dynamic>>> sheets,
  }) async {
    try {
      final excel = Excel.createExcel();
      excel.delete('Sheet1');

      for (final entry in sheets.entries) {
        final sheetName = entry.key;
        final data = entry.value;
        final sheet = excel[sheetName];

        if (data.isEmpty) continue;

        final columnHeaders = _extractHeaders(data);

        // Write headers
        for (int i = 0; i < columnHeaders.length; i++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
          );
          cell.value = TextCellValue(columnHeaders[i]);
          cell.cellStyle = CellStyle(bold: true);
        }

        // Write data
        for (int rowIndex = 0; rowIndex < data.length; rowIndex++) {
          final row = data[rowIndex];
          for (int colIndex = 0; colIndex < columnHeaders.length; colIndex++) {
            final header = columnHeaders[colIndex];
            final value = _formatCellValue(row[header]);
            final cell = sheet.cell(
              CellIndex.indexByColumnRow(
                columnIndex: colIndex,
                rowIndex: rowIndex + 1,
              ),
            );
            cell.value = value;
          }
        }

        // Auto-size columns (approximate)
        for (int i = 0; i < columnHeaders.length; i++) {
          sheet.setColumnWidth(i, 20);
        }
      }

      final bytesList = excel.encode();
      if (bytesList == null) throw Exception('Failed to encode Excel file');
      final bytes = Uint8List.fromList(bytesList);

      await downloadFile(
        filename: '$fileName.xlsx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      throw Exception('Failed to export all data: $e');
    }
  }
}
