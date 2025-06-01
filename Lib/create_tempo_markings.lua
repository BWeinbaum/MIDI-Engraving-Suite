--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module is responsible for carrying out the subtask of creating tempo markings in the
    industry standard format for media scoring from tempo data generated from score's source
    MIDI file.

]]

--[[
    Import Modules
]]

local preset = require "Lib.preset_browser_lib"
local midi = require "Lib.midi_engraving_lib"

--[[
    Constants
]]

--- Enum for the visual format of a tempo expression.
--- @enum TEMPO_EXPRESSION_VISUAL
TEMPO_EXPRESSION_VISUAL = {
    DEFAULT = 0,
    MINIMAL = 1,
    MAXIMAL = 2
}


--- @class PHCreateTempoMarkings
local PHCreateTempoMarkings = {}
PHCreateTempoMarkings.__index = PHCreateTempoMarkings

--[[
    Instance Variables
]]

local config = {
    -- The minimum difference in tempo between two tempo elements to warrant a new tempo expression.
    tempo_difference_threshold = 0.5,
    -- The minimum difference in tempi to warrant maximizing the expression.
    tempo_maximize_threshold = 6
}

--[[
    Helper Methods
]]

--- Helper function for determining the visual formatting of a new tempo indication based on the
--- difference between the new tempo and the old tempo. The first tempo in the score will use DEFAULT,
--- while all subsequent tempi will use MINIMAL or MAXIMAL based on the difference. The threshold for
--- difference can be set in the config table.
--- @param old_tempo integer?
--- @param new_tempo integer
--- @return integer
local function calc_tempo_expression_visual_type(old_tempo, new_tempo)
    if old_tempo == nil then return TEMPO_EXPRESSION_VISUAL.DEFAULT end
    if math.abs(new_tempo - old_tempo) > config.tempo_maximize_threshold then
        return TEMPO_EXPRESSION_VISUAL.MAXIMAL
    else
        return TEMPO_EXPRESSION_VISUAL.MINIMAL
    end
end

--- Creates a tempo expression in the score.
--- @param tempo integer
--- @param prev_tempo integer?
--- @param measure integer
--- @param measure_pos integer
--- @param visual_type TEMPO_EXPRESSION_VISUAL
local function create_tempo_expression(tempo, prev_tempo, measure, measure_pos, visual_type)

    local tempo_category, music_font, number_font = finale.FCCategoryDef(), finale.FCFontInfo(), finale.FCFontInfo()
    tempo_category:Load(finale.DEFAULTCATID_TEMPOMARKS)
    tempo_category:GetMusicFontInfo(music_font)
    tempo_category:GetNumberFontInfo(number_font)
    local music_font_string = music_font:CreateEnigmaString()
    local number_font_string = number_font:CreateEnigmaString()

    -- To make the expression appear where it should on the staff list.
    -- Hopefully a temporary solution, as it results in multiple expressions being made.
    local staff_list = finale.FCStaffList()
    staff_list:SetMode(finale.SLMODE_CATEGORY_SCORE)
    staff_list:Load(1)
    local staves = finale.FCStaves()
    local destinations = {}
    midi.LoadStaves(staves)
    for staff in each(staves) do
        if staff_list:IncludesStaff(staff.ItemNo) then
            destinations[#destinations+1] = staff.ItemNo
        end
    end
    if staff_list:IncludesTopStaff() then
        destinations[#destinations+1] = staves:GetItemAt(0).ItemNo
    end
    if staff_list:IncludesBottomStaff() then
        destinations[#destinations+1] = staves:GetItemAt(staves:GetCount() - 1).ItemNo
    end


    local tempo_string
    if visual_type == TEMPO_EXPRESSION_VISUAL.DEFAULT then
        -- Default: music-font, , number-font, " = ", math.tostring(math.tointeger(tempo))
        tempo_string = music_font_string
        tempo_string:AppendLuaString("^baseline(5)^baseline(0)")
        tempo_string:AppendString(number_font_string)
        tempo_string:AppendLuaString(" = " .. tostring(math.tointeger(tempo)))
        
    elseif visual_type == TEMPO_EXPRESSION_VISUAL.MINIMAL then
        -- Minimal: number-font, +/- difference
        tempo_string = number_font_string
        if tempo > prev_tempo then
            tempo_string:AppendLuaString("+" .. tostring(math.tointeger(tempo) - math.tointeger(prev_tempo)))
        else
            tempo_string:AppendLuaString("-" .. tostring(math.tointeger(prev_tempo) - math.tointeger(tempo)))
        end
    elseif visual_type == TEMPO_EXPRESSION_VISUAL.MAXIMAL then
        -- Maximal: music-font, , number-font, " = ", math.tostring(math.tointeger(tempo)), "(+/-", difference, ")"
        tempo_string = music_font_string
        tempo_string:AppendLuaString("^baseline(5)^baseline(0)")
        tempo_string:AppendString(number_font_string)
        tempo_string:AppendLuaString(" = " .. tostring(math.tointeger(tempo)) .. " (")
        if tempo > prev_tempo then
            tempo_string:AppendLuaString("+" .. tostring(math.tointeger(tempo) - math.tointeger(prev_tempo)))
        else
            tempo_string:AppendLuaString("-" .. tostring(math.tointeger(prev_tempo) - math.tointeger(tempo)))
        end
        tempo_string:AppendLuaString(")")
    end

    -- Create expression
    local text_string = finale.FCString(tempo_string.LuaString)
    local tempo_def = preset.FindTextExpressionDef(finale.DEFAULTCATID_TEMPOMARKS, text_string, false)
    if tempo_def == nil then
        -- Create new expression def
        tempo_def = finale.FCTextExpressionDef()
        tempo_def:AssignToCategory(tempo_category)
        tempo_def:SaveNewTextBlock(tempo_string)
        tempo_def:SaveNew()
    end
    local expression = finale.FCExpression()
    expression:AssignTextExpressionDef(tempo_def)
    expression:SetMeasurePos(measure_pos)
    expression:SetStaffListID(1)
    for i=1, #destinations do
        -- TODO: Change to just one expression. Not the best solution in the world...
        local cell = finale.FCCell(measure, destinations[i])
        expression:SaveNewToCell(cell)
    end
end

--[[
    Public Methods
]]

--- Returns a table of {measure_no, FCTempoElement} pairs for all tempo elements in the document.
--- @return table<integer, FCTempoElement>
function PHCreateTempoMarkings.CreateTempoElements()
    local result = {}

    local measures = finale.FCMeasures()
    measures:LoadAll()
    for m in each(measures) do
        local tempo_elements = m:CreateTempoElements()
        for te in each(tempo_elements) do
            result[#result+1] = {
                measure = m.ItemNo,
                tempo_info = te
            }
        end
    end

    return result
end

--- Creates tempo expressions from the given table of {measure_no, FCTempoElement} pairs.
--- @param tempo_table table<integer, FCTempoElement>
function PHCreateTempoMarkings.CreateTempoMarkings(tempo_table)
    local last_displayed_tempo_exact, last_displayed_tempo_int, last_measure

    for _, element in ipairs(tempo_table) do
        local tempo_exact = element.tempo_info:CalcValue()
        local tempo_int = math.tointeger(tempo_exact)

        if last_displayed_tempo_exact == nil or last_displayed_tempo_int == nil or last_measure == nil
            or ((math.abs(tempo_exact - last_displayed_tempo_exact) > config.tempo_difference_threshold and tempo_int ~= last_displayed_tempo_int)
            and (last_measure ~= element.measure)) then
                create_tempo_expression(tempo_exact, last_displayed_tempo_exact, element.measure, element.tempo_info.MeasurePos, calc_tempo_expression_visual_type(last_displayed_tempo_exact, tempo_exact))
                last_displayed_tempo_exact = tempo_exact
                last_displayed_tempo_int = tempo_int
                last_measure = element.measure
        end
    end
end

return PHCreateTempoMarkings