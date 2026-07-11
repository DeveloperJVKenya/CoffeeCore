import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Farm%20Management/farm_management_theme.dart';

/// Standard loading / error / content branching used by every
/// `Consumer<X>` in this section. Renders [errorMessage] (typically a
/// `ServiceUnavailableException.userMessage`) instead of ever substituting
/// fabricated data.
class LoadingErrorView extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final WidgetBuilder builder;

  const LoadingErrorView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.builder,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(FarmTheme.spaceXl),
          child: CircularProgressIndicator(color: FarmTheme.primaryBrown),
        ),
      );
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(FarmTheme.spaceXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: FarmTheme.accentBad),
              const SizedBox(height: FarmTheme.spaceMd),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: FarmTheme.spaceMd),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Retry',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: FarmTheme.primaryBrown),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return builder(context);
  }
}
