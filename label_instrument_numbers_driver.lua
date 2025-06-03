-- Plugin definition function recognized by RGP Lua. Displays in the Finale plugin menu.
function plugindef()
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3" -- API CHANGE.MAJOR ADDITION.MINOR ADDITION-PUBLICITY.MINOR ADJUSTMENT
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    finaleplugin.RequireSelection = true
    -- Menu name, undo name, and description.
    return "Label Instrument Numbers", "Instrument Numbers", "Change staff names to include instrument numbers."
end

local label_instrument_numbers = require "Lib.label_instrument_numbers"

 if label_instrument_numbers.DisplayDialog() == 1 then
    label_instrument_numbers.CreateInstrumentNumbers()
end