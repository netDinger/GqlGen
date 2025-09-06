/// gql_gen
///
/// Build-runner builder that turns `.graphql` files into Dart string constants
/// (embed mode) or lazy-loaded strings from Flutter assets (load mode).
///
/// End users typically don't need to import anything, but if you choose
/// `load` mode you can optionally import `loadQuery` from this package.

export 'src/loader.dart' show loadQuery;
