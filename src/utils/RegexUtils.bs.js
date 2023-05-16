const f = (s) => {
    // const re = /(^open(\x20*)[^A-Z][A-Za-z0-9]*\n)/g;
    const re = /(^open(\x20*)[^A-Z][A-Za-z0-9]*)/g;
    let matches = [];
    let remainingStr = s // f("open ModuleName\nopen Test\nlet x = 100")

    while (re.test(remainingStr)) {
        // console.log(`Found end=${re.lastIndex}.`);
        matches.push(remainingStr.slice(0, re.lastIndex))
        remainingStr = remainingStr.split("").splice(re.lastIndex, s.length-1).join("").trim()
        re.test(remainingStr) // if this is commented out... it causes the result to be erroneous
    }

    return {  openModulesSection: matches.join("\n"), remainingStr }
}

const g = (s) => {
    const re = /(open(\x20*)[^A-Z][A-Za-z0-9]*\n)/g;
    let matches = [];
    let remainingStr = s // f("open ModuleName\nopen Test\nlet x = 100")

    while (re.test(remainingStr)) {
        // console.log(`Found end=${re.lastIndex}.`);
        matches.push(remainingStr.slice(0, re.lastIndex))
        remainingStr = remainingStr.split("").splice(re.lastIndex, s.length-1).join("").trim()
        // re.test(remainingStr) // if this is commented out... it causes the result to be erroneous
    }

    return { openModulesSection: matches.join(""), remainingStr }
}

// > f("open ModuleName\nopen Test\nlet x = 100")
// {
//   openModuleSection: 'open ModuleName\nopen Test\n'
//   remainingStr: 'let x = 100'
// }

// Erroneous
// > g("open ModuleName\nopen Test\nlet x = 100")
// {
//   openModuleSection: 'open ModuleName\n'
//   remainingStr: 'open Test\nlet x = 100'
// }
  


// input: 
// "open ModuleName\nopen Test\nlet x = 100"
// output:
// {
//     matches: [ 'open ModuleName\n', 'open Test\n' ],
//     remainingStr: 'let x = 100'
// }
// ^^ Well this is the desired output...
const separateOpenModulesFromRemainingCode = f
  
// separateOpenModulesFromRemainingCode("open ModuleName\nopen Test\nlet x = 100")

exports.separateOpenModulesFromRemainingCode = separateOpenModulesFromRemainingCode