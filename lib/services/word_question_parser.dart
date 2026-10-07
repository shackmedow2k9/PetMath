import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../models/question_model.dart';

class WordMediaAsset {
  final String path;
  final String fileName;
  final Uint8List bytes;

  const WordMediaAsset({
    required this.path,
    required this.fileName,
    required this.bytes,
  });
}

class WordImportResult {
  final List<QuestionModel> questions;
  final List<String> errors;
  final List<WordMediaAsset> mediaAssets;

  const WordImportResult({
    required this.questions,
    required this.errors,
    this.mediaAssets = const [],
  });

  bool get isValid => questions.isNotEmpty && errors.isEmpty;
}

/// Nhập DOCX theo nội dung thực tế của Word, không bắt buộc giáo viên phải
/// dán toàn bộ tài liệu vào một mẫu cứng. Parser nhận diện câu hỏi theo dòng
/// "Câu 1"/"Question 1", ba loại câu hỏi, bảng Word và ảnh nhúng.
class WordQuestionParser {
  static final _questionPattern = RegExp(
    r'^(?:(?:câu|question|bài|bai)\s*)?\d+\s*[.) :-]\s*(.*)$',
    caseSensitive: false,
  );
  static final _optionPattern = RegExp(
    r'^([A-D])\s*[.):-]\s*(.*)$',
    caseSensitive: false,
  );
  static final _typePattern = RegExp(
    r'^(?:dạng câu|dạng|loại câu|loại|type)\s*[:=-]\s*(.*)$',
    caseSensitive: false,
  );
  static final _answerPattern = RegExp(
    r'^(?:đáp án|dap an|đáp|đáp số|dap so|kết quả|ket qua|answer|đúng\s*[/\\-]?\s*sai)\s*[:=-]\s*(.*)$',
    caseSensitive: false,
  );
  static final _explanationPattern = RegExp(
    r'^(?:giải thích|giai thich|lời giải|loi giai)\s*[:=-]?\s*(.*)$',
    caseSensitive: false,
  );
  static final _topicPattern = RegExp(
    r'^(?:chuyên đề|chuyen de|chủ đề|chu de)\s*[:=-]\s*(.*)$',
    caseSensitive: false,
  );
  static final _difficultyPattern = RegExp(
    r'^(?:độ khó|do kho|difficulty)\s*[:=-]\s*([1-3])\b',
    caseSensitive: false,
  );
  static final _visual3dPattern = RegExp(
    r'^(?:hình 3d|hinh 3d|3d)\s*[:=-]\s*(.*)$',
    caseSensitive: false,
  );
  static final _mediaLinePattern = RegExp(
    r'^(?:ảnh|anh|hình ảnh|media|image)\s*[:=-]\s*(.*)$',
    caseSensitive: false,
  );

  const WordQuestionParser();

  WordImportResult parse({
    required Uint8List bytes,
    required String subject,
    required int? grade,
    required String sourceId,
    required String sourceName,
    required String sourceUrl,
    required String createdBy,
  }) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentEntry = archive.files.firstWhere(
        (file) => file.name == 'word/document.xml',
        orElse: () => throw const FormatException(
          'Không tìm thấy word/document.xml trong tệp DOCX.',
        ),
      );
      final documentBytes = documentEntry.readBytes();
      if (documentBytes == null) {
        throw const FormatException('Không thể đọc dữ liệu word/document.xml.');
      }
      final document = XmlDocument.parse(utf8.decode(documentBytes));
      final relationships = _readRelationships(archive);
      final mediaAssets = _readMediaAssets(archive);
      final blocks = _readBlocks(document, relationships);

      final drafts = <_QuestionDraft>[];
      _QuestionDraft? current;
      final pendingMediaPaths = <String>[];
      for (final block in blocks) {
        if (block.mediaPaths.isNotEmpty) {
          if (current != null) {
            current.mediaPaths.addAll(block.mediaPaths);
          } else {
            pendingMediaPaths.addAll(block.mediaPaths);
          }
        }
        final paragraph = block.text.trim();
        if (paragraph.isEmpty) continue;

        final questionMatch = _questionPattern.firstMatch(paragraph);
        if (questionMatch != null) {
          if (current != null) drafts.add(current);
          current = _QuestionDraft(
            content: questionMatch.group(1)?.trim() ?? '',
          );
          current.mediaPaths.addAll(pendingMediaPaths);
          pendingMediaPaths.clear();
          continue;
        }
        if (current == null) continue;
        if (paragraph.toLowerCase().startsWith('bảng:')) {
          current.content = '${current.content}\n$paragraph'.trim();
          continue;
        }

        final typeMatch = _typePattern.firstMatch(paragraph);
        if (typeMatch != null) {
          current.questionType = _normalizeQuestionType(typeMatch.group(1)!);
          continue;
        }
        final optionMatch = _optionPattern.firstMatch(paragraph);
        if (optionMatch != null) {
          current.options.add(optionMatch.group(2)?.trim() ?? '');
          continue;
        }
        final answerMatch = _answerPattern.firstMatch(paragraph);
        if (answerMatch != null) {
          current.answerRaw = answerMatch.group(1)?.trim();
          continue;
        }
        final explanationMatch = _explanationPattern.firstMatch(paragraph);
        if (explanationMatch != null) {
          current.explanation = explanationMatch.group(1)?.trim();
          continue;
        }
        final topicMatch = _topicPattern.firstMatch(paragraph);
        if (topicMatch != null) {
          current.topic = topicMatch.group(1)?.trim();
          continue;
        }
        final difficultyMatch = _difficultyPattern.firstMatch(paragraph);
        if (difficultyMatch != null) {
          current.difficulty = int.tryParse(difficultyMatch.group(1)!) ?? 1;
          continue;
        }
        final visual3dMatch = _visual3dPattern.firstMatch(paragraph);
        if (visual3dMatch != null) {
          current.visual3d = _parseVisual3d(visual3dMatch.group(1) ?? '');
          continue;
        }
        final mediaMatch = _mediaLinePattern.firstMatch(paragraph);
        if (mediaMatch != null) {
          current.mediaPaths.add(mediaMatch.group(1)!.trim());
          continue;
        }

        if (current.options.isEmpty && current.answerRaw == null) {
          current.content = '${current.content} $paragraph'.trim();
        } else if (current.explanation != null) {
          current.explanation = '${current.explanation} $paragraph'.trim();
        }
      }
      if (current != null) drafts.add(current);

      final questions = <QuestionModel>[];
      final errors = <String>[];
      for (var i = 0; i < drafts.length; i++) {
        final draft = drafts[i];
        if (draft.content.isEmpty) {
          errors.add('Câu ${i + 1}: thiếu nội dung.');
          continue;
        }
        final type = draft.questionType;
        if (type == 'multiple_choice') {
          final answerIndex = _multipleChoiceAnswerIndex(draft.answerRaw);
          if (draft.options.length != 4) {
            errors.add('Câu ${i + 1}: dạng 4 lựa chọn phải có đủ A-D.');
            continue;
          }
          if (answerIndex < 0) {
            errors.add('Câu ${i + 1}: thiếu hoặc sai dòng Đáp án A-D.');
            continue;
          }
          questions.add(_toQuestion(
            draft,
            subject: subject,
            grade: grade,
            sourceId: sourceId,
            sourceName: sourceName,
            sourceUrl: sourceUrl,
            createdBy: createdBy,
            questionType: type,
            correctOptionIndex: answerIndex,
          ));
        } else if (type == 'true_false') {
          if (draft.options.length < 2) {
            errors
                .add('Câu ${i + 1}: dạng đúng/sai cần ít nhất 2 mệnh đề A-D.');
            continue;
          }
          final answers = _parseBooleanAnswers(draft.answerRaw);
          if (answers.length != draft.options.length) {
            errors.add(
                'Câu ${i + 1}: cần đáp án Đ/S tương ứng với ${draft.options.length} mệnh đề.');
            continue;
          }
          questions.add(_toQuestion(
            draft,
            subject: subject,
            grade: grade,
            sourceId: sourceId,
            sourceName: sourceName,
            sourceUrl: sourceUrl,
            createdBy: createdBy,
            questionType: type,
            correctOptionIndex: 0,
            trueFalseAnswers: answers,
          ));
        } else {
          if ((draft.answerRaw ?? '').trim().isEmpty) {
            errors.add('Câu ${i + 1}: dạng trả lời ngắn cần dòng Đáp án.');
            continue;
          }
          questions.add(_toQuestion(
            draft,
            subject: subject,
            grade: grade,
            sourceId: sourceId,
            sourceName: sourceName,
            sourceUrl: sourceUrl,
            createdBy: createdBy,
            questionType: 'short_answer',
            correctOptionIndex: 0,
            shortAnswer: draft.answerRaw!.trim(),
          ));
        }
      }
      return WordImportResult(
        questions: questions,
        errors: errors,
        mediaAssets: mediaAssets,
      );
    } catch (error) {
      return WordImportResult(
        questions: const [],
        errors: ['Không thể đọc DOCX: $error'],
      );
    }
  }

  QuestionModel _toQuestion(
    _QuestionDraft draft, {
    required String subject,
    required int? grade,
    required String sourceId,
    required String sourceName,
    required String sourceUrl,
    required String createdBy,
    required String questionType,
    required int correctOptionIndex,
    List<bool>? trueFalseAnswers,
    String? shortAnswer,
  }) {
    return QuestionModel(
      id: '',
      subject: subject,
      content: draft.content,
      options: List.unmodifiable(draft.options),
      correctOptionIndex: correctOptionIndex,
      explanation: draft.explanation,
      difficulty: draft.difficulty.clamp(1, 3).toInt(),
      createdBy: createdBy,
      grade: grade,
      topic: draft.topic,
      sourceId: sourceId,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
      visual3d: draft.visual3d,
      questionType: questionType,
      trueFalseAnswers: trueFalseAnswers,
      shortAnswer: shortAnswer,
      mediaUrls: draft.mediaPaths.map((path) => 'docx:$path').toList(),
    );
  }

  String _normalizeQuestionType(String raw) {
    final value = raw.toLowerCase().replaceAll(' ', '');
    if (value.contains('đúng') ||
        value.contains('sai') ||
        value.contains('true')) {
      return 'true_false';
    }
    if (value.contains('ngắn') || value.contains('short')) {
      return 'short_answer';
    }
    return 'multiple_choice';
  }

  int _multipleChoiceAnswerIndex(String? raw) {
    if (raw == null) return -1;
    final letter =
        RegExp(r'[A-D]', caseSensitive: false).firstMatch(raw)?.group(0);
    return letter == null ? -1 : 'ABCD'.indexOf(letter.toUpperCase());
  }

  List<bool> _parseBooleanAnswers(String? raw) {
    if (raw == null) return const [];
    final tokens = raw
        .split(RegExp(r'[,;|/\s]+'))
        .map((token) => token.trim().toLowerCase())
        .where((token) => token.isNotEmpty)
        .toList();
    return tokens
        .where((token) =>
            token == 'đ' ||
            token == 'd' ||
            token == 'đúng' ||
            token == 'true' ||
            token == '1' ||
            token == 's' ||
            token == 'sai' ||
            token == 'false' ||
            token == '0')
        .map((token) =>
            token == 'đ' ||
            token == 'd' ||
            token == 'đúng' ||
            token == 'true' ||
            token == '1')
        .toList();
  }

  Map<String, String> _readRelationships(Archive archive) {
    final result = <String, String>{};
    final matchingFiles = archive.files
        .where((entry) => entry.name == 'word/_rels/document.xml.rels')
        .toList();
    if (matchingFiles.isEmpty) return result;
    final file = matchingFiles.first;
    final data = file.readBytes();
    if (data == null) return result;
    final xml = XmlDocument.parse(utf8.decode(data));
    for (final relation
        in xml.findAllElements('Relationship', namespace: '*')) {
      final id = relation.getAttribute('Id');
      final target = relation.getAttribute('Target');
      if (id == null || target == null) continue;
      result[id] = target.startsWith('word/') ? target : 'word/$target';
    }
    return result;
  }

  List<WordMediaAsset> _readMediaAssets(Archive archive) {
    return archive.files
        .where((file) => file.name.startsWith('word/media/'))
        .map((file) {
          final bytes = file.readBytes();
          if (bytes == null) return null;
          return WordMediaAsset(
            path: file.name,
            fileName: file.name.split('/').last,
            bytes: Uint8List.fromList(bytes),
          );
        })
        .whereType<WordMediaAsset>()
        .toList();
  }

  List<_WordBlock> _readBlocks(
      XmlDocument document, Map<String, String> relationships) {
    final blocks = <_WordBlock>[];
    for (final node in document.descendants.whereType<XmlElement>()) {
      if (node.name.local == 'p') {
        final mediaPaths = <String>[];
        for (final blip in node.findAllElements('blip', namespace: '*')) {
          final relId = blip.getAttribute('r:embed');
          if (relId != null && relationships[relId] != null) {
            mediaPaths.add(relationships[relId]!);
          }
        }
        blocks.add(_WordBlock(
          node
              .findAllElements('t', namespace: '*')
              .map((text) => text.innerText)
              .join(),
          mediaPaths,
        ));
      } else if (node.name.local == 'tbl') {
        final rows = node.findAllElements('tr', namespace: '*').map((row) => row
            .findAllElements('tc', namespace: '*')
            .map((cell) => cell
                .findAllElements('t', namespace: '*')
                .map((t) => t.innerText)
                .join())
            .join(' | '));
        blocks.add(_WordBlock('Bảng: ${rows.join('\n')}', const []));
      }
    }
    return blocks;
  }

  Map<String, dynamic>? _parseVisual3d(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    final shape = lower.contains('chóp') || lower.contains('chop')
        ? 'pyramid'
        : lower.contains('lăng trụ') || lower.contains('lang tru')
            ? 'prism'
            : lower.contains('trụ') || lower.contains('tru')
                ? 'cylinder'
                : lower.contains('cầu') || lower.contains('cau')
                    ? 'sphere'
                    : 'cuboid';
    final result = <String, dynamic>{
      'shape': shape,
      'title': value,
      'caption': 'Mô hình dựng theo tham số trong đề bài.',
    };
    final number = RegExp(
      r'(rộng|rong|width|cao|height|sâu|sau|depth|bán kính|ban kinh|radius|cạnh|canh|số cạnh|so canh)\s*[=:]\s*([0-9]+(?:[.,][0-9]+)?)',
      caseSensitive: false,
    );
    for (final match in number.allMatches(lower)) {
      final key = match.group(1)!.replaceAll(' ', '');
      final parsed = double.tryParse(match.group(2)!.replaceAll(',', '.'));
      if (parsed == null) continue;
      if (key.contains('rộng') || key.contains('rong') || key == 'width') {
        result['width'] = parsed;
      } else if (key.contains('cao') || key == 'height') {
        result['height'] = parsed;
      } else if (key.contains('sâu') || key.contains('sau') || key == 'depth') {
        result['depth'] = parsed;
      } else if (key.contains('bánkính') ||
          key.contains('bankinh') ||
          key == 'radius') {
        result['width'] = parsed * 2;
        result['depth'] = parsed * 2;
      } else if (key.contains('sốcạnh') || key.contains('socanh')) {
        result['sides'] = parsed.round();
      }
    }
    return result;
  }
}

class _QuestionDraft {
  String content;
  final List<String> options = [];
  String? answerRaw;
  String? explanation;
  String? topic;
  int difficulty = 1;
  String questionType = 'multiple_choice';
  Map<String, dynamic>? visual3d;
  final List<String> mediaPaths = [];

  _QuestionDraft({required this.content});
}

class _WordBlock {
  final String text;
  final List<String> mediaPaths;

  const _WordBlock(this.text, this.mediaPaths);
}
