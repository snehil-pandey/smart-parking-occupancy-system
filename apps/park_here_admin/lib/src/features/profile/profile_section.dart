part of '../../admin_dashboard_screen.dart';

class _ProfileSection extends StatefulWidget {
  const _ProfileSection({
    required this.firebase,
    required this.state,
    required this.controller,
  });

  final FirebaseReadiness firebase;
  final AdminAppState state;
  final AdminAppController controller;

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  late final TextEditingController _business;
  late final TextEditingController _owner;
  late final TextEditingController _phone;
  late final TextEditingController _upi;

  @override
  void initState() {
    super.initState();
    _business = TextEditingController(
      text: widget.state.admin?.businessName ?? '',
    );
    _owner = TextEditingController(text: widget.state.admin?.ownerName ?? '');
    _phone = TextEditingController(text: widget.state.admin?.phone ?? '');
    _upi = TextEditingController(text: widget.state.admin?.upiId ?? '');
  }

  @override
  void dispose() {
    _business.dispose();
    _owner.dispose();
    _phone.dispose();
    _upi.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ProfileSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldAdmin = oldWidget.state.admin;
    final admin = widget.state.admin;
    if (admin != null && oldAdmin?.id != admin.id) {
      _business.text = admin.businessName;
      _owner.text = admin.ownerName;
      _phone.text = admin.phone;
      _upi.text = admin.upiId ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.state.admin;
    if (admin == null) {
      return const _EmptyState(message: 'Sign in to manage admin settings.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile / Settings', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Business identity, Firebase status, and account controls.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Business info', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _business,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _owner,
                  decoration: const InputDecoration(labelText: 'Owner name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _upi,
                  decoration: const InputDecoration(
                    labelText: 'UPI/payment id optional',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: () => widget.controller.updateAdminProfile(
                        businessName: _business.text.trim(),
                        ownerName: _owner.text.trim(),
                        phone: _phone.text.trim(),
                        upiId: _upi.text.trim().isEmpty ? null : _upi.text.trim(),
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save profile'),
                    ),
                    OutlinedButton.icon(
                      onPressed: widget.controller.signOut,
                      icon: const Icon(Icons.logout),
                      label: const Text('Logout'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Firebase status', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    widget.firebase.isConfigured
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                  ),
                  title: Text(
                    widget.firebase.isConfigured
                        ? 'Connected to Firebase'
                        : 'Firebase setup required',
                  ),
                  subtitle: Text(widget.firebase.message),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Admin profile id'),
                  subtitle: SelectableText(admin.id),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
