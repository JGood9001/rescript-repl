#! /usr/bin/env node
// const { exec } = require("child_process");
const { repl } = require("../src/Repl.bs.js")

// NOTE:
// Any changes in this file won't be reflected the next time you run:
// $ resrepl
// Unless you first run:
// $ npm install -g . 

repl()

// // > eval("console.log('hello world')")
// // hello world
// // undefined

// // 1. Read input from user
// // 2. Save input to a string (saving the previous
// //    version in case and error occurs when running the javascript
// //    and we need to rollback), which will then be written to a file.
// //      - I'll just save the rescript typed in by the user to a RescriptRepl.res
// //        file, and then be sure to delete RescriptRepl.res and RescriptRepl.bs.js
// //        once they exit the repl.
// exec("npm run res:build", (error, stdout, stderr) => {
//     if (error) {
//         console.log(`error: ${error.message}`);
//         return;
//     }
//     if (stderr) {
//         console.log(`stderr: ${stderr}`);
//         return;
//     }
//     console.log(`stdout: ${stdout}`);
// });

// // This solution has a nice way, which should allow me to perform the cleanup on exit:
// // https://stackoverflow.com/a/68504470
// const readline = require('readline');

// const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
// const prompt = (query) => new Promise((resolve) => rl.question(query, resolve));

// // Usage inside aync function do not need closure demo only*
// (async() => {
//   try {
//     // GOT MY LAMBDA UNICODE PROMPT!
//     const name = await prompt("\u03BB> ");
//     // Can use name for next question if needed
//     const lastName = await prompt(`Hello ${name}, what's your last name?: `);
//     // Can prompt multiple times
//     console.log(name, lastName);
//     rl.close();
//   } catch (e) {
//     console.error("Unable to prompt", e);
//   }
// })();

// // When done reading prompt, exit program 
// rl.on('close', () => {
//     console.log("CLEANUP HERE")
//     process.exit(0)
// });

// // ^^ All right, this is the general idea.