import 'package:flutter/material.dart';
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

  testWidgets('transaction history renders a relative saved operation date',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionTile(
            item: MoneyTransaction(
              'Покупки',
              'Карта · Сегодня',
              -25,
              Icons.shopping_bag_rounded,
              const Color(0xFFB9A5FF),
              account: 'Карта',
              date: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Карта · Позавчера'), findsOneWidget);
    expect(find.text('Карта · Сегодня'), findsNothing);
  });

  testWidgets('transaction history uses a regular date after two days',
      (tester) async {
    final date = DateTime.now().subtract(const Duration(days: 3));
    const months = [
      'янв.', 'фев.', 'мар.', 'апр.', 'мая', 'июн.',
      'июл.', 'авг.', 'сен.', 'окт.', 'ноя.', 'дек.',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionTile(
            item: MoneyTransaction(
              'Покупки',
              'Карта · Сегодня',
              -25,
              Icons.shopping_bag_rounded,
              const Color(0xFFB9A5FF),
              account: 'Карта',
              date: date,
            ),
          ),
        ),
      ),
    );

    final year = date.year == DateTime.now().year ? '' : ' ${date.year}';
    expect(
      find.text('Карта · ${date.day} ${months[date.month - 1]}$year'),
      findsOneWidget,
    );
  });

  testWidgets('transfer renders route and date on separate lines',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TransactionTile(
            item: MoneyTransaction(
              'Перевод',
              'Карта → Накопления',
              100,
              Icons.swap_horiz_rounded,
              const Color(0xFFFFCF66),
              kind: TransactionKind.transfer,
              fromAccount: 'Карта',
              account: 'Накопления',
              date: DateTime.now(),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Карта → Накопления'), findsOneWidget);
    expect(find.text('Сегодня'), findsOneWidget);
    expect(find.textContaining('Накопления · Сегодня'), findsNothing);
  });
}
