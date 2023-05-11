// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Fs = require("fs");
var Curry = require("rescript/lib/js/curry.js");
var Js_exn = require("rescript/lib/js/js_exn.js");
var Parser = require("../repl-commands-parser/Parser.bs.js");
var Js_array = require("rescript/lib/js/js_array.js");
var Caml_array = require("rescript/lib/js/caml_array.js");
var Belt_Option = require("rescript/lib/js/belt_Option.js");
var Child_process = require("child_process");
var Js_null_undefined = require("rescript/lib/js/js_null_undefined.js");
var ParserCombinators = require("../repl-commands-parser/ParserCombinators.bs.js");
var Caml_js_exceptions = require("rescript/lib/js/caml_js_exceptions.js");

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
  return Parser.runParser(ParserCombinators.rescriptJavascriptFileP, s) !== undefined;
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
                            console.log(stdout);
                            return resolve(undefined);
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

function handleContOrClose(contOrClose, cont, close) {
  return new Promise((function (resolve, _reject) {
                if (contOrClose) {
                  Curry._1(cont, contOrClose._0).then(function (param) {
                        return new Promise((function (res, _rej) {
                                      res(undefined);
                                    }));
                      });
                  return resolve(contOrClose);
                } else {
                  console.log("See you Space Cowboy");
                  Curry._1(close, undefined);
                  return resolve(contOrClose);
                }
              }));
}

async function start_repl(make, prompt, close) {
  var state = Curry._1(make, undefined);
  var run_loop = async function (s) {
    var contOrClose = await Curry._1(prompt, s);
    return await handleContOrClose(contOrClose, run_loop, close);
  };
  return await run_loop(state);
}

function parseReplCommand(s) {
  var xs = [
    Parser.runParser(ParserCombinators.loadCommandP, s),
    Parser.runParser(ParserCombinators.startMultiLineCommandP, s),
    Parser.runParser(ParserCombinators.endMultiLineCommandP, s),
    Parser.runParser(ParserCombinators.resetCommandP, s)
  ];
  var ys = Js_array.filter(Belt_Option.isSome, xs);
  if (ys.length === 0) {
    return {
            TAG: /* RescriptCode */0,
            _0: s
          };
  }
  var match = Caml_array.get(ys, 0);
  if (match !== undefined) {
    return match[1];
  } else {
    return Js_exn.raiseError("INVARIANT VIOLATION: Impossible state, Nones were filtered out of the array prior to this section of the code");
  }
}

function startsOrEndsWithJsLog(s) {
  return Parser.runParser(ParserCombinators.rescriptCodeStartsOrEndsWithJsLogP, s) !== undefined;
}

function then(p, f) {
  return p.then(function (x) {
              return new Promise((function (resolve, _reject) {
                            Curry._1(f, x);
                            resolve(undefined);
                          }));
            });
}

function handleBuildAndEval(code_str, FO, RB, EvalJS) {
  var prevContents = Curry._1(FO.read, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      });
  Curry._2(FO.write, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      }, prevContents + "\n" + code_str);
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
                                    if (startsOrEndsWithJsLog(code_str)) {
                                      Curry._2(FO.write, /* Filepath */{
                                            _0: "./src/RescriptREPL.res"
                                          }, prevContents);
                                    }
                                    resolve(undefined);
                                  }));
                          }));
            });
}

function handleLoadModuleBuildAndEval(code_str, FO, RB, EvalJS) {
  var prevContents = Curry._1(FO.read, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      });
  Curry._2(FO.write, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      }, code_str);
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
                                    if (startsOrEndsWithJsLog(code_str)) {
                                      Curry._2(FO.write, /* Filepath */{
                                            _0: "./src/RescriptREPL.res"
                                          }, prevContents);
                                    }
                                    resolve(undefined);
                                  }));
                          }));
            });
}

function handleEndMultiLineCase(state, FO, RB, EvalJS) {
  var codeStr = state.multilineMode.rescriptCodeInput;
  if (codeStr !== undefined) {
    return handleBuildAndEval(codeStr, FO, RB, EvalJS).then(function (_result) {
                return new Promise((function (resolve, _reject) {
                              resolve({
                                    multilineMode: {
                                      active: false,
                                      rescriptCodeInput: undefined
                                    }
                                  });
                            }));
              });
  } else {
    return Js_exn.raiseError("INVARIANT VIOLATION: The EndMultiLineMode case expects for there to be some rescriptCodeInput present.");
  }
}

function handleRescriptCodeCase(state, nextCodeStr, FO, RB, EvalJS) {
  return new Promise((function (resolve, _reject) {
                if (state.multilineMode.active) {
                  var prevCodeStr = state.multilineMode.rescriptCodeInput;
                  if (prevCodeStr !== undefined) {
                    var updated_state = {
                      multilineMode: {
                        active: true,
                        rescriptCodeInput: prevCodeStr + "\n" + nextCodeStr
                      }
                    };
                    return resolve(updated_state);
                  }
                  console.log("INVARIANT VIOLATION: The RescriptCode case expects for there to be some rescriptCodeInput present.");
                  return ;
                }
                then(handleBuildAndEval(nextCodeStr, FO, RB, EvalJS), (function (param) {
                        resolve(state);
                      }));
              }));
}

function handleLoadModuleCase(moduleName, FO, RB, EvalJS) {
  var codeStr = Curry._1(FO.read, /* Filepath */{
        _0: "./src/RescriptREPL.res"
      });
  var match = Parser.runParser(ParserCombinators.openModuleSectionP, codeStr);
  if (match !== undefined) {
    var nextCodeStr = match[1]._0 + ("open " + moduleName + "") + match[0];
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

function parseAndHandleCommands(state, s, FO, RB, EvalJS) {
  return new Promise((function (resolve, _reject) {
                var moduleName = parseReplCommand(s);
                if (typeof moduleName === "number") {
                  switch (moduleName) {
                    case /* StartMultiLineMode */0 :
                        return resolve(/* Continue */{
                                    _0: {
                                      multilineMode: {
                                        active: true,
                                        rescriptCodeInput: ""
                                      }
                                    }
                                  });
                    case /* EndMultiLineMode */1 :
                        then(handleEndMultiLineCase(state, FO, RB, EvalJS), (function (updatedState) {
                                resolve(/* Continue */{
                                      _0: updatedState
                                    });
                              }));
                        return ;
                    case /* Reset */2 :
                        Curry._2(FO.write, /* Filepath */{
                              _0: "./src/RescriptREPL.res"
                            }, "");
                        return resolve(/* Continue */{
                                    _0: state
                                  });
                    
                  }
                } else {
                  if (moduleName.TAG === /* RescriptCode */0) {
                    then(handleRescriptCodeCase(state, moduleName._0, FO, RB, EvalJS), (function (nextState) {
                            resolve(/* Continue */{
                                  _0: nextState
                                });
                          }));
                    return ;
                  }
                  then(handleLoadModuleCase(moduleName._0, FO, RB, EvalJS), (function (param) {
                          resolve(/* Continue */{
                                _0: state
                              });
                        }));
                  return ;
                }
              }));
}

exports.build = build;
exports.RescriptBuild = RescriptBuild;
exports.isFilepath = isFilepath;
exports.FileOperations = FileOperations;
exports.eval_js_code = eval_js_code;
exports.EvalJavaScriptCode = EvalJavaScriptCode;
exports.handleContOrClose = handleContOrClose;
exports.start_repl = start_repl;
exports.parseReplCommand = parseReplCommand;
exports.startsOrEndsWithJsLog = startsOrEndsWithJsLog;
exports.then = then;
exports.handleBuildAndEval = handleBuildAndEval;
exports.handleLoadModuleBuildAndEval = handleLoadModuleBuildAndEval;
exports.handleEndMultiLineCase = handleEndMultiLineCase;
exports.handleRescriptCodeCase = handleRescriptCodeCase;
exports.handleLoadModuleCase = handleLoadModuleCase;
exports.parseAndHandleCommands = parseAndHandleCommands;
/* fs Not a pure module */
