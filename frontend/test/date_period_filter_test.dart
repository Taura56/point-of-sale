import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/date_period_filter.dart';

void main() {
  test('day period includes records from only the selected date', () {
    final selection = DatePeriodSelection(
      period: DatePeriod.day,
      anchorDate: DateTime(2026, 11, 17),
    );
    final entries = [
      {'createdAt': '2026-11-16T23:59:59', 'total': 10},
      {'createdAt': '2026-11-17T00:00:00', 'total': 20},
      {'createdAt': '2026-11-17T23:59:59', 'total': 30},
      {'createdAt': '2026-11-18T00:00:00', 'total': 40},
    ];

    expect(selection.filterEntries(entries), [entries[1], entries[2]]);
    expect(selection.totalFor(entries, 'total'), 50);
  });

  test('week period runs from Sunday through Saturday', () {
    final selection = DatePeriodSelection(
      period: DatePeriod.week,
      anchorDate: DateTime(2026, 11, 18),
    );
    final entries = [
      {'createdAt': '2026-11-14T23:59:59'},
      {'createdAt': '2026-11-15T00:00:00'},
      {'createdAt': '2026-11-21T23:59:59'},
      {'createdAt': '2026-11-22T00:00:00'},
    ];

    expect(selection.filterEntries(entries), [entries[1], entries[2]]);
    expect(selection.dateLabel, contains('Sunday'));
    expect(selection.dateLabel, contains('Saturday'));
  });

  test('month period includes records from only the selected month', () {
    final selection = DatePeriodSelection(
      period: DatePeriod.month,
      anchorDate: DateTime(2026, 11, 17),
    );
    final entries = [
      {'createdAt': '2026-10-31T23:59:59'},
      {'createdAt': '2026-11-01T00:00:00'},
      {'createdAt': '2026-11-30T23:59:59'},
      {'createdAt': '2026-12-01T00:00:00'},
    ];

    expect(selection.filterEntries(entries), [entries[1], entries[2]]);
  });

  test('date filters can use a non-default timestamp field', () {
    final selection = DatePeriodSelection(
      period: DatePeriod.day,
      anchorDate: DateTime(2026, 11, 17),
    );
    final entries = [
      {'expenseDate': '2026-11-16T23:59:59', 'amount': 10},
      {'expenseDate': '2026-11-17T00:00:00', 'amount': 20},
      {'expenseDate': '2026-11-18T00:00:00', 'amount': 30},
    ];

    expect(selection.filterEntries(entries, dateField: 'expenseDate'), [
      entries[1],
    ]);
    expect(selection.totalFor(entries, 'amount', dateField: 'expenseDate'), 20);
  });
}
