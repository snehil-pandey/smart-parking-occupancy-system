part of '../../admin_dashboard_screen.dart';

class _IssuesPanel extends StatelessWidget {
  const _IssuesPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final byArea = {
      for (final location in state.locations) location.id: location.name,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issues Received',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (state.issues.isEmpty)
              const _EmptyState(message: 'No parking area issues received.')
            else
              for (final issue in state.issues)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    issue.status == IssueStatus.resolved
                        ? Icons.task_alt
                        : Icons.report_problem_outlined,
                  ),
                  title: Text(
                    '${issue.type} - ${byArea[issue.areaId] ?? issue.areaId}',
                  ),
                  subtitle: Text('${issue.message}\n${issue.createdAt}'),
                  isThreeLine: true,
                  trailing: DropdownButton<IssueStatus>(
                    value: issue.status,
                    onChanged: (status) {
                      if (status != null) {
                        controller.updateIssueStatus(issue, status);
                      }
                    },
                    items: IssueStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
