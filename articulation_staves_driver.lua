-- Plugin definition function recognized by RGP Lua. Displays in the Finale plugin menu.
function plugindef()
    finaleplugin.RequireScore = true
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3" -- API CHANGE.MAJOR ADDITION.MINOR ADDITION-PUBLICITY.MINOR ADJUSTMENT
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    finaleplugin.CategoryTags = "Staff, UI"
    -- Menu name, undo name, and description.
    return "Assign Staves to Instruments", "Assign Staves", "Allows user to combine articulation staves meant to belong to the same instrument."
end

local PHAssignStaves = require "Lib.assign_articulation_staves"

PHAssignStaves.Initialize()

if PHAssignStaves.DisplayDialog() == 1 then
    PHAssignStaves.OrganizeScore()
end