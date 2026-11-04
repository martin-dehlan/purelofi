const List<String> _months = <String>[
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

/// "Member since November 2026": the month and year an account was made.
///
/// Month and year only. The day is a detail nobody looks for, and a date in
/// full reads like a receipt.
String memberSinceLabel(DateTime createdAt) {
  final DateTime local = createdAt.toLocal();
  return 'Member since ${_months[local.month - 1]} ${local.year}';
}

/// "Since November 2026", for a line that already says whose account it is.
String sinceLabel(DateTime createdAt) =>
    memberSinceLabel(createdAt).replaceFirst('Member since', 'Since');
