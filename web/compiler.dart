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
func greet(name) {
  return "Hello $(name)"
}

let names = ["Kenneth", "Logan", "Sam", "Mike"]

for name in names {
  print(greet(name))
}
""";

const String HELLO = r"""
print("Hello World")
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

  inputEditor.onChange.listen((e) {
    recompile();
  });

  var $t = querySelector("#compiler");

  $t.onChange.listen((e) {
    type = $t.value;
    recompile();
  });

  var $e = querySelector("#example");

  $e.onChange.listen((e) {
    var e = $e.value;
    String s;
    if (e == "hello") {
      s = HELLO;
    } else if (e == "greeting") {
      s = GREETING;
    } else {
      window.alert("Unknown Example: ${e}");
      return;
    }

    inputEditor.setValue(s, -1);
    recompile();
  });

  recompile();
  inputEditor.focus();
}

recompile() async {
  var parser = new BadgerParser();
  var result = parser.parse(inputEditor.session.value);

  if (result.isFailure) {
    print(result);
    var annotations = [];

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

  CompilerTarget compiler;

  if (type == "js") {
    compiler = new JsCompilerTarget();
    outputEditor.session.setOption("mode", "ace/mode/javascript");
  } else if (type == "dart") {
    compiler = new DartCompilerTarget();
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

  var out = await compiler.compile(result.value);

  if (type == "js") {
    out = JS.context.callMethod("js_beautify", [out, new JS.JsObject.jsify({
      "indent_size": 2
    })]);
  } else if (type == "ast" || type == "tiny-ast") {
    out = formatJSON(out);
  }

  outputEditor.setValue(out, -1);
}
