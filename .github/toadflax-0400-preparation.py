from pathlib import Path
from sys import argv

output = Path(argv[1])
source = (output / "app-schema.before.cirru").read_text()
start = source.index("    'decode-op $ ")
end = source.index("    'empty-records $ ", start)
definition = source[start:end]
schema = "      :schema $ quote $ Fn AnyEnum (-> app.schema/Op)\n"
assert definition.count(schema) == 1
assert "(:states cursor value)" in definition
updated = definition.replace(schema, schema.rstrip() + " (:open :decode)\n")
(output / "app-schema.after.cirru").write_text(source[:start] + updated + source[end:])
