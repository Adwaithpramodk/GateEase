const mentorApprovalExpiredMessage =
    'Mentor did not approve before the requested exit time.';

DateTime? passApprovalDeadline(dynamic pass) {
  final raw = pass['approval_deadline'];
  return raw is String ? DateTime.tryParse(raw) : null;
}

bool mentorApprovalExpired(dynamic pass) {
  if (pass['mentor_status'] == 'expired') return true;
  if (pass['mentor_status'] != 'pending') return false;
  final deadline = passApprovalDeadline(pass);
  return deadline != null && !DateTime.now().isBefore(deadline);
}

Duration? nextPassApprovalRefresh(Iterable<dynamic> passes) {
  final now = DateTime.now();
  Duration? delay;
  for (final pass in passes) {
    if (pass['mentor_status'] != 'pending') continue;
    final deadline = passApprovalDeadline(pass);
    if (deadline == null || !now.isBefore(deadline)) continue;
    final remaining = deadline.difference(now) + const Duration(seconds: 1);
    if (delay == null || remaining < delay) delay = remaining;
  }
  return delay;
}
