import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';

/// A failed attempt must always return the UI to a retryable disconnected state.
const connectionAttemptTimeout = Duration(seconds: 30);

ConnectionStatus recoverConnectionFailure(ConnectionFailure failure) => Disconnected(failure);
