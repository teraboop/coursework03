import 'package:cloud_functions/cloud_functions.dart';

final askQuestCoach =
    FirebaseFunctions.instance.httpsCallable('askQuestCoach');

Future<String> getQuestHint(String question) async {
  final trimmed = question.trim();
  final safeQuestion = trimmed.length > 300
      ? trimmed.substring(0, 300)
      : trimmed;
  final result = await askQuestCoach.call<Map<String, dynamic>>({
    'question': safeQuestion,
  });
  return result.data['reply'] as String;
}