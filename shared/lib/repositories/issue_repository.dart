import '../models/issue_report.dart';

abstract interface class IssueRepository {
  Future<List<IssueReport>> getForAdmin(String adminId, {IssueStatus? status});

  Stream<List<IssueReport>> watchForAdmin(
    String adminId, {
    IssueStatus? status,
  });

  Future<IssueReport> createIssue(IssueReport issue);

  Future<void> updateIssueStatus({
    required String issueId,
    required IssueStatus status,
  });
}
