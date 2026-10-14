import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/core/cache/cache_status.dart';
import 'package:unshrimp_app/features/home/widgets/offline_indicator.dart';

class _FixedStatus extends CacheStatusNotifier {
  _FixedStatus(this._status);
  final CacheStatus _status;
  @override
  CacheStatus build() => _status;
}

Future<void> _pump(WidgetTester tester, CacheStatus status) => tester.pumpWidget(
  ProviderScope(
    overrides: [cacheStatusProvider.overrideWith(() => _FixedStatus(status))],
    child: const MaterialApp(
      home: Scaffold(appBar: _Bar()),
    ),
  ),
);

class _Bar extends StatelessWidget implements PreferredSizeWidget {
  const _Bar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) =>
      AppBar(actions: const [OfflineIndicator()]);
}

void main() {
  testWidgets('shows Offline and the data age when offline', (tester) async {
    await _pump(tester, CacheStatus(offline: true, asOf: DateTime(2024, 1, 1, 10, 42)));

    expect(find.text('Offline'), findsOneWidget);
    expect(find.textContaining('as of'), findsOneWidget);
    expect(find.textContaining('10:42'), findsOneWidget);
  });

  testWidgets('shows nothing when online', (tester) async {
    await _pump(tester, const CacheStatus(offline: false));

    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('shows Offline without an age when none is known', (tester) async {
    await _pump(tester, const CacheStatus(offline: true));

    expect(find.text('Offline'), findsOneWidget);
    expect(find.textContaining('as of'), findsNothing);
  });
}
