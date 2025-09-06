import 'package:flutter/services.dart' show rootBundle;

/// Loads the contents of a `.graphql` file from Flutter assets.
///
/// Make sure to declare the original `.graphql` assets in your app's `pubspec.yaml`, e.g.:
///
/// flutter:
///   assets:
///     - lib/graphql/
///
/// If the `.graphql` lives inside a package dependency, set [package] to that
/// package name so Flutter can locate the asset correctly.
Future<String> loadQuery(String assetPath, {String? package}) {
  final key = package == null ? assetPath : 'packages/' + package + '/' + assetPath;
  return rootBundle.loadString(key);
}
