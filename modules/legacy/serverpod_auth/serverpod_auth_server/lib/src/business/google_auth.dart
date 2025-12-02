import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

// ignore: implementation_imports
import 'package:googleapis_auth/src/auth_http_utils.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_server/serverpod_auth_server.dart';

const _configFilePath = 'config/google_client_secret.json';
const _passwordKey = 'serverpod_auth_googleClientSecret';

/// Convenience methods for handling authentication with Google and accessing
/// Google's APIs.
class GoogleAuth {
  /// The client secret loaded from `config/google_client_secret.json` or
  /// password `serverpod_auth_googleClientSecret`, null if the client secrets
  /// failed to load.
  static final clientSecret = _loadClientSecret();

  static GoogleClientSecret? _loadClientSecret() {
    try {
      late final String jsonData;
      final password = Serverpod.instance.getPassword(_passwordKey);
      if (password != null) {
        jsonData = password;
      } else {
        var file = File(_configFilePath);
        jsonData = file.readAsStringSync();
      }

      var data = jsonDecode(jsonData);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Not a JSON (map) object');
      }

      if (data['web'] == null) {
        throw const FormatException('Missing "web" section');
      }

      Map web = data['web'];

      var webClientId = web['client_id'];
      if (webClientId == null) {
        throw const FormatException('Missing "client_id"');
      }

      var webClientSecret = web['client_secret'];
      if (webClientSecret == null) {
        throw const FormatException('Missing "client_secret"');
      }

      var webRedirectUris = web['redirect_uris'];
      if (webRedirectUris == null) {
        throw const FormatException('Missing "redirect_uris"');
      }

      // Parse additional_client_ids (optional)
      List<String> additionalClientIds = [];
      var webAdditionalClientIds = web['additional_client_ids'];
      if (webAdditionalClientIds != null) {
        if (webAdditionalClientIds is! List) {
          throw const FormatException(
            '"additional_client_ids" must be a list of strings',
          );
        }
        additionalClientIds = (webAdditionalClientIds as List)
            .cast<String>()
            .where((id) => id.isNotEmpty)
            .toList();
      }

      // Log configuration loading results
      if (additionalClientIds.isEmpty && webAdditionalClientIds == null) {
        stderr.writeln(
          'serverpod_auth_server: No additional_client_ids configured. '
          'Only primary client ID will be accepted.',
        );
      } else if (additionalClientIds.isEmpty &&
          webAdditionalClientIds != null) {
        stderr.writeln(
          'serverpod_auth_server: additional_client_ids configured but all entries are empty. '
          'No additional client IDs will be used.',
        );
      } else {
        stderr.writeln(
          'serverpod_auth_server: Google auth config loaded successfully. '
          'Primary client ID: $webClientId, '
          'Additional client IDs (${additionalClientIds.length}): ${additionalClientIds.join(", ")}',
        );
      }

      return GoogleClientSecret._(
        clientId: webClientId,
        clientSecret: webClientSecret,
        redirectUris: (webRedirectUris as List).cast<String>(),
        additionalClientIds: additionalClientIds,
      );
    } catch (e) {
      stderr.writeln(
        'serverpod_auth_server: Failed to load $_configFilePath or password $_passwordKey. Sign in with Google will be disabled. Error: $e',
      );
      return null;
    }
  }

  /// Returns an authenticated client for a specific, authenticated user. The
  /// client can be used to access Google's APIs. To be able to get a client
  /// the user must have been authenticated with Google, otherwise null is
  /// returned.
  static Future<AutoRefreshingAuthClient?> authClientForUser(
    Session session,
    int userId,
  ) async {
    if (clientSecret == null) {
      throw StateError(
        'Google client secret from $_configFilePath or password $_passwordKey is not loaded',
      );
    }

    var refreshTokenData = await GoogleRefreshToken.db.findFirstRow(
      session,
      where: (t) => t.userId.equals(userId),
    );
    if (refreshTokenData == null) {
      return null;
    }

    var credentials = AccessCredentials.fromJson(
      jsonDecode(refreshTokenData.refreshToken),
    );

    var client = http.Client();

    var clientId = ClientId(clientSecret!.clientId, clientSecret!.clientSecret);

    return AutoRefreshingClient(
      client,
      const GoogleAuthEndpoints(),
      clientId,
      credentials,
      closeUnderlyingClient: true,
    );
  }
}

/// Contains information about the credentials for the server to access Google's
/// APIs. The secrets are typically loaded from
/// `config/google_client_secret.json`. The file can be downloaded from Google's
/// cloud console.
class GoogleClientSecret {
  /// The client identifier.
  late final String clientId;

  /// The client secret.
  late final String clientSecret;

  /// List of redirect uris.
  late List<String> redirectUris;

  /// Additional client IDs that are allowed to authenticate.
  /// This typically includes iOS, macOS, and Android client IDs.
  late final List<String> additionalClientIds;

  /// Private constructor to initialize the object.
  GoogleClientSecret._({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUris,
    this.additionalClientIds = const [],
  });

  /// Test constructor for creating instances in tests.
  /// This should only be used in test code.
  @visibleForTesting
  factory GoogleClientSecret.forTest({
    required String clientId,
    required String clientSecret,
    required List<String> redirectUris,
    List<String> additionalClientIds = const [],
  }) {
    return GoogleClientSecret._(
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUris: redirectUris,
      additionalClientIds: additionalClientIds,
    );
  }

  /// Returns true if the given clientId is valid (matches primary or additional IDs).
  bool isValidClientId(String clientIdToCheck) {
    if (clientIdToCheck == clientId) return true;
    return additionalClientIds.contains(clientIdToCheck);
  }

  /// Returns all valid client IDs (primary + additional).
  List<String> get allClientIds => [clientId, ...additionalClientIds];
}
