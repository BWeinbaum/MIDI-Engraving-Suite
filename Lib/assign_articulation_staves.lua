--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module is responsible for carrying out the subtask of organizing the articulation staves
    output of a Digital Audio Workstation (DAW) into an instrument list that is more useful in Finale.

]]

-- TODO: Go through initialize, create_main_ui and make many little, local helper methods out of the code that is there.

--[[
    Import Modules
]]

local midi = require "Lib.midi_engraving_lib"
local ArticulationXMLHandler = require "Lib.articulation_xml_handler"
local ArticulationXMLParser = require "Lib.articulation_xml_parser"
local FinaleInstrumentXMLParser = require "Lib.finale_instrument_xml_parser"

--[[
    Global Module: PHAssignStaves

    Steps for conversion:
    1. Declare instance fields
    2. Create a constructor; assign instance fields.
    3. Organize helper methods.
    4. Create interface.
]]

-- Static class for organizing articulation staves into instruments. Recommended to call methods in the following order:
---- Initialize(),
---- DisplayDialog(),
---- OrganizeScore().
--- @class PHAssignStaves
local PHAssignStaves = {}
PHAssignStaves.__index = PHAssignStaves

--[[
    Instance Variables
]]

--- @type TreeInstrument[]
--- Table of TreeInstrument objects as defined in the UI.
local instruments = {}

--- @type integer[]
--- Table of 1-based integers determining the assignment of each staff (-1 = unassigned).
local staff_instrument_assignment = {}

--- @type XMLArticulation[]
--- Table of XMLArticulation objects (articulation_xml_lib.lua) determining the articulation actions to be performed on each staff.
local staff_articulation = {}

--- @type integer
--- Integer variable to discern the currently visible instruments in the instrument tree.
--- 0  : all instruments (compressed overdubs)
--- 1+ : specific overdub group
local overdub_display = 0

-- Collection of staves for interacting with the document.
-- Warning: Avoid using staves:LoadAll() to avoid loading inaccessible (previously deleted)
-- staves. Instead use LoadStaves() from midi_engraving_lib.lua. 
local staves = finale.FCStaves()

local current_directory = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")
local art_xml_parser = ArticulationXMLParser.Init({current_directory .. 'Data/default.xml',
                current_directory .. 'Data/saved.xml',
                current_directory .. 'Data/spitfire_bbcsymphonyorchestra.xml'}) --TODO: Read Entire Folder
local finale_xml_parser = FinaleInstrumentXMLParser.Init(current_directory .. 'Data/finale.xml')

--[[
    Sub-Module (not externally accessible): TreeInstrument
]]

--- Organizational class for consolidating articulation staves into a single instrument definition.
---@class TreeInstrument
---@field private full_name FCString
---@field private abrv_name FCString
---@field private uuid string?
---@field private staff_count integer
---@field private overdub_group integer
local TreeInstrument = {}
TreeInstrument.__index = TreeInstrument

--- Constructor for TreeInstrument class.
--- @param full_name? FCString
--- @param abrv_name? FCString
--- @param uuid? string
--- @param staff_count? integer
--- @param overdub_group? integer
--- @return TreeInstrument
function TreeInstrument.New(full_name, abrv_name, uuid, staff_count, overdub_group)
    local self = setmetatable({}, TreeInstrument)
    self.full_name = full_name
    self.abrv_name = abrv_name
    self.uuid = uuid
    self.staff_count = staff_count or 1
    self.overdub_group = overdub_group or 0
    self:AddToList()
    return self
end

-- Adds the TreeInstrument object being called to the Assign Articulation Staves' global instruments table.
function TreeInstrument:AddToList()
    if self.full_name ~= nil and self.abrv_name ~= nil and self.uuid ~= nil then
        instruments[#instruments+1] = self
    end
end

--- Returns the full name of the instrument as an FCString object.
--- @return FCString
function TreeInstrument:CreateFullNameString()
    return finale.FCString(self.full_name.LuaString)
end

--- Returns the abbreviated name of the instrument as an FCString object.
--- @return FCString
function TreeInstrument:CreateAbbreviatedNameString()
    return finale.FCString(self.abrv_name.LuaString)
end

--- Returns the UUID of the instrument.
--- @return string
function TreeInstrument:GetUUID()
    return self.uuid
end

--- Returns the number of staves spanned/required by the instrument.
--- @return integer
function TreeInstrument:GetStaffCount()
    return self.staff_count
end

--- Returns the overdub group that the instrument belongs to.
--- 1+ : The instrument's overdub group.
--- 0  : Instrument does not belong to an overdub group.
--- @return integer
function TreeInstrument:GetOverdubGroup()
    return self.overdub_group
end

--- Sets the full name of the instrument.
--- @param full_name FCString FCString
function TreeInstrument:SaveNewFullNameString(full_name)
    if self.full_name == nil then self.full_name = finale.FCString(full_name.LuaString)
    else self.full_name:SetString(full_name) end
end

--- Sets the abbreviated name of the instrument.
--- @param abrv_name any FCString
function TreeInstrument:SaveNewAbbreviatedNameString(abrv_name)
    if self.abrv_name == nil then self.abrv_name = finale.FCString(abrv_name.LuaString)
    else self.abrv_name:SetString(abrv_name) end
end

--- Sets the UUID of the instrument.
--- @param uuid string
function TreeInstrument:SetUUID(uuid)
    self.uuid = uuid
end

--- Redefines the staff span of the instrument. Should correspond with the UUID of the
--- instrument (e.g. clarinet = 1, piano = 2).
--- @param staff_count integer
function TreeInstrument:SetStaffCount(staff_count)
    self.staff_count = staff_count
end

--- Redefines the overdub group that the instrument belongs to.
--- 0  : instrument does not belong to an overdub group
--- 1+ : overdub group
--- @param overdub_group integer
function TreeInstrument:SetOverdubGroup(overdub_group)
    self.overdub_group = overdub_group
end

--- Returns the class name of the object.
--- @return string
function TreeInstrument.ClassName() return "TreeInstrument" end

--[[
    Helper methods
]]

--- Returns the ItemNo of the first staff belonging to an instrument specified by instrument_number.
--- Order is determined by index of the table: instruments. Returns nil if instrument does not possess
--- any staves.
--- @param instrument_number integer
--- @return integer|nil
local function calc_instrument_start_staff(instrument_number)
    for staff in each(staves) do
        if staff_instrument_assignment[staff.ItemNo] == instrument_number then return staff.ItemNo end
    end
    return nil
end

--- Returns the ItemNo of the last staff belonging to an instrument specified by instrument_number.
--- Order is determined by index of the table: instruments. Returns nil if instrument does not possess
--- any staves.
--- @param instrument_number integer
--- @return integer|nil
local function calc_instrument_end_staff(instrument_number)
    for staff in eachbackwards(staves) do
        if staff_instrument_assignment[staff.ItemNo] == instrument_number then return staff.ItemNo end
    end
    return nil
end

--- Calculates the number of overdub groups with at least one instrument assigned to them.
--- @return integer
local function calc_overdub_total()
    local overdub_total = 0
    for _,instrument in ipairs(instruments) do
        if instrument:GetOverdubGroup() > overdub_total then overdub_total = instrument:GetOverdubGroup() end
    end
    return overdub_total
end

--- Returns the index of the first instrument belonging to a specific overdub group from the table: instruments.
--- @param overdub_group integer
--- @return integer
local function calc_first_instrument_index_in_overdub(overdub_group)
    for i,instrument in ipairs(instruments) do
        if instrument:GetOverdubGroup() == overdub_group then return i end
    end
    return -1
end

--- Returns the index of the last instrument belonging to a specific overdub group from the table: instruments.
--- @param overdub_group integer
--- @return integer
local function calc_last_instrument_index_in_overdub(overdub_group)
    local index = -1
    for i,instrument in ipairs(instruments) do
        if instrument:GetOverdubGroup() == overdub_group then index = i end
    end
    return index
end

--- Calculates the number of instruments belonging to a specific overdub group.
--- @param overdub_group integer
--- @return integer
local function calc_instruments_in_overdub(overdub_group)
    local insts_in_overdub = 0
    for _,instrument in ipairs(instruments) do
        if instrument:GetOverdubGroup() == overdub_group then insts_in_overdub = insts_in_overdub + 1 end
    end
    return insts_in_overdub
end

--- Returns the number of articulation staves in an instrument. Multistaff instruments are treated
--- as separate instruments for each staff.
--- @param instrument_number integer
--- @return integer
local function calc_staves_in_instrument(instrument_number)
    local result = 0
    for staff in each(staves) do
        if staff_instrument_assignment[staff.ItemNo] == instrument_number then result = result + 1 end
    end
    return result
end

--- Returns the number of staves in an overdub group.
--- @param overdub_group integer
--- @return integer
local function calc_staves_in_overdub(overdub_group)
    local first_inst_in_overdub = calc_first_instrument_index_in_overdub(overdub_group)
    local last_inst_in_overdub = calc_last_instrument_index_in_overdub(overdub_group)

    local result = 0
    for staff in each(staves) do
        if staff_instrument_assignment[staff.ItemNo] <= last_inst_in_overdub
            and staff_instrument_assignment[staff.ItemNo] >= first_inst_in_overdub then
            result = result + 1
        end
    end

    return result
end

--- Returns true if the instrument is the first in its overdub group. Otherwise, returns false.
--- @param instrument_number integer
--- @return boolean
local function calc_is_instrument_first_in_overdub(instrument_number)
    local overdub_group = instruments[instrument_number]:GetOverdubGroup()
    if overdub_group ~= 0 then
        if instruments[instrument_number-1] == nil or
            overdub_group ~= instruments[instrument_number-1]:GetOverdubGroup() then return true
        end
    end
    return false
end

--- Returns the position of an articulation staff within its instrument. Order is determined by
--- index of the table: instruments.
--- @param staff_number integer ItemNo of the articulation staff. 
--- @return integer
local function calc_staff_pos_in_instrument(staff_number)
    local instrument_number = staff_instrument_assignment[staff_number]
    local result = 0
    for staff in each(staves) do
        if staff.ItemNo <= staff_number and staff_instrument_assignment[staff.ItemNo] == instrument_number then
            result = result + 1
        end
    end

    return result
end

--- Launches the New Instrument Dialog. Takes one parameter: the instrument ID if editing an instrument. (TODO)
--- @param instrument_id? integer
--- @return integer?
local function display_new_instrument_dialog(instrument_id)

    -- TODO: Edit button will pass an instrument argument. Create method to import instrument data to new_instrument.
    -- If instrument argument ~= nil, user presses Ok, and the data is valid, save the new instrument info to the original instruments table index.

    New_Instrument_Dialog = finale.FCCustomLuaWindow()
    local str = finale.FCString()

    str.LuaString = "Add Instrument"
    New_Instrument_Dialog:SetTitle(str)

    local choose_instrument_static = New_Instrument_Dialog:CreateStatic(0, 0)
    str.LuaString = "Choose an instrument."
    choose_instrument_static:SetText(str)
    choose_instrument_static:SetWidth(200)

    local search_edit = New_Instrument_Dialog:CreateEdit(0, 15)
    search_edit:SetWidth(175)

    local multistaff_warning_static = New_Instrument_Dialog:CreateStatic(400, 19)
    multistaff_warning_static:SetWidth(50)

    local filter_listbox = New_Instrument_Dialog:CreateListBox(0, 37)
    filter_listbox:SetWidth(150)
    filter_listbox:SetHeight(200)
    filter_listbox:SetStrings(finale_xml_parser:CreateFilterStrings())
    local family_listbox = New_Instrument_Dialog:CreateListBox(150, 37)
    family_listbox:SetWidth(150)
    family_listbox:SetHeight(200)
    local instrument_listbox = New_Instrument_Dialog:CreateListBox(300, 37)
    instrument_listbox:SetWidth(150)
    instrument_listbox:SetHeight(200)

    local instructions_static = New_Instrument_Dialog:CreateStatic(0, 249)
    str.LuaString = "Define instrument parameters."
    instructions_static:SetText(str)
    instructions_static:SetWidth(200)

    --TODO: Replace with prompt in order to facilitate special characters
    local full_name_static = New_Instrument_Dialog:CreateStatic(0, 279)
    str.LuaString = "Full Name"
    full_name_static:SetText(str)
    full_name_static:SetWidth(100)
    local full_name_edit = New_Instrument_Dialog:CreateEdit(0, 294)
    full_name_edit:SetWidth(205)

    local abrv_name_static = New_Instrument_Dialog:CreateStatic(0, 324)
    str.LuaString = "Abbreviated Name"
    abrv_name_static:SetText(str)
    abrv_name_static:SetWidth(100)
    local abrv_name_edit = New_Instrument_Dialog:CreateEdit(0, 339)
    abrv_name_edit:SetWidth(205)

    New_Instrument_Dialog:CreateVerticalLine(225, 274, 110)

    local todo_static = New_Instrument_Dialog:CreateStatic(260, 304)
    str.LuaString = "Addl. parameters to come. . . "
    todo_static:SetText(str)
    todo_static:SetWidth(200)

    local new_instrument = TreeInstrument.New()

    --- Sets the selected item of the family listbox based on a LuaString rather than an integer index.
    --- @param family_name string
    local function set_family_listbox_from_string(family_name)
        --Loop through the names of all of the items in family listbox. If it equals family_name, set it as the selection
        for i=0, family_listbox:GetCount() do
            family_listbox:GetItemText(i, str)
            if str.LuaString == family_name then
                family_listbox:SetSelectedItem(i)
                return
            end
        end
        family_listbox:SetSelectedItem(0)
    end

    -- Loads instrument data into new_instrument and sets the controls in the New Instrument dialog.
    local function fill_instrument_info()
        -- Load instrument data into assign_articulation_staves::TreeInstrument
        local visible_instruments = finale_xml_parser:GetVisibleInstrumentsTable()
        local instrument_id_to_load = visible_instruments[instrument_listbox:GetSelectedItem() + 1]
        if instrument_id_to_load == nil then return end
        finale_xml_parser:LoadInstrumentFromXML(instrument_id_to_load, new_instrument)

        --Set controls in New Instrument dialog.
        str = new_instrument:CreateFullNameString()
        full_name_edit:SetText(str)
        str = new_instrument:CreateAbbreviatedNameString()
        abrv_name_edit:SetText(str)
        local staff_count = new_instrument:GetStaffCount()
        if staff_count == 1 then
            str.LuaString = ""
        else
            str.LuaString = "(" .. staff_count .. " Staves)"
        end
        multistaff_warning_static:SetText(str)
    end

    New_Instrument_Dialog:RegisterHandleControlEvent(search_edit,
        function()
            family_listbox:SetSelectedItem(-1)
            search_edit:GetText(str)
            instrument_listbox:SetStrings(finale_xml_parser:CreateInstrumentStrings(filter_listbox:GetSelectedItem() + 1, 0, str.LuaString))
            family_listbox:SetStrings(finale_xml_parser:CreateFamilyStrings())
        end
    )

    -- Update listboxes when a new filter is selected.
    New_Instrument_Dialog:RegisterHandleControlEvent(filter_listbox,
        function()
            family_listbox:GetItemText(family_listbox:GetSelectedItem(), str)
            local selected_family = str.LuaString -- Stores the previously selected family...
            local family_ID = finale_xml_parser:FindFamily(selected_family)
            search_edit:GetText(str)
            local search_filter = str.LuaString
            local instrument_strings = finale_xml_parser:CreateInstrumentStrings(filter_listbox:GetSelectedItem() + 1, family_ID, search_filter)
            if instrument_strings:GetCount() > 0 then
                instrument_listbox:SetStrings(instrument_strings)
            else
                instrument_strings = finale_xml_parser:CreateInstrumentStrings(filter_listbox:GetSelectedItem() + 1, 0, search_filter)
            end

            family_listbox:SetStrings(finale_xml_parser:CreateFamilyStrings())
            set_family_listbox_from_string(selected_family) -- ...and attempts to reselect it.
        end
    )

    -- Update instrument listbox when a new family is selected.
    New_Instrument_Dialog:RegisterHandleControlEvent(family_listbox,
        function()
            family_listbox:GetItemText(family_listbox:GetSelectedItem(), str)
            local selected_family = str.LuaString
            local family_ID = finale_xml_parser:FindFamily(selected_family)
            search_edit:GetText(str)
            local search_filter = str.LuaString
            instrument_listbox:SetStrings(finale_xml_parser:CreateInstrumentStrings(filter_listbox:GetSelectedItem() + 1, family_ID, search_filter))
        end
    )

    New_Instrument_Dialog:RegisterHandleControlEvent(instrument_listbox, fill_instrument_info)

    -- Technical necessity in order to display instrument and family names in their respective listboxes when
    -- the window opens.
    New_Instrument_Dialog:RegisterInitWindow(
        function()
            instrument_listbox:SetStrings(finale_xml_parser:CreateInstrumentStrings(filter_listbox:GetSelectedItem() + 1, 1, ""))
            family_listbox:SetStrings(finale_xml_parser:CreateFamilyStrings())
        end
    )

    New_Instrument_Dialog:CreateOkButton()
    New_Instrument_Dialog:CreateCancelButton()
    local result = New_Instrument_Dialog:ExecuteModal(Main_Dialog)

    if result == 1 then
        if new_instrument:GetUUID() == nil then return end
        if overdub_display == 0 or calc_instruments_in_overdub(overdub_display) == 0 then
            -- Standard Instrument Creation --
            local full_name_result, abrv_name_result = finale.FCString(), finale.FCString()
            full_name_edit:GetText(full_name_result)
            abrv_name_edit:GetText(abrv_name_result)
            new_instrument:SaveNewFullNameString(full_name_result)
            new_instrument:SaveNewAbbreviatedNameString(abrv_name_result)
            if new_instrument:GetStaffCount() > 1 then new_instrument:SetUUID(finale.FFUUID_UNKNOWN) end
            new_instrument:SetOverdubGroup(overdub_display)
            for _=1, new_instrument:GetStaffCount() do
                new_instrument:AddToList()
            end
        else
            -- Handle Placing Instrument Right After Previous in Overdub Group --
            local last_inst_index = calc_last_instrument_index_in_overdub(overdub_display)
            local temp_list = {}
            for i = last_inst_index + 1, #instruments do
                temp_list[i - last_inst_index] = instruments[i]
                instruments[i] = nil
            end
            local full_name_result, abrv_name_result = finale.FCString(), finale.FCString()
            full_name_edit:GetText(full_name_result)
            abrv_name_edit:GetText(abrv_name_result)
            new_instrument:SaveNewFullNameString(full_name_result)
            new_instrument:SaveNewAbbreviatedNameString(abrv_name_result)
            if new_instrument:GetStaffCount() > 1 then new_instrument:SetUUID(finale.FFUUID_UNKNOWN) end
            new_instrument:SetOverdubGroup(overdub_display)
            for _=1, new_instrument:GetStaffCount() do
                new_instrument:AddToList()
            end

            for i=1,#temp_list do
                instruments[last_inst_index + new_instrument:GetStaffCount() + i] = temp_list[i]
            end

            for staff in each(staves) do
                if staff_instrument_assignment[staff.ItemNo] > last_inst_index then
                    staff_instrument_assignment[staff.ItemNo] = staff_instrument_assignment[staff.ItemNo] + new_instrument:GetStaffCount()
                end
            end
        end
        return result
    end
end

--[[
            PHASE 1: GUI
]]

-- Method for interpreting groups in the document. If groups are determined to be
-- either indicative of an instrument or an overdub group, they are organized as such
-- upon the opening of the dialog. It is necessary to run this method in order for
-- PHAssignStaves to work.
function PHAssignStaves.Initialize()
    midi.LoadStaves(staves)
    for staff in each(staves) do
        staff_instrument_assignment[staff.ItemNo] = -1
    end

    local groups = finale.FCGroups()
    groups:LoadAll()

    -- Predict instruments.
    for group in each(groups) do
        if midi.IsValidInstrument(group) then
            local group_staves = midi.GetStavesFromGroup(group)
            local model_UUID = group_staves:GetItemAt(0):GetInstrumentUUID()
            TreeInstrument.New(group:CreateTrimmedFullNameString(), group:CreateAbbreviatedNameString(), model_UUID, 1, 0)
            for staff in each(group_staves) do
                staff_instrument_assignment[staff.ItemNo] = #instruments
            end
        elseif midi.IsValidMultistaffDetectionGroup(group) then
            local french_display_group = midi.GetMultistaffDisplayGroup(group)
            if french_display_group == nil then goto continue5 end

            local multistaff_staff_count, create_new_instruments = midi.CalcMultistaffStaffCount(group)
            if multistaff_staff_count == nil or create_new_instruments == false then goto continue5 end

            -- Create new instruments for multistaff groups without predefined subgroups for RH, LH, etc.
            for i=1, multistaff_staff_count do
                local full_name = french_display_group:CreateTrimmedFullNameString()
                local abrv_name = french_display_group:CreateAbbreviatedNameString()
                local uuid = midi.GetMultistaffUUID(group)
                if uuid == nil then error("Invalid multistaff data group.") end
                abrv_name:TrimEnigmaFontTags()
                local initial_staff_address = 0
                for staff in each(staves) do
                    if staff.ItemNo == group:GetStartStaff() then break end
                    initial_staff_address = initial_staff_address + 1
                end
                TreeInstrument.New(full_name, abrv_name, uuid, multistaff_staff_count, 0)
                staff_instrument_assignment[staves:GetItemAt(initial_staff_address + i - 1).ItemNo] = #instruments
            end
            ::continue5::
        end
    end

    -- Returns a table of instrument_id numbers pointing to TreeInstruments in the instruments table
    -- that possess the staves passed through as an argument. Takes an FCStaves object as its parameter.
    local function get_instruments_from_staves(staves)
        local result = {}
        for staff in each(staves) do
            local instrument_id = staff_instrument_assignment[staff.ItemNo]
            local add_id = true
            if instrument_id == -1 then add_id = false end
            for i=1, #result do
                if result[i] == instrument_id then add_id = false end
            end

            if add_id then result[#result+1] = instrument_id end
        end
        table.sort(result)
        return result
    end

    -- Predict multistaff instruments.
    for group in each(groups) do
        if midi.IsValidMultistaffDetectionGroup(group) then
            local french_display_group = midi.GetMultistaffDisplayGroup(group)
            if french_display_group == nil then goto continue4 end

            local multistaff_staff_count, create_new_instruments = midi.CalcMultistaffStaffCount(group)
            if multistaff_staff_count == nil or create_new_instruments == true then goto continue4 end
            
            -- Reassign variables of existing instruments.
            for _, instrument_id in ipairs(get_instruments_from_staves(midi.GetStavesFromGroup(group))) do
                local full_name = french_display_group:CreateTrimmedFullNameString()
                local abrv_name = french_display_group:CreateAbbreviatedNameString()
                local uuid = midi.GetMultistaffUUID(group)
                if uuid == nil then uuid = finale.FFUUID_UNKNOWN end
                abrv_name:TrimEnigmaFontTags()

                instruments[instrument_id]:SaveNewFullNameString(full_name)
                instruments[instrument_id]:SaveNewAbbreviatedNameString(abrv_name)
                instruments[instrument_id]:SetUUID(uuid)
                instruments[instrument_id]:SetStaffCount(multistaff_staff_count)
            end

            ::continue4::
        end
    end

    -- Predict overdub groups.
    local overdub_index = 1
    for group in each(groups) do
        if midi.IsOverdub(group) then
            local start_staff = group:GetStartStaff()
            local end_staff = group:GetEndStaff()
            local start_instrument = staff_instrument_assignment[start_staff]
            local end_instrument = staff_instrument_assignment[end_staff]
            for instrument = start_instrument, end_instrument do
                instruments[instrument]:SetOverdubGroup(overdub_index)
            end
            overdub_index = overdub_index + 1
        end
    end
end

--- Launches the main dialog for articulation assignment/instrument definition.
--- @return integer
--- - 0 : If the user closes the window.
--- - 1 : If the user clicks Ok.
function PHAssignStaves.DisplayDialog()

    Main_Dialog = finale.FCCustomLuaWindow()

    local str = finale.FCString()

    str.LuaString = "Assign Instruments"
    Main_Dialog:SetTitle(str)

    local instrument_staves_static = Main_Dialog:CreateStatic(0,0)
    str.LuaString = "Instrument Staves"
    instrument_staves_static:SetText(str)

    local instrument_staves_tree = Main_Dialog:CreateTree(0, 20)
    instrument_staves_tree:SetWidth(150)
    instrument_staves_tree:SetHeight(400)

    local add_instrument_button = Main_Dialog:CreateButton(0, 430)
    str.LuaString = "Add Instrument"
    add_instrument_button:SetText(str)
    add_instrument_button:SetWidth(100)

    local move_up_button = Main_Dialog:CreateButton(102,430)
    str.LuaString = "↑"
    move_up_button:SetText(str)
    move_up_button:SetWidth(23)

    local move_down_button = Main_Dialog:CreateButton(127,430)
    str.LuaString = "↓"
    move_down_button:SetText(str)
    move_down_button:SetWidth(23)

    local add_overdub_button = Main_Dialog:CreateButton(0,458)
    str.LuaString = "Add Overdub"
    add_overdub_button:SetText(str)
    add_overdub_button:SetWidth(100)

    local previous_overdub_button = Main_Dialog:CreateButton(102,458)
    str.LuaString = "←"
    previous_overdub_button:SetText(str)
    previous_overdub_button:SetWidth(23)

    local next_overdub_button = Main_Dialog:CreateButton(127,458)
    str.LuaString = "→"
    next_overdub_button:SetText(str)
    next_overdub_button:SetWidth(23)

    local expand_all = Main_Dialog:CreateCheckbox(0,498)
    str.LuaString = "Expand All"
    expand_all:SetText(str)

    local add_staff_button = Main_Dialog:CreateButton(160,150)
    str.LuaString = "< Add"
    add_staff_button:SetText(str)
    add_staff_button:SetWidth(100)

    local remove_staff_button = Main_Dialog:CreateButton(160,180)
    str.LuaString = "Remove >"
    remove_staff_button:SetText(str)
    remove_staff_button:SetWidth(100)

    local art_staff_static = Main_Dialog:CreateStatic(270,0)
    str.LuaString = "Articulation Staves"
    art_staff_static:SetText(str)

    local art_staff_list_box = Main_Dialog:CreateListBox(270, 20)
    art_staff_list_box:SetWidth(150)
    art_staff_list_box:SetHeight(400)

    -- Returns the ItemNo of an FCStaff based on its reference in the articulation listbox control.
    -- Index of art_list_number is 0-based. Returns nil if not found.
    local function calc_staff_number_from_articulation_list(art_list_number)
        local art_list_index = 0
        for staff in each(staves) do
            if staff_instrument_assignment[staff.ItemNo] == -1 then
                if art_list_index == art_list_number then return staff.ItemNo end
                art_list_index = art_list_index + 1
            end
        end
        return nil
    end

    -- Returns the ItemNo of an FCStaff based on its TreeInstrument (1-based index) and child location in that instrument's tree node (0-based index).
    -- If the instrument is a multistaff instrument, the child_number can automatically account for
    -- any staff/TreeInstrument in that multistaff instrument.
    local function calc_staff_number_from_instrument(instrument_number, child_number)
        if instruments[instrument_number]:GetStaffCount() > 1 then
            local art_staves_in_first_staff = calc_staves_in_instrument(instrument_number)
            while art_staves_in_first_staff <= child_number do
                instrument_number = instrument_number + 1
                child_number = child_number - art_staves_in_first_staff
                art_staves_in_first_staff = calc_staves_in_instrument(instrument_number)
            end
        end
        local inst_child_index = 0
        for staff in each(staves) do
            if staff_instrument_assignment[staff.ItemNo] == instrument_number then
                if child_number == inst_child_index then return staff.ItemNo end
                inst_child_index = inst_child_index + 1
            end
        end
    end

    -- Returns the table index of an instrument based on its location in the tree control.
    local function calc_instrument_index_from_node_index(node_index)
        -- Is there an easier way to do this using the new method calc_instrument_length_of_node?
        if overdub_display == 0 then
            -- For calculating the instrument index when all instruments are displayed.
            local instrument_index = 1
            for _ = 0, node_index - 1 do
                local instrument = instruments[instrument_index]
                if instrument:GetOverdubGroup() == 0 then
                    instrument_index = instrument_index + instrument:GetStaffCount()
                else
                    instrument_index = instrument_index + calc_instruments_in_overdub(instrument:GetOverdubGroup())
                end
            end
            return instrument_index
        else
            -- For calculating the instrument index when an overdub group is displayed.
            local result = calc_first_instrument_index_in_overdub(overdub_display)
            for _ = 0, node_index - 1 do
                result = result + instruments[result]:GetStaffCount()
            end
            return result
        end
    end
    
    -- Removes an instrument from the list of instruments and reassigns staves accordingly.
    local function remove_instrument(instrument_number)
        for staff in each(staves) do
            if staff_instrument_assignment[staff.ItemNo] == instrument_number then staff_instrument_assignment[staff.ItemNo] = -1
            elseif staff_instrument_assignment[staff.ItemNo] > instrument_number then staff_instrument_assignment[staff.ItemNo] = staff_instrument_assignment[staff.ItemNo] - 1 end
        end
        for i=instrument_number,#instruments do
            instruments[i] = instruments[i+1]
        end
    end

    -- Updates the instrument tree and articulation staff listbox controls.
    function RedrawLists()
        -- Redraw Instrument List --
        instrument_staves_tree:Clear()
        
        -- Adds an instrument node to the tree control.
        local function add_instrument_to_tree(instrument_index, instrument)
            local instrument_node = instrument_staves_tree:AddNode(nil, true, instrument:CreateFullNameString())
            local instrument_staff_count = instrument:GetStaffCount()
            for staff in each(staves) do
                if instrument_staff_count >= 1 then
                    if staff_instrument_assignment[staff.ItemNo] == instrument_index then
                        local art_staff_str = staff:CreateTrimmedFullNameString()
                        if instrument_staff_count > 1 then
                            art_staff_str:AppendLuaString(" (RH)")
                        end
                        instrument_staves_tree:AddNode(instrument_node, false, art_staff_str)
                        goto continue3
                    end
                end
                if instrument_staff_count >= 2 then
                    if staff_instrument_assignment[staff.ItemNo] == instrument_index + 1 then
                        local art_staff_str = staff:CreateTrimmedFullNameString()
                        art_staff_str:AppendLuaString(" (LH)")
                        instrument_staves_tree:AddNode(instrument_node, false, art_staff_str)
                        goto continue3
                    end
                end
                if instrument_staff_count == 3 then
                    if staff_instrument_assignment[staff.ItemNo] == instrument_index + 2 then
                        local art_staff_str = staff:CreateTrimmedFullNameString()
                        art_staff_str:AppendLuaString(" (Ped.)")
                        instrument_staves_tree:AddNode(instrument_node, false, art_staff_str)
                    end
                end
                ::continue3::
            end
        end

        if overdub_display == 0 then str.LuaString = "Instrument Staves"
        elseif calc_overdub_total() <= 1 and overdub_display == 1 then str.LuaString = "Overdub"
        else str.LuaString = "Overdub " .. overdub_display end
        instrument_staves_static:SetText(str)

        if overdub_display == 0 then
            local multistaff_inst_skip_index = 0
            for i,instrument in ipairs(instruments) do
                if instrument:GetOverdubGroup() == 0 then
                    if multistaff_inst_skip_index == 0 then
                        add_instrument_to_tree(i,instrument)
                        multistaff_inst_skip_index = instrument:GetStaffCount() - 1
                    else
                        multistaff_inst_skip_index = multistaff_inst_skip_index - 1
                    end
                else -- Combine overdub groups
                    if calc_is_instrument_first_in_overdub(i) then
                        local overdub_display_name = "Overdub"
                        if calc_overdub_total() > 1 then overdub_display_name = "Overdub " .. instrument:GetOverdubGroup() end
                        str.LuaString = overdub_display_name
                        instrument_staves_tree:AddNode(nil, true, str)
                    end
                end
            end
        else -- Display overdub group
            local multistaff_inst_skip_index = 0
            for i, instrument in ipairs(instruments) do
                if instrument:GetOverdubGroup() == overdub_display then
                    if multistaff_inst_skip_index == 0 then
                        add_instrument_to_tree(i,instrument)
                        multistaff_inst_skip_index = instrument:GetStaffCount() - 1
                    else
                        multistaff_inst_skip_index = multistaff_inst_skip_index - 1
                    end
                end
            end
        end

        if expand_all:GetCheck() == 1 then
            instrument_staves_tree:ExpandAllContainers()
        end

        -- Redraw Articulation List --
        local art_list_selected_item = art_staff_list_box:GetSelectedItem()
        art_staff_list_box:Clear()
        
        for staff in each(staves) do
            if staff_instrument_assignment[staff.ItemNo] == -1 then
                art_staff_list_box:AddString(staff:CreateTrimmedFullNameString())
            end
        end
        if art_staff_list_box:GetCount() > art_list_selected_item then art_staff_list_box:SetSelectedItem(art_list_selected_item) end
    end

    local function calc_instrument_length_of_node(node_index)
        local instrument_index = calc_instrument_index_from_node_index(node_index)
        if instrument_index == -1 then return 0 end
        local instrument = instruments[instrument_index]
        if instrument:GetOverdubGroup() == overdub_display then return instrument:GetStaffCount()
        else return calc_instruments_in_overdub(instrument:GetOverdubGroup()) end
    end

    -- Swaps the position of two adjacent instrument nodes in the tree control. Based on the 0-based indices of the two tree nodes from instrument_staves_tree.
    -- You can only swap root nodes, not articulation staves.
    local function swap_adjacent_instrument_nodes(first_node_index, second_node_index)
        -- Check that the nodes are adjacent.
        if math.abs(first_node_index - second_node_index) ~= 1 then return end
        local top_node_index = math.min(first_node_index, second_node_index)
        local bottom_node_index = math.max(first_node_index, second_node_index)

        local first_instrument_index = calc_instrument_index_from_node_index(top_node_index)
        local second_instrument_index = calc_instrument_index_from_node_index(bottom_node_index)

        if first_instrument_index == -1 or second_instrument_index == -1 then return end

        local first_node_length = calc_instrument_length_of_node(top_node_index)
        local second_node_length = calc_instrument_length_of_node(bottom_node_index)

        if first_node_length == 0 or second_node_length == 0 then return end

        print("First (Top): ", first_instrument_index, "(".. first_node_length.. ")")
        print("Second (Bottom): ", second_instrument_index, "(".. second_node_length.. ")")

        -- Reassign articulation staves to new order.
        for staff in each(staves) do
            if staff_instrument_assignment[staff.ItemNo] >= first_instrument_index and staff_instrument_assignment[staff.ItemNo] < first_instrument_index + first_node_length then
                staff_instrument_assignment[staff.ItemNo] = staff_instrument_assignment[staff.ItemNo] + second_node_length
            elseif staff_instrument_assignment[staff.ItemNo] >= second_instrument_index and staff_instrument_assignment[staff.ItemNo] < second_instrument_index + second_node_length then
                staff_instrument_assignment[staff.ItemNo] = staff_instrument_assignment[staff.ItemNo] - first_node_length
            end
        end

        -- Store bottom node in a temporary table
        local temp_inst_table = {}
        for i=1, second_node_length do
            temp_inst_table[i] = instruments[second_instrument_index + i - 1]
            instruments[second_instrument_index + i - 1] = nil
        end

        -- Move top node to bottom node
        for i=first_node_length, 1, -1 do
            instruments[first_instrument_index + i - 1 + second_node_length] = instruments[first_instrument_index + i - 1]
        end

        -- Move bottom node to top node from temporary table
        for i=1, #temp_inst_table do
            instruments[first_instrument_index + i - 1] = temp_inst_table[i]
        end
    end

    Main_Dialog:RegisterHandleControlEvent(add_instrument_button,
        function()
            local result = display_new_instrument_dialog()
            if result == 1 then
                RedrawLists()
                instrument_staves_tree:SetSelectedNode(instrument_staves_tree:GetRootItemAt(instrument_staves_tree:GetRootCount() - 1))
            end
        end
    )

    Main_Dialog:RegisterHandleControlEvent(move_up_button,
        function()
            local selected_node = instrument_staves_tree:GetSelectedNode()
            if selected_node == nil or not selected_node:GetIsContainer() then return end
            local selected_index = selected_node:GetIndex()
            if selected_index == 0 then return end
            swap_adjacent_instrument_nodes(selected_index - 1, selected_index)

            RedrawLists()
            instrument_staves_tree:SetSelectedNode(instrument_staves_tree:GetRootItemAt(selected_index - 1))
        end
    )

    Main_Dialog:RegisterHandleControlEvent(move_down_button,
        function()
            local selected_node = instrument_staves_tree:GetSelectedNode()
            if selected_node == nil or not selected_node:GetIsContainer() then return end
            local selected_index = selected_node:GetIndex()
            if selected_index == instrument_staves_tree:GetRootCount() - 1 then return end
            swap_adjacent_instrument_nodes(selected_index, selected_index + 1)

            RedrawLists()
            instrument_staves_tree:SetSelectedNode(instrument_staves_tree:GetRootItemAt(selected_index + 1))
        end
    )

    Main_Dialog:RegisterHandleControlEvent(add_overdub_button,
        function()
            overdub_display = calc_overdub_total() + 1
            RedrawLists()
        end
    )
    
    Main_Dialog:RegisterHandleControlEvent(previous_overdub_button,
        function()
            overdub_display = overdub_display - 1
            if overdub_display < 0 then overdub_display = calc_overdub_total() end
            RedrawLists()
        end
    )
    
    Main_Dialog:RegisterHandleControlEvent(next_overdub_button,
        function()
            overdub_display = overdub_display + 1
            if overdub_display > calc_overdub_total() then overdub_display = 0 end
            RedrawLists()
        end
    )

    Main_Dialog:RegisterHandleControlEvent(expand_all,
        function()
            if expand_all:GetCheck() == 1 then
                instrument_staves_tree:ExpandAllContainers()
            else
                instrument_staves_tree:CollapseAllContainers()
            end
        end
    )

    Main_Dialog:RegisterHandleControlEvent(add_staff_button,
        function()
            local selected_node = instrument_staves_tree:GetSelectedNode()
            if selected_node == nil then
                -- Inform the user if no instruments in tree.
                if instrument_staves_tree:GetRootCount() == 0 then
                    finenv.UI():AlertInfo("Please start by adding an instrument.", "Combine Staves")
                end
                return
            end
            local instrument = instruments[calc_instrument_index_from_node_index(selected_node:GetIndex())]
            if art_staff_list_box:GetSelectedItem() == -1 or
                instrument_staves_tree:GetSelectedNode() == nil or
                instrument_staves_tree:GetSelectedNode():GetIsContainer() == false or
                (overdub_display == 0 and instrument:GetOverdubGroup() ~= 0) then return
            end

            -- Add Articulation Staff to Instrument Dialog --
            --parser:DebugDump()
            local articulation, instrument_offset = art_xml_parser:DisplayDialog(instrument:GetStaffCount())
            if articulation == nil then return
            else
                local staff_no = calc_staff_number_from_articulation_list(art_staff_list_box:GetSelectedItem())
                if staff_no == nil then return end
                staff_articulation[staff_no] = articulation

                local listbox_selected_index = art_staff_list_box:GetSelectedItem()
                local instrument_staves_tree_selected_index = instrument_staves_tree:GetSelectedNode():GetIndex()
                staff_instrument_assignment[staff_no] = calc_instrument_index_from_node_index(instrument_staves_tree_selected_index) + instrument_offset
                RedrawLists()
                instrument_staves_tree:SetSelectedNode(instrument_staves_tree:GetRootItemAt(instrument_staves_tree_selected_index))
                instrument_staves_tree:ExpandNode(instrument_staves_tree:GetRootItemAt(instrument_staves_tree_selected_index))
                art_staff_list_box:SetSelectedItem(listbox_selected_index)
            end
        end
    )

    Main_Dialog:RegisterHandleControlEvent(remove_staff_button,
        function()
            local selected_node = instrument_staves_tree:GetSelectedNode()
            if selected_node == nil then return end
            if selected_node:GetIsContainer() then
                local selected_node_index = selected_node:GetIndex()
                local instrument_number = calc_instrument_index_from_node_index(selected_node_index) -- Selected instrument.
                local instrument_overdub_group = instruments[instrument_number]:GetOverdubGroup() -- Selected instrument's overdub group.
                
                if overdub_display == 0 and instrument_overdub_group > 0 then
                    -- Remove Overdub Group --
                    for i=#instruments,1,-1 do
                        local instrument = instruments[i]
                        if instrument:GetOverdubGroup() == instrument_overdub_group then
                            remove_instrument(instrument_number)
                        elseif instrument:GetOverdubGroup() > instrument_overdub_group then
                            instrument:SetOverdubGroup(instrument:GetOverdubGroup() - 1)
                        end
                    end
                else
                    -- Remove Instrument from List --
                    for i = instruments[instrument_number]:GetStaffCount() - 1, 0, -1 do
                        remove_instrument(instrument_number + i)
                    end
                end
                RedrawLists()
            else
                -- Remove Articulation Staff from Instrument --
                local selected_node_index = selected_node:GetIndex()
                local parent_node_index = selected_node:GetParentNode():GetIndex()
                local instrument_index = calc_instrument_index_from_node_index(parent_node_index)
                staff_instrument_assignment[calc_staff_number_from_instrument(instrument_index, selected_node_index)] = -1
                RedrawLists()
                instrument_staves_tree:ExpandNode(instrument_staves_tree:GetRootItemAt(parent_node_index))
                instrument_staves_tree:SetSelectedNode(instrument_staves_tree:GetRootItemAt(parent_node_index))
            end
        end
    )

    Main_Dialog:RegisterInitWindow( RedrawLists )
    Main_Dialog:CreateOkButton()
    Main_Dialog:CreateCancelButton()
    return(Main_Dialog:ExecuteModal(nil))
end

--[[
            PHASE 2: Functionality
]]

-- Organizes the score based on the instrument assignments made in the main dialog.
-- Calls the following methods in order: ReorderStaves, AssignUUIDs, CreateTemporaryDisplayGroups.
function PHAssignStaves.OrganizeScore()
    PHAssignStaves.ReorderStaves()
    PHAssignStaves.AssignUUIDs()
    PHAssignStaves.CreateTemporaryDisplayGroups()
end

-- Assigns UUIDs to staves based on the UUID of their instrument determined in the main dialog.
function PHAssignStaves.AssignUUIDs()
    for staff in each(staves) do
        if staff_instrument_assignment[staff.ItemNo] ~= -1 then
            staff:SetInstrumentUUID(instruments[staff_instrument_assignment[staff.ItemNo]]:GetUUID())
        end
    end
end

-- Reorders staves based on their instrument assignments.
function PHAssignStaves.ReorderStaves()-- Perhaps a temporary solution. Will reorder staves that have been manually moved by the user to the order in which they were created.
    local function articulation_staves_are_ordered()
        local current_highest_instrument = 1
        for staff in each(staves) do
            if ((staff_instrument_assignment[staff.ItemNo] > current_highest_instrument and current_highest_instrument > -1) or
                (staff_instrument_assignment[staff.ItemNo] == -1 and current_highest_instrument > -1)) then
                current_highest_instrument = staff_instrument_assignment[staff.ItemNo]
            elseif (staff_instrument_assignment[staff.ItemNo] < current_highest_instrument and current_highest_instrument > -1) or
                (staff_instrument_assignment[staff.ItemNo] > current_highest_instrument and current_highest_instrument == -1) then
                return false
            end
        end
        -- Staff order needs to be adjusted if any of the instrument definitions are empty.
        for i=1,#instruments do
            local empty = true
            for staff in each(staves) do
                if staff_instrument_assignment[staff.ItemNo] == i then
                    empty = false
                    goto continue2
                end
            end
            ::continue2::
            if empty then return false end
        end
        return true
    end

    --- Applies all of the actions associated with the XMLArticulation object [articulation] to the
    --- staff specified by the ItemNo [staff_number].
    --- @param articulation XMLArticulation
    --- @param staff_number integer
    local function apply_articulations(articulation, staff_number)
        if articulation == nil or staff_number < 1 then return end
        local art_handler = ArticulationXMLHandler.Create()
        art_handler:SetStaff(staff_number)
        art_handler:ApplyArticulation(articulation)
    end
    
    local staves_are_ordered = articulation_staves_are_ordered()
    if staves_are_ordered then
        for staff in each(staves) do
            apply_articulations(staff_articulation[staff.ItemNo], staff.ItemNo)
        end
        return
    end

    local staves_count = staves:GetItemAt(staves:GetCount() - 1).ItemNo

    -- Creates a new staff at the bottom of the document and copies over the contents of the source staff.
    local function append_staff_and_copy_layer(source_staff)
        local source_ID = source_staff.ItemNo
        local dest_ID = finale.FCStaves.Append()
        source_staff:SaveAs(dest_ID)
        staff_instrument_assignment[dest_ID] = staff_instrument_assignment[source_ID]
        staff_articulation[dest_ID] = staff_articulation[source_ID]
        for i=0,3 do
            local note_entry_layer = finale.FCNoteEntryLayer(i, source_ID, 1, -1)
            midi.SendLayerTo(note_entry_layer, dest_ID, i)
        end

        return dest_ID
    end
    
    for i=1, #instruments do
        local empty = true
        for staff in each(staves) do
            if staff_instrument_assignment[staff.ItemNo] == i then
                empty = false
                if i > 1 then
                    local dest_ID = append_staff_and_copy_layer(staff)
                    apply_articulations(staff_articulation[staff.ItemNo], dest_ID)
                elseif i == 1 then
                    apply_articulations(staff_articulation[staff.ItemNo], staff.ItemNo)
                end
            end
        end

        if empty then
            local dest_ID = finale.FCStaves.Append()
            local new_staff = finale.FCStaff()
            new_staff:Load(dest_ID)
            new_staff:SetInstrumentUUID(finale.FFUUID_UNKNOWN)
            new_staff:Save()
            staff_instrument_assignment[dest_ID] = i
            staff_articulation[dest_ID] = nil
        end
    end

    for staff in each(staves) do
        if staff_instrument_assignment[staff.ItemNo] == -1 then
            append_staff_and_copy_layer(staff)
        end
    end

    midi.LoadStaves(staves)
    for staff in eachbackwards(staves) do
        if staff_instrument_assignment[staff.ItemNo] ~= 1 and staff.ItemNo <= staves_count then
            finale.FCStaves.Delete(staff.ItemNo)
        end
    end

    midi.LoadStaves(staves)
    --TODO: Remove All Clef Changes
end

-- Creates temporary staff and group names/styles for the purpose of combination.
function PHAssignStaves.CreateTemporaryDisplayGroups()

    -- Create Temporary Staff Names --
    local fontinfo = finale.FCFontInfo()
    local str = finale.FCString("Times New Roman")
    fontinfo.Size = 8
    fontinfo:SetNameString(str)

	for staff in each(staves) do
        local name_string = fontinfo:CreateEnigmaString()
        local staff_name = staff:CreateTrimmedFullNameString()
        local staff_instrument = instruments[staff_instrument_assignment[staff.ItemNo]]

        if staff_name.LuaString == "" and staff_instrument ~= nil then
            staff_name.LuaString = staff_instrument:CreateFullNameString().LuaString .. " (" .. calc_staff_pos_in_instrument(staff.ItemNo) .. ")"
            staff:SetShowScoreStaffNames(false)
            name_string:AppendString(staff_name)
            staff:SaveNewFullNameString(name_string)
        else
            name_string:AppendString(staff_name)
            staff:SaveFullNameString(name_string)
        end
        
        staff:SaveNewAbbreviatedNameString(name_string)

        --- Specifies the document positioning of a text block containing the staff name.
        --- @param name_position FCStaffNamePosition
        local function set_name_position(name_position)
            name_position.Alignment = finale.TEXTHORIZALIGN_RIGHT
            name_position.Justification = finale.TEXTJUSTIFY_RIGHT
            if staff_instrument ~= nil and staff_instrument:GetStaffCount() > 1 then
                name_position.HorizontalOffset = -43
            else
                name_position.HorizontalOffset = -17
            end
            name_position.VerticalOffset = -68
            name_position:SetUsePositioning(true)
        end

        set_name_position(staff:GetFullNamePosition())
        set_name_position(staff:GetAbbreviatedNamePosition())
        staff:Save()
	end

    -- Remove All Existing Groups --
    local groups = finale.FCGroups()
    groups:LoadAll()
    for group in eachbackwards(groups) do
        group:DeleteData()
    end

    -- Create Overdub Groups --
    local overdub_count = calc_overdub_total()
    for o=1, overdub_count do
        local overdub_fcg = finale.FCGroup()
        local staves_in_overdub = calc_staves_in_overdub(o)
        overdub_fcg:SetStartStaff(calc_instrument_start_staff(calc_first_instrument_index_in_overdub(o)))
        overdub_fcg:SetEndStaff(calc_instrument_end_staff(calc_last_instrument_index_in_overdub(o)))
        overdub_fcg:SetStartMeasure(1)
        overdub_fcg:SetEndMeasure(32767)
        overdub_fcg:SetBracketStyle(finale.GRBRAC_DESK)
        overdub_fcg:SetBracketHorizontalPos(-288)

        if staves_in_overdub == 1 then str.LuaString = '^size(6)'
        elseif staves_in_overdub == 2 then str.LuaString = '^size(10)'
        else str.LuaString = "" end
        str:AppendLuaString('O\rV\rE\rR\rD\rU\rB')
        if overdub_count > 1 then
            str:AppendLuaString('\r^size(3)\r')
            if staves_in_overdub == 1 then str:AppendLuaString('^size(6)')
            elseif staves_in_overdub == 2 then str:AppendLuaString('^size(10)') end
            str:AppendLuaString(o .. '')
        end
        overdub_fcg:SaveNewFullNameBlock(str)
        overdub_fcg:SetFullNameHorizontalOffset(-331)
        overdub_fcg:SetFullNameAlign(finale.TEXTHORIZALIGN_CENTER)
        overdub_fcg:SetFullNameJustify(finale.TEXTJUSTIFY_CENTER)
        overdub_fcg:SetUseFullNamePositioning(true)
        overdub_fcg:SaveNewAbbreviatedNameBlock(str)
        overdub_fcg:SetAbbreviatedNameHorizontalOffset(-331)
        overdub_fcg:SetAbbreviatedNameAlign(finale.TEXTHORIZALIGN_CENTER)
        overdub_fcg:SetAbbreviatedNameJustify(finale.TEXTJUSTIFY_CENTER)
        overdub_fcg:SetUseAbbreviatedNamePositioning(true)
        overdub_fcg:SaveNew(o)
    end

    -- Create Temporary Groups --
    local multistaff_group_count = 0
    local multistaff_inst_skip_index = 0
    for i=1,#instruments do
        local temp_group = finale.FCGroup()
        temp_group:SetStartStaff(calc_instrument_start_staff(i))
        temp_group:SetEndStaff(calc_instrument_end_staff(i))
        temp_group:SetStartMeasure(1)
        temp_group:SetEndMeasure(32767)
        temp_group:SetBracketStyle(finale.GRBRAC_DESK)
        temp_group:SetBracketHorizontalPos(-12)
        
        local staff_name = finale.FCString()
        if instruments[i]:GetStaffCount() > 1 then -- Multistaff Instrument
            fontinfo.Size = 10
            temp_group:SetFullNameHorizontalOffset(-50)
            temp_group:SetAbbreviatedNameHorizontalOffset(-50)
            if multistaff_inst_skip_index == 0 then
                staff_name.LuaString = "RH"

                -- Label multistaff instruments for future reordering.
                local multistaff_data_group = finale.FCGroup()
                multistaff_data_group:SetStartStaff(calc_instrument_start_staff(i))
                multistaff_data_group:SetEndStaff(calc_instrument_end_staff(i + instruments[i]:GetStaffCount() - 1))
                multistaff_data_group:SetStartMeasure(1)
                multistaff_data_group:SetEndMeasure(32767)
                multistaff_data_group:SetBracketStyle(finale.GRBRAC_NONE)
                str.LuaString = "[Multistaff] {" .. instruments[i]:GetUUID() .. "}" --TODO: Replace with new parameter: instrument_id
                multistaff_data_group:SaveNewFullNameBlock(str)
                multistaff_data_group:SetShowGroupName(false)
                multistaff_data_group:SaveNew(overdub_count + #instruments + multistaff_group_count + 1)
                multistaff_group_count = multistaff_group_count + 1
                
                -- Create French brace around multistaff instrument.
                local multistaff_display_group = finale.FCGroup()
                multistaff_display_group:SetStartStaff(calc_instrument_start_staff(i))
                multistaff_display_group:SetEndStaff(calc_instrument_end_staff(i + 1))
                multistaff_display_group:SetStartMeasure(1)
                multistaff_display_group:SetEndMeasure(32767)
                multistaff_display_group:SetBracketStyle(finale.GRBRAC_PIANO)
                multistaff_display_group:SetBracketHorizontalPos(-17)
                multistaff_display_group:SaveNewFullNameBlock(instruments[i]:CreateFullNameString())
                multistaff_display_group:SetFullNameHorizontalOffset(-62)
                multistaff_display_group:SetFullNameAlign(finale.TEXTHORIZALIGN_RIGHT)
                multistaff_display_group:SetFullNameJustify(finale.TEXTJUSTIFY_RIGHT)
                multistaff_display_group:SetUseFullNamePositioning(true)
                multistaff_display_group:SaveNewAbbreviatedNameBlock(instruments[i]:CreateAbbreviatedNameString())
                multistaff_display_group:SetAbbreviatedNameHorizontalOffset(-62)
                multistaff_display_group:SetAbbreviatedNameAlign(finale.TEXTHORIZALIGN_RIGHT)
                multistaff_display_group:SetAbbreviatedNameJustify(finale.TEXTJUSTIFY_RIGHT)
                multistaff_display_group:SetUseAbbreviatedNamePositioning(true)
                multistaff_display_group:SaveNew(overdub_count + #instruments + multistaff_group_count + 1)
                multistaff_group_count = multistaff_group_count + 1

            elseif (multistaff_inst_skip_index == 1 and instruments[i]:GetStaffCount() == 2)
                    or (multistaff_inst_skip_index == 2 and instruments[i]:GetStaffCount() == 3) then
                staff_name.LuaString = "LH"
            elseif (multistaff_inst_skip_index == 1 and instruments[i]:GetStaffCount() == 3) then
                staff_name.LuaString = "Ped."
            end
        else -- Normal Instrument
            fontinfo.Size = 12
            staff_name = instruments[i]:CreateFullNameString()
            temp_group:SetFullNameHorizontalOffset(-17)
            temp_group:SetAbbreviatedNameHorizontalOffset(-17)
        end

        str = fontinfo:CreateEnigmaString()
        staff_name:TrimEnigmaFontTags()
        str:AppendString(staff_name)

        temp_group:SaveNewFullNameBlock(str)
        temp_group:SetFullNameAlign(finale.TEXTHORIZALIGN_RIGHT)
        temp_group:SetFullNameJustify(finale.TEXTJUSTIFY_RIGHT)
        temp_group:SetUseFullNamePositioning(true)
        
        if instruments[i]:GetStaffCount() == 1 then staff_name = instruments[i]:CreateAbbreviatedNameString() end
        str = fontinfo:CreateEnigmaString()
        staff_name:TrimEnigmaFontTags()
        str:AppendString(staff_name)

        temp_group:SaveNewAbbreviatedNameBlock(str)
        temp_group:SetAbbreviatedNameAlign(finale.TEXTHORIZALIGN_RIGHT)
        temp_group:SetAbbreviatedNameJustify(finale.TEXTJUSTIFY_RIGHT)
        temp_group:SetUseAbbreviatedNamePositioning(true)
        temp_group:SaveNew(overdub_count + i)
        if instruments[i]:GetStaffCount() > 1 then
            if multistaff_inst_skip_index == 0 then
                multistaff_inst_skip_index = instruments[i]:GetStaffCount() - 1
            else
                multistaff_inst_skip_index = multistaff_inst_skip_index - 1
            end
        end
    end
end

return PHAssignStaves


--[[ EXECUTION STARTS HERE --

-- PHASE 1 --
initialize()
local success = create_main_ui()

-- PHASE 2 --
if success == 1 then
    reorder_staves()
    assign_instrument_UUIDs()
    create_temporary_groups()
end]]