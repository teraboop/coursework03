import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/coach_service.dart';
import '../services/challenge_service.dart';
import 'package:flutter/material.dart';
import '../services/reward_service.dart';

class ChallengeScreen extends StatefulWidget {
  const ChallengeScreen({
    super.key,
    required this.user,
  });
  final User user;

  @override
  State<ChallengeScreen> createState() => _ChallengeScreenState();
}

class _ChallengeScreenState extends State<ChallengeScreen> {
  final questionController = TextEditingController();
  bool isLoading = false;
  String coachReply = '';
  late Future<Map<String, Object?>> _todayFuture;

  @override
  void initState() {
    super.initState();
    _todayFuture = loadToday();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cloud Quest')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Signed in as ${widget.user.email ?? widget.user.uid}'),
        Text("Today's challenge", style: Theme.of(context).textTheme.headlineSmall),
        FutureBuilder<Map<String, Object?>>(
          future: _todayFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              );
            }
            if (snapshot.hasError) {
              return Text('Could not load today\'s challenge: ${snapshot.error}');
            }
            final challenge = snapshot.data?['challenge'] as Map<String, dynamic>?;
            final progress = snapshot.data?['progress'] as Map<String, dynamic>?;
            if (challenge == null) {
              return const Text('No challenge is available today.');
            }
            final completed = progress?['completed'] == true;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge['title'] as String? ?? 'Untitled challenge',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(challenge['prompt'] as String? ?? ''),
                if (completed) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Completed • ${progress?['points']} pts • ${progress?['badgeId']}',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () async {
            try {
              await completeChallenge();
              if (!mounted) return;
              setState(() {
                _todayFuture = loadToday();
              });
            } on FirebaseFunctionsException catch (error) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not complete challenge: ${error.message}')),
              );
            }
          },
          child: const Text('Complete challenge'),
        ),
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
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => FirebaseAuth.instance.signOut(),
          child: const Text('Log out'),
        ),
      ],
    ),
  );
}