function plugindef()
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3"
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    finaleplugin.RequireSelection = true
    return "Combine Staves", "Combine Staves", "Combine the notes of two or more staves based on measure or phrase."
end

--[[
    Import Modules
]]

local PHCombineStaves = require "Lib.combine_articulation_staves"

-- EXECUTION STARTS HERE --
PHCombineStaves.DisplayDialog()