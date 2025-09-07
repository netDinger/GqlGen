import 'dart:convert';

import 'package:build/build.dart';
import 'package:yaml/yaml.dart' as y;

/// Configuration for gql_gen builder.
class GqlGenConfig {
  final String mode; // 'embed' or 'load'
  final String outputSubdir; // relative to lib/, used by aggregate builder
  final List<String> include;
  final List<String> exclude;

  const GqlGenConfig({
    required this.mode,
    required this.outputSubdir,
    required this.include,
    required this.exclude,
  });

  static const GqlGenConfig defaults = GqlGenConfig(
    mode: 'embed',
    outputSubdir: '',
    include: ['lib/**/*.graphql'],
    exclude: <String>[],
  );

  factory GqlGenConfig.fromOptions(BuilderOptions options) {
    final map = options.config;
    return GqlGenConfig(
      mode: (map['mode'] as String?)?.toLowerCase() == 'load' ? 'load' : 'embed',
      outputSubdir: _nonEmpty((map['output_subdir'] as String?)?.trim()) ?? defaults.outputSubdir,
      include: _stringList(map['include']) ?? defaults.include,
      exclude: _stringList(map['exclude']) ?? defaults.exclude,
    );
  }

  /// Load configuration from a YAML file if present.
  /// This allows end users to create a `gql_gen.yaml` file at the root of their package.
  static Future<GqlGenConfig> fromYamlAssetOrDefault(BuildStep buildStep) async {
    final rootPackage = buildStep.inputId.package;
    final id = AssetId(rootPackage, 'gql_gen.yaml');
    try {
      final exists = await buildStep.canRead(id);
      if (!exists) return defaults;
      final content = await buildStep.readAsString(id);
      final doc = y.loadYaml(content);
      if (doc is! y.YamlMap) return defaults;
      final map = json.decode(json.encode(doc)) as Map<String, dynamic>;
      return GqlGenConfig(
        mode: (map['mode'] as String?)?.toLowerCase() == 'load' ? 'load' : 'embed',
        outputSubdir: (map['output_subdir'] as String?)?.trim() ?? '',
        include: _stringList(map['include']) ?? defaults.include,
        exclude: _stringList(map['exclude']) ?? defaults.exclude,
      );
    } catch (_) {
      return defaults;
    }
  }
}

extension GqlGenConfigBehavior on GqlGenConfig {
  /// Emit per-file outputs when no outputSubdir is specified.
  bool get emitPerFile => outputSubdir.trim().isEmpty;

  /// Emit aggregate output only when an outputSubdir is specified.
  bool get emitAggregate => outputSubdir.trim().isNotEmpty;
}

List<String>? _stringList(Object? value) {
  if (value == null) return null;
  if (value is List) {
    return value.whereType<Object>().map((e) => e.toString()).toList();
  }
  return null;
}

String? _nonEmpty(String? s) {
  if (s == null) return null;
  if (s.trim().isEmpty) return null;
  return s;
}
