import '../updates/release_version.dart';

/// The source commit and release version the running binary was built from.
///
/// Automated builds stamp both through `--dart-define` (see
/// `.github/workflows/build.yml`): `LAZER_COMMIT=<sha>` and
/// `LAZER_VERSION=<tag>`. Branch builds pass a branch name, which is not a
/// version; those fall back to the latest stable release below so the About
/// row agrees with the app metadata and the update checker can still tell
/// whether a newer release exists.
abstract final class BuildInfo {
  static const String _stamped = String.fromEnvironment('LAZER_COMMIT');
  static const String _fallback = 'a8518ab';
  static const String _stampedVersion = String.fromEnvironment('LAZER_VERSION');

  /// Keep in sync with the last stable tag and the `version:` in pubspec.yaml.
  /// The fork uses the 0.1.x line; the old 2.0.0-beta fallback made branch
  /// builds look newer than every 0.1.x release and hid update prompts.
  static const String _fallbackVersion = '0.1.0';

  /// The full commit SHA the binary was built from.
  static String get commit => _stamped.isEmpty ? _fallback : _stamped;

  /// The first seven characters, the short form GitHub prints.
  static String get shortCommit {
    final String value = commit.trim();
    return value.length <= 7 ? value : value.substring(0, 7);
  }

  /// The release version without the tag's `v` prefix, e.g. `0.1.1`.
  ///
  /// A branch build is not a version, so it falls back to the latest stable
  /// release instead of feeding a branch name to SemVer comparison.
  static String get version {
    final ReleaseVersion? parsed = ReleaseVersion.parse(_stampedVersion);
    return parsed?.normalized ?? _fallbackVersion;
  }

  /// The version as it appears in the interface.
  static String get displayVersion => 'v$version';
}
