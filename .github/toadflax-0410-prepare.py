import json
from pathlib import Path
from sys import argv

out = Path(argv[1])
target = "app.comp.container/handle-chapter-tool-call"
ops = json.loads(Path(".github/toadflax-0410-transaction.json").read_text())
ops[1:1] = [
    ["edit", "def", "--input-format", "cirru", "--code", "quote $ def empty-chapter-tool-result ({})", "--", "app.comp.container/empty-chapter-tool-result"],
    ["edit", "schema", "--input-format", "cirru", "--code", "quote $ Map Tag (JsNullish app.comp.container/ChapterToolValue)", "--", "app.comp.container/empty-chapter-tool-result"],
]

def read_tree(name):
    return json.loads((out / name).read_text())["tree"]

def typed_map(pairs):
    result = "empty-chapter-tool-result"
    for key, value in pairs:
        result = [".assoc", result, key, value]
    return result

count = 0

def change_results(node):
    global count
    if not isinstance(node, list):
        return node
    if len(node) > 1 and node[0] == "{}" and node[1][0] == ":ok?":
        count += 1
        return typed_map(node[1:])
    return [change_results(child) for child in node]

branches = change_results(read_tree("tool-branches.json"))
assert count == 12, count
neighbors = read_tree("neighbors.json")
assert [entry[0] for entry in neighbors[1:]] == [":previous", ":next"], neighbors
assert neighbors[0] == "{}"
for path, tree in [("@4.3", branches), ("@4.1.3.1.3.2", typed_map(neighbors[1:]))]:
    ops.insert(-1, ["tree", "replace", "--path", path, "--input-format", "json-ast",
                    "--code", json.dumps(tree), "--", target])
(out / "transaction.json").write_text(json.dumps(ops))
