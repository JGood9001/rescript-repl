# ReScript Repl

Run a REPL to execute ReScript code in interactive mode

## Installation

```sh
npm install rescript-repl -g
```

Then add rescript-repl to bsconfig.json:
```sh
"bs-dependencies": [
   "rescript-repl"
]
```

## Getting Started

- Start the REPL, run this command within the top level directory of a ReScript project: `$ resrepl`

# Supported REPL Commands
- ':load ModuleName'
- ':{' To start MultiLine Mode
- '}:' To end MultiLine Mode
- ':reset' To clear ReScript code saved in the current REPL context
- Enter any arbitrary string of characters which will be interpreted as ReScript code
