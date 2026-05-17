import '../models/issue_report.dart';
import 'firebase_repository_exception.dart';
import 'issue_repository.dart';

class FirebaseIssueRepository implements IssueRepository {
  const FirebaseIssueRepository();

  Never _missingConfig() {
    throw const FirebaseRepositoryException(
      'FirebaseIssueRepository needs cloud_firestore wiring. Query /issue_reports by adminId/status.',
    );
  }

  @override
  Future<IssueReport> createIssue(IssueReport issue) async => _missingConfig();

  @override
  Future<List<IssueReport>> getForAdmin(
    String adminId, {
    IssueStatus? status,
  }) async => _missingConfig();

  @override
  Stream<List<IssueReport>> watchForAdmin(
    String adminId, {
    IssueStatus? status,
  }) => _missingConfig();

  @override
  Future<void> updateIssueStatus({
    required String issueId,
    required IssueStatus status,
  }) async => _missingConfig();
}
