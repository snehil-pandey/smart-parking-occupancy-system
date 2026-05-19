part of '../../admin_dashboard_screen.dart';

class _DashboardSection extends StatelessWidget {
  const _DashboardSection({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final unresolvedIssues = state.issues
        .where((issue) => issue.status != IssueStatus.resolved)
        .length;
    final openAreas = state.locations
        .where((location) => location.isOpen)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Live operations',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'SIT Tumkur parking status, bookings, and owner actions in one quick view.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _StatsGrid(state: state),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _QuickActionCard(
              icon: Icons.local_parking,
              title: 'Manage areas',
              subtitle: '$openAreas open of ${state.locations.length}',
              onTap: () => controller.changeSection(AdminSection.parkingAreas),
            ),
            _QuickActionCard(
              icon: Icons.confirmation_number,
              title: 'Active bookings',
              subtitle: '${state.activeBookings} live tickets',
              onTap: () => controller.changeSection(AdminSection.bookings),
            ),
            _QuickActionCard(
              icon: Icons.report_problem,
              title: 'Issues received',
              subtitle: '$unresolvedIssues need attention',
              onTap: () => controller.changeSection(AdminSection.issues),
            ),
            _QuickActionCard(
              icon: Icons.polyline,
              title: 'Region Management',
              subtitle: '${state.region.boundaryPoints.length} boundary points',
              onTap: () => controller.changeSection(AdminSection.region),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recent activity',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                if (state.bookings.isEmpty && state.issues.isEmpty)
                  const _EmptyState(
                    message:
                        'Bookings and user issues will appear here as Firebase updates arrive.',
                  )
                else ...[
                  for (final booking in state.bookings.take(3))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.qr_code_2),
                      title: Text(booking.vehicleNumber),
                      subtitle: Text(
                        '${booking.status.name} - ${formatInr(booking.price)}',
                      ),
                    ),
                  for (final issue in state.issues.take(2))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.report_problem_outlined),
                      title: Text(issue.type),
                      subtitle: Text(issue.message),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width >= 700 ? 240 : double.infinity,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.state});

  final AdminAppState state;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Total spaces', '${state.totalSpaces}', Icons.grid_view_outlined),
      ('Available', '${state.availableSpaces}', Icons.event_available_outlined),
      (
        'Active bookings',
        '${state.activeBookings}',
        Icons.confirmation_number_outlined,
      ),
      ('Today income', formatInr(state.todaysIncome), Icons.payments_outlined),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1100
            ? 4
            : constraints.maxWidth < 420
            ? 1
            : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 1 ? 3.2 : 1.55,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final stat = stats[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    CircleAvatar(child: Icon(stat.$3)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stat.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              stat.$2,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
