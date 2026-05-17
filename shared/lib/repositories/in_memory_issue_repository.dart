import '../models/issue_report.dart';
import '../utils/demo_seed.dart';
import 'issue_repository.dart';

class InMemoryIssueRepository implements IssueRepository {
  InMemoryIssueRepository({List<IssueReport>? seed}) : _issues = [...?seed] {
    if (_issues.isEmpty) {
      _issues.addAll(DemoSeed.issues());
    }
  }

  final List<IssueReport> _issues;

  @override
  Future<IssueReport> createIssue(IssueReport issue) async {
    _issues.insert(0, issue);
    return issue;
  }

  @override
  Future<List<IssueReport>> getForAdmin(
    String adminId, {
    IssueStatus? status,
  }) async {
    return _issues
        .where((issue) => issue.adminId == adminId)
        .where((issue) => status == null || issue.status == status)
        .toList();
  }

  @override
  Stream<List<IssueReport>> watchForAdmin(
    String adminId, {
    IssueStatus? status,
  }) {
    return Stream.fromFuture(getForAdmin(adminId, status: status));
  }

  @override
  Future<void> updateIssueStatus({
    required String issueId,
    required IssueStatus status,
  }) async {
    final index = _issues.indexWhere((issue) => issue.issueId == issueId);
    if (index == -1) {
      return;
    }
    _issues[index] = _issues[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
  }
}
