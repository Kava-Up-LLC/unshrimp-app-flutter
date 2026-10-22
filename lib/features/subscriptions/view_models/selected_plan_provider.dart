import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan_type.dart';

final selectedPlanProvider =
    NotifierProvider.autoDispose<SelectedPlan, PlanType>(SelectedPlan.new);

/// Which plan card is selected on the Pro screen. Yearly is the default (the
/// best-value plan).
class SelectedPlan extends Notifier<PlanType> {
  @override
  PlanType build() => PlanType.yearly;

  void select(PlanType plan) => state = plan;
}
