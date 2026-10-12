# Domain layer (pure Dart)

Entities, value objects (exact `Cft`, `Money`), and policies (allocation, tax,
loading). **No Flutter imports. No `dart:io`.** Runs under `flutter test` /
`dart test` on Windows (Requirement 20.1).

Strict inward dependency direction: domain depends on nothing above it.
