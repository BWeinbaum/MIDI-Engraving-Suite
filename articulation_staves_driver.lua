function plugindef()
    --finaleplugin.HandlesUndo = true -- suppresses automatic Undo handling
    finaleplugin.RequireScore = true
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3" -- API CHANGE.MAJOR ADDITION.MINOR ADDITION-PUBLICITY.MINOR ADJUSTMENT
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    finaleplugin.CategoryTags = "Staff, UI"
    return "Assign Staves to Instruments", "Assign Staves", "Allows user to combine articulation staves meant to belong to the same instrument."
end

--[[
    Import Modules
]]

local PHAssignStaves = require "Lib.assign_articulation_staves"

-- EXECUTION STARTS HERE --

PHAssignStaves.Initialize()

if PHAssignStaves.DisplayDialog() == 1 then
    PHAssignStaves.OrganizeScore()
end