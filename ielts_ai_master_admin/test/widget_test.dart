import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ielts_ai_master_admin/core/theme/admin_theme.dart';
import 'package:ielts_ai_master_admin/core/widgets/status_badge.dart';

void main() {
  testWidgets('learner status badge renders production account states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.darkTheme,
        home: const Scaffold(body: StatusBadge(status: 'suspended')),
      ),
    );

    expect(find.text('SUSPENDED'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
  });
}
