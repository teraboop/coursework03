import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChallengeScreen extends StatelessWidget {
  const ChallengeScreen({
    super.key,
    required this.user,
    required this.onComplete,
  });
  final User user;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Cloud Quest')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Signed in as ${user.email ?? user.uid}'),
        Text("Today's challenge", style: Theme.of(context).textTheme.headlineSmall),
        const Text('Challenge prompt loads from Cloud Firestore.'),
        const SizedBox(height: 16),
        FilledButton(onPressed: onComplete, child: const Text('Complete challenge')),
        TextField(
          maxLength: 300,
          decoration: InputDecoration(labelText: 'Ask the Quest Coach for a hint'),
        ),
        OutlinedButton(onPressed: () {}, child: const Text('Get hint')),
      ],
    ),
  );
}