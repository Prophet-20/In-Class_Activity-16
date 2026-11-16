import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ica16_cloud_quiz/quiz.dart';

void main() {
  Map<String, dynamic> question() => {
    'category': 'General Knowledge',
    'difficulty': 'easy',
    'type': 'multiple',
    'question': 'A &amp; B?',
    'correct_answer': 'A',
    'incorrect_answers': ['B', 'C', 'D'],
  };
  String fixture(List<dynamic> list) =>
      jsonEncode({'response_code': 0, 'results': list});
  test('T02 decoded valid data and stable four-choice lists', () {
    final q = parseQuestions(fixture(List.generate(10, (_) => question())));
    expect(q.length, 10);
    expect(q.first.text, 'A & B?');
    expect(q.first.choices.toSet(), {'A', 'B', 'C', 'D'});
  });
  test(
    'T03 malformed, API failure, nine results, duplicate decoded choices',
    () {
      for (final body in [
        '{bad',
        '{"response_code":5,"results":[]}',
        fixture(List.generate(9, (_) => question())),
      ]) {
        expect(() => parseQuestions(body), throwsFormatException);
      }
      final bad = question()..['incorrect_answers'] = ['&#65;', 'C', 'D'];
      expect(
        () => parseQuestions(fixture(List.filled(10, bad))),
        throwsFormatException,
      );
    },
  );
  test(
    'T03 retry is rate limited even for injected malformed responses',
    () async {
      final service = QuestionService();
      await expectLater(
        service.load(injected: 'bad-json'),
        throwsFormatException,
      );
      await expectLater(service.load(injected: 'bad-json'), throwsStateError);
    },
  );
}
