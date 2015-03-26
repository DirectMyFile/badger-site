import "dart:async";
import "dart:html";
import "dart:convert";

import "package:badger/parser.dart";
import "package:badger/compiler.dart";

import "dart:js" as JS;
import "package:ace/ace.dart" as ace;
import "package:ace/proxy.dart";

ace.Editor inputEditor;
ace.Editor outputEditor;
String type = "js";
String example;

const String GREETING = r"""
greet(name) {
  return "Hello $(name)"
}

let names = ["Kenneth", "Logan", "Sam", "Mike"]

for name in names {
  print(name)
}
""";

const String HELLO = r"""
print("Hello World")
""";

const String SIMPLE_MATH = r"""
print(2 + 2)
print(4 + 4)
print(10 / 2)
print(5 - 5)
print(5 * 5)
print(10 ~/ 2)
print(16 << 5)
print(16 >> 5)
""";

String _lastContent;

const String BUG_BODY = """
## Description

Bug Description

## Compiler Input

```badger
{input}
```

## Compiler Output

```{target}
{output}
```
""";

const String NAMESPACES = """
namespace Badger {
  hello() {
    print("Hello World")
  }
}

Badger.hello()
""";

const String TYPES = """
type Animal {
  speak() {
    print("(Silence)")
  }
}

let animal = Animal()
animal.speak()
""";

String formatJSON(String input) {
  var value = JSON.decode(input);
  return new JsonEncoder.withIndent("  ").convert(value);
}

void main() {
  ace.implementation = ACE_PROXY_IMPLEMENTATION;

  inputEditor = ace.edit("splitter-left");
  outputEditor = ace.edit("splitter-right");

  inputEditor.setValue(GREETING, -1);

  outputEditor.setOption("useWorker", false);
  outputEditor.session.setOption("mode", "ace/mode/javascript");
  outputEditor.setOption("readOnly", true);

  SelectElement $t = querySelector("#compiler");

  $t.onChange.listen((e) {
    type = $t.value;
    recompile();
  });

  SelectElement $e = querySelector("#example");

  $e.onChange.listen((e) {
    var e = $e.value;
    String s;
    s = {
      "greeting": GREETING,
      "hello": HELLO,
      "math": SIMPLE_MATH,
      "types": TYPES,
      "namespaces": NAMESPACES
    }[e];

    if (s == null) {
      window.alert("Unknown Example: ${e}");
      return;
    }

    inputEditor.setValue(s, -1);
    recompile();
  });

  querySelector("#file_bug").onClick.listen((e) {
    var body = BUG_BODY
      .replaceAll("{input}", inputEditor.session.value)
      .replaceAll("{output}", outputEditor.session.value)
      .replaceAll("{target}", ["ast", "tiny-ast"].contains($t.value) ? "json" : $t.value);
    var url = "https://github.com/badger-lang/badger/issues/new?title=Compiler+Bug&body=${Uri.encodeComponent(body)}";
    window.open(url, "Badger: File Compiler Bug");
  });

  new Timer.periodic(new Duration(milliseconds: 1500), (t) {
    if (_lastContent != inputEditor.session.value) {
      recompile();
    }
  });

  var uri = Uri.parse(window.location.href);
  if (uri.queryParameters.containsKey("example")) {
    $e.value = uri.queryParameters["example"];
  }

  if (uri.queryParameters.containsKey("target")) {
    $t.value = uri.queryParameters["target"];
  }

  recompile();
  inputEditor.focus();

  querySelector("#run").onClick.listen((e) {
    var w = window.open("executor.html", "Badger Script Execution");
    window.addEventListener("message", (e) {
      var data = e.data;

      if (data["command"] == "ready") {
        var code = outputEditor.session.value.toString();
        w.postMessage({
          "code": code
        }, window.location.href);
      }
    });
  });
}

recompile() async {
  _lastContent = inputEditor.session.value;
  var parser = new BadgerParser();
  var result = parser.parse(inputEditor.session.value);

  if (result.isFailure) {
    print(result);
    var pstr = result.toPositionString();

    if (pstr.contains(":")) {
      var x = int.parse(pstr.split(":").first) - 1;
      inputEditor.session.setAnnotations([
        new ace.Annotation(row: x, text: result.message, type: ace.Annotation.ERROR)
      ]);
      return;
    } else {
      window.alert("Parser Error: ${result}");
      return;
    }
  }

  inputEditor.session.setAnnotations([]);

  CompilerTarget compiler;

  if (type == "js") {
    compiler = new JsCompilerTarget();
    compiler.options["hooks"] = true;
    outputEditor.session.setOption("mode", "ace/mode/javascript");
  } else if (type == "dart") {
    compiler = new DartCompilerTarget();
    compiler.options["pretty"] = true;
    outputEditor.session.setOption("mode", "ace/mode/dart");
  } else if (type == "ast") {
    compiler = new AstCompilerTarget();
    outputEditor.session.setOption("mode", "ace/mode/json");
  } else if (type == "tiny-ast") {
    compiler = new TinyAstCompilerTarget();
    outputEditor.session.setOption("mode", "ace/mode/json");
  } else {
    window.alert("Unknown Target Type: ${type}");
    return;
  }

  String out;
  try {
    out = await compiler.compile(result.value);
  } catch (e) {
    window.alert("Failed to Compile: ${e}");
    return;
  }

  if (type == "js") {
    out = JS.context.callMethod("js_beautify", [out, new JS.JsObject.jsify({
      "indent_size": 2
    })]);
  } else if (type == "ast" || type == "tiny-ast") {
    out = formatJSON(out);
  }

  outputEditor.setValue(out, -1);
  querySelector("#run").hidden = type != "js";
}
