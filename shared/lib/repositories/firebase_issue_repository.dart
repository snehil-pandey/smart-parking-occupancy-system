import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/issue_report.dart';
import '../services/firebase_collection_paths.dart';
import '../services/firestore_model_mapper.dart';
import 'issue_repository.dart';

class FirebaseIssueRepository implements IssueRepository {
  FirebaseIssueRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<IssueReport> createIssue(IssueReport issue) async {
    await _issues
        .doc(issue.issueId)
        .set(
          FirestoreModelMapper.issueToFirestore(issue),
          SetOptions(merge: true),
        );
    return issue;
  }

  @override
  Future<List<IssueReport>> getForAdmin(
    String adminId, {
    IssueStatus? status,
  }) async {
    Query<Map<String, dynamic>> query = _issues.where(
      'adminId',
      isEqualTo: adminId,
    );
    if (status != null) {
      query = query.where('status', isEqualTo: status.label);
    }
    final snapshot = await query.get();
    return _sortedIssues(snapshot).take(50).toList();
  }

  @override
  Stream<List<IssueReport>> watchForAdmin(
    String adminId, {
    IssueStatus? status,
  }) {
    Query<Map<String, dynamic>> query = _issues.where(
      'adminId',
      isEqualTo: adminId,
    );
    if (status != null) {
      query = query.where('status', isEqualTo: status.label);
    }
    return query.snapshots().map(
      (snapshot) => _sortedIssues(snapshot).take(50).toList(),
    );
  }

  @override
  Future<void> updateIssueStatus({
    required String issueId,
    required IssueStatus status,
  }) async {
    await _issues.doc(issueId).update({
      'status': status.label,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  CollectionReference<Map<String, dynamic>> get _issues =>
      _firestore.collection(FirebaseCollectionPaths.issueReports);

  List<IssueReport> _sortedIssues(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs.map(FirestoreModelMapper.issueFromDoc).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
