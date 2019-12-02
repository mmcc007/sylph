// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:mockito/mockito.dart';
import 'package:sylph/src/base/version.dart';
import 'package:test/test.dart';
import 'package:tool_base/tool_base.dart';
import 'package:tool_base_test/tool_base_test.dart';

final SystemClock _testClock = SystemClock.fixed(DateTime(2015, 1, 1));
final DateTime _stampUpToDate = _testClock.ago(FlutterVersion.checkAgeConsideredUpToDate ~/ 2);
final DateTime _stampOutOfDate = _testClock.ago(FlutterVersion.checkAgeConsideredUpToDate * 2);

void main() {
  MockCache mockCache;
  MockToolVersion mockToolVersion;

  setUp(() {
    mockCache = MockCache();
    mockToolVersion = MockToolVersion();
  });

  final String channel = 'stable';
    DateTime getChannelUpToDateVersion() {
      return _testClock.ago(FlutterVersion.versionAgeConsideredUpToDate(channel) ~/ 2);
    }

    DateTime getChannelOutOfDateVersion() {
      return _testClock.ago(FlutterVersion.versionAgeConsideredUpToDate(channel) * 2);
    }

    group('$FlutterVersion for $channel', () {
      setUpAll(() {
        Cache.disableLocking();
        FlutterVersion.timeToPauseToLetUserReadTheMessage = Duration.zero;
      });

      testUsingContext('prints nothing when Flutter installation looks fresh', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelUpToDateVersion(),
          // Server will be pinged because we haven't pinged within last x days
          expectServerPing: true,
          remoteCommitDate: getChannelOutOfDateVersion(),
          expectSetStamp: true,
          channel: channel,
        );
        await FlutterVersion.instance.checkFlutterVersionFreshness();
        _expectVersionMessage('');
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('prints nothing when Flutter installation looks out-of-date but is actually up-to-date', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelOutOfDateVersion(),
          stamp: VersionCheckStamp(
            lastTimeVersionWasChecked: _stampOutOfDate,
            lastKnownRemoteVersion: getChannelOutOfDateVersion(),
          ),
          remoteCommitDate: getChannelOutOfDateVersion(),
          expectSetStamp: true,
          expectServerPing: true,
          channel: channel,
        );
        final FlutterVersion version = FlutterVersion.instance;

        await version.checkFlutterVersionFreshness();
        _expectVersionMessage('');
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('does not ping server when version stamp is up-to-date', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelOutOfDateVersion(),
          stamp: VersionCheckStamp(
            lastTimeVersionWasChecked: _stampUpToDate,
            lastKnownRemoteVersion: getChannelUpToDateVersion(),
          ),
          expectSetStamp: true,
          channel: channel,
        );

        final FlutterVersion version = FlutterVersion.instance;
        await version.checkFlutterVersionFreshness();
        _expectVersionMessage(FlutterVersion.newVersionAvailableMessage());
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('does not print warning if printed recently', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelOutOfDateVersion(),
          stamp: VersionCheckStamp(
            lastTimeVersionWasChecked: _stampUpToDate,
            lastKnownRemoteVersion: getChannelUpToDateVersion(),
          ),
          expectSetStamp: true,
          channel: channel,
        );

        final FlutterVersion version = FlutterVersion.instance;
        await version.checkFlutterVersionFreshness();
        _expectVersionMessage(FlutterVersion.newVersionAvailableMessage());
        expect((await VersionCheckStamp.load()).lastTimeWarningWasPrinted, _testClock.now());

        await version.checkFlutterVersionFreshness();
        _expectVersionMessage('');
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('pings server when version stamp is missing then does not', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelOutOfDateVersion(),
          remoteCommitDate: getChannelUpToDateVersion(),
          expectSetStamp: true,
          expectServerPing: true,
          channel: channel,
        );
        final FlutterVersion version = FlutterVersion.instance;

        await version.checkFlutterVersionFreshness();
        _expectVersionMessage(FlutterVersion.newVersionAvailableMessage());

        // Immediate subsequent check is not expected to ping the server.
        fakeData(
          mockCache,
          localCommitDate: getChannelOutOfDateVersion(),
          stamp: await VersionCheckStamp.load(),
          channel: channel,
        );
        await version.checkFlutterVersionFreshness();
        _expectVersionMessage('');
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      }, skip: true); // todo: mock at http with in-memory stamp

      testUsingContext('pings server when version stamp is out-of-date', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelOutOfDateVersion(),
          stamp: VersionCheckStamp(
            lastTimeVersionWasChecked: _stampOutOfDate,
            lastKnownRemoteVersion: _testClock.ago(const Duration(days: 2)),
          ),
          remoteCommitDate: getChannelUpToDateVersion(),
          expectSetStamp: true,
          expectServerPing: true,
          channel: channel,
        );
        final FlutterVersion version = FlutterVersion.instance;

        await version.checkFlutterVersionFreshness();
        _expectVersionMessage(FlutterVersion.newVersionAvailableMessage());
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      }, skip: true); // todo: mock at http with in-memory stamp

      testUsingContext('does not print warning when unable to connect to server if not out of date', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelUpToDateVersion(),
          errorOnFetch: true,
          expectServerPing: true,
          expectSetStamp: true,
          channel: channel,
        );
        final FlutterVersion version = FlutterVersion.instance;

        await version.checkFlutterVersionFreshness();
        _expectVersionMessage('');
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('prints warning when unable to connect to server if really out of date', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelOutOfDateVersion(),
          errorOnFetch: true,
          expectServerPing: true,
          expectSetStamp: true,
          channel: channel,
        );
        final FlutterVersion version = FlutterVersion.instance;

        await version.checkFlutterVersionFreshness();
        _expectVersionMessage(FlutterVersion.versionOutOfDateMessage(_testClock.now().difference(getChannelOutOfDateVersion())));
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('versions comparison', () async {
        fakeData(
          mockCache,
          localCommitDate: getChannelOutOfDateVersion(),
          errorOnFetch: true,
          expectServerPing: true,
          expectSetStamp: true,
          channel: channel,
        );
//        final FlutterVersion version = FlutterVersion.instance;
//
//        when(mockProcessManager.runSync(
//          <String>['git', 'merge-base', '--is-ancestor', 'abcdef', '123456'],
//          workingDirectory: anyNamed('workingDirectory'),
//        )).thenReturn(ProcessResult(1, 0, '', ''));

//        expect(
//            version.checkRevisionAncestry(
//              tentativeDescendantRevision: '123456',
//              tentativeAncestorRevision: 'abcdef',
//            ),
//            true);
//
//        verify(mockProcessManager.runSync(
//          <String>['git', 'merge-base', '--is-ancestor', 'abcdef', '123456'],
//          workingDirectory: anyNamed('workingDirectory'),
//        ));
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        ToolVersion: () => mockToolVersion,
      }, skip: true);
    });

    group('$VersionCheckStamp for $channel', () {
      void _expectDefault(VersionCheckStamp stamp) {
        expect(stamp.lastKnownRemoteVersion, isNull);
        expect(stamp.lastTimeVersionWasChecked, isNull);
        expect(stamp.lastTimeWarningWasPrinted, isNull);
      }

      testUsingContext('loads blank when stamp file missing', () async {
        fakeData(
            mockCache, channel: channel);

        _expectDefault(await VersionCheckStamp.load());
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('loads blank when stamp file is malformed JSON', () async {
        fakeData(
            mockCache, stampJson: '<', channel: channel);
        _expectDefault(await VersionCheckStamp.load());
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('loads blank when stamp file is well-formed but invalid JSON', () async {
        fakeData(
          mockCache,
          stampJson: '[]',
          channel: channel,
        );
        _expectDefault(await VersionCheckStamp.load());
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('loads valid JSON', () async {
        fakeData(
          mockCache,
          stampJson: '''
      {
        "lastKnownRemoteVersion": "${_testClock.ago(const Duration(days: 1))}",
        "lastTimeVersionWasChecked": "${_testClock.ago(const Duration(days: 2))}",
        "lastTimeWarningWasPrinted": "${_testClock.now()}"
      }
      ''',
          channel: channel,
        );

        final VersionCheckStamp stamp = await VersionCheckStamp.load();
        expect(stamp.lastKnownRemoteVersion, _testClock.ago(const Duration(days: 1)));
        expect(stamp.lastTimeVersionWasChecked, _testClock.ago(const Duration(days: 2)));
        expect(stamp.lastTimeWarningWasPrinted, _testClock.now());
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('stores version stamp', () async {
        fakeData(
          mockCache,
          expectSetStamp: true,
          channel: channel,
        );

        _expectDefault(await VersionCheckStamp.load());

        final VersionCheckStamp stamp = VersionCheckStamp(
          lastKnownRemoteVersion: _testClock.ago(const Duration(days: 1)),
          lastTimeVersionWasChecked: _testClock.ago(const Duration(days: 2)),
          lastTimeWarningWasPrinted: _testClock.now(),
        );
        await stamp.store();

        final VersionCheckStamp storedStamp = await VersionCheckStamp.load();
        expect(storedStamp.lastKnownRemoteVersion, _testClock.ago(const Duration(days: 1)));
        expect(storedStamp.lastTimeVersionWasChecked, _testClock.ago(const Duration(days: 2)));
        expect(storedStamp.lastTimeWarningWasPrinted, _testClock.now());
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });

      testUsingContext('overwrites individual fields', () async {
        fakeData(
          mockCache,
          expectSetStamp: true,
          channel: channel,
        );

        _expectDefault(await VersionCheckStamp.load());

        final VersionCheckStamp stamp = VersionCheckStamp(
          lastKnownRemoteVersion: _testClock.ago(const Duration(days: 10)),
          lastTimeVersionWasChecked: _testClock.ago(const Duration(days: 9)),
          lastTimeWarningWasPrinted: _testClock.ago(const Duration(days: 8)),
        );
        await stamp.store(
          newKnownRemoteVersion: _testClock.ago(const Duration(days: 1)),
          newTimeVersionWasChecked: _testClock.ago(const Duration(days: 2)),
          newTimeWarningWasPrinted: _testClock.now(),
        );

        final VersionCheckStamp storedStamp = await VersionCheckStamp.load();
        expect(storedStamp.lastKnownRemoteVersion, _testClock.ago(const Duration(days: 1)));
        expect(storedStamp.lastTimeVersionWasChecked, _testClock.ago(const Duration(days: 2)));
        expect(storedStamp.lastTimeWarningWasPrinted, _testClock.now());
      }, overrides: <Type, Generator>{
        FlutterVersion: () => FlutterVersion(_testClock),
        Cache: () => mockCache,
        ToolVersion: () => mockToolVersion,
      });
    });
}

void _expectVersionMessage(String message) {
  final BufferLogger logger = context.get<Logger>();
  expect(logger.statusText.trim(), message.trim());
  logger.clear();
}

void fakeData(
    Cache cache, {
      DateTime localCommitDate,
      DateTime remoteCommitDate,
      VersionCheckStamp stamp,
      String stampJson,
      bool errorOnFetch = false,
      bool expectSetStamp = false,
      bool expectServerPing = false,
      String channel = 'master',
    }) {
  print('localCommitDate=$localCommitDate');
  print('remoteCommitDate=$remoteCommitDate');
  print('stamp=$stamp');
  print('stampJson=$stampJson');
  print('errorOnFetch=$errorOnFetch');
  print('expectSetStamp=$expectSetStamp');
  print('expectServerPing=$expectServerPing');
  print('channel=$channel');

  when(cache.getStampFor(any)).thenAnswer((Invocation invocation) {
    expect(invocation.positionalArguments.single, VersionCheckStamp.flutterVersionCheckStampFile);

    if (stampJson != null) {
      return stampJson;
    }

    if (stamp != null) {
      return json.encode(stamp.toJson());
    }

    return null;
  });

  when(cache.setStampFor(any, any)).thenAnswer((Invocation invocation) {
    expect(invocation.positionalArguments.first, VersionCheckStamp.flutterVersionCheckStampFile);

    if (expectSetStamp) {
      stamp = VersionCheckStamp.fromJson(json.decode(invocation.positionalArguments[1]));
      return null;
    }

    throw StateError('Unexpected call to Cache.setStampFor(${invocation.positionalArguments}, ${invocation.namedArguments})');
  });

  when(ToolVersion.instance.getVersionDate()).thenAnswer((_){
    print('called ToolVersion.instance.getVersionDate()');
    return Future.value(
          '${localCommitDate == null ? remoteCommitDate : localCommitDate}');
  });

    when(ToolVersion.instance.getVersionDate(forceRemote: anyNamed('forceRemote')))
        .thenAnswer((_) {
      if (errorOnFetch) {
        throw HttpException('network down');
      }
      return Future.value(
          '${localCommitDate == null ? remoteCommitDate : localCommitDate}');
    });

    when(ToolVersion.instance.getVersionDate())
        .thenAnswer((_){
      return Future.value(
          '${localCommitDate == null ? remoteCommitDate : localCommitDate}');
    });
}

class MockCache extends Mock implements Cache {}

class MockToolVersion extends Mock implements ToolVersion {}