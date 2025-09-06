import 'package:flutter_test/flutter_test.dart';

import 'package:gql_gen/gql_gen.dart';

void main() {
  test('exports loader function', () {
    // smoke test that the loader symbol exists
    expect(loadQuery, isNotNull);
  });
}
