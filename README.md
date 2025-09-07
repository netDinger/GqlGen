### String escaping

In embed mode the generator writes raw triple-quoted Dart strings (`r'''...'''`) so that
GraphQL variables like `$id` and newlines are preserved without Dart string interpolation.

## gql_gen

Small builder to turn GraphQL `.graphql` files into Dart strings.

Two outputs are generated when you run build_runner:

- Per-file: For each `*.graphql`, a sibling `*.graphql.dart` file is generated with a Dart string (embed mode) or lazy loader (load mode).
- Aggregate: One `lib/graphql/generatedOutputs/Queries.dart` file is created aggregating all discovered queries/mutations/subscriptions/fragments as constants or lazy getters.

### Install

Add to your app or package `pubspec.yaml`:

```yaml
dev_dependencies:
  build_runner: ^2.4.11
  gql_gen:
    path: ../gql_gen # or from pub when published
```

If you will use `load` mode (strings loaded at runtime), declare your `.graphql` assets:

```yaml
flutter:
  assets:
    - lib/graphql/
```

### Configure (optional)

Create a `gql_gen.yaml` at your package root to customize discovery and behavior:

```yaml
# gql_gen.yaml
mode: embed  # or 'load'
include:
  - lib/graphql/**/*.graphql
exclude: []
# When non-empty, disables per-file outputs and generates only the aggregate file.
# Note: Due to build_runner constraints the aggregate output path is fixed to
# lib/graphql/generatedOutputs/Queries.dart. To change it, edit build.yaml.
output_subdir: ""
```

Notes:

- Output behavior:
  - When `output_subdir` is empty (default): only per-file outputs are generated next to each `.graphql` file.
  - When `output_subdir` is non-empty: per-file outputs are disabled and only the aggregate file is generated.
  - Aggregate output path is fixed to `lib/graphql/generatedOutputs/Queries.dart` by `build.yaml`.
    If you need a different path, change the mapping in `build.yaml`.

### Run

```bash
dart run build_runner build
# or
flutter pub run build_runner build
```

### Use

Given files:

- `lib/graphql/userModel.graphql` (fragment)
- `lib/graphql/GetUser.graphql` (query)

You will get:

- `lib/graphql/GetUser.graphql.dart` with a `getUser` constant (embed) or `Future<String> get getUser` (load)
- `lib/graphql/generatedOutputs/Queries.dart` with constants/getters like `getUserQuery`, `userFragment`, etc.

Example (embed mode):

```dart
import 'package:your_app/graphql/generatedOutputs/Queries.dart';

void main() {
  print(getUserQuery); // Raw GraphQL string
}
```

Example (load mode):

```dart
import 'package:your_app/graphql/generatedOutputs/Queries.dart';

Future<void> run() async {
  final doc = await getUserQuery; // Loaded from asset
  print(doc);
}
```

If you prefer per-file imports:

```dart
import 'package:your_app/graphql/GetUser.graphql.dart';

void main() {
  print(getUser); // string or loader depending on mode
}
```
