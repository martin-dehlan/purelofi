import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purelofi/features/pro/data/pro.repository.impl.dart';
import 'package:purelofi/features/pro/domain/pro_plan.entity.dart';

void main() {
  group('periodFrom', () {
    test('reads the plan from the store product id', () {
      expect(
        RevenueCatProRepository.periodFrom('pro_yearly'),
        PlanPeriod.yearly,
      );
      expect(
        RevenueCatProRepository.periodFrom('pro:annual'),
        PlanPeriod.yearly,
      );
      expect(
        RevenueCatProRepository.periodFrom('PRO_MONTHLY'),
        PlanPeriod.monthly,
      );
      expect(RevenueCatProRepository.periodFrom('lifetime'), isNull);
    });
  });

  group('daysIn', () {
    test('a free week is seven days, however the store says it', () {
      expect(RevenueCatProRepository.daysIn(PeriodUnit.day, 7), 7);
      expect(RevenueCatProRepository.daysIn(PeriodUnit.week, 1), 7);
      expect(RevenueCatProRepository.daysIn(PeriodUnit.month, 1), 30);
    });
  });
}
