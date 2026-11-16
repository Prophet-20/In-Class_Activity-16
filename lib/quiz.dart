import 'dart:convert';
import 'dart:math';

import 'package:html_unescape/html_unescape.dart';
import 'package:http/http.dart' as http;

class Question {
  final String text, correct;
  final List<String> choices;
  Question(this.text, this.correct, this.choices);
}

List<Question> parseQuestions(String body) {
  final dynamic data = jsonDecode(body);
  if (data is! Map || data['response_code'] != 0) {
    throw const FormatException('Question service rejected the request.');
  }
  final dynamic results = data['results'];
  if (results is! List || results.length != 10) {
    throw const FormatException('Expected exactly ten questions.');
  }
  final decoder = HtmlUnescape();
  String decode(dynamic value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Question or answer is empty.');
    }
    final result = decoder.convert(value).trim();
    if (result.isEmpty) throw const FormatException('Decoded text is empty.');
    return result;
  }

  return results
      .map((dynamic item) {
        if (item is! Map ||
            item['category'] != 'General Knowledge' ||
            item['difficulty'] != 'easy' ||
            item['type'] != 'multiple' ||
            item['incorrect_answers'] is! List ||
            (item['incorrect_answers'] as List).length != 3) {
          throw const FormatException('Invalid Class A question schema.');
        }
        final correct = decode(item['correct_answer']);
        final choices = [
          correct,
          ...(item['incorrect_answers'] as List).map(decode),
        ];
        if (choices.toSet().length != 4) {
          throw const FormatException(
            'Answers must be distinct after decoding.',
          );
        }
        choices.shuffle(Random());
        return Question(
          decode(item['question']),
          correct,
          List.unmodifiable(choices),
        );
      })
      .toList(growable: false);
}

class QuestionService {
  static final uri = Uri.parse(
    'https://opentdb.com/api.php?amount=10&category=9&difficulty=easy&type=multiple',
  );
  DateTime? lastRequest;
  Future<List<Question>> load({String injected = 'none'}) async {
    final now = DateTime.now();
    if (lastRequest != null && now.difference(lastRequest!).inSeconds < 5) {
      throw StateError('Wait at least five seconds between question requests.');
    }
    lastRequest = now;
    if (injected == 'bad-json') return parseQuestions('{broken');
    if (injected == 'api-code')
      return parseQuestions('{"response_code":5,"results":[]}');
    if (injected == 'nine-results')
      return parseQuestions(
        jsonEncode({'response_code': 0, 'results': List.filled(9, {})}),
      );
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('HTTP ${response.statusCode}: question request failed.');
    }
    return parseQuestions(response.body);
  }
}
