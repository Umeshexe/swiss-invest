class SyncResult {
  const SyncResult({
    required this.success,
    required this.syncedAt,
    required this.message,
    required this.recordCount,
  });

  final bool success;
  final DateTime syncedAt;
  final String message;
  final int recordCount;
}
