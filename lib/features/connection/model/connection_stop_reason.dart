/// Why a running connection is expected to stop.  This is UI lifecycle state;
/// it never changes core, sing-box, or outbound configuration.
enum ConnectionStopReason {
  userInitiated,
  networkLost,
  coreFailure,
  permissionDenied,
  serverSwitch,
  subscriptionUpdate,
  serviceRestart,
  unknownFailure,
}

extension ConnectionStopReasonX on ConnectionStopReason {
  bool get isExpected => switch (this) {
    ConnectionStopReason.userInitiated ||
    ConnectionStopReason.serverSwitch ||
    ConnectionStopReason.subscriptionUpdate ||
    ConnectionStopReason.serviceRestart ||
    ConnectionStopReason.permissionDenied => true,
    _ => false,
  };
}
