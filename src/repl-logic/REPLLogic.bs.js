// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Fs = require("fs");
var Curry = require("rescript/lib/js/curry.js");
var Js_array = require("rescript/lib/js/js_array.js");
var Child_process = require("child_process");
var Js_null_undefined = require("rescript/lib/js/js_null_undefined.js");
var Caml_js_exceptions = require("rescript/lib/js/caml_js_exceptions.js");
var RegexUtilsBsJs = require("../utils/RegexUtils.bs.js");

function separateOpenModulesFromRemainingCode(prim) {
  return RegexUtilsBsJs.separateOpenModulesFromRemainingCode(prim);
}

function build(param) {
  return new Promise((function (resolve, _reject) {
                Child_process.exec("npm run res:build", (function (error, stdout, stderr) {
                        if (error == null) {
                          return resolve(/* BuildSuccess */0);
                        } else {
                          Js_null_undefined.bind(error, (function (error_str) {
                                  var msg = error_str.message;
                                  if (msg !== undefined) {
                                    console.log("ERROR building ReScript code: " + msg);
                                    console.log("stdout: " + stdout.toString());
                                    return resolve(/* BuildFail */1);
                                  } else {
                                    return resolve(/* BuildFail */1);
                                  }
                                }));
                          return ;
                        }
                      }));
              }));
}

var RescriptBuild = {
  build: build
};

function isFilepath(s) {
  var rescriptFileRegex = /.res/g;
  var jsFileRegex = /.js/g;
  if (rescriptFileRegex.test(s)) {
    return true;
  } else {
    return jsFileRegex.test(s);
  }
}

function write(s, contents) {
  Fs.writeFileSync(s._0, contents);
}

function read(s) {
  var s$1 = s._0;
  var initialContents = "";
  if (isFilepath(s$1)) {
    try {
      return Fs.readFileSync(s$1, "utf8");
    }
    catch (exn){
      write(/* Filepath */{
            _0: s$1
          }, initialContents);
      return initialContents;
    }
  } else {
    write(/* Filepath */{
          _0: s$1
        }, initialContents);
    return initialContents;
  }
}

var FileOperations = {
  write: write,
  read: read
};

function eval_js_code(code, FO) {
  var code$1 = code._0;
  return new Promise((function (resolve, _reject) {
                try {
                  Curry._2(FO.write, /* Filepath */{
                        _0: "./src/evalJsCode.js"
                      }, "eval(\`" + code$1 + "\`)");
                  Child_process.exec("node ./src/evalJsCode.js", (function (error, stdout, stderr) {
                          if (error == null) {
                            return resolve(stdout.toString().trim());
                          } else {
                            Js_null_undefined.bind(error, (function (error_str) {
                                    var msg = error_str.message;
                                    if (msg !== undefined) {
                                      console.log("ERROR running JavaScript code: " + msg);
                                      console.log("stdout: " + stdout.toString());
                                      return resolve(undefined);
                                    } else {
                                      return resolve(undefined);
                                    }
                                  }));
                            return ;
                          }
                        }));
                  return ;
                }
                catch (raw_x){
                  var x = Caml_js_exceptions.internalToOCamlException(raw_x);
                  console.log("ERROR: Failed to evalutate the following JavaScript code: \n" + code$1);
                  console.log("REASON: ");
                  console.log(x);
                  return resolve(undefined);
                }
              }));
}

var EvalJavaScriptCode = {
  $$eval: eval_js_code
};

function then(p, f) {
  return p.then(function (x) {
              return new Promise((function (resolve, _reject) {
                            Curry._1(f, x);
                            resolve(undefined);
                          }));
            });
}

async function handleBuildAndEval(codeStr, FO, RB, EvalJS) {
  var prevContents = Curry._1(FO.read, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      });
  Curry._2(FO.write, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      }, prevContents + "\n" + codeStr);
  var result = await Curry._1(RB.build, undefined);
  if (result) {
    Curry._2(FO.write, /* Filepath */{
          _0: "./src/RescriptREPL.res"
        }, prevContents);
    return ;
  }
  var jsCodeStr = Curry._1(FO.read, /* Filepath */{
        _0: "./src/RescriptREPL.bs.js"
      });
  var stdout = await Curry._2(EvalJS.$$eval, /* JavaScriptCode */{
        _0: jsCodeStr
      }, FO);
  var startsWithJsLogRegex = /^Js.log/g;
  var endsWithJsLogRegex = /->(\x20*)Js.log(.*)/g;
  if (startsWithJsLogRegex.test(codeStr) || endsWithJsLogRegex.test(codeStr)) {
    Curry._2(FO.write, /* Filepath */{
          _0: "./src/RescriptREPL.res"
        }, prevContents);
  }
  return stdout;
}

function handleLoadModuleBuildAndEval(codeStr, FO, RB, EvalJS) {
  var prevContents = Curry._1(FO.read, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      });
  Curry._2(FO.write, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      }, codeStr);
  return Curry._1(RB.build, undefined).then(function (result) {
              return new Promise((function (resolve, _reject) {
                            if (result) {
                              Curry._2(FO.write, /* Filepath */{
                                    _0: "./src/RescriptREPL.res"
                                  }, prevContents);
                              return resolve(undefined);
                            }
                            var jsCodeStr = Curry._1(FO.read, /* Filepath */{
                                  _0: "./src/RescriptREPL.bs.js"
                                });
                            then(Curry._2(EvalJS.$$eval, /* JavaScriptCode */{
                                      _0: jsCodeStr
                                    }, FO), (function (param) {
                                    var startsWithJsLogRegex = /^Js.log/g;
                                    var endsWithJsLogRegex = /->(\x20*)Js.log(.*)/g;
                                    if (startsWithJsLogRegex.test(codeStr) || endsWithJsLogRegex.test(codeStr)) {
                                      Curry._2(FO.write, /* Filepath */{
                                            _0: "./src/RescriptREPL.res"
                                          }, prevContents);
                                    }
                                    resolve(undefined);
                                  }));
                          }));
            });
}

function handleLoadModuleCase(moduleName, FO, RB, EvalJS) {
  var codeStr = Curry._1(FO.read, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      });
  var x = RegexUtilsBsJs.separateOpenModulesFromRemainingCode(codeStr);
  if (x.openModulesSection.length > 0) {
    var xs = [
      x.openModulesSection,
      "open " + moduleName + ""
    ];
    var nextCodeStr = Js_array.joinWith("\n", xs) + "\n" + x.remainingStr;
    return handleLoadModuleBuildAndEval(nextCodeStr, FO, RB, EvalJS).then(function (_result) {
                return new Promise((function (resolve, _reject) {
                              resolve(undefined);
                            }));
              });
  }
  var nextCodeStr$1 = "open " + moduleName + "\n" + codeStr;
  return handleLoadModuleBuildAndEval(nextCodeStr$1, FO, RB, EvalJS).then(function (_result) {
              return new Promise((function (resolve, _reject) {
                            resolve(undefined);
                          }));
            });
}

exports.separateOpenModulesFromRemainingCode = separateOpenModulesFromRemainingCode;
exports.build = build;
exports.RescriptBuild = RescriptBuild;
exports.isFilepath = isFilepath;
exports.FileOperations = FileOperations;
exports.eval_js_code = eval_js_code;
exports.EvalJavaScriptCode = EvalJavaScriptCode;
exports.then = then;
exports.handleBuildAndEval = handleBuildAndEval;
exports.handleLoadModuleBuildAndEval = handleLoadModuleBuildAndEval;
exports.handleLoadModuleCase = handleLoadModuleCase;
/* fs Not a pure module */
