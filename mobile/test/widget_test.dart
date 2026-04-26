import 'package:flutter_test/flutter_test.dart';

void main() {
  test('placeholder smoke test', () {
    // Real widget tests arrive once the app has real screens.
    // Boot of the full app requires .env + Supabase init, which
    // is not viable in a unit-test environment without mocks.
    expect(1 + 1, 2);
  });
}
