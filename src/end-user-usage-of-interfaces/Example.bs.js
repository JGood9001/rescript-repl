// Generated by ReScript, PLEASE EDIT WITH CARE
'use strict';

var Fs = require("fs");
var Curry = require("rescript/lib/js/curry.js");
var NewRepl = require("../new-repl-impl/NewRepl.bs.js");
var Process = require("process");
var Readline = require("readline");

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

function handleUserInput(s) {
  return new Promise((function (resolve, _reject) {
                resolve(/* Close */1);
              }));
}

function cleanup(param) {
  Fs.unlinkSync("./src/RescriptRepl.res");
  Fs.unlinkSync("./src/RescriptRepl.bs.js");
}

var DomainLogicAlg = {
  handleUserInput: handleUserInput,
  cleanup: cleanup
};

function run_repl(param) {
  NewRepl.repl(CommandLineIOAlg, DomainLogicAlg);
}

exports.CommandLineIOAlg = CommandLineIOAlg;
exports.DomainLogicAlg = DomainLogicAlg;
exports.run_repl = run_repl;
/* fs Not a pure module */
