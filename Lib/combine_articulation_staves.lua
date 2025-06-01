--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module is responsible for carrying out the subtask of combining the articulation staves
    ordered by the Assign Staves to Instruments subtask into a single instrument staff.

]]

-- TODO: Take all of the modules and turn them into classes. That way, they can be initialized from a central source plugin.
-- Also create driver plug-ins that can be called from the menu. They should basically contain everything below ---EXECUTION BEGINS HERE--

--[[
    Import Modules
]]

local cmath = require "Lib.math_lib"
local midi = require "Lib.midi_engraving_lib"

--[[
    Constants
]]

--- Global constants for determining the behavior of detect_next_iteration_region.
--- @enum REGION_DETECTION_TYPES
local REGION_DETECTION_TYPES = {
    BY_MEASURE = 0,
    AUTO_DETECT_PHRASE = 1
}

--- Global constants for accessing the Combine Staves dialog controls.
--- @enum WIDGETS
local WIDGETS = {
    MEASURE_SELECTION_FIRST_STATIC = 1,
    MEASURE_SELECTION_FIRST_EDIT = 2,
    MEASURE_SELECTION_THROUGH_STATIC = 3,
    MEASURE_SELECTION_LAST_EDIT = 4,
    MEASURE_SELECTION_RADIO_GROUP = 5,
    UPDATE_SELECTION_BUTTON = 6,
    MINIMIZE_WINDOW_BUTTON = 7,
    COMBINE = 8,
    SELECT_TARGET_LAYER_STATIC = 9,
    CLEAR_LAYERS_CHECKBOX = 10,
    AUTOMATIC_TRANSFER_CHECKBOX = 11,
    MINIMIZE_AFTER_COMPLETION_CHECKBOX = 12,
    MODIFY_STAFF_ARTICULATION_ASSIGNMENTS = 13,
    ROWS_START = 20
}

--- @class PHCombineStaves
local PHCombineStaves = {}
PHCombineStaves.__index = PHCombineStaves

--[[
    Instance Variables
]]

--- @type integer[]
--- A table of FCStaff ItemNos. Representative of the staves being combined.
local staffIDs = {}

-- A global table of controls in the Combine Staves dialog. Accessible via index using the constants from WIDGETS.
local widget_list = {}

--- @type boolean[]
--- A short-term memory table for restoring checkbox states after a row is disabled and re-enabled.
local check_memory = {}

-- Determines if the user should be alerted about multiple layers in the region. Will only alert once.
local ALERT_MULTIPLE_LAYERS = true

--[[
    Helper Methods
]]

--- Returns the index for accessing a control from the Combine Staves dialog from widget_list.
--- Parameters column and row are both 1-based.
--- @param column integer
--- @param row integer
--- @return integer
local function calc_row_widget_ID(column, row)
    return WIDGETS.ROWS_START + (column - 1) + (row - 1) * 7
end

--- Returns the row number index of the destination staff from staffIDs.
--- @return integer
local function calc_destination_staff_index()
    for i = calc_row_widget_ID(2, 1), calc_row_widget_ID(2, #staffIDs), 7 do
        if widget_list[i]:GetCheck() == 1 then
            return (i + 6 - WIDGETS.ROWS_START) / 7
        end
    end

    return 0
end

--- Returns the integer value of the text in the MEASURE_SELECTION_FIRST_EDIT control.
--- Returns nil if the text is not a valid integer.
--- @return integer?
local function get_measure_selection_start_from_edit()
    local measure_selection_first_edit = widget_list[WIDGETS.MEASURE_SELECTION_FIRST_EDIT]
    if measure_selection_first_edit == nil then return end
    local output = finale.FCString()
    measure_selection_first_edit:GetText(output)
    output = cmath.GetInteger(output.LuaString)

    if output ~= nil and output > 0 then return output end
end

--- Returns the integer value of the text in the MEASURE_SELECTION_LAST_EDIT control.
--- Returns nil if the text is not a valid integer.
--- @return integer?
function get_measure_selection_end_from_edit()
    local measure_selection_last_edit = widget_list[WIDGETS.MEASURE_SELECTION_LAST_EDIT]
    if measure_selection_last_edit == nil then return end
    local output = finale.FCString()
    measure_selection_last_edit:GetText(output)
    output = cmath.GetInteger(output.LuaString)

    if output ~= nil and output > 0 then return output end
end

--- Changes the text in the MEASURE_SELECTION_FIRST_EDIT and MEASURE_SELECTION_LAST_EDIT controls to the provided values.
--- @param start_measure integer|string
--- @param end_measure integer|string
local function update_measure_selection_edits(start_measure, end_measure)
    local measure_selection_first_edit = widget_list[WIDGETS.MEASURE_SELECTION_FIRST_EDIT]
    local measure_selection_last_edit = widget_list[WIDGETS.MEASURE_SELECTION_LAST_EDIT]
    local str = finale.FCString()
    str.LuaString = start_measure..""
    measure_selection_first_edit:SetText(str)
    str.LuaString = end_measure..""
    measure_selection_last_edit:SetText(str)
end

--- Displays music region in the document based on the provided parameters.
--- If start_staff and/or end_staff are not defined, the function will default to the first and last staves in staffIDs.
--- If start_measure and/or end_measure are not defined, the function will default to the values in the MEASURE_SELECTION_FIRST_EDIT and MEASURE_SELECTION_LAST_EDIT controls.
--- @param start_staff integer?
--- @param end_staff integer?
--- @param start_measure integer?
--- @param end_measure integer?
local function update_selection(start_staff, end_staff, start_measure, end_measure)
    local region = finenv.Region()

    start_staff = start_staff or staffIDs[1]
    end_staff = end_staff or staffIDs[#staffIDs]
    start_measure = start_measure or get_measure_selection_start_from_edit()
    end_measure = end_measure or get_measure_selection_end_from_edit()

    if start_measure == nil or end_measure == nil then return end

    region:SetStartStaff(start_staff)
    region:SetEndStaff(end_staff)
    region:SetStartMeasure(start_measure)
    region:SetEndMeasure(end_measure)
    region:SetStartMeasurePosLeft()
    region:SetEndMeasurePosRight()
    region:SetInDocument()
    region:Redraw()
    finenv.UI():MoveToMeasure(start_measure, start_staff)

    update_measure_selection_edits(start_measure, end_measure)
end

--- Enables the controls in a row of the Combine Staves dialog.
--- @param row_number integer
local function enable_row(row_number)
    for i=3,6 do
        local widgetID = calc_row_widget_ID(i, row_number)
        widget_list[widgetID]:SetEnable(true)
        if check_memory[widgetID] == nil then check_memory[widgetID] = widget_list[widgetID]:GetCheck() end
        widget_list[widgetID]:SetCheck(check_memory[widgetID])
    end
    widget_list[calc_row_widget_ID(7, row_number)]:SetEnable(true)
end

--- Disables the controls in a row of the Combine Staves dialog.
--- @param row_number integer
local function disable_row(row_number)
    for i=3,6 do
        local widgetID = calc_row_widget_ID(i, row_number)
        -- If previously enabled, save the check state and disable the control.
        if widget_list[widgetID]:GetEnable() == 1 then
            check_memory[widgetID] = widget_list[widgetID]:GetCheck()
        end

        widget_list[widgetID]:SetEnable(false)
        widget_list[widgetID]:SetCheck(0)
    end
    widget_list[calc_row_widget_ID(7, row_number)]:SetEnable(false)
end

--- Converts the boundaries of the parameter [layer] into a new music region that is returned by the method.
--- @param layer FCNoteEntryLayer FCNoteEntryLayer
--- @return FCMusicRegion
local function create_region_from_note_entry_layer(layer)
    local region = finenv.Region()
    region:SetStartStaff(layer:GetStaff())
    region:SetEndStaff(layer:GetStaff())
    region:SetStartMeasure(layer:GetStartMeasure())
    region:SetEndMeasure(layer:GetEndMeasure())
    region:SetStartMeasurePosLeft()
    region:SetEndMeasurePosRight()
    return region
end


--- Returns an FCMusicRegion object that spans the staves to be combined.
--- Will attempt to set the start and end measures to the values in the MEASURE_SELECTION_FIRST_EDIT and MEASURE_SELECTION_LAST_EDIT controls.
--- If that is not possible, it will match the measure span of the selected region in the document.
--- @return FCMusicRegion
local function calc_current_selection_as_region()
    local region = finenv.Region()
    region:SetStartStaff(staffIDs[1])
    region:SetEndStaff(staffIDs[#staffIDs])

    local measure_selection_start = get_measure_selection_start_from_edit()
    local measure_selection_end = get_measure_selection_end_from_edit()

    if measure_selection_start ~= nil then
        region:SetStartMeasure(measure_selection_start)
    else
        region:SetStartMeasure(finenv.Region():GetStartMeasure())
    end
    if measure_selection_end ~= nil then
        region:SetEndMeasure(measure_selection_end)
    else
        region:SetEndMeasure(finenv.Region():GetEndMeasure())
    end

    return region
end

-- Updates the enabled/disabled state of all of the rows in the Combine Staves dialog based on the presence of notes in the region.
-- Region is calculated from calc_current_selection_as_region (which prioritizes the edit controls).
local function update_accessible_rows()
    local region = calc_current_selection_as_region()

    for staffno=1, #staffIDs do
        local note_entry_layer = finale.FCNoteEntryLayer(0, staffIDs[staffno], region:GetStartMeasure(), region:GetEndMeasure())
        note_entry_layer:Load()
        if note_entry_layer:GetCount() == 0 then
            disable_row(staffno)
        else
            enable_row(staffno)
        end
    end
end

--- Runs tests to ensure that the plug-in can be run.
--- Namely, it checks to make sure that multiple staves are selected.
--- @return boolean
local function init_tests()
    local region = finenv.Region()
    local first_staff = region:GetStartStaff()
    local end_staff = region:GetEndStaff()
    if first_staff == end_staff then
        finenv.UI():AlertInfo("Please select multiple staves.", "Combine Staves")
        return false
    end
    return true
end

--- Launches the end of line dialog. Asks the user if they would like to delete the staves that are not the destination staff.
--- Returns 1 if successful, 0 if not.
--- @return integer
local function launch_end_of_line_dialog()
    End_of_Line_Dialog = finale.FCCustomLuaWindow()
    local str = finale.FCString()
    str.LuaString = "Combine Staves"
    End_of_Line_Dialog:SetTitle(str)

    local desc_static = End_of_Line_Dialog:CreateStatic(0,0)
    str.LuaString = "You have reached the end of this line. Delete the following staves?"
    desc_static:SetWidth(325)
    desc_static:SetHeight(20)
    desc_static:SetText(str)
    local destination_staff = calc_destination_staff_index()

    local measures = finale.FCMeasures()
    local max_measures = measures:LoadAll()

    local list_static = End_of_Line_Dialog:CreateStatic(30,13)
    list_static:SetWidth(265)
    list_static:SetHeight(#staffIDs * 13)

    str.LuaString = ""

    for staff_no=1, #staffIDs do
        if staff_no ~= destination_staff then
            local staff = finale.FCStaff()
            staff:Load(staffIDs[staff_no])
            str:AppendLuaString("\r"..staff:CreateDisplayFullNameString().LuaString)
            if midi.RegionContainsMusic(staffIDs[staff_no], staffIDs[staff_no], 1, max_measures) then
                str:AppendLuaString(" (Still Contains Music)")
            end
        end
    end
    list_static:SetText(str)

    local yes_button = End_of_Line_Dialog:CreateOkButton(50, 30 + #staffIDs * 13)
    str.LuaString = "Yes"
    yes_button:MoveAbsolute(50, 30 + #staffIDs * 13)
    yes_button:SetText(str)
    yes_button:SetWidth(100)

    local no_button = End_of_Line_Dialog:CreateCancelButton(170, 30 + #staffIDs * 13)
    str.LuaString = "No"
    no_button:SetText(str)
    no_button:SetWidth(100)

    End_of_Line_Dialog:RegisterHandleOkButtonPressed(
        function()
            -- Delete all staves in selection besides the destination staff.
            for staff_no=#staffIDs, 1, -1 do
                if staff_no ~= destination_staff then
                    finale.FCStaves.Delete(staffIDs[staff_no])
                end
            end

            local groups = finale.FCGroups()
            groups:LoadAll()
            for group in eachbackwards(groups) do
                if group:GetStartStaff() == staffIDs[destination_staff]
                        and group:GetEndStaff() == staffIDs[destination_staff]
                        and midi.IsValidInstrument(group) then
                    midi.HandleGroupConsolidation(group)
                end
            end
        end
    )

    local minimize_after_completion = widget_list[WIDGETS.MINIMIZE_AFTER_COMPLETION_CHECKBOX]:GetCheck()

    if minimize_after_completion == 1 then
        -- TODO: Minimize
    else
        --TODO: Close/crash program
    end

    return(End_of_Line_Dialog:ExecuteModal(nil))
end

--- Updates the selection in the document to span the next valid iteration region.
--- Dependent on the parameter region_detection_type, which determines the measure span of the resulting region.
--- Automatically handles end of line if handle_end_of_line == true. Automatically updates which controls are enabled in the Combine Staves dialog.
--- Warns the user if multiple staves are selected.
--- @param original_region FCMusicRegion FCMusicRegion
--- @param region_detection_type REGION_DETECTION_TYPES
--- @param handle_end_of_line boolean
local function detect_next_iteration_region(original_region, region_detection_type, handle_end_of_line)
    handle_end_of_line = handle_end_of_line or false
    
    local start_measure = original_region:GetStartMeasure()
    local end_measure = nil
    local max_measures = finale.FCMeasures():LoadAll()

    -- BY MEASURE --
    for measure_no=start_measure, max_measures do
        for staff_no=1,#staffIDs do
            local note_entry_layer = finale.FCNoteEntryLayer(0, staffIDs[staff_no], measure_no, measure_no)
            note_entry_layer:Load()
            if note_entry_layer:GetCount() > 0 then
                start_measure = measure_no
                end_measure = measure_no
                break
            end
        end
        if end_measure ~= nil then break end
    end
    if region_detection_type == REGION_DETECTION_TYPES.AUTO_DETECT_PHRASE then
        -- AUTO-DETECT REGION --
        local original_texture = {}
        local non_empty = false
        for staff_no = 1, #staffIDs do
            local note_entry_layer = finale.FCNoteEntryLayer(0, staffIDs[staff_no], start_measure, start_measure)
            note_entry_layer:Load()
            if note_entry_layer:GetCount() > 0 then
                original_texture[staff_no] = true
                non_empty = true
            else original_texture[staff_no] = false end
        end

        if not non_empty then goto skip_point1 end

        for measure_no = start_measure, max_measures do
            local measure_texture = {}
            for staff_no = 1, #staffIDs do
                local note_entry_layer = finale.FCNoteEntryLayer(0, staffIDs[staff_no], measure_no, measure_no)
                note_entry_layer:Load()
                if note_entry_layer:GetCount() > 0 then measure_texture[staff_no] = true
                else measure_texture[staff_no] = false end
            end

            for i = 1, #original_texture do
                if original_texture[i] ~= measure_texture[i] then
                    end_measure = measure_no - 1
                    goto skip_point1
                end
            end
        end
    end
    ::skip_point1::

    -- Handle End of Line --
    if end_measure == nil then
        if handle_end_of_line then
            launch_end_of_line_dialog()
        end
        if region_detection_type == REGION_DETECTION_TYPES.BY_MEASURE then
            end_measure = start_measure
        else
            end_measure = max_measures
        end
    end

    update_selection(nil, nil, start_measure, end_measure)
    
    update_accessible_rows()

    if ALERT_MULTIPLE_LAYERS then
        for staffno=1, #staffIDs do
            for layer_no=1, 3 do
                local note_entry_layer = finale.FCNoteEntryLayer(layer_no, staffIDs[staffno], original_region:GetStartMeasure(), original_region:GetEndMeasure())
                note_entry_layer:Load()
                if note_entry_layer:GetCount() > 0 then
                    ALERT_MULTIPLE_LAYERS = false
                    break
                end
            end
            if not ALERT_MULTIPLE_LAYERS then break end
        end
        if not ALERT_MULTIPLE_LAYERS then
            finenv.UI():AlertInfo("Multiple layers detected in region. Please note that this plug-in is designed specifically for MIDI engraving, and layers 2-4 will be ignored.", "Combine Staves")
        end
    end
end

--- Combines music from a music region into a single staff. Makes determinations about the destination layer
--- and layer destinations based directly from the Combine Staves dialog. Returns true if successful, false if not.
--- @param region FCMusicRegion
--- @return boolean
local function combine_staves_from_region(region)
    local start_measure = region:GetStartMeasure()
    local end_measure = region:GetEndMeasure()

    local note_entry_layers = {}
    local destination_layers = {} -- [staff_no][destination_layer (bool 0/1)]

    for staff=1, #staffIDs do
        note_entry_layers[staff] = finale.FCNoteEntryLayer(0, staffIDs[staff], start_measure, end_measure)
        note_entry_layers[staff]:Load()
        destination_layers[staff] = {
            widget_list[calc_row_widget_ID(3,staff)]:GetCheck(),
            widget_list[calc_row_widget_ID(4,staff)]:GetCheck(),
            widget_list[calc_row_widget_ID(5,staff)]:GetCheck(),
            widget_list[calc_row_widget_ID(6,staff)]:GetCheck()
        }
    end

    -- Returns a table of FCNoteEntryLayers meant to be combined into a single destination layer.
    local function get_note_entry_layers_by_destination_layer(layer_no)
        local result = {} --If in C++, transform this output to an FCNoteEntryLayers object
        for staff=1, #staffIDs do
            if destination_layers[staff][layer_no] == 1 then
                result[#result+1] = note_entry_layers[staff]
            end
        end
        return result
    end

    local dest_index = calc_destination_staff_index()

    --[[
        Combination Algorithm. See docs for explanation. References: [A], [B], [B1], etc.
    ]]

    local one_layer_selected = false -- If never set true, nothing is selected. Handle accordingly.
    local temp_layer = 0 -- If 1-4, that layer will first be sent to the temp staff (10001). At the end, it is sent where it should be. This is done to deal with shifting around the destination staff to a different layer.
    local TEMP_STAFF = 10001

    local function combine_staves_for_layer(layer)
        local layer_nels = get_note_entry_layers_by_destination_layer(layer)
        if #layer_nels == 1 then
            --[A]--
            midi.SendLayerTo(layer_nels[1], staffIDs[dest_index], layer - 1, start_measure)
            one_layer_selected = true
        elseif #layer_nels > 1 then
            --[B]--
            one_layer_selected = true

            local tuplet_intervals = {}
            for _,nel in ipairs(layer_nels) do
                if nel:GetStaff() == staffIDs[dest_index] then
                    temp_layer = layer
                end
                for entry in each(nel) do
                    if entry:IsStartOfTuplet() then
                        local entry_tuplets = entry:CreateTuplets()
                        for tuplet in each(entry_tuplets) do
                            tuplet_intervals[#tuplet_intervals+1] = {
                                entry.MeasurePos,
                                entry.MeasurePos + tuplet:CalcFullReferenceDuration()
                            }
                        end
                    end
                end
            end
            --[B1]--
            table.sort(tuplet_intervals, function(a, b) return a[1] < b[1] end)
            if #tuplet_intervals > 1 then
                local i = 2
                while i <= #tuplet_intervals do
                    if tuplet_intervals[i][2] > tuplet_intervals[i - 1][1] then
                        tuplet_intervals[i - 1][2] = tuplet_intervals[i][2]
                        table.remove(tuplet_intervals, i)
                    else
                        i = i + 1
                    end
                end
            end
            --[B2]--
            local base_layer, tuplet_entry_count_to_beat = layer_nels[1], 0
            for _,nel in ipairs(layer_nels) do
                local nel_tuplet_entry_count = 0
                for entry in each(nel) do
                    if entry:IsPartOfTuplet() then
                        nel_tuplet_entry_count = nel_tuplet_entry_count + 1
                    end
                end
                if nel_tuplet_entry_count > tuplet_entry_count_to_beat then
                    base_layer = nel
                end
            end
            local mismatched_tuplets = false
            for _,nel in ipairs(layer_nels) do
                for entry in each(nel) do
                    if entry:IsPartOfTuplet() then
                        local entry_pos, entry_pos_exists_in_base = entry.MeasurePos, false
                        for base_entry in each(base_layer) do
                            if base_entry.MeasurePos == entry_pos then
                                entry_pos_exists_in_base = true
                                break
                            end
                        end
                        if not entry_pos_exists_in_base then
                            mismatched_tuplets = true
                            break
                        end
                    end
                end
            end
            
            if not mismatched_tuplets then
                --[C]--
                local destination_layer
                if layer ~= temp_layer then destination_layer = midi.SendLayerTo(base_layer, staffIDs[dest_index], layer - 1, start_measure)
                else destination_layer = midi.SendLayerTo(base_layer, TEMP_STAFF, layer - 1, start_measure) end
                
                for _,nel in ipairs(layer_nels) do
                    if nel == base_layer then goto continue6 end

                    for entry in each(nel) do
                        local entry_pos_exists_in_base = false
                        
                        for base_entry in each(destination_layer) do
                            --print('Source Entry: (' .. entry.Measure .. ', ' .. entry.MeasurePos .. '), Base Entry: (' .. base_entry.Measure .. ', ' .. base_entry.MeasurePos .. ')')
                            if entry.Measure == base_entry.Measure and entry.MeasurePos == base_entry.MeasurePos then
                                --[C1]--
                                entry_pos_exists_in_base = true
                                midi.TransferEntry(entry, base_entry, destination_layer)
                                --[CA1]--
                                if entry:GetActualDuration() > base_entry:GetActualDuration() and entry:IsNote() then
                                    local remaining_extend_duration = entry:GetActualDuration() - base_entry:GetActualDuration()
                                    local current_entry = base_entry:Next()
                                    while true do
                                        if current_entry == nil or current_entry:IsNote() then break end
                                        if remaining_extend_duration == 0 then break end

                                        -- Change rest to notes with same pitches as first one.
                                        if current_entry:GetActualDuration() > 0 then
                                            if remaining_extend_duration >= current_entry:GetActualDuration() then
                                                --print("1. ", remaining_extend_duration, current_entry:GetActualDuration())
                                                base_entry.Duration = base_entry.Duration + current_entry.Duration
                                                remaining_extend_duration = remaining_extend_duration - current_entry:GetActualDuration()
                                                current_entry.Duration = 0
                                                current_entry = current_entry:Next()
                                            else
                                                --Change only part of the rest in the destination to a note.
                                                break
                                            end
                                        else
                                            current_entry = current_entry:Next()
                                        end
                                    end
                                end
                                destination_layer:Save()
                                break
                            end
                        end


                        if not entry_pos_exists_in_base and entry:IsNote() then
                            --[C2]--
                            local function calc_closest_entry_before()
                                local result
                                for base_entry in each(destination_layer) do
                                    if entry.Measure == base_entry.Measure
                                        and ((base_entry.MeasurePos < entry.MeasurePos and result == nil)
                                        or (base_entry.MeasurePos < entry.MeasurePos and base_entry.MeasurePos > result.MeasurePos)) then
                                        result = base_entry
                                    end
                                end
                                return result
                            end
                            local closest_entry = calc_closest_entry_before()
                            local closest_entry_duration = closest_entry:GetActualDuration()
                            closest_entry:SetDuration(entry.MeasurePos - closest_entry.MeasurePos)
                            local new_entry = destination_layer:InsertEntriesAfter(closest_entry, 1, false)
                            if new_entry ~= nil then
                                if entry:IsNote() then
                                    new_entry:MakeNote()
                                    new_entry:CopyNotes(entry)
                                else
                                    new_entry:MakeRest()
                                end
                                new_entry.Duration = closest_entry.MeasurePos + closest_entry_duration - entry.MeasurePos
                                new_entry.Legality = true
                                destination_layer:Save()
                                midi.TransferEntryDetails(entry, new_entry)
                                destination_layer:Save()
                            end
                        end
                    end
                    
                    ::continue6::
                end
                --[CA2]--
                destination_layer:DeleteAllNullEntries()
                create_region_from_note_entry_layer(destination_layer):RebarMusic(finale.REBARSTOP_REGIONEND, true, true)
            else
                --[D]--
                finenv.UI():AlertInfo("Mismatched tuplets support coming in later version...", "Combine Staves")
            end
        end
    end

    -- Prepare to clear layers of the destination staff with nothing being sent to them.
    local clear_layer_after_combination = {false, false, false, false}

    -- Transfer order should prioritize the destination layer of the destination staff.
    local first_in_order = 0
    for i=1,4 do
        local layer_nels = get_note_entry_layers_by_destination_layer(i)
        if #layer_nels == 0 then clear_layer_after_combination[i] = true end
        for _,layer_nel in ipairs(layer_nels) do
            if layer_nel:GetStaff() == staffIDs[dest_index] then
                first_in_order = i
                break
            end
        end
    end
    if first_in_order ~= 0 then combine_staves_for_layer(first_in_order) end
    for i=1,4 do
        if i ~= first_in_order then
            combine_staves_for_layer(i)
        end
    end

    if temp_layer ~= 0 then
        local temp_layer_nel = finale.FCNoteEntryLayer(temp_layer-1, TEMP_STAFF, start_measure, end_measure)
        temp_layer_nel:Load()
        midi.SendLayerTo(temp_layer_nel, staffIDs[dest_index], temp_layer-1, start_measure)
    end

    if not one_layer_selected then
        local result = finenv.UI():AlertOkCancel("No layers selected. Are you sure you want to clear the destination staff?", "Combine Staves")
        if result ~= finale.OKRETURN then return false end
    end

    -- Clear layers with nothing going to them
    for i=1,4 do
        local dest_layer = finale.FCNoteEntryLayer(i-1, staffIDs[dest_index], start_measure, end_measure)
        dest_layer:Load()
        if clear_layer_after_combination[i] then
            dest_layer:ClearAllEntries()
            dest_layer:Save()
        end
    end

    region:Redraw()
    return true
end

-- Launches the main Combine Staves dialog.
local function initialize_gui()
    local region = finenv.Region()

    local start_slot = region:GetStartSlot()
    local end_slot = region:GetEndSlot()

    for i=start_slot,end_slot do
        staffIDs[#staffIDs+1] = region:CalcStaffNumber(i)
    end

    Dialog = finale.FCCustomLuaWindow()

    local str = finale.FCString()

    str.LuaString = "Combine Staves"
    Dialog:SetTitle(str)

    local measure_selection_first_static = Dialog:CreateStatic(0,7)
    str.LuaString = "Measure:"
    measure_selection_first_static:SetText(str)
    widget_list[WIDGETS.MEASURE_SELECTION_FIRST_STATIC] = measure_selection_first_static

    local measure_selection_first_edit = Dialog:CreateEdit(50, 5)
    measure_selection_first_edit:SetWidth(25)
    str.LuaString = finenv.Region():GetStartMeasure()
    measure_selection_first_edit:SetText(str)
    widget_list[WIDGETS.MEASURE_SELECTION_FIRST_EDIT] = measure_selection_first_edit

    local measure_selection_through_static = Dialog:CreateStatic(80,7)
    str.LuaString = "Through:"
    measure_selection_through_static:SetText(str)
    widget_list[WIDGETS.MEASURE_SELECTION_THROUGH_STATIC] = measure_selection_through_static

    local measure_selection_last_edit = Dialog:CreateEdit(130,5)
    str.LuaString = finenv.Region():GetEndMeasure()
    measure_selection_last_edit:SetText(str)
    measure_selection_last_edit:SetWidth(25)
    widget_list[WIDGETS.MEASURE_SELECTION_LAST_EDIT] = measure_selection_last_edit

    local measure_selection_radio_group = Dialog:CreateRadioButtonGroup(177, 0, 2)
    measure_selection_radio_group:SetWidth(120)
    str.LuaString = "Iterate by Measure"
    measure_selection_radio_group:GetItemAt(0):SetText(str)
    str.LuaString = "Auto-Detect Phrase"
    measure_selection_radio_group:GetItemAt(1):SetText(str)
    widget_list[WIDGETS.MEASURE_SELECTION_RADIO_GROUP] = measure_selection_radio_group

    local update_selection_button = Dialog:CreateButton(305,4)
    str.LuaString = "Update Selection"
    update_selection_button:SetText(str)
    update_selection_button:SetWidth(100)
    widget_list[WIDGETS.UPDATE_SELECTION_BUTTON] = update_selection_button

    local minimize_window_button = Dialog:CreateButton(407,4)
    str.LuaString = "—"
    minimize_window_button:SetText(str)
    minimize_window_button:SetWidth(20)
    widget_list[WIDGETS.MINIMIZE_WINDOW_BUTTON] = minimize_window_button

    Dialog:CreateHorizontalLine(0, 40, 427)

    local combine_button = Dialog:CreateButton(267,94+#staffIDs*24)
    str.LuaString = "Combine"
    combine_button:SetText(str)
    combine_button:SetWidth(90)
    widget_list[WIDGETS.COMBINE] = combine_button

    Dialog:CreateCloseButton(367, 94 + #staffIDs * 24)

    local select_target_layer_static = Dialog:CreateStatic(170, 47)
    str.LuaString = "Select target layer."
    select_target_layer_static:SetText(str)
    widget_list[WIDGETS.SELECT_TARGET_LAYER_STATIC] = select_target_layer_static

    local clear_layers_checkbox = Dialog:CreateCheckbox(0, 90 + #staffIDs * 24)
    str.LuaString = "Clear Layers After Transfer"
    clear_layers_checkbox:SetText(str)
    clear_layers_checkbox:SetWidth(160)
    clear_layers_checkbox:SetCheck(1)
    widget_list[WIDGETS.CLEAR_LAYERS_CHECKBOX] = clear_layers_checkbox

    local automatic_transfer_checkbox = Dialog:CreateCheckbox(0, 110 + #staffIDs * 24)
    str.LuaString = "Automatically Transfer Single Lines"
    automatic_transfer_checkbox:SetText(str)
    automatic_transfer_checkbox:SetWidth(190)
    automatic_transfer_checkbox:SetCheck(0)
    widget_list[WIDGETS.AUTOMATIC_TRANSFER_CHECKBOX] = automatic_transfer_checkbox

    local minimize_after_completion_checkbox = Dialog:CreateCheckbox(0, 130 + #staffIDs * 24)
    str.LuaString = "Minimize After Line Completion"
    minimize_after_completion_checkbox:SetText(str)
    minimize_after_completion_checkbox:SetWidth(190)
    minimize_after_completion_checkbox:SetCheck(0)
    widget_list[WIDGETS.MINIMIZE_AFTER_COMPLETION_CHECKBOX] = minimize_after_completion_checkbox

    local modify_staff_articulation_assignments_button = Dialog:CreateButton(267, 128+#staffIDs*24)
    str.LuaString = "Modify Staff Assignments . . ."
    modify_staff_articulation_assignments_button:SetText(str)
    modify_staff_articulation_assignments_button:SetWidth(160)
    modify_staff_articulation_assignments_button:SetHeight(16)
    widget_list[WIDGETS.MODIFY_STAFF_ARTICULATION_ASSIGNMENTS] = modify_staff_articulation_assignments_button

    for row=1, #staffIDs do
        local row_static = Dialog:CreateStatic(0,72+(24*(row-1)))
        local staff = finale.FCStaff()
        staff:Load(staffIDs[row])
        row_static:SetText(staff:CreateDisplayFullNameString())
        row_static:SetWidth(125)
        widget_list[calc_row_widget_ID(1, row)] = row_static

        local row_destination_checkbox = Dialog:CreateCheckbox(142,72+(24*(row-1)))
        local row_layer_checkboxes = {
            Dialog:CreateCheckbox(222,72+(24*(row-1))),
            Dialog:CreateCheckbox(254,72+(24*(row-1))),
            Dialog:CreateCheckbox(286,72+(24*(row-1))),
            Dialog:CreateCheckbox(318,72+(24*(row-1)))
        }
        local send_to_button = Dialog:CreateButton(353,71+(24*(row-1)))

        for i=1,4 do
            row_layer_checkboxes[i]:SetWidth(30)
            widget_list[calc_row_widget_ID(2+i, row)] = row_layer_checkboxes[i]

            Dialog:RegisterHandleControlEvent(row_layer_checkboxes[i],
                function(control)
                    if control:GetCheck() == 1 then
                        for j=1,4 do
                            if i ~= j then row_layer_checkboxes[j]:SetCheck(0) end
                            check_memory[calc_row_widget_ID(j+2, row)] = row_layer_checkboxes[j]:GetCheck()
                        end
                    end
                end
            )
        end
        row_destination_checkbox:SetWidth(80)
        send_to_button:SetHeight(14)
        widget_list[calc_row_widget_ID(2, row)] = row_destination_checkbox
        widget_list[calc_row_widget_ID(7, row)] = send_to_button
        if row == 1 then
            row_destination_checkbox:SetEnable(false)
            row_destination_checkbox:SetCheck(1)
        end

        str.LuaString = "Destination"
        row_destination_checkbox:SetText(str)
        str.LuaString = "1"
        row_layer_checkboxes[1]:SetText(str)
        str.LuaString = "2"
        row_layer_checkboxes[2]:SetText(str)
        str.LuaString = "3"
        row_layer_checkboxes[3]:SetText(str)
        str.LuaString = "4"
        row_layer_checkboxes[4]:SetText(str)
        str.LuaString = "Send to . . ."
        send_to_button:SetText(str)

        Dialog:RegisterHandleControlEvent(row_destination_checkbox,
            function(control)
                for i=calc_row_widget_ID(2, 1),calc_row_widget_ID(2,#staffIDs),7 do
                    widget_list[i]:SetEnable(true)
                    widget_list[i]:SetCheck(0)
                end

                control:SetCheck(1)
                control:SetEnable(false)
            end
        )

        Dialog:RegisterHandleControlEvent(send_to_button,
            function()
                --TODO: Create Dialog for Send to... button
                finenv.UI():AlertInfo("Send to... functionality to come in later version.", "Combine Staves")
            end
        )
    end

    Dialog:RegisterHandleControlEvent(measure_selection_radio_group:GetItemAt(0),
        function()
            local selection = finenv.Region()
            if selection:GetStartStaff() == staffIDs[1] and selection:GetEndStaff() == staffIDs[#staffIDs] then
                detect_next_iteration_region(finenv.Region(), REGION_DETECTION_TYPES.BY_MEASURE, false)
            else
                detect_next_iteration_region(calc_current_selection_as_region(), REGION_DETECTION_TYPES.BY_MEASURE, false)
            end
        end
    )

    Dialog:RegisterHandleControlEvent(measure_selection_radio_group:GetItemAt(1),
        function()
            local selection = finenv.Region()
            if selection:GetStartStaff() == staffIDs[1] and selection:GetEndStaff() == staffIDs[#staffIDs] then
                detect_next_iteration_region(finenv.Region(), REGION_DETECTION_TYPES.AUTO_DETECT_PHRASE, false)
            else
                detect_next_iteration_region(calc_current_selection_as_region(), REGION_DETECTION_TYPES.AUTO_DETECT_PHRASE, false)
            end
        end
    )

    Dialog:RegisterHandleControlEvent(update_selection_button,
        function()
            -- Nothing selected, one staff selected, same staves selected, new staves selected
            local region = finenv.Region()
            local start_staff = region:GetStartStaff()
            local end_staff = region:GetEndStaff()
            local start_measure = region:GetStartMeasure()
            local end_measure = region:GetEndMeasure()
            if start_staff == 0 or end_staff == 0 then
                update_selection()
            elseif start_staff == end_staff then
                finenv.UI():AlertInfo("Please select multiple staves.", "Combine Staves")
            elseif start_staff == staffIDs[1] and end_staff == staffIDs[#staffIDs] then
                if midi.RegionContainsMusic(nil, nil, start_measure, end_measure) then
                    update_selection(start_staff, end_staff, start_measure, end_measure)
                    update_accessible_rows()
                else
                    detect_next_iteration_region(finenv.Region(), measure_selection_radio_group:GetSelectedItem(), false)
                end
            else
                -- TODO: Reinitialize
            end
        end
    )

    Dialog:RegisterHandleControlEvent(minimize_window_button,
        function()
            --TODO: Minimize
                finenv.UI():AlertInfo("Minimization functionality to come in later version.", "Combine Staves")
        end
    )

    Dialog:RegisterHandleControlEvent(automatic_transfer_checkbox,
        function()
            finenv.UI():AlertInfo("Automatically Transfer Single Lines functionality to come in later version.", "Combine Staves")
        end
    )

    Dialog:RegisterHandleControlEvent(minimize_after_completion_checkbox,
        function()
            finenv.UI():AlertInfo("Minimize After Line Completion functionality to come in later version.", "Combine Staves")
        end
    )

    Dialog:RegisterHandleControlEvent(combine_button,
        function()
            local current_region = calc_current_selection_as_region()
            local success = combine_staves_from_region(current_region)
            if success then
                current_region:AddMeasureOffset(current_region:CalcMeasureSpan())
                current_region:SetEndMeasure(current_region:GetStartMeasure())
                detect_next_iteration_region(current_region, measure_selection_radio_group:GetSelectedItem(), true)
            end
            -- TODO: Handle Automatically Transfer Single Lines
        end
    )

    Dialog:RegisterHandleControlEvent(modify_staff_articulation_assignments_button,
        function()
            local articulation_assignment_os_menu_command = finenv.UI():GetOSMenuCommandFromItemText("Plug-ins","Phantom Assign Staves to Instruments")
            if articulation_assignment_os_menu_command == -1 then
                finenv.UI():AlertInfo("Assign Staves to Instruments Plug-in Not Detected.", "Combine Staves")
            else
                finenv.UI():ExecuteOSMenuCommand(articulation_assignment_os_menu_command)
            end
        end
    )

    Dialog:RegisterHandleControlEvent(clear_layers_checkbox,
        function()
            finenv.UI():AlertInfo("Clear Layers After Transfer functionality to come in later version.", "Combine Staves")
        end
    )

    detect_next_iteration_region(calc_current_selection_as_region(), measure_selection_radio_group:GetSelectedItem(), false)

    finenv.RegisterModelessDialog(Dialog)
    Dialog:ShowModeless()
end

--[[
    Public Methods
]]

-- Launches the Combine Staves dialog. Returns true if successful, false if unsuccessful.
function PHCombineStaves.DisplayDialog()
    if init_tests() then
        initialize_gui()
        return true
    end

    return false
end

return PHCombineStaves