import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectExportGenerator {
  /// Generate comprehensive PDF report for a subject
  static Future<Uint8List> generateSubjectPDF({
    required String subjectName,
    required String groupName,
    required String subjectId,
    required String institutionCode,
  }) async {
    // 1. Fetch all sessions for this institution first, then filter in memory
    // This is necessary because sessions might have subject and group as separate fields
    final allSessionsSnapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    // Filter sessions that match this subject and group
    final targetSubjectLower = subjectName.trim().toLowerCase();
    final targetGroupLower = groupName.trim().toLowerCase();
    final compositeSubjectName = groupName.isNotEmpty
        ? '$subjectName ($groupName)'
        : subjectName;

    final sessionsSnapshot = allSessionsSnapshot.docs.where((doc) {
      final data = doc.data();
      final sSubject = data['subject'] as String? ?? '';
      final sGroupField = data['group'] as String?;

      String? sGroup = sGroupField;
      String sName = sSubject;

      // Parse if subject contains group in parentheses
      if (sSubject.contains('(') && sSubject.endsWith(')')) {
        final parts = sSubject.split('(');
        sName = parts.first.trim();
        sGroup ??= parts.last.replaceAll(')', '').trim();
      }

      final sGroupLower = sGroup?.trim().toLowerCase();
      final sNameLower = sName.trim().toLowerCase();

      // Match logic same as teacher_students_page.dart
      final groupMatch = sGroupLower == targetGroupLower;
      final nameMatch = sNameLower == targetSubjectLower;
      final isGeneralSession =
          nameMatch && (sGroupLower == null || sGroupLower.isEmpty);
      final exactMatch = sSubject == compositeSubjectName;

      return (groupMatch && nameMatch) || exactMatch || isGeneralSession;
    }).toList();

    final totalSessions = sessionsSnapshot.length;

    // 2. Fetch all students for this group
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('institutionCode', isEqualTo: institutionCode)
        .where('role', isEqualTo: 'student')
        .get();

    // 3. Fetch class groups to resolve IDs
    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('class_groups')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    final groupIdToName = {
      for (var doc in groupsSnapshot.docs) doc.id: doc.data()['name'] as String,
    };

    // 4. Filter students belonging to this group
    final groupStudents = studentsSnapshot.docs.where((doc) {
      final data = doc.data();
      final lectureGroup = data['lectureGroup'] as String?;
      final labGroup = data['labGroup'] as String?;
      final legacyGroup = data['group'] as String?;

      final lectureGroupName = (groupIdToName[lectureGroup] ?? lectureGroup)
          ?.trim()
          .toLowerCase();
      final labGroupName = (groupIdToName[labGroup] ?? labGroup)
          ?.trim()
          .toLowerCase();
      final fallbackGroupName = legacyGroup?.trim().toLowerCase();

      return lectureGroupName == targetGroupLower ||
          labGroupName == targetGroupLower ||
          fallbackGroupName == targetGroupLower;
    }).toList();

    // 5. Calculate attendance for each student
    final studentRecords = <Map<String, dynamic>>[];

    for (final studentDoc in groupStudents) {
      final studentData = studentDoc.data();
      final uid = studentDoc.id;
      final name = studentData['displayName'] ?? 'Unknown';

      String? rollNum = studentData['rollNumber'] as String?;
      if (rollNum == null || rollNum.isEmpty) {
        rollNum = studentData['idNumber'] as String?;
      }
      final rollNumber = rollNum ?? 'N/A';

      // Count attended sessions for this student
      int attended = 0;
      for (final sessionDoc in sessionsSnapshot) {
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionDoc.id)
            .collection('attendance')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();

        if (attendanceSnapshot.docs.isNotEmpty) {
          attended++;
        }
      }

      final percentage = totalSessions > 0
          ? (attended / totalSessions * 100)
          : 0.0;

      studentRecords.add({
        'name': name,
        'rollNumber': rollNumber,
        'attended': attended,
        'total': totalSessions,
        'percentage': percentage,
      });
    }

    // Sort by roll number
    studentRecords.sort(
      (a, b) =>
          (a['rollNumber'] as String).compareTo(b['rollNumber'] as String),
    );

    // 6. Generate PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            // Main Header - Subject Name
            pw.Center(
              child: pw.Text(
                subjectName,
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            // Second Header - Group Name
            pw.Center(
              child: pw.Text(
                groupName,
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
                'Total Sessions: $totalSessions',
                style: const pw.TextStyle(
                  fontSize: 14,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 20),
            // Student Records Table
            pw.TableHelper.fromTextArray(
              headers: [
                'Roll Number',
                'Student Name',
                'Sessions Attended',
                'Attendance %',
              ],
              data: studentRecords.map((record) {
                return [
                  record['rollNumber'],
                  record['name'],
                  '${record['attended']}/${record['total']}',
                  '${(record['percentage'] as double).toStringAsFixed(1)}%',
                ];
              }).toList(),
              border: null,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blueGrey800,
              ),
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
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
            ),
          ];
        },
      ),
    );

    final pdfBytes = await pdf.save();
    return pdfBytes;
  }

  /// Generate comprehensive Excel report for a subject
  static Future<List<int>?> generateSubjectExcel({
    required String subjectName,
    required String groupName,
    required String subjectId,
    required String institutionCode,
  }) async {
    // 1. Fetch all sessions for this institution first, then filter in memory
    final allSessionsSnapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    // Filter sessions that match this subject and group
    final targetSubjectLower = subjectName.trim().toLowerCase();
    final targetGroupLower = groupName.trim().toLowerCase();
    final compositeSubjectName = groupName.isNotEmpty
        ? '$subjectName ($groupName)'
        : subjectName;

    final sessionsSnapshot = allSessionsSnapshot.docs.where((doc) {
      final data = doc.data();
      final sSubject = data['subject'] as String? ?? '';
      final sGroupField = data['group'] as String?;

      String? sGroup = sGroupField;
      String sName = sSubject;

      // Parse if subject contains group in parentheses
      if (sSubject.contains('(') && sSubject.endsWith(')')) {
        final parts = sSubject.split('(');
        sName = parts.first.trim();
        sGroup ??= parts.last.replaceAll(')', '').trim();
      }

      final sGroupLower = sGroup?.trim().toLowerCase();
      final sNameLower = sName.trim().toLowerCase();

      // Match logic same as teacher_students_page.dart
      final groupMatch = sGroupLower == targetGroupLower;
      final nameMatch = sNameLower == targetSubjectLower;
      final isGeneralSession =
          nameMatch && (sGroupLower == null || sGroupLower.isEmpty);
      final exactMatch = sSubject == compositeSubjectName;

      return (groupMatch && nameMatch) || exactMatch || isGeneralSession;
    }).toList();

    final totalSessions = sessionsSnapshot.length;

    // 2. Fetch all students for this group
    final studentsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('institutionCode', isEqualTo: institutionCode)
        .where('role', isEqualTo: 'student')
        .get();

    // 3. Fetch class groups to resolve IDs
    final groupsSnapshot = await FirebaseFirestore.instance
        .collection('class_groups')
        .where('institutionCode', isEqualTo: institutionCode)
        .get();

    final groupIdToName = {
      for (var doc in groupsSnapshot.docs) doc.id: doc.data()['name'] as String,
    };

    // 4. Filter students belonging to this group
    final groupStudents = studentsSnapshot.docs.where((doc) {
      final data = doc.data();
      final lectureGroup = data['lectureGroup'] as String?;
      final labGroup = data['labGroup'] as String?;
      final legacyGroup = data['group'] as String?;

      final lectureGroupName = (groupIdToName[lectureGroup] ?? lectureGroup)
          ?.trim()
          .toLowerCase();
      final labGroupName = (groupIdToName[labGroup] ?? labGroup)
          ?.trim()
          .toLowerCase();
      final fallbackGroupName = legacyGroup?.trim().toLowerCase();

      return lectureGroupName == targetGroupLower ||
          labGroupName == targetGroupLower ||
          fallbackGroupName == targetGroupLower;
    }).toList();

    // 5. Calculate attendance for each student
    final studentRecords = <Map<String, dynamic>>[];

    for (final studentDoc in groupStudents) {
      final studentData = studentDoc.data();
      final uid = studentDoc.id;
      final name = studentData['displayName'] ?? 'Unknown';

      String? rollNum = studentData['rollNumber'] as String?;
      if (rollNum == null || rollNum.isEmpty) {
        rollNum = studentData['idNumber'] as String?;
      }
      final rollNumber = rollNum ?? 'N/A';

      // Count attended sessions for this student
      int attended = 0;
      for (final sessionDoc in sessionsSnapshot) {
        final attendanceSnapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .doc(sessionDoc.id)
            .collection('attendance')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();

        if (attendanceSnapshot.docs.isNotEmpty) {
          attended++;
        }
      }

      final percentage = totalSessions > 0
          ? (attended / totalSessions * 100)
          : 0.0;

      studentRecords.add({
        'name': name,
        'rollNumber': rollNumber,
        'attended': attended,
        'total': totalSessions,
        'percentage': percentage,
      });
    }

    // Sort by roll number
    studentRecords.sort(
      (a, b) =>
          (a['rollNumber'] as String).compareTo(b['rollNumber'] as String),
    );

    // 6. Generate Excel with professional formatting
    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];

    // Define cell styles
    final titleStyle = CellStyle(
      bold: true,
      fontSize: 18,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final subtitleStyle = CellStyle(
      bold: true,
      fontSize: 14,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final infoStyle = CellStyle(
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headerStyle = CellStyle(
      bold: true,
      fontSize: 12,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    final dataStyle = CellStyle(
      fontSize: 11,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    final dataCenterStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: Border(borderStyle: BorderStyle.Thin),
      rightBorder: Border(borderStyle: BorderStyle.Thin),
      topBorder: Border(borderStyle: BorderStyle.Thin),
      bottomBorder: Border(borderStyle: BorderStyle.Thin),
    );

    // Set column widths
    sheet.setColumnWidth(0, 20); // Roll Number
    sheet.setColumnWidth(1, 30); // Student Name
    sheet.setColumnWidth(2, 20); // Sessions Attended
    sheet.setColumnWidth(3, 18); // Attendance %

    // Title row (row 0)
    var cell = sheet.cell(CellIndex.indexByString('A1'));
    cell.value = TextCellValue(subjectName);
    cell.cellStyle = titleStyle;
    sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('D1'));

    // Subtitle row (row 1)
    cell = sheet.cell(CellIndex.indexByString('A2'));
    cell.value = TextCellValue(groupName);
    cell.cellStyle = subtitleStyle;
    sheet.merge(CellIndex.indexByString('A2'), CellIndex.indexByString('D2'));

    // Info row (row 2)
    cell = sheet.cell(CellIndex.indexByString('A3'));
    cell.value = TextCellValue('Total Sessions: $totalSessions');
    cell.cellStyle = infoStyle;
    sheet.merge(CellIndex.indexByString('A3'), CellIndex.indexByString('D3'));

    // Empty row for spacing
    // Row 3 is empty

    // Table headers (row 4)
    final headers = [
      'Roll Number',
      'Student Name',
      'Sessions Attended',
      'Attendance %',
    ];
    for (int i = 0; i < headers.length; i++) {
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data rows (starting from row 5)
    int rowIndex = 5;
    for (final record in studentRecords) {
      // Roll Number
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      cell.value = TextCellValue(record['rollNumber']);
      cell.cellStyle = dataStyle;

      // Student Name
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
      );
      cell.value = TextCellValue(record['name']);
      cell.cellStyle = dataStyle;

      // Sessions Attended
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
      );
      cell.value = TextCellValue('${record['attended']}/${record['total']}');
      cell.cellStyle = dataCenterStyle;

      // Attendance %
      cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
      );
      cell.value = TextCellValue(
        '${(record['percentage'] as double).toStringAsFixed(1)}%',
      );
      cell.cellStyle = dataCenterStyle;

      rowIndex++;
    }

    // Return bytes
    return excel.encode();
  }
}
