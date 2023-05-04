// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Fs = require("fs");
var Curry = require("rescript/lib/js/curry.js");
var Js_exn = require("rescript/lib/js/js_exn.js");
var Process = require("process");
var Js_array = require("rescript/lib/js/js_array.js");
var Readline = require("readline");
var Js_string = require("rescript/lib/js/js_string.js");
var Caml_array = require("rescript/lib/js/caml_array.js");
var Child_process = require("child_process");
var Js_null_undefined = require("rescript/lib/js/js_null_undefined.js");
var Caml_js_exceptions = require("rescript/lib/js/caml_js_exceptions.js");

var rl = Readline.createInterface({
      input: Process.stdin,
      output: Process.stdout
    });

function prompt_2(rl, query, cb) {
  new Promise((function (resolve, _reject) {
            rl.question(query, (function (x) {
                    resolve(x);
                  }));
          })).then(Curry.__1(cb));
}

function repl_2(CLIO, DL) {
  var cliInterface = Curry._1(CLIO.make, undefined);
  Curry._3(CLIO.prompt, cliInterface, "\u03BB> ", DL.handleUserInput);
}

rl.on("close", (function (param) {
        console.log("See You Space Cowboy");
        Fs.unlinkSync("./src/RescriptRepl.res");
        Fs.unlinkSync("./src/RescriptRepl.bs.js");
      }));

function prompt(query) {
  return new Promise((function (resolve, _reject) {
                rl.question(query, (function (x) {
                        resolve(x);
                      }));
              }));
}

function write(filename, contents) {
  Fs.writeFileSync(filename, contents);
}

function rewrite(filename, contents) {
  Fs.unlinkSync(filename);
  Fs.writeFileSync(filename, contents);
}

function handle_get_next_contents(s) {
  try {
    var contents = Fs.readFileSync("./src/RescriptRepl.res", "utf8");
    return [
            contents,
            contents + "\n" + s
          ];
  }
  catch (raw__obj){
    var _obj = Caml_js_exceptions.internalToOCamlException(raw__obj);
    if (_obj.RE_EXN_ID === Js_exn.$$Error) {
      return [
              "",
              s
            ];
    }
    throw _obj;
  }
}

function build_rescript_code(prev_contents, f) {
  return Child_process.exec("npm run res:build", (function (error, stdout, stderr) {
                if (error == null) {
                  return Curry._1(f, undefined);
                } else {
                  Js_null_undefined.bind(error, (function (error_str) {
                          var msg = error_str.message;
                          if (msg !== undefined) {
                            console.log("ERROR: " + msg);
                            console.log("stdout: " + stdout.toString());
                            Fs.writeFileSync("./src/RescriptRepl.res", prev_contents);
                            return ;
                          }
                          
                        }));
                  return ;
                }
              }));
}

function eval_js_code(param) {
  var contents = Fs.readFileSync("./src/RescriptRepl.bs.js", "utf8");
  eval(contents);
}

function extract_module_name(module_filepath) {
  var xs = Js_string.split("/", module_filepath);
  var x = Js_string.split(".", Caml_array.get(xs, xs.length - 1 | 0));
  if (x.length === 2) {
    var module_name = x[0];
    var match = x[1];
    if (match === "res") {
      return module_name;
    }
    
  }
  console.log("ERROR: expected a .res file, but received: " + Js_array.joinWith(".", x));
}

function create_module_str(module_name, module_contents) {
  return "module " + module_name + " = { \n" + module_contents + "\n }";
}

function repl(reset_contents) {
  prompt("\u03BB> ").then(function (user_input) {
        var match = Js_string.split(" ", user_input);
        var exit = 0;
        var len = match.length;
        if (len >= 3) {
          exit = 1;
        } else {
          switch (len) {
            case 0 :
                exit = 1;
                break;
            case 1 :
                var match$1 = match[0];
                switch (match$1) {
                  case ":exit" :
                      rl.close();
                      break;
                  case ":reset" :
                      rewrite("./src/RescriptRepl.res", "");
                      repl(undefined);
                      break;
                  default:
                    exit = 1;
                }
                break;
            case 2 :
                var match$2 = match[0];
                if (match$2 === ":load") {
                  var module_filepath = match[1];
                  var module_name = extract_module_name(module_filepath);
                  if (module_name !== undefined) {
                    try {
                      var module_contents = Fs.readFileSync(module_filepath, "utf8");
                      var module_str = create_module_str(module_name, module_contents);
                      var match$3 = handle_get_next_contents(module_str);
                      Fs.writeFileSync("./src/RescriptRepl.res", match$3[1]);
                      build_rescript_code(match$3[0], eval_js_code);
                      repl(undefined);
                    }
                    catch (raw_obj){
                      var obj = Caml_js_exceptions.internalToOCamlException(raw_obj);
                      if (obj.RE_EXN_ID === Js_exn.$$Error) {
                        console.log(obj._1);
                        repl(undefined);
                      } else {
                        throw obj;
                      }
                    }
                  } else {
                    repl(undefined);
                  }
                } else {
                  exit = 1;
                }
                break;
            
          }
        }
        if (exit === 1) {
          var xs = Js_string.split("(", user_input);
          var x = Caml_array.get(xs, 0);
          if (x === "Js.log") {
            if (reset_contents !== undefined) {
              rewrite("./src/RescriptRepl.res", reset_contents);
            }
            var match$4 = handle_get_next_contents(user_input);
            var prev_contents = match$4[0];
            Fs.writeFileSync("./src/RescriptRepl.res", match$4[1]);
            build_rescript_code(prev_contents, eval_js_code);
            repl(prev_contents);
          } else {
            if (reset_contents !== undefined) {
              rewrite("./src/RescriptRepl.res", reset_contents);
            }
            var match$5 = handle_get_next_contents(user_input);
            Fs.writeFileSync("./src/RescriptRepl.res", match$5[1]);
            build_rescript_code(match$5[0], eval_js_code);
            repl(undefined);
          }
        }
        return Promise.resolve(user_input);
      });
}

exports.rl = rl;
exports.prompt_2 = prompt_2;
exports.repl_2 = repl_2;
exports.prompt = prompt;
exports.write = write;
exports.rewrite = rewrite;
exports.handle_get_next_contents = handle_get_next_contents;
exports.build_rescript_code = build_rescript_code;
exports.eval_js_code = eval_js_code;
exports.extract_module_name = extract_module_name;
exports.create_module_str = create_module_str;
exports.repl = repl;
/* rl Not a pure module */
