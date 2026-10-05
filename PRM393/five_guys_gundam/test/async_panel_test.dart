import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:five_guys_gundam/widgets/common.dart';

void main() {
  testWidgets('API failure shows retry action', (tester) async {
    var retried = false;
    final response = Completer<int>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncPanel<int>(
            future: response.future,
            onRetry: () => retried = true,
            builder: (value) => Text('$value'),
          ),
        ),
      ),
    );
    response.completeError(Exception('Mất kết nối'));
    await tester.pump();
    expect(find.textContaining('Mất kết nối'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retried, isTrue);
  });
}
