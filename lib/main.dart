import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'attempts.dart';
import 'controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    QuizApp(
      controller: QuizController(
        FirebaseAuth.instance,
        AttemptRepository(FirebaseFirestore.instance),
      ),
    ),
  );
}

class QuizApp extends StatelessWidget {
  final QuizController controller;
  const QuizApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Cloud Quiz',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff185d69)),
      scaffoldBackgroundColor: const Color(0xfff6f8fa),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 8)),
    ),
    home: QuizScreen(controller: controller),
  );
}

class QuizScreen extends StatefulWidget {
  final QuizController controller;
  const QuizScreen({super.key, required this.controller});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final email = TextEditingController(),
      password = TextEditingController(),
      savedId = TextEditingController();
  QuizController get c => widget.controller;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    savedId.dispose();
    super.dispose();
  }

  Widget gap() => const SizedBox(height: 16);
  Widget card(Widget child) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Quiz'),
        actions: [
          if (c.uid != null)
            TextButton(
              onPressed: c.locked ? null : c.signOut,
              child: const Text('Sign out'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'GENERAL KNOWLEDGE / CLASS A',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ten questions. One cloud record.',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  gap(),
                  Semantics(
                    liveRegion: true,
                    child: card(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                c.phase == QuizPhase.cloudVerified
                                    ? Icons.cloud_done
                                    : c.busy
                                    ? Icons.hourglass_top
                                    : Icons.info_outline,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  c.phase.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (c.busy)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: LinearProgressIndicator(),
                            ),
                          const SizedBox(height: 8),
                          Text(c.message, key: const Key('status')),
                        ],
                      ),
                    ),
                  ),
                  if (c.uid == null) ...[
                    gap(),
                    TextField(
                      controller: email,
                      key: const Key('email'),
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    gap(),
                    TextField(
                      controller: password,
                      key: const Key('password'),
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    gap(),
                    FilledButton(
                      onPressed: c.busy
                          ? null
                          : () async {
                              final p = password.text;
                              password.clear();
                              await c.signIn(email.text, p);
                            },
                      child: const Text('Sign in'),
                    ),
                  ] else ...[
                    Text('Account …${c.uid!.substring(c.uid!.length - 6)}'),
                    if (c.roundId != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: SelectableText(
                          'users/${c.uid}/attempts/${c.roundId}',
                          key: const Key('path'),
                        ),
                      ),
                    if (c.phase == QuizPhase.playing) ...[
                      gap(),
                      LinearProgressIndicator(value: (c.index + 1) / 10),
                      gap(),
                      Text(
                        'Question ${c.index + 1} of 10 • Score ${c.score}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              c.questions[c.index].text,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            gap(),
                            for (final answer in c.questions[c.index].choices)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OutlinedButton(
                                  onPressed: c.selections[c.index] == null
                                      ? () => c.choose(answer)
                                      : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        if (c.selections[c.index] != null)
                                          Icon(
                                            answer ==
                                                    c.questions[c.index].correct
                                                ? Icons.check_circle
                                                : answer ==
                                                      c.selections[c.index]
                                                ? Icons.cancel
                                                : Icons.circle_outlined,
                                            color:
                                                answer ==
                                                    c.questions[c.index].correct
                                                ? Colors.green.shade800
                                                : Colors.red.shade800,
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            answer,
                                            style: const TextStyle(
                                              color: Color(0xff163943),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            FilledButton(
                              onPressed: c.selections[c.index] == null
                                  ? null
                                  : c.next,
                              child: Text(
                                c.index == 9 ? 'Review round' : 'Next question',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (c.questions.isNotEmpty &&
                        c.phase != QuizPhase.playing &&
                        c.selections.every((s) => s != null)) ...[
                      gap(),
                      Text(
                        'Final score ${c.score} / 10',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Wrap(
                        spacing: 12,
                        children: [
                          FilledButton(
                            onPressed:
                                c.phase == QuizPhase.readyToSubmit && !c.locked
                                ? c.submit
                                : null,
                            child: const Text('Submit score'),
                          ),
                          OutlinedButton(
                            onPressed: c.locked ? null : c.startRound,
                            child: const Text('Replay'),
                          ),
                        ],
                      ),
                      for (var i = 0; i < c.questions.length; i++)
                        card(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}. ${c.questions[i].text}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('Selected: ${c.selections[i]}'),
                              Text('Correct: ${c.questions[i].correct}'),
                              Text(
                                c.selections[i] == c.questions[i].correct
                                    ? '✓ Correct'
                                    : '✗ Incorrect',
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (c.unresolved ||
                        c.phase == QuizPhase.verificationUnavailable)
                      FilledButton.tonal(
                        onPressed: c.busy ? null : c.reconcile,
                        child: const Text('Check same ID on server'),
                      ),
                    if (c.verified != null)
                      card(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verified server payload',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            for (final entry in c.verified!.entries)
                              Text(
                                '${entry.key}: ${entry.value is Timestamp ? (entry.value as Timestamp).toDate().toUtc().toIso8601String() : entry.value}',
                              ),
                            const Text(
                              'Source.server • cache false • pending writes false',
                            ),
                          ],
                        ),
                      ),
                    if (c.questions.isEmpty && !c.locked)
                      FilledButton(
                        onPressed: c.startRound,
                        child: Text(
                          c.phase == QuizPhase.requestError
                              ? 'Retry questions'
                              : 'Start new round',
                        ),
                      ),
                    gap(),
                    ExpansionTile(
                      title: const Text('Retrieve an existing attempt'),
                      children: [
                        TextField(
                          controller: savedId,
                          enabled: !c.locked,
                          decoration: const InputDecoration(
                            labelText: 'Saved round ID',
                          ),
                        ),
                        TextButton(
                          onPressed: c.locked
                              ? null
                              : () => c.retrieve(savedId.text.trim()),
                          child: const Text('Read from server'),
                        ),
                      ],
                    ),
                    if (developmentTools)
                      ExpansionTile(
                        title: const Text('Development fault injection'),
                        subtitle: const Text(
                          'Test build only • all injections are labeled',
                        ),
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: c.apiFault,
                            items:
                                ['none', 'bad-json', 'api-code', 'nine-results']
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                            onChanged: c.locked
                                ? null
                                : (s) => setState(() => c.apiFault = s!),
                            decoration: const InputDecoration(
                              labelText: 'Question injection',
                            ),
                          ),
                          gap(),
                          DropdownButtonFormField<String>(
                            initialValue: c.cloudFault,
                            items: ['none', 'unavailable', 'resource-exhausted']
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(s),
                                  ),
                                )
                                .toList(),
                            onChanged: c.locked
                                ? null
                                : (s) => setState(() => c.cloudFault = s!),
                            decoration: const InputDecoration(
                              labelText: 'Cloud injection',
                            ),
                          ),
                          SwitchListTile(
                            title: const Text('Hide committed acknowledgement'),
                            value: c.hideAcknowledgement,
                            onChanged: c.locked
                                ? null
                                : (v) =>
                                      setState(() => c.hideAcknowledgement = v),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
