--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module is referenced mainly by the Assign Staves to Instruments subtask. It is
    responsible for interpretting and applying actions stored in an XMLArticulation object
    (defined in articulation_xml_lib.lua).

]]

--[[
    TODO:
    - Determine if this class would be better implemented entirely statically.
]]

local artxml = require "Lib.articulation_xml_lib"
local cmath = require "Lib.math_lib"
local preset = require "Lib.preset_browser_lib"

--- @class ArticulationXMLHandler
--- @field private staff integer
local ArticulationXMLHandler = {}
ArticulationXMLHandler.__index = ArticulationXMLHandler

--[[
    Action definitions / Helper methods
]]

--- Adds an articulation to all entries in a staff.
--- @param staff integer
--- @param preset integer
local function apply_articulation_from_preset(staff, preset)
    local max_measures = finale.FCMeasures():LoadAll()
    local nel = finale.FCNoteEntryLayer(0, staff, 1, max_measures)
    nel:Load()
    for entry in each(nel) do
        if entry:IsNote() then
            local articulation = finale.FCArticulation()
            articulation:SetNoteEntry(entry)
            local art_def = finale.FCArticulationDef()
            art_def:Load(preset)
            articulation:SetArticulationDef(art_def)
            articulation:SaveNew()
        end
    end
    nel:Save()
end

--- Applies a notehead mod to all notes in a staff.
--- @param staff integer
--- @param values table Table should contain four elements, either under the labels 'double-whole', 'whole', 'half', and 'quarter', or numbers 1-4.
local function apply_notehead_mod(staff, values)
    local double_whole = values['double-whole'] or values[1]
    double_whole = cmath.HexToDecimal(double_whole)
    local whole = values['whole'] or values[2]
    whole = cmath.HexToDecimal(whole)
    local half = values['half'] or values[3]
    half = cmath.HexToDecimal(half)
    local quarter = values['quarter'] or values[4]
    quarter = cmath.HexToDecimal(quarter)

    local max_measures = finale.FCMeasures():LoadAll()
    local nel = finale.FCNoteEntryLayer(0, staff, 1, max_measures)
    nel:Load()
    local notehead_mod = finale.FCNoteheadMod()
    for entry in each(nel) do
        if entry:IsNote() then
            local entry_duration = entry:GetDuration()
            if entry_duration >= finale.BREVE then notehead_mod.CustomChar = double_whole
            elseif entry_duration >= finale.WHOLE_NOTE then notehead_mod.CustomChar = whole
            elseif entry_duration >= finale.HALF_NOTE then notehead_mod.CustomChar = half
            else notehead_mod.CustomChar = quarter end
            for note in each(entry) do
                notehead_mod:EraseAt(note)
                notehead_mod:SaveAt(note)
            end
        end
    end
    nel:Save()
end

--- Transposes all notes in a staff by a given number of half-steps (values).
--- @param staff integer
--- @param values integer
local function transpose(staff, values)
    local transpose = values
    local max_measures = finale.FCMeasures():LoadAll()
    local nel = finale.FCNoteEntryLayer(0, staff, 1, max_measures)
    nel:Load()
    for entry in each(nel) do
        if entry:IsNote() then
            for note in each(entry) do
                note:SetMIDIKey(note:CalcMIDIKey() + transpose)
            end
        end
    end
    nel:Save()
end

--- Attempts to create an expression at the start of every phrase (before/after measures of rest).
--- @param staff integer
--- @param value integer|table
local function add_expression_to_phrase_starts(staff, value)
    if type(value) == "table" then
        if value['result'] ~= nil then
            value = cmath.GetInteger(value['result']) or 1
        else
            value = preset.FindTextExpressionDef(value['category'], value['text']).ItemNo
        end
    end
    if value == nil then return end
    --Temporary: Add an expression to the start of the first bar containing music (above the first note) and to every start to a bar coming after at least one bar of rest
    --Permanent (later): Test against other staves belonging to the same instrument
    local max_measures = finale.FCMeasures():LoadAll()
    local region = finale.FCMusicRegion()
    region:SetCurrentSelection()
    region:SetStartStaff(staff)
    region:SetEndStaff(staff)
    region:SetStartMeasure(1)
    region:SetEndMeasure(max_measures)
    region:SetStartMeasurePosLeft()
    region:SetEndMeasurePosRight()
    local start_of_phrase = true
    for m,s in eachcell(region) do
        --Determine if the start of a phrase
        local nec = finale.FCNoteEntryCell(m,s)
        nec:Load()

        local function get_cell_note_count()
            local result = 0
            for entry in each(nec) do
                if entry:IsNote() then
                    result = result + 1
                end
            end
            return result
        end

        if get_cell_note_count() > 0 then
            if start_of_phrase then
                --Create expression
                local function find_first_note_pos()
                    local result = 32767
                    for entry in each(nec) do
                        if entry:IsNote() and entry.MeasurePos < result then
                            result = entry.MeasurePos
                        end
                    end
                    return result
                end

                local expression_measure_pos = find_first_note_pos()
                local expression = finale.FCExpression()
                local expression_def = finale.FCTextExpressionDef()
                local cell = finale.FCCell(m, s)
                expression_def:Load(value)
                expression:AssignTextExpressionDef(expression_def)
                expression:SetMeasurePos(expression_measure_pos)
                expression:SaveNewToCell(cell)
                start_of_phrase = false
            end
        else
            start_of_phrase = true
        end
    end
end

--- Constructor method for ArticulationXMLHandler.
--- @return ArticulationXMLHandler
function ArticulationXMLHandler.Create()
    local self = setmetatable({}, ArticulationXMLHandler)
    self.staff = -1
    return self
end

--[[
    Public methods
]]

--- Applies an action to the focused staff.
--- @param action Actions
--- @param value any
function ArticulationXMLHandler:ApplyAction(action, value)
    if not artxml.IsValidAction(action, value) then return end
    if action == 'apply_articulation_from_preset' then
        apply_articulation_from_preset(self.staff, value)
    elseif action == 'notehead_mod' then
        apply_notehead_mod(self.staff, value)
    elseif action == 'transpose' then
        transpose(self.staff, value)
    elseif action == 'add_expression_to_phrase_starts' then
        add_expression_to_phrase_starts(self.staff, value)
    end
end

--- Apply all of an XMLArticulation's actions to the current staff.
--- @param articulation XMLArticulation
function ArticulationXMLHandler:ApplyArticulation(articulation)
    if articulation == nil or self.staff == -1 then return end

    local actions = articulation:GetActions()
    for _,action in ipairs(actions) do
        self.ApplyAction(self, action.key, action.value)
    end
end

--- Set the staff for the ArticulationXMLHandler to focus on.
--- It is necessary to set this parameter in order for the handler to function.
--- @param staff_ID integer
function ArticulationXMLHandler:SetStaff(staff_ID)
    self.staff = staff_ID
end

return ArticulationXMLHandler