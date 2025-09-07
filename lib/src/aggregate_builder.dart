import 'dart:convert';

import 'package:build/build.dart';
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:pub_semver/pub_semver.dart';

import 'config.dart';

Builder graphQLAggregateBuilder(BuilderOptions options) => _GraphQLAggregateBuilder(options);

class _GraphQLAggregateBuilder implements Builder {
  _GraphQLAggregateBuilder(this._options);

  final BuilderOptions _options;
  final _formatter = DartFormatter(languageVersion: Version.parse('3.0.0'));

  // Pseudo input to generate one output per package
  @override
  final Map<String, List<String>> buildExtensions = const {
    r'$lib$': ['graphql/generatedOutputs/Queries.dart'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    // Only run once for the package pseudo-input.
    if (buildStep.inputId.path != 'lib/\$lib\$') return;

    final cfg = await _resolveConfig(buildStep);

    // If no outputSubdir is specified, we are in per-file mode: skip aggregate.
    if (!cfg.emitAggregate) {
      return;
    }

    // Discover all matching .graphql assets.
    final packageName = buildStep.inputId.package;
    final assets = <AssetId>[];
    for (final pattern in cfg.include) {
      final glob = Glob(pattern);
      await for (final id in buildStep.findAssets(glob)) {
        if (!_isExcluded(id.path, cfg.exclude)) {
          assets.add(id);
        }
      }
    }

    assets.sort((a, b) => a.path.compareTo(b.path));

    // Generate content
    final buf = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln('// *****************************************************')
      ..writeln('//  gql_gen: ${cfg.mode} mode - aggregated outputs')
      ..writeln('// *****************************************************')
      ..writeln()
      ..writeln('library graphql_generated_outputs;')
      ..writeln();

    if (cfg.mode == 'load') {
      buf.writeln("import 'package:gql_gen/src/loader.dart' as _gql_loader;");
      buf.writeln();
    }

    // Map to de-duplicate names
    final usedNames = <String>{};

    for (final id in assets) {
      final path = id.path; // e.g. lib/graphql/GetUser.graphql
      final content = await buildStep.readAsString(id);

      final typeAndName = _extractTypeAndName(content);
      final kind = typeAndName.$1; // query|mutation|subscription|fragment|doc
      final name = typeAndName.$2 ?? _fileBaseName(path);

      // Preferred variable name in lowerCamel with suffix
      final varBase = _toLowerCamel(_normalizeIdentifier(name));
      final suffix = switch (kind) {
        'query' => 'Query',
        'mutation' => 'Mutation',
        'subscription' => 'Subscription',
        'fragment' => 'Fragment',
        _ => 'Doc',
      };

      var varName = '$varBase$suffix';
      var i = 2;
      while (usedNames.contains(varName)) {
        varName = '$varBase$suffix$i';
        i++;
      }
      usedNames.add(varName);

      // Emit path const and value getter/const
      buf.writeln("/// Original .graphql asset path for $varName.");
      buf.writeln("const String ${varName}Path = ${jsonEncode(path)};");

      if (cfg.mode == 'load') {
        buf.writeln('Future<String> get $varName => _gql_loader.loadQuery(${varName}Path, package: ${jsonEncode(packageName)});');
      } else {
        // Use raw triple-quoted string to avoid interpolation of $ and preserve newlines.
        final raw = "r'''${content}'''";
        buf.writeln('const String $varName = ' + raw + ';');
      }
      buf.writeln();
    }

    // Note: Output path is fixed to match build_extensions mapping.
    // If you want to customize this, you must modify build.yaml in your app.
    final outId = AssetId(buildStep.inputId.package, 'lib/graphql/generatedOutputs/Queries.dart');
    final formatted = _format(buf.toString());
    await buildStep.writeAsString(outId, formatted);
  }

  Future<GqlGenConfig> _resolveConfig(BuildStep step) async {
    // YAML has priority; fallback to builder options; finally defaults.
    final yaml = await GqlGenConfig.fromYamlAssetOrDefault(step);
    if (yaml != GqlGenConfig.defaults) return yaml;
    return GqlGenConfig.fromOptions(_options);
  }

  String _format(String code) {
    try {
      return _formatter.format(code);
    } catch (_) {
      return code;
    }
  }

  bool _isExcluded(String path, List<String> excludes) {
    for (final pattern in excludes) {
      final glob = Glob(pattern);
      if (glob.matches(path)) return true;
    }
    return false;
  }
}

(String, String?) _extractTypeAndName(String content) {
  // Remove leading comments and whitespace, then match the kind and an optional name.
  final cleaned = content.replaceFirst(RegExp(r'^(\s*#.*\n)*\s*'), '');
  final match = RegExp(r'^(query|mutation|subscription|fragment)\s+(\w+)?', caseSensitive: false)
      .firstMatch(cleaned);
  if (match == null) return ('doc', null);
  final kind = match.group(1)!.toLowerCase();
  final name = match.group(2);
  return (kind, name);
}

String _fileBaseName(String path) {
  final lastSlash = path.lastIndexOf('/');
  final file = lastSlash == -1 ? path : path.substring(lastSlash + 1);
  final dot = file.lastIndexOf('.');
  return dot == -1 ? file : file.substring(0, dot);
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
