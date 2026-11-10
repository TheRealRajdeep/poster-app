/// Models and validation for poster `spec.json` files.
///
/// The JSON Schema in `schema/spec.schema.json` describes the same format
/// for the Python factory; `test/fixtures/` holds shared valid/invalid
/// examples that both sides must agree on.
library;

export 'src/model.dart';
export 'src/parse.dart';
