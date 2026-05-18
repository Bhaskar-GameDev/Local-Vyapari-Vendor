import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

/// Single source of truth for the Dio ApiClient.
/// Imported by any provider that needs network access.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
