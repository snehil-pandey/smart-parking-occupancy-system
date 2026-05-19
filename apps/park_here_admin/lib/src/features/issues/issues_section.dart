part of '../../admin_dashboard_screen.dart';

class _IssuesPanel extends StatefulWidget {
  const _IssuesPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  State<_IssuesPanel> createState() => _IssuesPanelState();
}

class _IssuesPanelState extends State<_IssuesPanel> {
  String? _areaId;
  IssueStatus? _status;

  @override
  Widget build(BuildContext context) {
    final byArea = {
      for (final location in widget.state.locations) location.id: location.name,
    };
    final visibleIssues = widget.state.issues.where((issue) {
      final areaMatches = _areaId == null || issue.areaId == _areaId;
      final statusMatches = _status == null || issue.status == _status;
      return areaMatches && statusMatches;
    }).toList();

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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                DropdownMenu<String?>(
                  initialSelection: _areaId,
                  label: const Text('Area filter'),
                  onSelected: (value) => setState(() => _areaId = value),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry(value: null, label: 'All areas'),
                    for (final location in widget.state.locations)
                      DropdownMenuEntry(
                        value: location.id,
                        label: location.name,
                      ),
                  ],
                ),
                DropdownMenu<IssueStatus?>(
                  initialSelection: _status,
                  label: const Text('Status'),
                  onSelected: (value) => setState(() => _status = value),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry(value: null, label: 'All statuses'),
                    for (final status in IssueStatus.values)
                      DropdownMenuEntry(value: status, label: status.label),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.state.issues.isEmpty)
              const _EmptyState(message: 'No parking area issues received.')
            else if (visibleIssues.isEmpty)
              const _EmptyState(message: 'No issues match the current filters.')
            else
              for (final issue in visibleIssues)
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
                        widget.controller.updateIssueStatus(issue, status);
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
