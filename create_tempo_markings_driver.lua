-- Plugin definition function recognized by RGP Lua. Displays in the Finale plugin menu.
function plugindef()
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3" -- API CHANGE.MAJOR ADDITION.MINOR ADDITION-PUBLICITY.MINOR ADJUSTMENT
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    -- Menu name, undo name, and description.
    return "Create Tempo Markings", "Create Tempo Markings", "Attempts to create tempo markings from MIDI data stored in the document."
end

local create_tempo_markings = require "Lib.create_tempo_markings"

local tempo_elements = create_tempo_markings.CreateTempoElements()
create_tempo_markings.CreateTempoMarkings(tempo_elements)