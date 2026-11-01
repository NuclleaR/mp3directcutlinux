import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mp3_direct_cut/core/update.dart';

void main() {
  group('compareVersions', () {
    test('orders by major, minor, patch', () {
      expect(compareVersions('0.0.2', '0.0.10'), lessThan(0));
      expect(compareVersions('0.1.0', '0.0.9'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('a pre-release comes before its release', () {
      expect(compareVersions('0.0.2-beta', '0.0.2'), lessThan(0));
      expect(compareVersions('0.0.3-beta', '0.0.2'), greaterThan(0));
      expect(compareVersions('0.0.2-beta.2', '0.0.2-beta.10'), lessThan(0));
    });
  });

  group('parseNewestRelease', () {
    String json({String tag = 'v0.0.3', List<String> assets = const ['mp3-direct-cut-linux-x64.tar.gz']}) => jsonEncode([
          {
            'tag_name': tag,
            'html_url': 'https://github.com/o/r/releases/tag/$tag',
            'assets': [
              for (final a in assets) {'name': a, 'browser_download_url': 'https://github.com/o/r/releases/download/$tag/$a'},
            ],
          },
        ]);

    test('takes the version, archive and page of the first release', () {
      final r = parseNewestRelease(json())!;
      expect(r.version, '0.0.3');
      expect(r.archiveUrl, Uri.parse('https://github.com/o/r/releases/download/v0.0.3/mp3-direct-cut-linux-x64.tar.gz'));
      expect(r.pageUrl, Uri.parse('https://github.com/o/r/releases/tag/v0.0.3'));
    });

    test('no release, or one without the Linux archive, gives null', () {
      expect(parseNewestRelease('[]'), isNull);
      expect(parseNewestRelease(json(assets: ['other.zip'])), isNull);
    });
  });

  group('installArchive', () {
    late Directory root, app;

    setUp(() {
      root = Directory.systemTemp.createTempSync('update');
      app = Directory('${root.path}/share/mp3-direct-cut')..createSync(recursive: true);
      File('${app.path}/mp3_direct_cut').writeAsStringSync('old');
      File('${app.path}/stale.txt').writeAsStringSync('old only');
    });
    tearDown(() => root.deleteSync(recursive: true));

    File archive(Map<String, String> files) {
      final src = Directory('${root.path}/src')..createSync();
      files.forEach((name, text) => File('${src.path}/$name')
        ..createSync(recursive: true)
        ..writeAsStringSync(text));
      final out = File('${root.path}/release.tar.gz');
      final r = Process.runSync('tar', ['-czf', out.path, '-C', src.path, '.']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      return out;
    }

    test('replaces the app directory with the archive contents', () async {
      final a = archive({'mp3-direct-cut/mp3_direct_cut': 'new', 'mp3-direct-cut/data/app_icon.png': 'icon'});
      await installArchive(a, app);
      expect(File('${app.path}/mp3_direct_cut').readAsStringSync(), 'new');
      expect(File('${app.path}/data/app_icon.png').existsSync(), isTrue);
      expect(File('${app.path}/stale.txt').existsSync(), isFalse);
      expect(root.listSync().map((e) => e.uri.pathSegments.where((s) => s.isNotEmpty).last).toSet(),
          {'share', 'src', 'release.tar.gz'});
      expect(Directory('${root.path}/share').listSync().map((e) => e.path), [app.path]);
    });

    test('an archive without the app leaves the installed app untouched', () async {
      final a = archive({'something/else': 'x'});
      await expectLater(installArchive(a, app), throwsA(isA<UpdateException>()));
      expect(File('${app.path}/mp3_direct_cut').readAsStringSync(), 'old');
      expect(Directory('${root.path}/share').listSync().map((e) => e.path), [app.path]);
    });

    test('a broken archive leaves the installed app untouched', () async {
      final a = File('${root.path}/broken.tar.gz')..writeAsStringSync('not a tarball');
      await expectLater(installArchive(a, app), throwsA(isA<UpdateException>()));
      expect(File('${app.path}/mp3_direct_cut').readAsStringSync(), 'old');
    });
  });
}
