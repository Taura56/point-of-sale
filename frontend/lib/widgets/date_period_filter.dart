import 'package:flutter/material.dart';

enum DatePeriod { day, week, month }

class DatePeriodSelection {
  const DatePeriodSelection({
    required this.period,
    required this.anchorDate,
  });

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdayNames = [
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  final DatePeriod period;
  final DateTime anchorDate;

  DateTime get date => _dateOnly(anchorDate);

  String get dateLabel {
    final today = _dateOnly(DateTime.now());
    final yesterday = DateTime(today.year, today.month, today.day - 1);

    switch (period) {
      case DatePeriod.day:
        if (date == today) return 'Today - ${_formatDate(date)}';
        if (date == yesterday) return 'Yesterday - ${_formatDate(date)}';
        return _formatDate(date);
      case DatePeriod.week:
        final start = _weekStart(date);
        final end = DateTime(start.year, start.month, start.day + 6);
        return '${_weekdayNames[start.weekday % 7]} ${_formatDate(start)} - '
            '${_weekdayNames[end.weekday % 7]} ${_formatDate(end)}';
      case DatePeriod.month:
        return '${_monthNames[date.month - 1]} ${date.year}';
    }
  }

  String get totalLabel {
    switch (period) {
      case DatePeriod.day:
        final today = _dateOnly(DateTime.now());
        if (date == today) return "Today's total";
        if (date == DateTime(today.year, today.month, today.day - 1)) {
          return "Yesterday's total";
        }
        return 'Day total';
      case DatePeriod.week:
        return 'Week total';
      case DatePeriod.month:
        return 'Month total';
    }
  }

  DatePeriodSelection copyWith({DatePeriod? period, DateTime? anchorDate}) {
    return DatePeriodSelection(
      period: period ?? this.period,
      anchorDate: anchorDate ?? this.anchorDate,
    );
  }

  bool includesDate(DateTime value) {
    final entryDate = _dateOnly(value.toLocal());

    switch (period) {
      case DatePeriod.day:
        return entryDate == date;
      case DatePeriod.week:
        final start = _weekStart(date);
        final end = DateTime(start.year, start.month, start.day + 6);
        return !entryDate.isBefore(start) && !entryDate.isAfter(end);
      case DatePeriod.month:
        return entryDate.year == date.year && entryDate.month == date.month;
    }
  }

  List<dynamic> filterEntries(
    Iterable<dynamic> entries, {
    String dateField = 'createdAt',
  }) {
    return entries.where((entry) {
      final entryDate = _entryDate(entry, dateField);
      return entryDate != null && includesDate(entryDate);
    }).toList();
  }

  double totalFor(
    Iterable<dynamic> entries,
    String amountField, {
    String dateField = 'createdAt',
  }) {
    var total = 0.0;
    for (final entry in entries) {
      if (entry is! Map) continue;

      final entryDate = _entryDate(entry, dateField);
      if (entryDate == null || !includesDate(entryDate)) continue;

      final value = entry[amountField];
      final amount = value is num
          ? value.toDouble()
          : double.tryParse(value?.toString() ?? '');
      if (amount != null && amount.isFinite) total += amount;
    }
    return total;
  }

  static DateTime? _entryDate(dynamic entry, String dateField) {
    if (entry is! Map) return null;
    final value = entry[dateField];
    if (value is DateTime) return value.toLocal();
    return DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime _weekStart(DateTime value) {
    final day = _dateOnly(value);
    return DateTime(day.year, day.month, day.day - (day.weekday % 7));
  }

  static String _formatDate(DateTime value) {
    return '${_monthNames[value.month - 1]} ${value.day}, ${value.year}';
  }
}

class DatePeriodFilterBar extends StatelessWidget {
  const DatePeriodFilterBar({
    required this.selection,
    required this.onChanged,
    super.key,
  });

  final DatePeriodSelection selection;
  final ValueChanged<DatePeriodSelection> onChanged;

  Future<void> _pickDate(BuildContext context) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: selection.date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selectedDate == null || !context.mounted) return;
    onChanged(selection.copyWith(anchorDate: selectedDate));
  }

  void _movePeriod(int amount) {
    final date = selection.date;
    final nextDate = switch (selection.period) {
      DatePeriod.day => DateTime(date.year, date.month, date.day + amount),
      DatePeriod.week => DateTime(
        date.year,
        date.month,
        date.day + amount * 7,
      ),
      DatePeriod.month => DateTime(date.year, date.month + amount, 1),
    };
    onChanged(selection.copyWith(anchorDate: nextDate));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<DatePeriod>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: DatePeriod.day, label: Text('Day')),
            ButtonSegment(value: DatePeriod.week, label: Text('Week')),
            ButtonSegment(value: DatePeriod.month, label: Text('Month')),
          ],
          selected: {selection.period},
          onSelectionChanged: (selected) {
            onChanged(selection.copyWith(period: selected.first));
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              tooltip: 'Previous ${selection.period.name}',
              onPressed: () => _movePeriod(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickDate(context),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  selection.dateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next ${selection.period.name}',
              onPressed: () => _movePeriod(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
