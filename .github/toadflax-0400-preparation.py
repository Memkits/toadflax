import json
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

container = (output / "container.before.cirru").read_text()
previous = "      :schema $ quote $ Fn (Map Dynamic Dynamic) app.schema/NovelConfig (-> respo.schema/Component)\n"
assert container.count(previous) == 1
container = container.replace(previous, previous.replace("(Map Dynamic Dynamic)", "respo.schema/States"))
for name, value in (
    ("style-font-code", "Source Code Pro, monospace"),
    ("style-font-fancy", "Georgia, serif"),
):
    entry = (
        f"    '{name} $ %{{}} 'CodeEntry (:doc |)\n"
        f'      :code $ quote $ def {name} "|{value}"\n'
        "      :examples $ []\n"
    )
    assert container.count(entry) == 1
    assert not container.split(entry, 1)[1].startswith("      ")
    container = container.replace(entry, entry + "      :schema $ quote String\n")
(output / "container.after.cirru").write_text(container)
operations = [
    ["edit", "ns", "--file", str(output / "app-schema.after.cirru"), "--", "app.schema"],
    ["edit", "ns", "--file", str(output / "container.after.cirru"), "--", "app.comp.container"],
]
(output / "transaction.json").write_text(json.dumps(operations))
