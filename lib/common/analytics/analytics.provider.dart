import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'analytics.service.dart';

part 'analytics.provider.g.dart';

/// Analytics is set up in `main.dart`, which overrides this provider. The
/// no-op default keeps tests and any un-overridden context silent.
@Riverpod(keepAlive: true)
AnalyticsService analyticsService(Ref ref) => const NoopAnalyticsService();
