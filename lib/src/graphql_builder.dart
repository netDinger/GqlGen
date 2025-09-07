// GENERATED WITH LOVE BY gql_gen

import 'dart:convert';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'config.dart';

Builder graphQLStringBuilder(BuilderOptions options) => _GraphQLStringBuilder(options);

class _GraphQLStringBuilder implements Builder {
  _GraphQLStringBuilder(this._options);

  final BuilderOptions _options;
  final _formatter = DartFormatter(languageVersion: Version.parse('3.0.0'));

  @override
  final buildExtensions = const {
    '.graphql': ['.graphql.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    // Resolve configuration (YAML takes precedence if present).
    final yamlCfg = await GqlGenConfig.fromYamlAssetOrDefault(buildStep);
    final optCfg = GqlGenConfig.fromOptions(_options);
    final cfg = yamlCfg != GqlGenConfig.defaults ? yamlCfg : optCfg;

    // If outputSubdir is provided (aggregate mode), skip per-file outputs.
    if (!cfg.emitPerFile) {
      return;
    }

    // Filter by include/exclude if configured.
    if (!_matchesAny(inputId.path, cfg.include)) return;
    if (_matchesAny(inputId.path, cfg.exclude)) return;

    final content = await buildStep.readAsString(inputId);

    final baseName = p.basenameWithoutExtension(inputId.path); // e.g. GetUser
    final variableBase = _toLowerCamel(_normalizeIdentifier(baseName));

    final packageName = inputId.package;
    final originalPath = inputId.path; // e.g. lib/graphql/GetUser.graphql

    final outId = inputId.changeExtension('.graphql.dart');
    final libName = _libraryNameFromPath(outId.path);

    final source = cfg.mode == 'load'
        ? _generateLoadSource(
            packageName: packageName,
            libName: libName,
            variableBase: variableBase,
            originalPath: originalPath,
          )
        : _generateEmbedSource(
            libName: libName,
            variableBase: variableBase,
            originalPath: originalPath,
            content: content,
          );

    final formatted = _format(source);
    await buildStep.writeAsString(outId, formatted);
  }

  bool _matchesAny(String path, List<String> patterns) {
    for (final pattern in patterns) {
      final glob = Glob(pattern);
      if (glob.matches(path)) return true;
    }
    return false;
  }

  String _format(String code) {
    try {
      return _formatter.format(code);
    } catch (_) {
      // If formatting fails, still emit readable code.
      return code;
    }
  }
}

String _generateEmbedSource({
  required String libName,
  required String variableBase,
  required String originalPath,
  required String content,
}) {
  return """
// GENERATED CODE - DO NOT MODIFY BY HAND
// *****************************************************
//  gql_gen: embed mode - strings are inlined at compile time
// *****************************************************

library $libName;

/// Original .graphql asset path.
const String ${variableBase}Path = ${jsonEncode(originalPath)};

/// GraphQL document content from [${originalPath}].
const String $variableBase = r'''$content''';
""";
}

String _generateLoadSource({
  required String packageName,
  required String libName,
  required String variableBase,
  required String originalPath,
}) {
  return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// *****************************************************
//  gql_gen: load mode - strings loaded at runtime from assets
// *****************************************************

library $libName;

import 'package:gql_gen/src/loader.dart' as _gql_loader;

/// Original .graphql asset path.
const String ${variableBase}Path = ${jsonEncode(originalPath)};

/// Loads the GraphQL content from Flutter asset bundle.
///
/// Note: Ensure the .graphql file is declared as an asset in your pubspec.yaml.
Future<String> get $variableBase => _gql_loader.loadQuery(${variableBase}Path, package: ${jsonEncode(packageName)});
''';
}

String _normalizeIdentifier(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    if (_isLetterOrDigit(ch)) {
      buffer.write(ch);
    } else {
      buffer.write(' ');
    }
  }
  final words = buffer.toString().trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return 'document';
  final camel = words.map((w) => w[0].toUpperCase() + w.substring(1)).join();
  return camel;
}

String _toLowerCamel(String input) {
  if (input.isEmpty) return input;
  return input[0].toLowerCase() + input.substring(1);
}

bool _isLetterOrDigit(String ch) {
  final code = ch.codeUnitAt(0);
  return (code >= 65 && code <= 90) || // A-Z
      (code >= 97 && code <= 122) || // a-z
      (code >= 48 && code <= 57); // 0-9
}

String _libraryNameFromPath(String path) {
  // Create a safe library name based on the path, replacing non-identifier chars with underscores.
  final withoutExt = path.replaceAll('.dart', '');
  final normalized = withoutExt
      .replaceAll(RegExp(r'[^A-Za-z0-9/]'), '_')
      .split('/')
      .where((s) => s.isNotEmpty)
      .join('_');
  final asIdentifier = normalized.replaceAll(RegExp(r'_+'), '_');
  return 'gql_gen_${asIdentifier}';
}
