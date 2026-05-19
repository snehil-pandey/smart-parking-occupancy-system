part of '../admin_dashboard_screen.dart';

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.firebase, required this.admin});

  final FirebaseReadiness firebase;
  final AdminProfile admin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: firebase.isConfigured
            ? const Color(0xFFEAF7EE)
            : const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7DEC1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${admin.businessName} - ${firebase.message}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRefresh});

  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF4B8B8)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton.icon(
              onPressed: () {
                onRefresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      ),
    );
  }
}
