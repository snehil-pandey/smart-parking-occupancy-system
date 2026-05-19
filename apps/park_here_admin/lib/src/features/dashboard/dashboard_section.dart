part of '../../admin_dashboard_screen.dart';

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
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 1100 ? 4 : 2,
        childAspectRatio: 1.9,
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
  }
}
