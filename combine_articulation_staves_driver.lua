-- Plugin definition function recognized by RGP Lua. Displays in the Finale plugin menu.
function plugindef()
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3" -- API CHANGE.MAJOR ADDITION.MINOR ADDITION-PUBLICITY.MINOR ADJUSTMENT
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    finaleplugin.RequireSelection = true
    -- Menu name, undo name, and description.
    return "Combine Staves", "Combine Staves", "Combine the notes of two or more staves based on measure or phrase."
end

local PHCombineStaves = require "Lib.combine_articulation_staves"

PHCombineStaves.DisplayDialog()