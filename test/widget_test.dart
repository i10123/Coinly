import 'package:flutter_test/flutter_test.dart';

import 'package:coinly/main.dart';

void main() {
  test('Coinly app widget is available', () {
    expect(CoinlyApp, isNotNull);
  });

  test('demo dataset contains six months of usable analytics data', () {
    final data = AppData.demo();

    expect(data.transactions, hasLength(204));
    expect(data.accounts, hasLength(3));
    expect(
      data.transactions.where((item) => item.kind == TransactionKind.income),
      hasLength(6),
    );
    expect(
      data.transactions.where((item) => item.kind == TransactionKind.expense),
      isNotEmpty,
    );
    expect(
      data.transactions.where((item) => item.kind == TransactionKind.transfer),
      hasLength(12),
    );
  });
}
