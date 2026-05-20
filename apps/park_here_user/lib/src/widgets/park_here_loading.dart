import 'package:flutter/material.dart';
import 'package:park_here_shared/park_here_shared.dart';

class ParkHereLoadingScreen extends StatelessWidget {
  const ParkHereLoadingScreen({
    required this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
    super.key,
  });

  final String message;
  final Future<void> Function()? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.94, end: 1.04),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeInOut,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    onEnd: () {},
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: ParkHereTheme.yellow),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Icon(
                          Icons.local_parking,
                          size: 72,
                          color: ParkHereTheme.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Park Here',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 22),
                  const SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(minHeight: 6),
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(retryLabel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class InlineParkHereLoading extends StatelessWidget {
  const InlineParkHereLoading({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(238),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_parking, size: 24),
            const SizedBox(width: 10),
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(message),
          ],
        ),
      ),
    );
  }
}
