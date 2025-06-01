--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module serves as a library that is used by many of the other modules. It's purpose
    is to decompose common subtasks related to interacting with the open document in Finale.

]]

-- Library for handling MIDI engraving tasks (static).
local midi = {}

--- Transfers the names and name positions of a source FCStaff or FCGroup to a destination FCStaff or FCGroup.
--- @param source FCStaff|FCGroup FCStaff|FCGroup
--- @param destination FCStaff|FCGroup FCStaff|FCGroup
function midi.TransferFormatting(source, destination)
    local source_type = source:ClassName()
    local destination_type = destination:ClassName()
    if source_type ~= 'FCStaff' and source_type ~= 'FCGroup' then return end
    if destination_type ~= 'FCStaff' and destination_type ~= 'FCGroup' then return end

    -- Transfer Staff/Group Name
    -- Transfer Font Info TODO: Make sure it doesn't crash if the destination has no text.
    destination:SaveFullNameString(source:CreateFullNameString())
    destination:SaveAbbreviatedNameString(source:CreateAbbreviatedNameString())

    -- Transfer Staff/Group Name Position
    local show_names
    local full_alignment, full_justification, full_horizontaloffset, full_verticaloffset, full_usepositioning
    local abrv_alignment, abrv_justification, abrv_horizontaloffset, abrv_verticaloffset, abrv_usepositioning
    if source_type == 'FCStaff' then
        show_names = source:GetShowScoreStaffNames()

        local full_name_position = source:GetFullNamePosition()
        full_alignment = full_name_position.Alignment
        full_justification = full_name_position.Justification
        full_horizontaloffset = full_name_position.HorizontalOffset
        full_verticaloffset = full_name_position.VerticalOffset
        full_usepositioning = full_name_position.UsePositioning

        local abrv_name_position = source:GetAbbreviatedNamePosition()
        abrv_alignment = abrv_name_position.Alignment
        abrv_justification = abrv_name_position.Justification
        abrv_horizontaloffset = abrv_name_position.HorizontalOffset
        abrv_verticaloffset = abrv_name_position.VerticalOffset
        abrv_usepositioning = abrv_name_position.UsePositioning
    else -- source ~ FCGroup
        show_names = source:GetShowGroupName()

        full_alignment = source.FullNameAlign
        full_justification = source.FullNameJustify
        full_horizontaloffset = source.FullNameHorizontalOffset
        full_verticaloffset = source.FullNameVerticalOffset
        full_usepositioning = source.UseFullNamePositioning

        abrv_alignment = source.AbbreviatedNameAlign
        abrv_justification = source.AbbreviatedNameJustify
        abrv_horizontaloffset = source.AbbreviatedNameHorizontalOffset
        abrv_verticaloffset = source.AbbreviatedNameVerticalOffset
        abrv_usepositioning = source.UseAbbreviatedNamePositioning
    end

    if destination_type == 'FCStaff' then
        destination:SetShowScoreStaffNames(show_names)

        local full_name_position = destination:GetFullNamePosition()
        full_name_position.Alignment = full_alignment
        full_name_position.Justification = full_justification
        full_name_position.HorizontalOffset = full_horizontaloffset
        full_name_position.VerticalOffset = full_verticaloffset
        full_name_position.UsePositioning = false --full_usepositioning

        local abrv_name_position = destination:GetAbbreviatedNamePosition()
        abrv_name_position.Alignment = abrv_alignment
        abrv_name_position.Justification = abrv_justification
        abrv_name_position.HorizontalOffset = abrv_horizontaloffset
        abrv_name_position.VerticalOffset = abrv_verticaloffset
        abrv_name_position.UsePositioning = false --abrv_usepositioning
    else -- source ~ FCGroup
        destination:SetShowGroupName(show_names)

        destination.FullNameAlign = full_alignment
        destination.FullNameJustify = full_justification
        destination.FullNameHorizontalOffset = full_horizontaloffset
        destination.FullNameVerticalOffset = full_verticaloffset
        destination.UseFullNamePositioning = false --full_usepositioning

        destination.AbbreviatedNameAlign = abrv_alignment
        destination.AbbreviatedNameJustify = abrv_justification
        destination.AbbreviatedNameHorizontalOffset = abrv_horizontaloffset
        destination.AbbreviatedNameVerticalOffset = abrv_verticaloffset
        destination.UseAbbreviatedNamePositioning = false --abrv_usepositioning
    end

    destination:Save()
end

--- Loads an FCStaves object with only the staves that are visible in the score.
--- @param staves_result FCStaves FCStaves
function midi.LoadStaves(staves_result)
    staves_result:LoadAll()
    -- TODO: Consider renaming LoadVisibleStaves()
    --Iterate through systems and prove that each staff exists
    local staffsystems = finale.FCStaffSystems()
    staffsystems:LoadAll()
    local staff_exists = {}
    for staffsys in each(staffsystems) do
        local sysstaves = staffsys:CreateSystemStaves()
        for sysstaff in each(sysstaves) do
            staff_exists[sysstaff.Staff] = true
        end
    end
    for staff in eachbackwards(staves_result) do
        if staff_exists[staff.ItemNo] == nil then
            staves_result:ClearItemAt(staff.ItemNo - 1)
        end
    end
end

--- Returns an FCStaves object containing only the staves that are part of a FCGroup (parameter).
---@param group FCGroup FCGroup
---@return unknown
function midi.GetStavesFromGroup(group)
    local group_staves = finale.FCStaves()
    midi.LoadStaves(group_staves)
    local index = group_staves:GetCount()
    for staff in eachbackwards(group_staves) do
        index = index - 1
        if not group:ContainsStaff(staff.ItemNo) then
            group_staves:ClearItemAt(index)
        end
    end
    return group_staves
end

--- Returns true if there is at least one entry in the region.
--- @param start_staff integer?
--- @param end_staff integer?
--- @param start_measure integer
--- @param end_measure integer
--- @return boolean
function midi.RegionContainsMusic(start_staff, end_staff, start_measure, end_measure)
    if start_staff == nil or end_staff == nil then
        for staff_no=1, #staffIDs do
            local note_entry_layer = finale.FCNoteEntryLayer(0, staffIDs[staff_no], start_measure, end_measure)
            note_entry_layer:Load()
            if note_entry_layer:GetCount() > 0 then
                return true
            end
        end
    else
        for staff_no=start_staff, end_staff do
            local note_entry_layer = finale.FCNoteEntryLayer(0, staff_no, start_measure, end_measure)
            note_entry_layer:Load()
            if note_entry_layer:GetCount() > 0 then
                return true
            end
        end
    end

    return false
end

--- Tests if an FCGroup meets the criteria for being an overdub group.
--- @param group FCGroup FCGroup
--- @return boolean
function midi.IsOverdub(group)
    local group_name = group:CreateTrimmedFullNameString()
    local group_name_str = group_name.LuaString:gsub("[\n\r]", "")
    if string.match(group_name_str, 'OVERDUB') then return true
    else return false end
end

--- Tests if an FCGroup meets the criteria for being a valid instrument group.
--- @param group FCGroup FCGroup
--- @return boolean
function midi.IsValidInstrument(group)
    if midi.IsOverdub(group) then return false end
    local group_name = group:CreateTrimmedFullNameString()

    if group_name.LuaString == "" then return false end
    if group:GetBracketStyle() ~= finale.GRBRAC_DESK then return false end

    local group_staves = midi.GetStavesFromGroup(group)
    local model_UUID = group_staves:GetItemAt(0):GetInstrumentUUID()

    for staff in each(group_staves) do
        if staff:GetInstrumentUUID() ~= model_UUID then
            return false
        end
    end

    return true
end

--- Tests if an FCGroup meets the criteria for being a valid multistaff detection/"data" group.
--- @param group FCGroup FCGroup
--- @return boolean
function midi.IsValidMultistaffDetectionGroup(group)
    if group == nil or group:ClassName() ~= "FCGroup" then return false end
    
    if midi.IsOverdub(group) or midi.IsValidInstrument(group) then return false end

    if group:GetBracketStyle() ~= finale.GRBRAC_NONE then return false end

    local group_name = group:CreateTrimmedFullNameString()
    if not group_name:ContainsLuaString("[Multistaff]") then return false end

    return true
end

--- Tests if an FCGroup meets the criteria for being a valid multistaff subgroup. Multistaff subgroups
--- are used to delineate the different staves belonging to the same instrument.
--- @param group FCGroup FCGroup
--- @return boolean
function midi.IsMultistaffSubGroup(group)
    if group == nil or group:ClassName() ~= "FCGroup" then return false end

    if not midi.IsValidInstrument(group) then return false end

    local group_name = group:CreateTrimmedFullNameString().LuaString
    if not (group_name == "RH" or group_name == "LH" or group_name == "Ped.") then return false end

    local function belongs_to_multistaff_group()
        local groups = finale.FCGroups()
        groups:LoadAll()
        for ms_candidate in each(groups) do
            if midi.IsValidMultistaffDetectionGroup(ms_candidate) then
                if group:GetStartStaff() >= ms_candidate:GetStartStaff() and group:GetEndStaff() <= ms_candidate:GetEndStaff() then
                    return true
                end
            end
        end
        return false
    end

    if not belongs_to_multistaff_group() then return false end

    return true
end

--- Returns an FCGroup pointer to a group that fits the criteria of a multistaff data group
--- containing the staff span of the FCGroup multistaff subgroup argument.
--- @param subgroup FCGroup FCGroup (Multistaff Subgroup)
--- @return FCGroup?
function midi.GetMultistaffDataGroup(subgroup)
    if subgroup == nil or subgroup:ClassName() ~= "FCGroup" then return end

    local top_staff = subgroup:GetStartStaff()
    local bottom_staff = subgroup:GetEndStaff()
    local groups = finale.FCGroups()
    groups:LoadAll()
    for group in each(groups) do
        if group:GetStartStaff() <= top_staff and group:GetEndStaff() >= bottom_staff
                and midi.IsValidMultistaffDetectionGroup(group) then
            return group
        end
    end
end

--- Returns an FCGroup pointer to a group that fits the criteria of a multistaff display within
--- the bounds of a multistaff detection/("data") group.
--- @param multistaff_group FCGroup FCGroup (Multistaff Data Group)
--- @return FCGroup?
function midi.GetMultistaffDisplayGroup(multistaff_group)
    if not midi.IsValidMultistaffDetectionGroup(multistaff_group) then return end

    local top_staff = multistaff_group:GetStartStaff()
    local bottom_staff = multistaff_group:GetEndStaff()
    local groups = finale.FCGroups()
    groups:LoadAll()
    for group in each(groups) do
        if group:GetStartStaff() >= top_staff and group:GetEndStaff() <= bottom_staff
                and group:GetBracketStyle() == finale.GRBRAC_PIANO
                and group:GetShowGroupName() then
            return group
        end
    end
end

--- Returns an FCGroups object containing all multistaff subgroups within the bounds of a multistaff detection/"data" group.
--- @param multistaff_group FCGroup FCGroup (Multistaff Data Group)
--- @return FCGroups?
function midi.GetMultistaffSubGroups(multistaff_group)
    if not midi.IsValidMultistaffDetectionGroup(multistaff_group) then return end

    local top_staff = multistaff_group:GetStartStaff()
    local bottom_staff = multistaff_group:GetEndStaff()
    local groups = finale.FCGroups()
    groups:LoadAll()

    local subgroups_result = finale.FCGroups()
    local index = subgroups_result:LoadAll()
    for group in eachbackwards(groups) do
        index = index - 1
        if not (group:GetStartStaff() >= top_staff and group:GetEndStaff() <= bottom_staff)
                or not midi.IsMultistaffSubGroup(group) then
            subgroups_result:ClearItemAt(index)
        end
    end

    return subgroups_result
end

--- Returns true if the surrounding multistaff data group spans the same number of staves as it is
--- determined to support. Takes one argument: a subgroup of the multistaff data group. If the passed
--- argument is not a valid multistaff data group, returns nil.
--- @param multistaff_group FCGroup FCGroup (Multistaff Data Group)
--- @return boolean?
function midi.IsMultistaffDoneCombining(multistaff_group)
    if not midi.IsValidMultistaffDetectionGroup(multistaff_group) then return end

    if multistaff_group:CalcStaffSpan() == midi.CalcMultistaffStaffCount(multistaff_group) then return true
    else return false end
end

--- Deletes the data of all FCGroups determined to be subgroups of the passed argument multistaff_group,
--- a valid multistaff data group.
--- @param multistaff_group FCGroup FCGroup (Multistaff Data Group)
function midi.DeleteMultistaffSubGroups(multistaff_group)
    if not midi.IsValidMultistaffDetectionGroup(multistaff_group) then return end

    local subgroups = midi.GetMultistaffSubGroups(multistaff_group)
    for subgroup in eachbackwards(subgroups) do
        subgroup:DeleteData()
    end
end

--- Calculates the number of staves in a multistaff group based on the existence of RH, LH, and Ped.
--- organizational groups. If none exist, returns the staff span of the multistaff group argument if 2 or 3.
--- First value can only return as nil, 2, or 3.
--- Returns a second boolean value indicating whether the user needs to create new instruments in assign_articulation_staves.lua.
--- Takes a multistaff detection/"data" group as its argument.
--- @param multistaff_group FCGroup FCGroup (Multistaff Data Group)
--- @return 2|3?, boolean?
function midi.CalcMultistaffStaffCount(multistaff_group)
    if not midi.IsValidMultistaffDetectionGroup(multistaff_group) then return end
    
    local top_staff = multistaff_group:GetStartStaff()
    local bottom_staff = multistaff_group:GetEndStaff()
    local rh_exists, lh_exists, ped_exists = false, false, false

    local groups = finale.FCGroups()
    groups:LoadAll()
    for group in each(groups) do
        if group:GetStartStaff() >= top_staff and group:GetEndStaff() <= bottom_staff
                and group:GetBracketStyle() == finale.GRBRAC_DESK
                and group:GetShowGroupName() then
            local group_name = group:CreateTrimmedFullNameString()
            if group_name.LuaString == "RH" then rh_exists = true
            elseif group_name.LuaString == "LH" then lh_exists = true
            elseif group_name.LuaString == "Ped." then ped_exists = true end
        end
        if rh_exists and lh_exists and ped_exists then return 3, false end
    end

    if rh_exists and lh_exists then return 2, false end
    if (not rh_exists) and (not lh_exists) and (not ped_exists) then
        local staff_count = multistaff_group:CalcStaffSpan()
        if staff_count == 2 or staff_count == 3 then return staff_count, true end
    end
end

--- Detects the UUID of a multistaff instrument from the full name of a passed multistaff detection/"data" group.
--- @param multistaff_group FCGroup FCGroup (Multistaff Data Group)
--- @return string?
function midi.GetMultistaffUUID(multistaff_group)
    if not midi.IsValidMultistaffDetectionGroup(multistaff_group) then return end

    local group_name = multistaff_group:CreateTrimmedFullNameString()
    if not group_name:ContainsLuaString("[Multistaff]") then return end

    local uuid_start_index = group_name.LuaString:find("{")
    local uuid_end_index = group_name.LuaString:find("}")
    if uuid_start_index and uuid_end_index then
        local uuid = group_name.LuaString:sub(uuid_start_index + 1, uuid_end_index - 1)
        return uuid
    end
end

--- Void function that should be called after staves are combined into a single staff. Will hide
--- the temporary group name and fix the staff name formatting. Function assumes that the group argument
--- is a valid instrument.
--- @param group FCGroup FCGroup
function midi.HandleGroupConsolidation(group)
    local staff = finale.FCStaff()
    staff:Load(group:GetStartStaff())

    if not midi.IsMultistaffSubGroup(group) then
        -- Transfer formatting between group name and staff name. Hide group.
        if group:GetShowGroupName() == true then
            midi.TransferFormatting(group, staff)
            group:SetShowGroupName(false)
            group:Save()
        end
    else
        -- In the case of a subgroup of a multistaff instrument (RH, LH, etc.),
        -- keep the group name, hide the staff name.
        staff:SetShowScoreStaffNames(false)
        staff:Save()

        local multistaff_data_group = midi.GetMultistaffDataGroup(group)

        if multistaff_data_group ~= nil and midi.IsMultistaffDoneCombining(multistaff_data_group) then
            local multistaff_display_group = midi.GetMultistaffDisplayGroup(multistaff_data_group)
            if multistaff_display_group ~= nil then
                multistaff_display_group:SetBracketHorizontalPos(-12)
                multistaff_display_group:Save()
            end

            midi.DeleteMultistaffSubGroups(multistaff_data_group)
        end
    end
end

--- Transfer expressions within the span of the source entry to destination entry.
--- @param source_entry FCNoteEntry FCNoteEntry
--- @param dest_entry FCNoteEntry FCNoteEntry
function midi.TransferExpressions(source_entry, dest_entry)
    local source_measure = source_entry:GetMeasure()
    local source_staff = source_entry:GetStaff()
    local dest_staff = dest_entry:GetStaff()
    local source_region = finale.FCMusicRegion()
    source_region:SetStartMeasure(source_measure)
    source_region:SetEndMeasure(source_measure)
    source_region:SetStartStaff(source_staff)
    source_region:SetEndStaff(source_staff)
    source_region:SetStartMeasurePos(source_entry:GetMeasurePos())
    source_region:SetEndMeasurePos(source_entry:GetMeasurePos() + source_entry:GetDuration())

    local expressions = finale.FCExpressions()
    expressions:LoadAllForRegion(source_region)
    for expression in each(expressions) do
        local cell = finale.FCCell(source_measure, dest_staff)
        expression:SaveNewToCell(cell)

        --TODO: test if other expressions in the destination cell necessitate mutual destruction
    end
end

--- Transfers entry details between entries, including those that are not covered by void FCNoteEntry:CopyEntryDetails().
---@param source_entry FCNoteEntry FCNoteEntry
---@param dest_entry FCNoteEntry FCNoteEntry
---@param include_tuplets? boolean
function midi.TransferEntryDetails(source_entry, dest_entry, include_tuplets)
    if include_tuplets == nil then include_tuplets = false end
    dest_entry:CopyEntryDetails(source_entry, include_tuplets)

    --Delete duplicate articulations
    local articulations = dest_entry:CreateArticulations()
    if articulations:GetCount() > 1 then
        for i=articulations:GetCount() - 1, 0, -1 do
            local compare_articulation_1 = articulations:GetItemAt(i)
            local compare_articulation_1_def = compare_articulation_1:CreateArticulationDef()
            for j=articulations:GetCount() - 1, i + 1, -1 do
                local compare_articulation_2 = articulations:GetItemAt(j)
                local compare_articulation_2_def = compare_articulation_2:CreateArticulationDef()
                if compare_articulation_1_def.ItemNo == compare_articulation_2_def.ItemNo then
                    compare_articulation_2:DeleteData()
                end
            end
        end
    end


    
    --Manual transfer of notehead mods
    for note in each(dest_entry) do
        local source_equivalent = source_entry:FindPitch(note)
        if source_equivalent ~= nil then
            local notehead_mod = finale.FCNoteheadMod()
            notehead_mod:SetNoteEntry(source_entry)
            if notehead_mod:LoadAt(source_equivalent) then
                notehead_mod:EraseAt(note)
                notehead_mod:SaveAt(note)
            end
        end
    end
    midi.TransferExpressions(source_entry, dest_entry)
end

--- Transfers all entries from an FCNoteEntryLayer (source_nel) to another staff (destID).
--- Optional parameters: layer_no (0-based index) and measure_no (1-based).
--- @param source_nel FCNoteEntry
--- @param destID integer
--- @param layer_no integer
--- @param measure_no? integer
--- @return FCNoteEntryLayer
function midi.SendLayerTo(source_nel, destID, layer_no, measure_no)
    source_nel:Load()
    layer_no = layer_no or source_nel:GetLayerIndex() or 0
    measure_no = measure_no or source_nel:GetStartMeasure() or 1

    -- Check if not making any changes.
    if layer_no == source_nel:GetLayerIndex() and destID == source_nel:GetStaff() then return source_nel end

    local destination_layer = source_nel:CreateCloneEntries(layer_no, destID, measure_no)
    destination_layer:Save()
    for i=0, source_nel:GetCount() - 1 do
        destination_layer:Load()
        midi.TransferEntryDetails(source_nel:GetItemAt(i), destination_layer:GetItemAt(i), true)
        destination_layer:Save()
    end
    destination_layer:Save()
    return destination_layer
    --end
end

--- Transfers pitches and entry details between entries.
--- @param source_entry FCNoteEntry FCNoteEntry
--- @param dest_entry FCNoteEntry FCNoteEntry
function midi.TransferPitches(source_entry, dest_entry)
    if dest_entry:IsRest() and source_entry:IsNote() then
        dest_entry:MakeNote()
        dest_entry:ClearPitches()
    end
    dest_entry:AddPitches(source_entry, true, true)
    midi.TransferEntryDetails(source_entry, dest_entry, false)
end

--- Similar to TransferPitches(), except this method will also create an additional rest entry to add to the frame
--- if the source_entry is a note with less duration than the destination if the destination is a rest.
--- @param source_entry FCNoteEntry FCNoteEntry
--- @param dest_entry FCNoteEntry FCNoteEntry
--- @param dest_layer FCNoteEntryLayer FCNoteEntryLayer
function midi.TransferEntry(source_entry, dest_entry, dest_layer)
    local rest_duration = 0
    if source_entry:IsNote() and dest_entry:IsRest() and source_entry:GetActualDuration() < dest_entry:GetActualDuration() then
        rest_duration = dest_entry:GetActualDuration() - source_entry:GetActualDuration()
    end

    midi.TransferPitches(source_entry, dest_entry)
    if rest_duration > 0 then
        local dest_rest = dest_layer:InsertEntriesAfter(dest_entry, 1, false)
        dest_entry.Duration = dest_entry.Duration - rest_duration
        dest_rest:MakeRest()
	    dest_rest.Duration = rest_duration
	    dest_rest.Legality = true
        dest_layer:Save()
    end
end


--- Affects the distance of all system staves below the start_slot (0-based) by the amount parameter.
--- If use_percent is false, it will change their distance by amount in EVPUs. If true, the
--- result will be based on the start_slot's distance from the slot right above it.
--- @param system_staves FCSystemStaves FCSystemStaves
--- @param start_slot integer
--- @param amount integer
--- @param use_percent boolean
function midi.MoveSystemStaves(system_staves, start_slot, amount, use_percent)
    if start_slot == 0 and use_percent then
        -- Cannot use percentage-based distance for the top system staff
        return
    end


    if use_percent then
        local slot_distance = system_staves:GetItemAt(start_slot):GetDistance()
        local slot_above_distance = system_staves:GetItemAt(start_slot - 1):GetDistance()
        amount = (slot_distance - slot_above_distance) * (amount / 100) - (slot_distance - slot_above_distance)
    end

    for i = start_slot, system_staves:GetCount() - 1 do
        local slot = system_staves:GetItemAt(i)
        slot:SetDistance(slot:GetDistance() + amount)
        slot:Save()
    end
end

return midi