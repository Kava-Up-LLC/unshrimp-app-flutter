import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Monday-first weekday labels for the work-days picker.
const _dayLabels = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// Draft selection while the sheet is open. Seeded per showing with an override
/// (see [showWorkDaysSheet]), so the sheet keeps its state without `setState`.
class _DraftWorkDays extends Notifier<List<bool>> {
  @override
  List<bool> build() => List.filled(7, true);

  void setDay(int index, bool worked) {
    final next = List.of(state);
    next[index] = worked;
    state = next;
  }
}

/// A [_DraftWorkDays] that starts from a given selection, used by the override.
class _SeededDraftWorkDays extends _DraftWorkDays {
  _SeededDraftWorkDays(this._initial);

  final List<bool> _initial;

  @override
  List<bool> build() => List.of(_initial);
}

final _draftWorkDaysProvider =
    NotifierProvider.autoDispose<_DraftWorkDays, List<bool>>(
      _DraftWorkDays.new,
    );

/// Bottom sheet to pick the days the user works (Mon first). Returns the chosen
/// list, or null when dismissed. At least one day must stay selected.
Future<List<bool>?> showWorkDaysSheet(
  BuildContext context,
  List<bool> current,
) {
  return showModalBottomSheet<List<bool>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ProviderScope(
      overrides: [
        _draftWorkDaysProvider.overrideWith(() => _SeededDraftWorkDays(current)),
      ],
      child: const _WorkDaysSheet(),
    ),
  );
}

class _WorkDaysSheet extends ConsumerWidget {
  const _WorkDaysSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final draft = ref.watch(_draftWorkDaysProvider);
    final anySelected = draft.any((worked) => worked);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                'Work days',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Reminders and your streak skip the days you do not work.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var i = 0; i < 7; i++)
                    SwitchListTile(
                      title: Text(_dayLabels[i]),
                      value: draft[i],
                      onChanged: (worked) => ref
                          .read(_draftWorkDaysProvider.notifier)
                          .setDay(i, worked),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: anySelected ? () => context.pop(draft) : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
