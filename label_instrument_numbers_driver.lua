function plugindef()
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3"
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    finaleplugin.RequireSelection = true
    return "Label Instrument Numbers", "Instrument Numbers", "Change staff names to include instrument numbers."
end

--[[
    Import Modules    
]]

local label_instrument_numbers = require "Lib.label_instrument_numbers"


 -- EXECUTION BEGINS HERE --
 if label_instrument_numbers.DisplayDialog() == 1 then
    label_instrument_numbers.CreateInstrumentNumbers()
end