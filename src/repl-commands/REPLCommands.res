type moduleName = string
type replCommand = RescriptCode(string) | StartMultiLineMode | EndMultiLineMode | LoadModule(moduleName)
