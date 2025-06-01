--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module is responsible for carrying out the subtask of numbering staves belonging to the
    same instrument in a customized manner. The numbers appear separate from the instrument name
    to the left of each staff's clef.

]]


--[[
    Algorithm Steps:

    (1) Based on the number of staves selected, launch a GUI with that many rows of checkboxes.
        Each row should be labeled 1-8. (Opt. Additional checkbox labeled "Auxiliary" with an Edit for the name)
        Each row of checkboxes should have a label: Staff 1, Staff 2, etc.
        (Opt. You select the affected measure range at the top of the GUI)
        Disable all other checkboxes in a row if four are checked in that row.
    (2) When OK is pressed, check whether the expression category Instrument Number exists. If not, create the category with its 134 members. (1., 2., 3., 1,2., etc., a2, a3, etc.)
    (3) Hide staff names for the FCSystemStaves contained within the specified measure range (if applicable).
        Create two layers of groups: one for instrument family and one for each staff containing the instrument numbers. Four possible arrangements.

]]

--[[
    Import Modules
]]

local cmath = require "Lib.math_lib"
local midi = require "Lib.midi_engraving_lib"

--- @class PHLabelInstrumentNumbers
local PHLabelInstrumentNumbers = {}
PHLabelInstrumentNumbers.__index = PHLabelInstrumentNumbers

--[[
    Instance Variables
]]

local config = {
    CATEGORY_DEF_NAME = "Instrument Numbers"
}

local top_staff_of_bracket, bottom_staff_of_bracket, staff_span_of_bracket
local first_measure, last_measure
local instrument_full_name = finale.FCString()
local instrument_abrv_name = finale.FCString()
local args = {} --- @type boolean[][] -- 2D array of booleans representing the checkboxes in the GUI.
local all_checkboxes = {} --- @type FCCtrlCheckbox Table of all checkbox controls in the GUI.
local staffIDs = {} --- @type integer[] Array of staff ItemNos selected by the user.

--[[
    Helper Methods
]]

--- Checks whether the first and last measure instance variables span all possible measure numbers.
--- @return boolean
local function are_all_measures_selected()
    if first_measure == 1 and last_measure == 32767 then return true
    else return false end
end

--- Predicts the full name of the instrument based on the selected staves.
--- @return FCString
local function predict_instrument_full_name()
    local first_staff = finale.FCStaff()
    first_staff:Load(staffIDs[1])
    if #staffIDs == 1 then return first_staff:CreateTrimmedFullNameString() end

    local index = 0
    local prediction

    while true do
        index = index + 1
        prediction = first_staff:CreateTrimmedFullNameString()
        prediction:TruncateAt(index)
        if prediction:IsEqualString(first_staff:CreateTrimmedFullNameString()) then break end
        for i=2, #staffIDs do
            local staff = finale.FCStaff()
            staff:Load(staffIDs[i])
            local staff_name = staff:CreateTrimmedFullNameString()
            staff_name:TruncateAt(index)
            if not staff_name:IsEqualString(prediction) then
                prediction:TruncateEnd(1)
                prediction:TrimWhitespace()
                break
            end
        end
    end
    
    if index < 3 then
        return first_staff:CreateTrimmedFullNameString()
    end

    return prediction
end

--- Predicts the abbreviated name of the instrument based on the selected staves.
--- @return FCString
local function predict_instrument_abrv_name()
    local first_staff = finale.FCStaff()
    first_staff:Load(staffIDs[1])
    if #staffIDs == 1 then return first_staff:CreateTrimmedAbbreviatedNameString() end

    local index = 0
    local prediction

    while true do
        index = index + 1
        prediction = first_staff:CreateTrimmedAbbreviatedNameString()
        prediction:TruncateAt(index)
        if prediction:IsEqualString(first_staff:CreateTrimmedAbbreviatedNameString()) then break end
        for i=2, #staffIDs do
            local staff = finale.FCStaff()
            staff:Load(staffIDs[i])
            local staff_name = staff:CreateTrimmedAbbreviatedNameString()
            staff_name:TruncateAt(index)
            if not staff_name:IsEqualString(prediction) then
                prediction:TruncateEnd(1)
                prediction:TrimWhitespace()
                break
            end
        end
    end

    if index < 3 then
        return first_staff:CreateTrimmedAbbreviatedNameString()
    end

    
    return prediction
end

--[[
    GUI
]]

--[[
    Modifying Expression Categories TODO
]]

-- Checks whether the expression category Instrument Number exists.
local function expression_category_exists()
    local expression_category_defs = finale.FCCategoryDefs()
    local str = finale.FCString()
    expression_category_defs:LoadAll()
    for categorydef in each(expression_category_defs) do
        categorydef:GetName(str)
        if str.LuaString == config.CATEGORY_DEF_NAME then
            return true
        end
    end
    return false
end

-- Currently does not work. Hindered by limitations of the Finale PDK.
local function create_expression_category()
    -- Create expression category --
    -- Create 134 expressions to form category --
    local category_defs = finale.FCCategoryDefs()
    category_defs:LoadAll()
    local instrument_numbers_category = finale.FCCategoryDef()
    local technique_text_category = category_defs:FindID(finale.DEFAULTCATID_TECHNIQUETEXT)
    local str = finale.FCString(config.CATEGORY_DEF_NAME)
    local fontinfo = finale.FCFontInfo()

    instrument_numbers_category:SetName(str)
    instrument_numbers_category:SaveNewWithType(finale.DEFAULTCATID_TECHNIQUETEXT)
    technique_text_category:GetTextFontInfo(fontinfo)
    print(instrument_numbers_category:SetTextFontInfo(fontinfo)) --TODO find a way to make this work
    technique_text_category:GetMusicFontInfo(fontinfo)
    print(instrument_numbers_category:SetMusicFontInfo(fontinfo)) --TODO find a way to make this work
    print(instrument_numbers_category:Save())
end

--[[
    Public Methods
]]

--- Handles the creation of the group in the document based on the statically assigned variables. Make sure
--- to run DisplayDialog() before this function. Returns true if successful.
--- @return boolean
function PHLabelInstrumentNumbers.CreateInstrumentNumbers()
    -- (XX) Set variables for measure bounds. If radio button "all measures", then last measure = 32767 --
    -- (0) Delete existing instrument staves --
    -- (1) Rename non-aux staves (if "all measures" is selected) --
    -- (2) Disable auto-numbering (if "all measures" is selected) --
    -- (3) Hide staff names on system staves between measure bounds --
    -- (4) Create group for all staves --
    -- (5) Offset group names depending on max number of instruments per staff --
    -- (6) Create groups for each individual staff --
        -- Design organization for each of the five categories --



    -- Start by ensuring that the instance variables have been assigned.
    if top_staff_of_bracket == nil or bottom_staff_of_bracket == nil
        or staff_span_of_bracket == nil or first_measure == nil
        or last_measure == nil then
            return false
    end

    local staff_instrument_count = {}
    for i=1,#staffIDs do
        local count = 0
        for j=1,9 do
            if args[i][j] then count = count + 1 end
        end
        staff_instrument_count[i] = count
    end

    --(0)--
    local groups = finale.FCGroups()
    local new_group_id = groups:LoadAll() + 1
    for group in eachbackwards(groups) do
        if group:GetStartStaff() >= top_staff_of_bracket and group:GetEndStaff() <= bottom_staff_of_bracket
                and not group:GetShowGroupName() and midi.IsValidInstrument(group) then
            new_group_id = group.ItemID
            group:DeleteData()
        end
    end


    --(1) and (2)--
    if are_all_measures_selected() then
        for staff=1,#staffIDs do
            if args[staff][9] == false then
                local fcstaff = finale.FCStaff()
                fcstaff:Load(staffIDs[staff])

                local temp_full_name = fcstaff:CreateFullNameString():CreateLastFontInfo():CreateEnigmaString(nil)
                local temp_abrv_name = fcstaff:CreateFullNameString():CreateLastFontInfo():CreateEnigmaString(nil)

                temp_full_name:AppendString(instrument_full_name)
                temp_abrv_name:AppendString(instrument_abrv_name)
                if staff_instrument_count[staff] > 0 then
                    temp_full_name:AppendLuaString(" ")
                    temp_abrv_name:AppendLuaString(" ")
                    for i=1,8 do
                        if args[staff][i] then
                            temp_full_name:AppendLuaString(i .. ", ")
                            temp_abrv_name:AppendLuaString(i .. ", ")
                        end
                    end
                    temp_full_name.LuaString = string.sub(temp_full_name.LuaString, 1, #temp_full_name.LuaString-2)
                    temp_abrv_name.LuaString = string.sub(temp_abrv_name.LuaString, 1, #temp_abrv_name.LuaString-2)
                end

                fcstaff:SetUseAutoNumberingStyle(false)
                fcstaff:SetShowScoreStaffNames(false)
                fcstaff:SaveFullNameString(temp_full_name)
                fcstaff:SaveAbbreviatedNameString(temp_abrv_name)
                fcstaff:Save()
            end
        end
    else
        --(3)--
        local hide_name_style_def = finale.FCStaffStyleDef()
        hide_name_style_def:SetUseShowScoreStaffNames(true)
        hide_name_style_def:SetShowScoreStaffNames(false)
        hide_name_style_def:SaveNew()
        local hnsd_style_id = hide_name_style_def:GetItemNo()
        local hide_name_style_assign = finale.FCStaffStyleAssign()
        hide_name_style_assign:SetStartMeasure(cmath.GetInteger(first_measure or 1))
        hide_name_style_assign:SetEndMeasure(cmath.GetInteger(last_measure or 32767))
        hide_name_style_assign:SetStyleID(hnsd_style_id)
        for i=1,#staffIDs do
            hide_name_style_assign:SaveNew(staffIDs[i])
        end
    end

    --(4) and (5)--
    local groups = finale.FCGroups()
    local fullgroup_prefs = finale.FCFontPrefs()
    local abrvgroup_prefs = finale.FCFontPrefs()
    fullgroup_prefs:Load(finale.FONTPREF_GROUPNAME)
    abrvgroup_prefs:Load(finale.FONTPREF_ABRVGROUPNAME)
    local instrument_full_name_display = fullgroup_prefs:CreateFontInfo():CreateEnigmaString(nil)
    local instrument_abrv_name_display = abrvgroup_prefs:CreateFontInfo():CreateEnigmaString(nil)
    instrument_full_name_display:AppendString(instrument_full_name)
    instrument_abrv_name_display:AppendString(instrument_abrv_name)

    local max_staves_per_instrument = 0
    for i=1, #staff_instrument_count do
        if staff_instrument_count[i] > max_staves_per_instrument then
            max_staves_per_instrument = staff_instrument_count[i]
        end
    end

    local instrument_group = finale.FCGroup()
    instrument_group:SetStartStaff(top_staff_of_bracket)
    instrument_group:SetEndStaff(bottom_staff_of_bracket)
    instrument_group:SetStartMeasure(cmath.GetInteger(first_measure or 0))
    instrument_group:SetEndMeasure(cmath.GetInteger(last_measure or 32767))
    instrument_group:SetBracketStyle(finale.GRBRAC_DESK)
    instrument_group:SetBracketHorizontalPos(-24)
    instrument_group:SaveNewFullNameBlock(instrument_full_name_display)
    instrument_group:SaveNewAbbreviatedNameBlock(instrument_abrv_name_display)
    if staff_span_of_bracket % 2 == 1 then
        if max_staves_per_instrument == 4 then
            instrument_group:SetFullNameHorizontalOffset(-141)
            instrument_group:SetAbbreviatedNameHorizontalOffset(-141)
        elseif max_staves_per_instrument > 0 then
            instrument_group:SetFullNameHorizontalOffset(-107)
            instrument_group:SetAbbreviatedNameHorizontalOffset(-107)
        end
    else
        instrument_group:SetFullNameHorizontalOffset(-72)
        instrument_group:SetAbbreviatedNameHorizontalOffset(-72)
    end
    instrument_group:SetFullNameAlign(finale.TEXTHORIZALIGN_RIGHT)
    instrument_group:SetFullNameJustify(finale.TEXTJUSTIFY_RIGHT)
    instrument_group:SetUseFullNamePositioning(true)
    instrument_group:SetAbbreviatedNameAlign(finale.TEXTHORIZALIGN_RIGHT)
    instrument_group:SetAbbreviatedNameJustify(finale.TEXTJUSTIFY_RIGHT)
    instrument_group:SetUseAbbreviatedNamePositioning(true)
    instrument_group:SaveNew(new_group_id) -- Not working...

    --(6)--
    for staff=1,#staffIDs do
        if staff_instrument_count[staff] > 0 and not args[staff][9] then
            local staff_group = finale.FCGroup()
            staff_group:SetStartStaff(staffIDs[staff])
            staff_group:SetEndStaff(staffIDs[staff])
            staff_group:SetStartMeasure(cmath.GetInteger(first_measure or 0))
            staff_group:SetEndMeasure(cmath.GetInteger(last_measure or 32767))

            local staff_group_name = fullgroup_prefs:CreateFontInfo():CreateEnigmaString(nil)

            local function subtract_from_font_size(source, amount)
                local result = finale.FCString()
                local strings = source:CreateEnigmaStrings()
                for str in each(strings) do
                    if str:ContainsLuaString("^size") then
                        local size = ""
                        for i = 1, #str.LuaString do
                            local char = string.sub(str.LuaString, i, i)
                            if char:match("%d") then
                                size = size .. char
                            end
                        end
                        size = size - amount
                        result:AppendLuaString("^size("..size..")")
                    else
                        result:AppendString(str)
                    end
                end
                return result
            end

            if staff_instrument_count[staff] == 1 then
                for i=1,8 do
                    if args[staff][i] then
                        staff_group_name:AppendLuaString(i.."")
                    end
                end
            elseif staff_instrument_count[staff] == 2 then
                local top_number = 0
                local bottom_number = 0
                for i=1,8 do
                    if args[staff][i] then
                        if top_number == 0 then
                            top_number = i
                        else
                            bottom_number = i
                        end
                    end
                end
                staff_group_name:AppendLuaString(top_number.."\r"..bottom_number)
            elseif staff_instrument_count[staff] == 3 then
                staff_group_name = subtract_from_font_size(staff_group_name, 1)

                local first_number = 0
                local second_number = 0
                local third_number = 0
                for i=1,8 do
                    if args[staff][i] then
                        if first_number == 0 then
                            first_number = i
                        elseif second_number == 0 then
                            second_number = i
                        else
                            third_number = i
                        end
                    end
                end
                staff_group_name:AppendLuaString(first_number.."\r"..second_number.."\r"..third_number)
            elseif staff_instrument_count[staff] == 4 then
                staff_group_name = subtract_from_font_size(staff_group_name, 1)

                local first_number = 0
                local second_number = 0
                local third_number = 0
                local fourth_number = 0
                for i=1,8 do
                    if args[staff][i] then
                        if first_number == 0 then
                            first_number = i
                        elseif second_number == 0 then
                            second_number = i
                        elseif third_number == 0 then
                            third_number = i
                        else
                            fourth_number = i
                        end
                    end
                end
                staff_group_name:AppendLuaString(first_number.. "  "..second_number.."\r"..third_number.."  "..fourth_number)
            end
            staff_group:SaveNewFullNameBlock(staff_group_name)
            staff_group:SaveNewAbbreviatedNameBlock(staff_group_name)
            staff_group:SetFullNameAlign(finale.TEXTHORIZALIGN_RIGHT)
            staff_group:SetFullNameJustify(finale.TEXTJUSTIFY_RIGHT)
            staff_group:SetFullNameHorizontalOffset(-49)
            staff_group:SetFullNameVerticalOffset(0)
            staff_group:SetUseFullNamePositioning(true)
            staff_group:SetAbbreviatedNameAlign(finale.TEXTHORIZALIGN_RIGHT)
            staff_group:SetAbbreviatedNameJustify(finale.TEXTJUSTIFY_RIGHT)
            staff_group:SetAbbreviatedNameHorizontalOffset(-49)
            staff_group:SetAbbreviatedNameVerticalOffset(0)
            staff_group:SetUseAbbreviatedNamePositioning(true)
            staff_group:SaveNew(groups:LoadAll() + 1)
        end
    end

    return true
end

--- Launches the main Instrument Group Labeler dialog.
--- Returns 1 if the user presses Ok, 0 if the window is closed.
--- @return integer
function PHLabelInstrumentNumbers.DisplayDialog()
    local region = finenv.Region()

    local start_slot = region:GetStartSlot()
    local end_slot = region:GetEndSlot()

    for i=start_slot,end_slot do
        staffIDs[#staffIDs+1] = region:CalcStaffNumber(i)
    end

    Dialog = finale.FCCustomLuaWindow()

    local str = finale.FCString()

    str.LuaString = "Number Instruments"
    Dialog:SetTitle(str)

    local instrument_name_static = Dialog:CreateStatic(0, 3)
    str.LuaString = "Full Name"
    instrument_name_static:SetText(str)

    local instrument_name_edit = Dialog:CreateEdit(58, 0)
    instrument_name_edit:SetWidth(100)
    str = predict_instrument_full_name()
    instrument_name_edit:SetText(str)

    local abrv_instrument_name_static = Dialog:CreateStatic(0, 28)
    str.LuaString = "Abbreviated Name"
    abrv_instrument_name_static:SetText(str)

    local abrv_instrument_name_edit = Dialog:CreateEdit(98, 25)
    abrv_instrument_name_edit:SetWidth(60)
    str = predict_instrument_abrv_name()
    abrv_instrument_name_edit:SetText(str)

    local measure_selection_radio_group = Dialog:CreateRadioButtonGroup(170, 7, 2)
    measure_selection_radio_group:SetWidth(80)
    str.LuaString = "All Measures"
    measure_selection_radio_group:GetItemAt(0):SetText(str)
    str.LuaString = "Measure:"
    measure_selection_radio_group:GetItemAt(1):SetText(str)

    local measure_selection_first_edit = Dialog:CreateEdit(255, 21)
    measure_selection_first_edit:SetWidth(25)
    str.LuaString = finenv.Region():GetStartMeasure()
    measure_selection_first_edit:SetText(str)
    measure_selection_first_edit:SetEnable(false)

    local measure_selection_through_static = Dialog:CreateStatic(288,24)
    str.LuaString = "Through:"
    measure_selection_through_static:SetText(str)
    measure_selection_through_static:SetEnable(false)

    local measure_selection_last_edit = Dialog:CreateEdit(335,21)
    str.LuaString = finenv.Region():GetEndMeasure()
    measure_selection_last_edit:SetText(str)
    measure_selection_last_edit:SetWidth(25)
    measure_selection_last_edit:SetEnable(false)

    Dialog:CreateHorizontalLine(0, 58, 380)

    local group_auxiliaries_checkbox = Dialog:CreateCheckbox(0, 105+#staffIDs*24)
    str.LuaString = "Group Auxiliaries"
    group_auxiliaries_checkbox:SetText(str)
    group_auxiliaries_checkbox:SetEnable(false)


    for row=0, #staffIDs-1 do
        local row_static = Dialog:CreateStatic(0,75+(24*row))
        str.LuaString = "Staff ".. (row+1)
        row_static:SetText(str)
        row_static:SetWidth(58)

        local row_numbered_checkboxes = {
            Dialog:CreateCheckbox(58,75+(24*row)),
            Dialog:CreateCheckbox(88,75+(24*row)),
            Dialog:CreateCheckbox(118,75+(24*row)),
            Dialog:CreateCheckbox(148,75+(24*row)),
            Dialog:CreateCheckbox(178,75+(24*row)),
            Dialog:CreateCheckbox(208,75+(24*row)),
            Dialog:CreateCheckbox(238,75+(24*row)),
            Dialog:CreateCheckbox(268,75+(24*row))
        }
        local aux_row_checkbox = Dialog:CreateCheckbox(298,75+(24*row))

        for cb=1,#row_numbered_checkboxes do
            row_numbered_checkboxes[cb]:SetWidth(30)
            all_checkboxes[#all_checkboxes+1] = row_numbered_checkboxes[cb]
        end
        aux_row_checkbox:SetWidth(50)
        all_checkboxes[#all_checkboxes+1] = aux_row_checkbox

        str.LuaString = "1"
        row_numbered_checkboxes[1]:SetText(str)
        str.LuaString = "2"
        row_numbered_checkboxes[2]:SetText(str)
        str.LuaString = "3"
        row_numbered_checkboxes[3]:SetText(str)
        str.LuaString = "4"
        row_numbered_checkboxes[4]:SetText(str)
        str.LuaString = "5"
        row_numbered_checkboxes[5]:SetText(str)
        str.LuaString = "6"
        row_numbered_checkboxes[6]:SetText(str)
        str.LuaString = "7"
        row_numbered_checkboxes[7]:SetText(str)
        str.LuaString = "8"
        row_numbered_checkboxes[8]:SetText(str)
        str.LuaString = "Aux"
        aux_row_checkbox:SetText(str)

        local function check_reenable(global_cb_id)
            --(1)--
            local cb_row = math.ceil(global_cb_id/9) - 1
            if all_checkboxes[(cb_row*9)+9]:GetCheck() == 1 then return false end

            --(2)--
            local checked_count = 0
            for cb=cb_row*9+1,(cb_row+1)*9-1 do
                if all_checkboxes[cb]:GetCheck() == 1 then
                    checked_count = checked_count + 1
                end
            end

            if checked_count >= 4 then return false end

            --(3)--
            for cb=global_cb_id%9,#all_checkboxes,9 do
                if all_checkboxes[cb]:GetCheck() == 1 then
                    return false
                end
            end

            return true
        end

        for cb=1,#row_numbered_checkboxes do
            Dialog:RegisterHandleControlEvent(row_numbered_checkboxes[cb],
                function(control)
                    -- CHECK : (1) Disable Aux, (2) Maximum 4 in row, (3) Disable other rows --
                    if control:GetCheck() == 1 then
                        --(1)-- GOOD
                        if aux_row_checkbox:GetEnable() then
                            aux_row_checkbox:SetCheck(0)
                            aux_row_checkbox:SetEnable(false)
                        end

                        --(2)--
                        local checked_count = 0
                        for cb2=1,#row_numbered_checkboxes do
                            if row_numbered_checkboxes[cb2]:GetCheck() == 1 then
                                checked_count = checked_count + 1
                            end
                        end

                        if checked_count >= 4 then
                            for cb2=1,#row_numbered_checkboxes do
                                if row_numbered_checkboxes[cb2]:GetCheck() == 0 then
                                    row_numbered_checkboxes[cb2]:SetEnable(false)
                                end
                            end
                        end

                        --(3)--
                        for cb2=cb,#all_checkboxes,9 do
                            if all_checkboxes[cb2]:GetCheck() == 0 then
                                all_checkboxes[cb2]:SetEnable(false)
                            end
                        end

                    -- UNCHECK : (1) Re-enable Aux, (2) Re-enable if <4, (3) Re-enable other rows --
                    else
                        --(1)-- GOOD
                        local reenable_aux = true
                        for cb2=1,#row_numbered_checkboxes do
                            if row_numbered_checkboxes[cb2]:GetCheck() == 1 then reenable_aux = false end
                        end
                        if reenable_aux then aux_row_checkbox:SetEnable(true) end

                        for cb2=row*9+1,(row+1)*9-1 do
                            if check_reenable(cb2) then
                                all_checkboxes[cb2]:SetEnable(true)
                            end
                        end

                        for cb2=cb,#all_checkboxes,9 do
                            if check_reenable(cb2) then
                                all_checkboxes[cb2]:SetEnable(true)
                            end
                        end
                    end
                end
            )
        end

        Dialog:RegisterHandleControlEvent(aux_row_checkbox,
            function()
                if aux_row_checkbox:GetCheck() == 1 then
                    for cb=1,#row_numbered_checkboxes do
                        row_numbered_checkboxes[cb]:SetCheck(0)
                        row_numbered_checkboxes[cb]:SetEnable(false)
                    end

                    local staff = finale.FCStaff()
                    staff:Load(staffIDs[row+1])
                    str = staff:CreateDisplayFullNameString()
                    row_static:SetText(str)

                    group_auxiliaries_checkbox:SetEnable(true)
                else
                    for cb=row*9+1,(row+1)*9-1 do
                        if check_reenable(cb) then
                            all_checkboxes[cb]:SetEnable(true)
                        end
                    end

                    str.LuaString = "Staff ".. (row+1)
                    row_static:SetText(str)

                    local disable_group_auxiliaries_checkbox = true
                    for cb=9,#all_checkboxes,9 do
                        if all_checkboxes[cb]:GetCheck() == 1 then disable_group_auxiliaries_checkbox = false end
                    end
                    if disable_group_auxiliaries_checkbox then
                        group_auxiliaries_checkbox:SetCheck(0)
                        group_auxiliaries_checkbox:SetEnable(false)
                    end
                end
            end
    )
    end

    Dialog:RegisterHandleControlEvent(measure_selection_radio_group:GetItemAt(0),
        function()
            measure_selection_first_edit:SetEnable(false)
            measure_selection_through_static:SetEnable(false)
            measure_selection_last_edit:SetEnable(false)
        end
    )

    Dialog:RegisterHandleControlEvent(measure_selection_radio_group:GetItemAt(1),
        function()
            measure_selection_first_edit:SetEnable(true)
            measure_selection_through_static:SetEnable(true)
            measure_selection_last_edit:SetEnable(true)
        end
    )

    Dialog:CreateOkButton()
    Dialog:CreateCancelButton()

    -- Transfers information decided by main GUI to instance variables in order to be accessible by
    -- create_groups().
    local function export_args()
        instrument_name_edit:GetText(instrument_full_name)
        abrv_instrument_name_edit:GetText(instrument_abrv_name)

        for staff=1,#all_checkboxes/9 do
            args[staff] = {}
            for cb=1,9 do
                args[staff][cb] = (all_checkboxes[(staff-1)*9+cb]:GetCheck() == 1)
            end
        end

        if group_auxiliaries_checkbox:GetCheck() == 1 then
            top_staff_of_bracket = staffIDs[1]
            bottom_staff_of_bracket = staffIDs[#staffIDs]
            staff_span_of_bracket = bottom_staff_of_bracket - top_staff_of_bracket + 1
        else
            local staff = 1
            while top_staff_of_bracket == nil and (staff <= #staffIDs) do
                if not args[staff][9] then
                    top_staff_of_bracket = staffIDs[staff]
                end
                staff = staff + 1
            end
            staff_span_of_bracket = staff - 1
            staff = #staffIDs
            while bottom_staff_of_bracket == nil and (staff >= 1) do
                if not args[staff][9] then
                    bottom_staff_of_bracket = staffIDs[staff]
                end
                staff = staff - 1
            end
            staff_span_of_bracket = (staff + 1) - (staff_span_of_bracket - 1)
        end
    end

    if Dialog:ExecuteModal(nil) == 1 then
        if measure_selection_radio_group:GetSelectedItem() == 1 then
            measure_selection_first_edit:GetText(str)
            first_measure = str.LuaString
            measure_selection_last_edit:GetText(str)
            last_measure = str.LuaString
            if cmath.IsInteger(first_measure) and cmath.IsInteger(last_measure) and last_measure >= first_measure then
                export_args()
                return 1
            else
                finenv.UI():AlertError("Invalid Arguments for Measure Range.", "Number Measures")
                return 0
            end
        else
            first_measure = 1
            last_measure = 32767
            export_args()
            return 1
        end
    else return 0 end
end

return PHLabelInstrumentNumbers