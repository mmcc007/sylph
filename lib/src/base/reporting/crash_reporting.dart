// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of reporting;

///// Tells crash backend that the error is from the Sylph CLI.
//const String _kProductId = 'Sylph';

/// Tells crash backend that this is a Dart error as opposed to, say, Java.
const String _kDartTypeId = 'DartError';

///// Crash backend host.
//const String _kCrashServerHost = 'clients2.google.com';
//const String _kCrashServerHost = 'clients2.mauricemccabe.com';
//
///// Path to the crash servlet.
//const String _kCrashEndpointPath = '/cr/report';

/// The field corresponding to the multipart/form-data file attachment where
/// crash backend expects to find the Dart stack trace.
const String _kStackTraceFileField = 'DartError';

/// The name of the file attached as [_kStackTraceFileField].
///
/// The precise value is not important. It is ignored by the crash back end, but
/// it must be supplied in the request.
const String _kStackTraceFilename = 'stacktrace_file';

/// Sends crash reports to a REST API.
///
/// There are two ways to override the behavior of this class:
///
/// * Define a `SYLPH_CRASH_SERVER_BASE_URL` environment variable that points
///   to a custom crash reporting server. This is useful if your development
///   environment is behind a firewall and unable to send crash reports to
///   remote REST API, or when you wish to use your own server for collecting crash
///   reports from an app.
/// * In tests call [initializeWith] and provide a mock implementation of
///   [http.Client].
class CrashReportSender {
  CrashReportSender._(
    this._client,
    this._crashServerHost,
    this._crashEndpointPath,
    this._productId,
  );

  static CrashReportSender _instance;

  static CrashReportSender get instance =>
      _instance ?? CrashReportSender._(http.Client(), '', '', '');

  /// Overrides the default [http.Client] with [client] for testing purposes.
  @visibleForTesting
  static void initializeWith(
    http.Client client,
    String crashServerHost,
    String crashEndpointPath,
    String productId,
  ) {
    _instance = CrashReportSender._(
        client, crashServerHost, crashEndpointPath, productId);
  }

  final http.Client _client;
  final Usage _usage = Usage.instance;
  final String _crashServerHost;
  final String _crashEndpointPath;
  final String _productId;

  Uri get _baseUrl {
    final String overrideUrl =
        platform.environment['SYLPH_CRASH_SERVER_BASE_URL'];

    if (overrideUrl != null) {
      return Uri.parse(overrideUrl);
    }
    return Uri(
//      scheme: 'https',
      scheme: 'http',
      host: _crashServerHost,
//      port: 443,
      port: 8080,
      path: _crashEndpointPath,
    );
  }

  /// Sends one crash report.
  ///
  /// The report is populated from data in [error] and [stackTrace].
  Future<void> sendReport({
    @required dynamic error,
    @required StackTrace stackTrace,
    @required String getFlutterVersion(),
    @required String command,
  }) async {
    try {
      final String flutterVersion = getFlutterVersion();

      // We don't need to report exceptions happening on user branches
      if (_usage.suppressAnalytics ||
          RegExp(r'^\[user-branch\]\/').hasMatch(flutterVersion)) {
        return;
      }

      printStatus('Sending crash report to Sylph.');

      final Uri uri = _baseUrl.replace(
        queryParameters: <String, String>{
          'product': _productId,
          'version': flutterVersion,
        },
      );

      final http.MultipartRequest req = http.MultipartRequest('POST', uri);
      req.fields['uuid'] = _usage.clientId;
      req.fields['product'] = _productId;
      req.fields['version'] = flutterVersion;
      req.fields['osName'] = platform.operatingSystem;
      req.fields['osVersion'] = os.name; // this actually includes version
      req.fields['type'] = _kDartTypeId;
      req.fields['error_runtime_type'] = '${error.runtimeType}';
      req.fields['error_message'] = '$error';
      req.fields['comments'] = command;

      req.files.add(http.MultipartFile.fromString(
        _kStackTraceFileField,
        stackTrace.toString(),
        filename: _kStackTraceFilename,
      ));

      final http.StreamedResponse resp = await _client.send(req);

      if (resp.statusCode == 200) {
        final String reportId =
            await http.ByteStream(resp.stream).bytesToString();
        printStatus('Crash report sent (report ID: $reportId)');
      } else {
        printError(
            'Failed to send crash report. Server responded with HTTP status code ${resp.statusCode}');
      }
    } catch (sendError, sendStackTrace) {
      if (sendError is SocketException) {
        printError(
            'Failed to send crash report due to a network error: $sendError');
      } else {
        // If the sender itself crashes, just print. We did our best.
        printError(
            'Crash report sender itself crashed: $sendError\n$sendStackTrace');
      }
    }
  }
}
