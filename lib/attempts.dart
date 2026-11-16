import 'package:cloud_firestore/cloud_firestore.dart';

class AttemptCollision implements Exception {
  @override
  String toString() => 'Round ID collision. The original attempt is preserved.';
}

class AttemptRepository {
  final FirebaseFirestore db;
  AttemptRepository(this.db);
  CollectionReference<Map<String, dynamic>> attempts(String uid) =>
      db.collection('users').doc(uid).collection('attempts');
  Map<String, dynamic> fixed(int score) => {
    'schemaVersion': 1,
    'variant': 'A',
    'categoryId': 9,
    'questionCount': 10,
    'correctCount': score,
  };
  bool matches(Map<String, dynamic> data, int score) =>
      data.length == 6 &&
      [
        'schemaVersion',
        'categoryId',
        'questionCount',
        'correctCount',
      ].every((k) => data[k] is int) &&
      fixed(score).entries.every((e) => data[e.key] == e.value) &&
      data['submittedAt'] is Timestamp;
  Future<void> commit(
    String uid,
    String id,
    Map<String, dynamic> frozen,
  ) async {
    final ref = attempts(uid).doc(id);
    await db.runTransaction(
      (tx) async {
        final existing = await tx.get(ref);
        if (existing.exists) {
          if (!matches(existing.data()!, frozen['correctCount'] as int)) {
            throw AttemptCollision();
          }
        } else {
          tx.set(ref, frozen);
        }
      },
      maxAttempts: 3,
      timeout: const Duration(seconds: 20),
    );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> read(String uid, String id) =>
      attempts(uid).doc(id).get(const GetOptions(source: Source.server));
  Future<DocumentSnapshot<Map<String, dynamic>>> verify(
    String uid,
    String id,
    int? score,
  ) async {
    final snap = await read(uid, id);
    if (snap.metadata.isFromCache || snap.metadata.hasPendingWrites) {
      throw StateError('Server confirmation is not yet available.');
    }
    if (snap.exists) {
      final data = snap.data()!;
      final savedScore = data['correctCount'];
      if (savedScore is! int ||
          savedScore < 0 ||
          savedScore > 10 ||
          !matches(data, score ?? savedScore)) {
        throw AttemptCollision();
      }
    }
    return snap;
  }
}
