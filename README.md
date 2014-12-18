For a demonstration, run:

    coffee example/spec.coffee > example/spec.json

to generate a JSON representation of the example specification from the CoffeeScript-based DSL.

    coffee lib/json-spec.coffee validate example/spec.json example/invalid-data.json

to validate a (invalid) JSON data file against that specification.

    coffee lib/json-spec.coffee validate example/spec.json example/valid-data.json

to validate a (valid) JSON data file against that specification.

    coffee lib/json-spec.coffee to-markdown example/spec.json > example/spec.md

to generate a Markdown document describing the specifcation.

    coffee lib/json-spec.coffee to-markdown example/spec.json | marked > example/spec.html

to generate an HTML representation of that  Markdown document.
