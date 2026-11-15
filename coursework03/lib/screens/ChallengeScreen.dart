import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/coach_service.dart';
import 'package:flutter/material.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.user,
    required this.onComplete,
  });
  final User user;
  final VoidCallback onComplete;
  
  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final questionController = TextEditingController();
  bool isLoading = false;
  String coachReply = '';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cloud Quest')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Signed in as ${widget.user.email ?? widget.user.uid}'),
        Text("Today's challenge", style: Theme.of(context).textTheme.headlineSmall),
        const Text('Challenge prompt loads from Cloud Firestore.'),
        const SizedBox(height: 16),
        FilledButton(onPressed: widget.onComplete, child: const Text('Complete challenge')),
        TextField(
          maxLength: 300,
          controller: questionController,
          decoration: InputDecoration(labelText: 'Ask the Quest Coach for a hint'),
        ),
        FilledButton(
          onPressed: isLoading ? null : () async {
            setState(() => isLoading = true);
            try {
              final reply = await getQuestHint(questionController.text);
              if (!mounted) return;
              setState(() => coachReply = reply);
            } on FirebaseFunctionsException catch (error) {
              debugPrint('Quest Coach request failed: ${error.code}');
              if (!mounted) return;
              setState(() => coachReply = 'The coach is unavailable. Try again.');
            } finally {
              if (mounted) setState(() => isLoading = false);
            }
          },
          child: Text(isLoading ? 'Thinking…' : 'Get hint'),
        ),
        if (coachReply.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(coachReply),
        ]
      ],
    ),
  );
}