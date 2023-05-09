// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Fs = require("fs");
var Curry = require("rescript/lib/js/curry.js");
var NewRepl = require("./new-repl-impl/NewRepl.bs.js");
var Process = require("process");
var Readline = require("readline");
var REPLLogic = require("./repl-logic/REPLLogic.bs.js");

function make(param) {
  return /* CommandLineIO */{
          _0: Readline.createInterface({
                input: Process.stdin,
                output: Process.stdout
              })
        };
}

function prompt(rl, query, cb) {
  var rl$1 = rl._0;
  return new Promise((function (resolve, _reject) {
                  rl$1.question(query, (function (x) {
                          resolve(x);
                        }));
                })).then(Curry.__1(cb));
}

function on(rl, $$event, cb) {
  return /* CommandLineIO */{
          _0: rl._0.on($$event, cb)
        };
}

function close(rl) {
  rl._0.close();
}

var CommandLineIOAlg = {
  make: make,
  prompt: prompt,
  on: on,
  close: close
};

function make$1(param) {
  return {
          multiline_mode: {
            active: false,
            rescipe_code_input: undefined
          },
          prev_file_contents_state: undefined
        };
}

function start_repl(prompt, close) {
  return REPLLogic.start_repl(make$1, prompt, close);
}

function handleUserInput(state, s) {
  return REPLLogic.parseAndHandleCommands(state, s, {
              read: REPLLogic.FileOperations.read,
              write: REPLLogic.FileOperations.write
            }, REPLLogic.RescriptBuild, REPLLogic.EvalJavaScriptCode);
}

function cleanup(param) {
  try {
    Fs.unlinkSync("./src/RescriptRepl.res");
    Fs.unlinkSync("./src/RescriptRepl.bs.js");
    return ;
  }
  catch (exn){
    return ;
  }
}

var DomainLogicAlg = {
  make: make$1,
  start_repl: start_repl,
  handleUserInput: handleUserInput,
  cleanup: cleanup
};

function run_repl(param) {
  return NewRepl.repl(CommandLineIOAlg, {
              make: make$1,
              handleUserInput: handleUserInput,
              start_repl: start_repl,
              cleanup: cleanup
            });
}

exports.CommandLineIOAlg = CommandLineIOAlg;
exports.DomainLogicAlg = DomainLogicAlg;
exports.run_repl = run_repl;
/* fs Not a pure module */
