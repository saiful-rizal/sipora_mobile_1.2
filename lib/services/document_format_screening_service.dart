import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'sipora_api_service.dart';

class DocumentFormatRule {
  const DocumentFormatRule({
    required this.minHeadingCount,
    required this.minJustifiedBodyRatio,
    required this.requiredKeywords,
  });

  final int minHeadingCount;
  final double minJustifiedBodyRatio;
  final List<String> requiredKeywords;
}

class DocumentFormatScreeningResult {
  const DocumentFormatScreeningResult({
    required this.canAnalyze,
    required this.passed,
    required this.summary,
    required this.score,
    required this.totalParagraphs,
    required this.headingCount,
    required this.justifiedBodyRatio,
    required this.checks,
    this.engine = 'local',
    this.totalPages = 0,
  });

  final bool canAnalyze;
  final bool passed;
  final String summary;
  final double score;
  final int totalParagraphs;
  final int headingCount;
  final double justifiedBodyRatio;
  final List<String> checks;
  final String engine;
  final int totalPages;

  factory DocumentFormatScreeningResult.fromApi(Map<String, dynamic> json) {
    final checksRaw = (json['checks'] as List?) ?? const [];
    return DocumentFormatScreeningResult(
      canAnalyze: json['can_analyze'] == true,
      passed: json['passed'] == true,
      summary: (json['summary'] ?? '').toString(),
      score: (json['score'] is num)
          ? (json['score'] as num).toDouble()
          : double.tryParse((json['score'] ?? '0').toString()) ?? 0,
      totalParagraphs: (json['total_paragraphs'] is num)
          ? (json['total_paragraphs'] as num).toInt()
          : int.tryParse((json['total_paragraphs'] ?? '0').toString()) ?? 0,
      headingCount: (json['heading_count'] is num)
          ? (json['heading_count'] as num).toInt()
          : int.tryParse((json['heading_count'] ?? '0').toString()) ?? 0,
      justifiedBodyRatio: (json['justified_body_ratio'] is num)
          ? (json['justified_body_ratio'] as num).toDouble()
          : double.tryParse((json['justified_body_ratio'] ?? '0').toString()) ??
                0,
      checks: checksRaw.map((e) => e.toString()).toList(),
      engine: (json['engine'] ?? 'api').toString(),
      totalPages: (json['total_pages'] is num)
          ? (json['total_pages'] as num).toInt()
          : int.tryParse((json['total_pages'] ?? '0').toString()) ?? 0,
    );
  }
}

class DocumentFormatScreeningService {
  DocumentFormatScreeningService({SiporaApiService? apiService})
    : _apiService = apiService ?? SiporaApiService();

  final SiporaApiService _apiService;

  final Map<String, DocumentFormatRule> _rules = const {
    'skripsi': DocumentFormatRule(
      minHeadingCount: 5,
      minJustifiedBodyRatio: 0.65,
      requiredKeywords: ['BAB I', 'BAB II', 'BAB III'],
    ),
    'thesis': DocumentFormatRule(
      minHeadingCount: 5,
      minJustifiedBodyRatio: 0.65,
      requiredKeywords: ['BAB I', 'BAB II', 'BAB III'],
    ),
    'tesis': DocumentFormatRule(
      minHeadingCount: 5,
      minJustifiedBodyRatio: 0.65,
      requiredKeywords: ['BAB I', 'BAB II', 'BAB III'],
    ),
    'disertasi': DocumentFormatRule(
      minHeadingCount: 6,
      minJustifiedBodyRatio: 0.7,
      requiredKeywords: ['BAB I', 'BAB II', 'BAB III'],
    ),
    'laporan pkl': DocumentFormatRule(
      minHeadingCount: 3,
      minJustifiedBodyRatio: 0.6,
      requiredKeywords: ['PENDAHULUAN'],
    ),
    'artikel ilmiah': DocumentFormatRule(
      minHeadingCount: 4,
      minJustifiedBodyRatio: 0.55,
      requiredKeywords: ['ABSTRAK', 'PENDAHULUAN'],
    ),
  };

  bool isWordDocument(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.doc') || lower.endsWith('.docx');
  }

  bool isPdfDocument(String fileName) {
    return fileName.toLowerCase().endsWith('.pdf');
  }

  bool isSupportedForScreening(String fileName) {
    return canScreenWordDocument(fileName) || isPdfDocument(fileName);
  }

  bool canScreenWordDocument(String fileName) {
    return fileName.toLowerCase().endsWith('.docx');
  }

  Future<DocumentFormatScreeningResult> screenDocument({
    required Uint8List bytes,
    required String fileName,
    required String tipeDokumen,
  }) async {
    if (!isSupportedForScreening(fileName)) {
      return const DocumentFormatScreeningResult(
        canAnalyze: false,
        passed: false,
        summary: 'Format file untuk screening harus DOCX atau PDF.',
        score: 0,
        totalParagraphs: 0,
        headingCount: 0,
        justifiedBodyRatio: 0,
        checks: <String>['Gunakan format DOCX atau PDF.'],
      );
    }

    try {
      final response = await _apiService.screenDocument(
        fileName: fileName,
        fileBytes: bytes,
        tipeDokumen: tipeDokumen,
      );

      final screeningPayload = Map<String, dynamic>.from(
        (response['screening'] as Map?) ?? const <String, dynamic>{},
      );

      if (screeningPayload.isNotEmpty) {
        return DocumentFormatScreeningResult.fromApi(screeningPayload);
      }
    } catch (_) {
      // Fallback ke screening lokal saat backend OCR/YOLO belum tersedia.
    }

    if (canScreenWordDocument(fileName)) {
      return screenDocx(
        bytes: bytes,
        fileName: fileName,
        tipeDokumen: tipeDokumen,
      );
    }

    return const DocumentFormatScreeningResult(
      canAnalyze: false,
      passed: false,
      summary:
          'Screening backend untuk PDF belum aktif. Pastikan service OCR/YOLOv8 tersedia di server.',
      score: 0,
      totalParagraphs: 0,
      headingCount: 0,
      justifiedBodyRatio: 0,
      checks: <String>[
        'Jalankan service screening Python (OCR + YOLOv8) pada backend.',
      ],
    );
  }

  DocumentFormatScreeningResult screenDocx({
    required Uint8List bytes,
    required String fileName,
    required String tipeDokumen,
  }) {
    if (!isWordDocument(fileName)) {
      return const DocumentFormatScreeningResult(
        canAnalyze: false,
        passed: true,
        summary: 'File bukan Word (.doc/.docx), screening format dilewati.',
        score: 100,
        totalParagraphs: 0,
        headingCount: 0,
        justifiedBodyRatio: 0,
        checks: <String>['Screening format hanya untuk file Word.'],
        engine: 'local',
      );
    }

    if (!canScreenWordDocument(fileName)) {
      return const DocumentFormatScreeningResult(
        canAnalyze: false,
        passed: false,
        summary: 'Format .doc belum didukung untuk screening otomatis.',
        score: 0,
        totalParagraphs: 0,
        headingCount: 0,
        justifiedBodyRatio: 0,
        checks: <String>[
          'Gunakan file .docx agar format bisa diperiksa otomatis.',
        ],
        engine: 'local',
      );
    }

    final normalizedType = tipeDokumen.trim().toLowerCase();
    final displayType = normalizedType.isEmpty ? 'dokumen umum' : tipeDokumen;
    final rule =
        _rules[normalizedType] ??
        const DocumentFormatRule(
          minHeadingCount: 3,
          minJustifiedBodyRatio: 0.55,
          requiredKeywords: <String>['PENDAHULUAN'],
        );

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final docEntry = archive.files.where((f) => f.name == 'word/document.xml');
    if (docEntry.isEmpty) {
      return const DocumentFormatScreeningResult(
        canAnalyze: false,
        passed: false,
        summary: 'File DOCX tidak valid: document.xml tidak ditemukan.',
        score: 0,
        totalParagraphs: 0,
        headingCount: 0,
        justifiedBodyRatio: 0,
        checks: <String>['Pastikan file adalah DOCX yang valid.'],
        engine: 'local',
      );
    }

    final xmlText = utf8.decode(docEntry.first.content as List<int>);
    final xmlDoc = XmlDocument.parse(xmlText);

    final paragraphs = xmlDoc.findAllElements('w:p');
    int totalParagraphs = 0;
    int headingCount = 0;
    int bodyParagraphs = 0;
    int justifiedBodyParagraphs = 0;
    final allTextsUpper = <String>[];

    for (final p in paragraphs) {
      final text = p
          .findAllElements('w:t')
          .map((e) => e.innerText)
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (text.isEmpty) {
        continue;
      }

      totalParagraphs++;
      allTextsUpper.add(text.toUpperCase());

      final styleVal = _readParagraphStyleValue(p)?.toLowerCase() ?? '';
      final alignment = _readParagraphAlignment(p)?.toLowerCase() ?? '';

      final looksLikeHeadingByStyle =
          styleVal.contains('heading') ||
          styleVal.contains('judul') ||
          styleVal.contains('bab');

      final looksLikeHeadingByText =
          RegExp(
            r'^(BAB\s+[IVXLC0-9]+|[0-9]+(\.[0-9]+)+)\b',
            caseSensitive: false,
          ).hasMatch(text) ||
          (text.length < 70 && text == text.toUpperCase());

      final isHeading = looksLikeHeadingByStyle || looksLikeHeadingByText;

      if (isHeading) {
        headingCount++;
      } else {
        bodyParagraphs++;
        if (alignment == 'both') {
          justifiedBodyParagraphs++;
        }
      }
    }

    final justifiedRatio = bodyParagraphs == 0
        ? 0.0
        : justifiedBodyParagraphs / bodyParagraphs;

    final hasEnoughHeadings = headingCount >= rule.minHeadingCount;
    final hasEnoughJustifiedBody = justifiedRatio >= rule.minJustifiedBodyRatio;

    final contentUpper = allTextsUpper.join(' ');
    final keywordFlags = rule.requiredKeywords
        .map((k) => contentUpper.contains(k.toUpperCase()))
        .toList();
    final hasRequiredKeywords = keywordFlags.every((e) => e);

    final checks = <String>[
      hasEnoughHeadings
          ? 'Heading terdeteksi $headingCount (minimal ${rule.minHeadingCount})'
          : 'Heading kurang: $headingCount (minimal ${rule.minHeadingCount})',
      hasEnoughJustifiedBody
          ? 'Paragraf body rata kanan-kiri ${(justifiedRatio * 100).toStringAsFixed(1)}%'
          : 'Paragraf body rata kanan-kiri baru ${(justifiedRatio * 100).toStringAsFixed(1)}% (minimal ${(rule.minJustifiedBodyRatio * 100).toStringAsFixed(0)}%)',
      hasRequiredKeywords
          ? 'Bagian wajib ditemukan (${rule.requiredKeywords.join(', ')})'
          : 'Bagian wajib belum lengkap (${rule.requiredKeywords.join(', ')})',
    ];

    final passedChecks = [
      hasEnoughHeadings,
      hasEnoughJustifiedBody,
      hasRequiredKeywords,
    ].where((v) => v).length;
    final score = (passedChecks / 3) * 100;
    final passed = passedChecks == 3;

    return DocumentFormatScreeningResult(
      canAnalyze: true,
      passed: passed,
      summary: passed
          ? 'Format dokumen sesuai aturan dasar untuk $displayType.'
          : 'Format dokumen belum memenuhi aturan dasar untuk $displayType.',
      score: score,
      totalParagraphs: totalParagraphs,
      headingCount: headingCount,
      justifiedBodyRatio: justifiedRatio,
      checks: checks,
      engine: 'local',
    );
  }

  String? _readParagraphStyleValue(XmlElement paragraph) {
    for (final pPr in paragraph.findElements('w:pPr')) {
      for (final pStyle in pPr.findElements('w:pStyle')) {
        final val = pStyle.getAttribute('w:val') ?? pStyle.getAttribute('val');
        if (val != null && val.isNotEmpty) {
          return val;
        }
      }
    }
    return null;
  }

  String? _readParagraphAlignment(XmlElement paragraph) {
    for (final pPr in paragraph.findElements('w:pPr')) {
      for (final jc in pPr.findElements('w:jc')) {
        final val = jc.getAttribute('w:val') ?? jc.getAttribute('val');
        if (val != null && val.isNotEmpty) {
          return val;
        }
      }
    }
    return null;
  }
}
