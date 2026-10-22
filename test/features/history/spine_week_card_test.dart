import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unshrimp_app/features/history/models/weekly_report.dart';
import 'package:unshrimp_app/features/history/view_models/spine_report_share.dart';
import 'package:unshrimp_app/features/history/view_models/weekly_report_view_model.dart';
import 'package:unshrimp_app/features/history/widgets/spine_week_card.dart';

class _FakeWeeklyVM extends WeeklyReportViewModel {
  _FakeWeeklyVM(this._value);
  final WeeklyReport _value;
  @override
  Future<WeeklyReport> build() async => _value;
}

void main() {
  testWidgets('shows the four numbers, the delta and the verdict', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklyReportViewModelProvider.overrideWith(
            () => _FakeWeeklyVM(
              const WeeklyReport(
                locked: false,
                breaks: 24,
                ignored: 3,
                longestStreak: 4,
                breaksDelta: 6,
                verdict: 'You ignored me 3 times. I counted.',
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SpineWeekCard())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('24'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.textContaining('6 more breaks than last week'), findsOneWidget);
    expect(find.text('You ignored me 3 times. I counted.'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  testWidgets('Share captures the card and shares it as a PNG', (tester) async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    Uint8List? shared;
    String? sharedName;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklyReportViewModelProvider.overrideWith(
            () => _FakeWeeklyVM(
              const WeeklyReport(locked: false, breaks: 10, breaksDelta: -3),
            ),
          ),
          captureImageProvider.overrideWithValue((key) async => bytes),
          shareImageProvider.overrideWithValue((b, {required name}) async {
            shared = b;
            sharedName = name;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: SpineWeekCard())),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump();

    expect(shared, bytes);
    expect(sharedName, 'spine_report.png');
  });

  testWidgets('Free shows the Pro lock instead of the numbers', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weeklyReportViewModelProvider.overrideWith(
            () => _FakeWeeklyVM(const WeeklyReport.locked()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SpineWeekCard())),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Unlock your Spine Report'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Share'), findsNothing);
  });
}
