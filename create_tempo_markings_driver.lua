function plugindef()
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3"
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    return "Create Tempo Markings", "Create Tempo Markings", "Attempts to create tempo markings from MIDI data stored in the document."
end

--[[
    Import Modules
]]

local create_tempo_markings = require "Lib.create_tempo_markings"

-- EXECUTION BEGINS HERE --
local tempo_elements = create_tempo_markings.CreateTempoElements()
create_tempo_markings.CreateTempoMarkings(tempo_elements)