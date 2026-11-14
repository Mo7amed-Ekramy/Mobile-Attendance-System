import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/api.dart';
import '../data/models.dart';
import '../widgets/common.dart';

class StudentReportPage extends StatelessWidget {
  const StudentReportPage(this.api, this.course, {super.key, this.section});
  final AttendanceApi api;
  final CourseOffering course;
  final CourseSection? section;

  @override
  Widget build(BuildContext context) => RemotePage<Map<String, dynamic>>(
      load: () async => await api.getCourse(course, 'report/students',
          sectionId: section?.id) as Map<String, dynamic>,
      builder: (data, reload) => _ReportView(course, section, data));
}

class _ReportView extends StatefulWidget {
  const _ReportView(this.course, this.section, this.data);
  final CourseOffering course;
  final CourseSection? section;
  final Map<String, dynamic> data;
  @override
  State<_ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<_ReportView> {
  final search = TextEditingController();
  int page = 0;
  bool exporting = false;
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> export({required bool print}) async {
    setState(() => exporting = true);
    try {
      final bytes =
          await buildStudentReport(widget.course, widget.section, widget.data);
      if (!mounted) return;
      final name =
          '${widget.course.code}-report-${widget.section?.id ?? 'all'}.pdf';
      if (print) {
        await Printing.layoutPdf(name: name, onLayout: (_) async => bytes);
      } else {
        await Printing.sharePdf(bytes: bytes, filename: name);
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = (widget.data['rows'] as List)
        .where((row) => '${row['full_name']} ${row['university_id']}'
            .toLowerCase()
            .contains(search.text.trim().toLowerCase()))
        .toList();
    final pages = ((rows.length + 24) ~/ 25).clamp(1, 100000);
    final current = page.clamp(0, pages - 1);
    return PageContent(
      footer: Row(children: [
        Expanded(
            child: AsyncButton(
                label: 'تصدير PDF',
                icon: Icons.download_outlined,
                enabled: !exporting,
                onPressed: () => export(print: false))),
        const SizedBox(width: 12),
        Expanded(
            child: AsyncButton(
                label: 'طباعة التقرير',
                icon: Icons.print_outlined,
                enabled: !exporting,
                onPressed: () => export(print: true))),
      ]),
      children: [
        PageHeading('تقرير الطلاب',
            '${widget.course.code} · ${widget.section?.label ?? 'جميع السكاشن'} · ${widget.data['total']} طالب'),
        const NoticeBanner(
            'التقرير يحتسب الحضور المعتمد والدرجات المنشورة فقط. التصدير يشمل جميع طلاب النطاق المحدد.'),
        TextField(
            controller: search,
            decoration: const InputDecoration(
                labelText: 'البحث باسم الطالب أو الرقم الجامعي',
                prefixIcon: Icon(Icons.search)),
            onChanged: (_) => setState(() => page = 0)),
        if (rows.isEmpty)
          const EmptyPanel('لا توجد نتائج', 'غيّر كلمات البحث أو نطاق المقرر.'),
        for (final row in rows.skip(current * 25).take(25))
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row['full_name'] as String,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                            '${row['university_id']} · سكشن ${row['section_number']} (${row['department_code']})',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 12),
                        Wrap(spacing: 18, runSpacing: 8, children: [
                          Text(
                              'المحاضرات: ${ltrValue(reportRate(row, 'lecture'))}'),
                          Text(
                              'السكاشن: ${ltrValue(reportRate(row, 'section'))}'),
                          Text(
                              'المجموع: ${row['official_total'] == null ? 'غير مكتمل' : points(row['official_total'])}'),
                        ]),
                        for (final category in row['categories'] as List? ?? [])
                          Text(
                              '${category['name']}: ${pointRatio(category['earned'], category['max_points'])}'
                              '${category['complete'] == true ? '' : ' · غير مكتمل'}'),
                      ]))),
        if (pages > 1)
          Row(children: [
            Expanded(
                child: OutlinedButton(
                    onPressed:
                        current == 0 ? null : () => setState(() => page--),
                    child: const Text('السابق'))),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${current + 1} / $pages',
                    textDirection: TextDirection.ltr)),
            Expanded(
                child: OutlinedButton(
                    onPressed: current + 1 >= pages
                        ? null
                        : () => setState(() => page++),
                    child: const Text('التالي'))),
          ]),
      ],
    );
  }
}

String reportRate(dynamic row, String kind) {
  final count = (row['attendance'] as Map?)?[kind] as Map?;
  return count?['rate'] == null
      ? '—'
      : '${count!['rate']}% (${count['present']}/${count['eligible']})';
}

Future<Uint8List> buildStudentReport(CourseOffering course,
    CourseSection? section, Map<String, dynamic> data) async {
  final regular =
      await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/NotoSansArabic-Bold.ttf');
  final latin = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final theme = pw.ThemeData.withFont(
      fontFallback: [pw.Font.ttf(latin)],
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold));
  final document = pw.Document(
      theme: theme,
      title: '${course.code} - تقرير الطلاب',
      author: 'جامعة أسيوط الأهلية');
  final rows = data['rows'] as List;
  final categories = ((data['policy'] as Map?)?['categories'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  void addTable(String title, List<String> headers, List<List<String>> cells) {
    document.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 1000,
      margin: const pw.EdgeInsets.all(28),
      textDirection: pw.TextDirection.rtl,
      header: (_) =>
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('جامعة أسيوط الأهلية',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 15)),
        pw.Text(course.name,
            textDirection: _pdfDirection(course.name),
            style: const pw.TextStyle(fontSize: 10)),
        pw.Text(
            '${course.code} / ${section?.department ?? 'All sections'} ${section?.number ?? ''}',
            textDirection: pw.TextDirection.ltr,
            style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 8),
      ]),
      footer: (context) => pw.Column(children: [
        pw.Divider(color: PdfColors.grey300),
        pw.Text(
            'الحضور المعتمد والدرجات المنشورة فقط · صفحة ${context.pageNumber}',
            style: const pw.TextStyle(fontSize: 8)),
        pw.Text(localTime(DateTime.now().toIso8601String()),
            textDirection: pw.TextDirection.ltr,
            style: const pw.TextStyle(fontSize: 8)),
      ]),
      build: (_) => [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        if (cells.isEmpty)
          pw.Text('لا يوجد طلاب في النطاق المحدد.')
        else
          pw.TableHelper.fromTextArray(
            headers: headers.reversed.toList(),
            data: cells.map((row) => row.reversed.toList()).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFF5A3824)),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellBuilder: (index, value, row) => pw.Text('$value',
                textDirection: _pdfDirection('$value'),
                style: const pw.TextStyle(fontSize: 8)),
            cellAlignment: pw.Alignment.centerRight,
            cellPadding:
                const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            oddRowDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8F6F2)),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: .4),
          ),
      ],
    ));
  }

  addTable('كشف الحضور', [
    'الطالب',
    'الرقم الجامعي',
    'السكشن',
    'المحاضرات',
    'السكاشن'
  ], [
    for (final row in rows)
      [
        row['full_name'] as String,
        row['university_id'] as String,
        '${row['department_code']} ${row['section_number']}',
        reportRate(row, 'lecture'),
        reportRate(row, 'section'),
      ],
  ]);
  // Keep each table readable even when a policy contains many categories.
  final groups = categories.isEmpty ? 1 : (categories.length + 3) ~/ 4;
  for (var group = 0; group < groups; group++) {
    final visible = categories.skip(group * 4).take(4).toList();
    addTable('كشف الدرجات المنشورة', [
      'الطالب',
      'الرقم الجامعي',
      for (final category in visible)
        '${category['name']} / ${category['max_points']}',
      'المجموع النهائي'
    ], [
      for (final row in rows)
        [
          row['full_name'] as String,
          row['university_id'] as String,
          for (final category in visible)
            _categoryResult(row, category['id'] as int),
          row['official_total'] == null
              ? 'غير مكتمل'
              : points(row['official_total']),
        ],
    ]);
  }
  return document.save();
}

String _categoryResult(dynamic row, int id) {
  final category = (row['categories'] as List? ?? [])
      .cast<Map<String, dynamic>>()
      .where((item) => item['id'] == id)
      .firstOrNull;
  if (category == null) return '—';
  return '${points(category['earned'])}${category['complete'] == true ? '' : ' *'}';
}

pw.TextDirection _pdfDirection(String value) =>
    RegExp(r'[\u0600-\u06ff]').hasMatch(value)
        ? pw.TextDirection.rtl
        : pw.TextDirection.ltr;
