--[[
-------------------------------------------------------------------------------------------------------

    Copyright (c) 2025 Brendan Weinbaum.
    All rights reserved.

    This module is referenced mainly by the Assign Staves to Instruments subtask. It is responsible for
    reading XML data from plugin definition files as well as providing a dialog for the user to select
    an articulation when assigning staves.

    Declaration order:
    1. Instance fields
    2. Constructor
    3. Helper methods
    4. Interface

-------------------------------------------------------------------------------------------------------
]]

--[[
-------------------------------------------------------------------------------------------------------
    Import Modules and Constants
-------------------------------------------------------------------------------------------------------
]]

local artxml = require "Lib.articulation_xml_lib"
local preset = require "Lib.preset_browser_lib"
local cmath = require "Lib.math_lib"

local DEFAULT_QUARTER_NOTEHEAD_ID = 57504 -- Default quarter notehead symbol ID in Finale.

--[[
-------------------------------------------------------------------------------------------------------

    Global Module: ArticulationXMLParser

    Module encompassing this Lua file. Reads XML data from plugin definition files, the paths of which
    are passed into this module's constructor. In addition, this module provides a dialog for selecting
    an articulation (with its pre-defined actions) and returning a new XMLArticulation (defined in
    articulation_xml_lib) object based on the user's selections. This XMLArticulation object is handled
    in assign_articulation_staves.lua.

-------------------------------------------------------------------------------------------------------
]]

--- @class ArticulationXMLParser
--- @field private plugins XMLPlugin[]
--- @field private paths string[]
local ArticulationXMLParser = {}
ArticulationXMLParser.__index = ArticulationXMLParser

--- Constructor method for ArticulationXMLParser.
--- Requires a table of file paths to XML documents containing plugin information.
--- @param paths string[]
--- @return ArticulationXMLParser
function ArticulationXMLParser.Init(paths)
    local self = setmetatable({}, ArticulationXMLParser)
    self.paths = paths
    self.plugins = {}

    for _, path in ipairs(paths) do
        -- Load XML Document
        local doc = tinyxml2.XMLDocument()
        doc:LoadFile(path)

        -- Error Handling
        if doc:Error() then
            error(doc:ErrorStr())
        end
        local root = doc:RootElement()
        if not root then
            error("No root element found in file: " .. path)
        end

        -- For each XML file, add a new XMLPlugin to the table.
        local plugin = self:AddPlugin(doc:FirstChildElement('plugin'):FirstChildElement('plugin-name'):GetText())
        -- Add each instrument defined in the XML file to the plugin.
        for inst_element in xmlelements(doc:FirstChildElement()) do
            if inst_element:Value() == 'instrument' then
                local inst = artxml.XMLInstrument.New(inst_element:FirstChildElement('instrument-name'):GetText())
                -- Add every articulation defined in the instrument.
                for art_element in xmlelements(inst_element) do
                    if art_element:Value() == 'articulation' then
                        local art = artxml.XMLArticulation.New(art_element:FirstChildElement('articulation-name'):GetText())
                        -- Add every action defined by each articulation.
                        for action_element in xmlelements(art_element) do
                            if action_element:Value() == 'action' then
                                if action_element:GetText() ~= nil then
                                    art:AddAction(action_element:Attribute('name'), action_element:GetText())
                                else
                                    art:AddAction(action_element:Attribute('name'), action_element)
                                end
                            end
                        end
                        inst:AddArticulation(art)
                    end
                end
                plugin:AddInstrument(inst)
            elseif inst_element:Value() == 'property' then
                local property_name = inst_element:Attribute('name')
                local property_value = inst_element:GetText()
                plugin:SetProperty(property_name, property_value)
            end
        end
    end

    return self
end

--- Creates a new XMLPlugin object and adds it to the parser's internal table.
--- @param name string
--- @return XMLPlugin
function ArticulationXMLParser:AddPlugin(name)
    local new_plugin = artxml.XMLPlugin.New(name)
    self.plugins[#self.plugins + 1] = new_plugin
    return new_plugin
end

--[[
-------------------------------------------------------------------------------------------------------
    Interface: Display Articulation Selection Dialog
-------------------------------------------------------------------------------------------------------
]]

--- Helper function of DisplayDialog to display a custom dialog for selecting notehead symbols.
--- This function is called when the user selects the "Notehead Mod" action in the articulation dialog.
--- Displays a dialog for selecting notehead symbols for the four distinct notehead duration types.
--- Returns a boolean equivalent to using_preset.
--- @param action_row integer
--- @param row_data table
--- @return boolean?
local function display_notehead_mod_selection_dialog(action_row, row_data, using_preset)
    using_preset = using_preset or true

    --[[
    -----------------------------------------------------------------------------------------------------
        Dialog Controls and Local Variables
    -----------------------------------------------------------------------------------------------------
    ]]

    -- Dialog window for custom notehead dialog. Declared global to prevent error from garbage collection.
    Notehead_Dialog = finale.FCCustomLuaWindow()
    local str = finale.FCString('Notehead Symbol Selection')
    Notehead_Dialog:SetTitle(str)

    -- Edit controls for entering/displaying notehead symbol values.
    local notehead_edits = {
        Notehead_Dialog:CreateEdit(100, 0),
        Notehead_Dialog:CreateEdit(100, 30),
        Notehead_Dialog:CreateEdit(100, 60),
        Notehead_Dialog:CreateEdit(100, 90)
    }

    -- Static to delineate the row for double whole note notehead selection.
    local double_whole_static = Notehead_Dialog:CreateStatic(0, 2)
    str.LuaString = 'Double Whole'
    double_whole_static:SetText(str)
    notehead_edits[1]:SetWidth(50)

    -- Static to delineate the row for whole note notehead selection.
    local whole_static = Notehead_Dialog:CreateStatic(0, 32)
    str.LuaString = 'Whole'
    whole_static:SetText(str)
    notehead_edits[2]:SetWidth(50)

    -- Static to delineate the row for half note notehead selection.
    local half_static = Notehead_Dialog:CreateStatic(0, 62)
    str.LuaString = 'Half'
    half_static:SetText(str)
    notehead_edits[3]:SetWidth(50)
    
    -- Static to delineate the row for quarter note notehead selection.
    local quarter_static = Notehead_Dialog:CreateStatic(0, 92)
    str.LuaString = 'Quarter (+8th, etc.)'
    quarter_static:SetText(str)
    notehead_edits[4]:SetWidth(50)

    -- Button controls to launch a symbol selection dialog for each notehead duration type.
    local notehead_buttons = {
        Notehead_Dialog:CreateButton(160, 0),
        Notehead_Dialog:CreateButton(160, 30),
        Notehead_Dialog:CreateButton(160, 60),
        Notehead_Dialog:CreateButton(160, 90)
    }
    str.LuaString = 'Select...'
    for i=1,4 do
        notehead_buttons[i]:SetWidth(50)
        notehead_buttons[i]:SetText(str)
    end

    -- Create exit controls.
    Notehead_Dialog:CreateOkButton()
    Notehead_Dialog:CreateCancelButton()


    -- Parse the row_data table to populate the edit controls with existing notehead values (if they exist).
    if row_data[action_row] ~= nil then
        if type(row_data[action_row]) == 'table' then
            for i=1,4 do
                str.LuaString = row_data[action_row][i]..""

                -- If the value is a valid positive integer, convert it to hexadecimal.
                local dec_var = cmath.GetInteger(str.LuaString)
                if dec_var ~= nil and dec_var > 0 then
                    str.LuaString = cmath.DecimalToHex(dec_var)
                end

                notehead_edits[i]:SetText(str)
            end
        end
    end
    
    -- Register event handlers for the notehead buttons to open a symbol selection dialog.
    for i=1,4 do
        Notehead_Dialog:RegisterHandleControlEvent(notehead_buttons[i],
            function()
                local fui = finenv.UI()

                --- Symbol ID stored in the edit control.
                --- @type integer?
                local curr_symbol
                -- Get the current symbol from the edit control.
                notehead_edits[i]:GetText(str)
                -- Tests whether the edit control contains a hexidecimal value.
                local hextest
                str.LuaString, hextest = string.gsub(str.LuaString, '0x', '')

                -- If the edit control contains a hexadecimal value, convert it to decimal.
                if hextest == 1 and cmath.IsHexadecimal(str.LuaString) then
                    str.LuaString = cmath.HexToDecimal(str.LuaString)..''
                end

                -- If the edit control does not contain a valid positive integer, set the current symbol to the default value (quarter notehead).
                curr_symbol = cmath.GetInteger(str.LuaString)
                if curr_symbol == nil or not (curr_symbol > 0) then curr_symbol = DEFAULT_QUARTER_NOTEHEAD_ID end

                -- Display the symbol selection dialog, selecting the symbol specified by curr_symbol.
                local music_font_pref = finale.FCFontPrefs()
                music_font_pref:Load(finale.FONTPREF_MUSIC)
                local result = fui:DisplaySymbolDialog(music_font_pref:CreateFontInfo(), curr_symbol)

                -- If the user selected a symbol, convert it to hexadecimal and set the edit control text to the new value.
                if result ~= 0 then
                    str.LuaString = cmath.DecimalToHex(result)
                    notehead_edits[i]:SetText(str)
                end
            end
        )
    end

    -- Register event handler for the OK button to update the row_data table with the selected notehead values.
    Notehead_Dialog:RegisterHandleOkButtonPressed(
        function()
            for i=1,4 do
                -- Retrive the notehead symbol value from the edit control.
                notehead_edits[i]:GetText(str)
                local val = str.LuaString
                -- If the value is a valid positive integer, convert it to hexadecimal.
                if cmath.IsInteger(val) and val+0 > 0 then
                    val = cmath.DecimalToHex(val+0)
                end

                if row_data[action_row] ~= nil and val ~= row_data[action_row][i] then
                    using_preset = false
                end

                -- Store the hexidecimal notehead symbol value in the row_data table.
                row_data[action_row] = {}
                row_data[action_row][i] = val
            end
        end
    )

    if Notehead_Dialog:ExecuteModal(nil) == 1 then
        for i=1,4 do
            notehead_edits[i]:GetText(str)
            row_data[action_row][i] = str.LuaString
        end
        return using_preset
    end

    return nil
end

--- Creates a dialog window for selecting articulations. Takes one optional parameter:
--- instrument_staff_count ; for assigning an articulation staff to a multistaff instrument (defaults to 1).
--- Returns two variables:
--- (1) A new XMLArticulation object based on the dialog selections and
--- (2) a number value indicating the offset of the instrument to assign the staff to (only applicable in the case of a multistaff instrument).
--- @param instrument_staff_count integer?
--- @return XMLArticulation?, integer?
function ArticulationXMLParser:DisplayDialog(instrument_staff_count)
    instrument_staff_count = instrument_staff_count or 1

    --[[
    ----------------------------------------------------------------------------------------------------
        Dialog Controls and Local Variables
    ----------------------------------------------------------------------------------------------------
    ]]

    -- Dialog window. Declared global to prevent error from garbage collection.
    Articulation_Dialog = finale.FCCustomLuaWindow()
    local str = finale.FCString('Select Staff Articulation')
    Articulation_Dialog:SetTitle(str)


    -- Static controls and listboxes for plugins, instruments, and articulations.


    -- Static control to delineate the plugin list.
    local plugin_static = Articulation_Dialog:CreateStatic(0, 0)
    str.LuaString = 'Plug-ins' --- @type string
    plugin_static:SetText(str)
    -- Listbox for selecting a plugin.
    local plugin_listbox = Articulation_Dialog:CreateListBox(0, 15)
    plugin_listbox:SetWidth(125)
    plugin_listbox:SetHeight(300)
    plugin_listbox:SetStrings(self:CreatePluginStrings())

    -- Static control to delineate the instrument list.
    local instrument_static = Articulation_Dialog:CreateStatic(135, 0)
    str.LuaString = 'Instruments'
    instrument_static:SetText(str)
    -- Listbox for selecting an instrument.
    local instrument_listbox = Articulation_Dialog:CreateListBox(135, 15)
    instrument_listbox:SetWidth(125)
    instrument_listbox:SetHeight(300)

    -- Static control to delineate the articulation list.
    local articulation_static = Articulation_Dialog:CreateStatic(270, 0)
    str.LuaString = 'Articulations'
    articulation_static:SetText(str)
    -- Listbox for selecting an articulation.
    local articulation_listbox = Articulation_Dialog:CreateListBox(270, 15)
    articulation_listbox:SetWidth(125)
    articulation_listbox:SetHeight(300)


    -- Static control for displaying the current articulation selection.
    local preview_static = Articulation_Dialog:CreateStatic(405, 0)
    preview_static:SetWidth(290)
    -- Local variable to keep track of whether the user is using a preset articulation or not. Displayed to the user in the control preview_static.
    local using_preset = false
    -- Table to keep track of the popup values for each row in the dialog. Used to test whether a preset has been modified to customize an articulation (in which case using_preset should be false).
    local preset_popup_values = {}
    -- Table to keep track of the edit values for each row in the dialog. Used to test whether a preset has been modified to customize an articulation (in which case using_preset should be false).
    local preset_edit_values = {}


    Articulation_Dialog:CreateHorizontalLine(405, 18, 290)


    --[[
    -----------------------------------------------------------------------------------------------------
        Controls for Multistaff Instruments (Temporary)
        
        TODO: Improve presentation of these controls.
    -----------------------------------------------------------------------------------------------------
    ]]

    -- Static control to ask the user which staff to assign the articulation to for a multistaff instrument.
    local assign_to_static
    -- Radio button group to list the staves of a multistaff instrument. (e.g., RH, LH, Ped.)
    local staff_destination_radio_button_group
    -- If the instrument has more than one staff, then the user must select which staff to assign the articulation to.
    if instrument_staff_count > 1 then
        assign_to_static = Articulation_Dialog:CreateStatic(360, 350)
        str.LuaString = 'Assign to:'
        assign_to_static:SetText(str)

        -- Assign radio button group depending on the number of staves in the instrument.
        if instrument_staff_count == 2 then
            staff_destination_radio_button_group = Articulation_Dialog:CreateRadioButtonGroup(405, 350, 2)
            staff_destination_radio_button_group:SetWidth(120)
            str.LuaString = "RH"
            staff_destination_radio_button_group:GetItemAt(0):SetText(str)
            str.LuaString = "LH"
            staff_destination_radio_button_group:GetItemAt(1):SetText(str)
        elseif instrument_staff_count == 3 then
            staff_destination_radio_button_group = Articulation_Dialog:CreateRadioButtonGroup(405, 350, 3)
            staff_destination_radio_button_group:SetWidth(120)
            str.LuaString = "RH"
            staff_destination_radio_button_group:GetItemAt(0):SetText(str)
            str.LuaString = "LH"
            staff_destination_radio_button_group:GetItemAt(1):SetText(str)
            str.LuaString = "Ped."
            staff_destination_radio_button_group:GetItemAt(2):SetText(str)
        end
    end


    --[[
    ----------------------------------------------------------------------------------------------------
        Helper Function: Update Preview

        Updates preview_static to display the currently selected articulation.

        [E.g. #1] Preset: No Articulation
        [E.g. #2] Custom
        [E.g. #3] Preset: Spiccato (Violin I) (from BBC Symphony Orchestra)
    ----------------------------------------------------------------------------------------------------
    ]]

    --- XMLPlugin object for determining the plugin currently selected by the user in the plugin listbox. Used to populate the instrument and articulation listboxes.
    --- @type XMLPlugin
    local selected_plugin = self:GetPlugin(plugin_listbox:GetSelectedItem() + 1)
    if selected_plugin ~= nil then
        instrument_listbox:SetStrings(selected_plugin:CreateInstrumentStrings())
    end

    --- XMLInstrument object for determining the instrument currently selected by the user in the instrument listbox. Used to populate the articulation listbox.
    --- @type XMLInstrument
    local selected_instrument
    if selected_plugin ~= nil then
        selected_instrument = selected_plugin:GetInstrument(instrument_listbox:GetSelectedItem() + 1)
    end

    -- XMLArticulation object for determining the articulation currently selected by the user in the articulation listbox.
    local selected_articulation --- @type XMLArticulation
    if selected_instrument ~= nil then
        articulation_listbox:SetStrings(selected_instrument:CreateArticulationStrings())
        using_preset = true
        selected_articulation = selected_instrument:GetArticulation(articulation_listbox:GetSelectedItem() + 1)
    end

    --- Updates the preview static control based on the selected articulation. No return value.
    --- @return nil
    local function update_preview()
        if using_preset and selected_instrument ~= nil then
            selected_articulation = selected_instrument:GetArticulation(articulation_listbox:GetSelectedItem() + 1)
            if selected_articulation ~= nil then
                str.LuaString = 'Preset: '
                str:AppendString(selected_articulation:CreateNameString())
                if selected_plugin ~= nil and not selected_plugin:GetProperty('hide_name_in_preview') then
                    str:AppendLuaString(' (')
                    str:AppendString(selected_instrument:CreateNameString())
                    str:AppendLuaString(') (from ')
                    str:AppendString(selected_plugin:CreateNameString())
                    str:AppendLuaString(')')
                end
            end
        else
            str.LuaString = 'Custom'
        end

        preview_static:SetText(str)
    end

    --[[
    ----------------------------------------------------------------------------------------------------
        Action Row-Related Controls

        Each articulation (or custom articulation) can have up to 9 actions associated with it. The
        actions determine how the articulation affects the staff it is applied to (via
        articulation_xml_handler.lua). Each action is represented by a row in the dialog, which
        contains:
        1. A static control with a number (1., 2., 3., etc.) to indicate the row number.
        2. A popup control for selecting the action to apply to the staff.
        3. An edit control for entering a value for the action (if applicable).
        4. A button for creating a value selection dialog for the action (if applicable).

    ----------------------------------------------------------------------------------------------------
    ]]

    -- Table of static controls numbering each row (1., 2., 3., etc.)
    local row_statics = {}
    -- Table of popup controls for selecting an action for each row.
    local row_popups = {}
    -- Table of edit controls for entering values for each row. (if applicable)
    local row_edits = {}
    -- Table of buttons for creating value selection dialogs for each row. (if applicable)
    local row_buttons = {}
    -- 2D Table containing output data for each row (action). Elements of the first row of this table are either nil (if meant to be read from the row's edit control) or a table.
    local row_data = {}

    -- FCStrings object containing the options for each action row's popup control. Allows the user to select an action to apply to the staff.
    local row_popup_options = finale.FCStrings()
    for i=1, #artxml.ACTIONS do
        row_popup_options:AddCopy(finale.FCString(artxml.ACTIONS[i].display))
    end

    --- Enables or disables controls belonging to a specified row by checking the popup selection of that row.
    --- E.g., if the popup selection is "Apply Articulation", then both the edit control and the dialog button control should be enabled.
    --- @param row integer
    local function update_row_controls(row)
        if artxml.ACTIONS[row_popups[row]:GetSelectedItem() + 1].enable_button == true then
            row_buttons[row]:SetEnable(true)
        else
            str.LuaString = ''
            row_edits[row]:SetText(str)
            row_buttons[row]:SetEnable(false)
        end

        local enable_edit = artxml.ACTIONS[row_popups[row]:GetSelectedItem() + 1].enable_edit
        if enable_edit ~= true then
            row_edits[row]:SetEnable(false)
        else
            row_edits[row]:SetEnable(true)
        end
    end


    -- Create the controls for each action row. (1. to 9.)

    for action_row = 1, 9 do -- Current row number (1 to 9).
        -- Verical position of the row in the dialog.
        local y_pos = 31 * action_row

        -- Create numbering static (1., 2., 3., etc.)
        row_statics[action_row] = Articulation_Dialog:CreateStatic(405, y_pos + 2)
        str.LuaString = action_row.."."
        row_statics[action_row]:SetText(str)

        -- Create popup control for selecting the action to apply to the staff.
        row_popups[action_row] = Articulation_Dialog:CreatePopup(422, y_pos)
        row_popups[action_row]:SetWidth(150)
        row_popups[action_row]:SetHeight(50)
        row_popups[action_row]:SetStrings(row_popup_options)

        -- Create edit control for entering a value for the action (if applicable to the action selected in the popup).
        row_edits[action_row] = Articulation_Dialog:CreateEdit(585, y_pos)
        row_edits[action_row]:SetWidth(50)

        -- Create button for opening a value selection dialog for the action (if applicable to the action selected in the popup).
        row_buttons[action_row] = Articulation_Dialog:CreateButton(645, y_pos)
        row_buttons[action_row]:SetWidth(50)
        row_buttons[action_row]:SetEnable(false)
        str.LuaString = 'Select...'
        row_buttons[action_row]:SetText(str)

        -- Detect change in row popup. Update the row controls to reflect the new action selected by the user.
        -- If the preset value is different from the current selection, then the preset is no longer being used.
        -- Update the preview_static control to reflect this change to the user.
        Articulation_Dialog:RegisterHandleControlEvent(row_popups[action_row],
            function()
                update_row_controls(action_row)
                if row_popups[action_row]:GetSelectedItem() ~= preset_popup_values[action_row] then
                    using_preset = false
                    row_data[action_row] = nil
                    update_preview()
                end
            end
        )

        -- Detect change in row edit control.
        -- If the edit value is different from the current selection, then the preset is no longer being used.
        -- Update the preview_static control to reflect this change to the user.
        Articulation_Dialog:RegisterHandleControlEvent(row_edits[action_row],
            function()
                row_edits[action_row]:GetText(str)
                if str.LuaString ~= preset_edit_values[action_row] then
                    using_preset = false
                    update_preview()
                end
            end
        )

        --[[
        ------------------------------------------------------------------------------------------------
        
            Select... Button Behavior

            This handler is called when the user clicks the "Select..." button for an action row.
            It opens a dialog for selecting a value for the action, depending on the action selected in
            the popup control. E.g., if the action is "Apply Articulation", then it opens the built-in
            Finale articulation selection dialog.
        
        ------------------------------------------------------------------------------------------------
        ]]

        Articulation_Dialog:RegisterHandleControlEvent(row_buttons[action_row],
            function()
                -- The display name of the action selected in the popup control.
                local selected_action = artxml.ACTIONS[row_popups[action_row]:GetSelectedItem() + 1].display
                -- Store the value of the edit control in str.
                row_edits[action_row]:GetText(str)

                -- ACTION: Apply Articulation
                -- Use the built-in Finale articulation selection dialog.
                if selected_action == 'Apply Articulation' then
                    local fui = finenv.UI()
                    -- Get the current articulation number from the edit control.
                    local curr_art = cmath.GetInteger(str.LuaString)
                    if curr_art == nil or not (curr_art > 0) then curr_art = 1 end

                    -- Launch the articulation selection dialog. Update the edit control.
                    local result = fui:DisplayArticulationDialog(curr_art)
                    if result ~= 0 then
                        str.LuaString = result..''
                        row_edits[action_row]:SetText(str)
                    end

                -- ACTION: Notehead Mod
                -- Create a custom dialog for selecting notehead symbols.
                -- Separate notehead selections are possible for the four distinct notehead duration types.
                elseif selected_action == 'Notehead Mod' then
                    local custom_preset = !display_notehead_mod_selection_dialog(action_row, row_data, using_preset);
                    if custom_preset then update_preview(); end

                -- ACTION: Add Expression to Phrase Starts
                -- Use the built-in Finale expression selection dialog.
                elseif selected_action == 'Add Expression to Phrase Starts' then
                    local fui = finenv.UI()
                    -- Get the current expression number from the edit control.
                    local curr_exp = cmath.GetInteger(str.LuaString)
                    if curr_exp == nil or not (curr_exp > 0) then curr_exp = 1 end

                    -- Launch the expression selection dialog. Update the edit control.
                    local result, result_isshape = fui:DisplayExpressionDialog(curr_exp, false)
                    if result ~= 0 and not result_isshape then
                        str.LuaString = result..''
                        row_edits[action_row]:SetText(str)
                    end
                end
            end
        )
    end

    --[[
    --------------------------------------------------------------------------------------------------------
    
        Helper Function: Apply Preset Articulation

        This function applies the actions of an XMLArticulation object to the dialog action row controls. It
        is called when the user selects an articulation from the articulation listbox. It will populate the
        action row controls with the preset values of the articulation.

    ---------------------------------------------------------------------------------------------------------
    ]]

    --- Apply information from the actions of an XMLArticulation object to the dialog controls.
    --- @param articulation XMLArticulation
    local function apply_preset(articulation)
        using_preset = true
        if articulation == nil then return end

        -- Local helper function to return the index of the action in the popup control that matches the given action.
        local function find_action_popup_index(action)
            for i=1, #artxml.ACTIONS do
                if action.key == artxml.ACTIONS[i].xml then
                    return i - 1
                end
            end
            return 0
        end


        -- Populate the dialog controls for each action row based on the actions defined in the given articulation.

        -- Table of actions belonging to the articulation preset being applied.
        local actions = articulation:GetActions()
        for i=1,9 do
            if i <= #actions then
                -- If there is an action defined for this row, then populate the controls with the action's values.

                -- Set the popup control.
                preset_popup_values[i] = find_action_popup_index(actions[i])
                row_popups[i]:SetSelectedItem(preset_popup_values[i])

                -- str.LuaString will be used to store the value of the edit control.
                str.LuaString = ""

                -- If row_data[i] is nil, then the action is meant to be read from the row's edit control.
                -- Otherwise, it is a table of values for the action.
                row_data[i] = nil
                
                -- Set the value to be displayed in the edit control and row_data based on the action type.
                if actions[i].key == 'apply_articulation_from_preset' then
                    -- TODO: If preset does not exist, this will crash the plugin. Should just not do anything.
                    str.LuaString = preset.FindArticulationDef(cmath.GetInteger(actions[i].value) or 0)..''
                elseif actions[i].key == 'notehead_mod' then
                    row_data[i] = {}
                    row_data[i][1] = actions[i].value['double-whole']
                    row_data[i][2] = actions[i].value['whole']
                    row_data[i][3] = actions[i].value['half']
                    row_data[i][4] = actions[i].value['quarter']
                elseif actions[i].key == 'transpose' then
                    str.LuaString = actions[i].value..""
                elseif actions[i].key == 'add_expression_to_phrase_starts' then
                    --TODO: Handle Shape Expressions (maybe)
                    local text_exp_def = preset.FindTextExpressionDef(actions[i].value['category'], actions[i].value['text'], true)
                    if text_exp_def ~= nil then str.LuaString = text_exp_def.ItemNo end
                end

                -- Update the edit control.
                preset_edit_values[i] = str.LuaString
                row_edits[i]:SetText(str)
            else
                -- If there are no more actions in the articulation, then set the row controls to their default values.
                preset_popup_values[i] = 0
                row_popups[i]:SetSelectedItem(0)
                str.LuaString = ""
                preset_edit_values[i] = ""
                row_edits[i]:SetText(str)
            end
            update_row_controls(i)
        end
        update_preview()
    end

    --[[
    ----------------------------------------------------------------------------------------------------
    
        Event Handlers for Listboxes

        These handlers update the selected plugin, instrument, and articulation based on the user's
        selections in the listboxes. They also update the action row controls based on the selected
        articulation by calling apply_preset.

    ----------------------------------------------------------------------------------------------------
    ]]

    Articulation_Dialog:RegisterHandleControlEvent(plugin_listbox,
        function()
            -- Set the selected plugin to reflect the user's selection in the plugin listbox.
            selected_plugin = self:GetPlugin(plugin_listbox:GetSelectedItem() + 1)
            if selected_plugin == nil then return end

            -- Populate the instrument listbox with the instruments of the selected plugin.
            instrument_listbox:SetStrings(selected_plugin:CreateInstrumentStrings())

            -- Reset selected instrument.
            selected_instrument = selected_plugin:GetInstrument(instrument_listbox:GetSelectedItem() + 1)
            if selected_instrument ~= nil then
                -- Populate the articulation listbox with the articulations of the selected instrument.
                articulation_listbox:SetStrings(selected_instrument:CreateArticulationStrings())
            else
                articulation_listbox:Clear()
            end
        end
    )

    Articulation_Dialog:RegisterHandleControlEvent(instrument_listbox,
        function()
            -- Verify that a valid plugin is selected.
            selected_plugin = self:GetPlugin(plugin_listbox:GetSelectedItem() + 1)
            if selected_plugin == nil then return end

            -- Verify that a valid instrument is selected.
            selected_instrument = selected_plugin:GetInstrument(instrument_listbox:GetSelectedItem() + 1)
            if selected_instrument == nil then return end

            -- Populate the articulation listbox with the articulations of the selected instrument.
            articulation_listbox:SetStrings(selected_instrument:CreateArticulationStrings())
        end
    )

    Articulation_Dialog:RegisterHandleControlEvent(articulation_listbox,
        function()
            if selected_instrument ~= nil then
                selected_articulation = selected_instrument:GetArticulation(articulation_listbox:GetSelectedItem() + 1)
                apply_preset(selected_articulation)
            end
        end
    )

    --[[
    ---------------------------------------------------------------------------------------------------
    
        Helper Function: Package Articulation for Return

        The DisplayDialog function as a whole returns an XMLArticulation object based on the user's
        selections. This is accomplished by packaging the actions selected by the user into an
        XMLArticulation object. This helper function is called to serve that role.

    ----------------------------------------------------------------------------------------------------
    ]]

    --- Create a new XMLArticulation object based on the dialog selections.
    --- @return XMLArticulation
    local function create_articulation_from_selection()
        -- Return preset articulation if using a preset.
        if using_preset then
            -- Set path for Edit button (feature TODO)
            selected_articulation:SetPath(plugin_listbox:GetSelectedItem() + 1, instrument_listbox:GetSelectedItem() + 1, articulation_listbox:GetSelectedItem() + 1)
            return selected_articulation

        -- Otherwise, create a new XMLArticulation object based on the dialog selections.
        else
            local result = artxml.XMLArticulation.New('Custom')
            for i=1,9 do
                -- If row_data[i] is nil, then the action is meant to be read from the row's edit control.
                -- It is possible that the ArticulationXMLHandler will ask for a table, though, depending on the action.
                if row_data[i] == nil then
                    -- Store edit control text in str
                    row_edits[i]:GetText(str)

                    -- If the handler expects a table, create one and store the edit control value in ['result'].
                    if artxml.ACTIONS[row_popups[i]:GetSelectedItem() + 1].type == "table" then 
                        local values_table = {}
                        values_table['result'] = str.LuaString
                        result:AddAction(artxml.ACTIONS[row_popups[i]:GetSelectedItem() + 1].xml, values_table)

                    -- Otherwise, both parser and handler expect a single variable.
                    else
                        result:AddAction(artxml.ACTIONS[row_popups[i]:GetSelectedItem() + 1].xml, str.LuaString)
                    end

                -- Otherwise, it can safely be assumed that row_data[i] is a table that is expected by the handler.
                else
                    -- Both parser and handler take a table
                    result:AddAction(artxml.ACTIONS[row_popups[i]:GetSelectedItem() + 1].xml, row_data[i])
                end
            end

            return result
        end
    end

    apply_preset(selected_articulation)

    Articulation_Dialog:CreateOkButton()
    Articulation_Dialog:CreateCancelButton()

    -- Display dialog if the user selects OK.
    -- Returns the XMLArticulation object packaged by create_articulation_from_selection and
    -- the staff offset to assign the articulation to (if applicable).
    if Articulation_Dialog:ExecuteModal(nil) == 1 then
        if instrument_staff_count == 1 then
            return create_articulation_from_selection(), 0
        else
            return create_articulation_from_selection(), staff_destination_radio_button_group:GetSelectedItem()
        end
    end
end

--[[
-------------------------------------------------------------------------------------------------------
    End of GUI.

    ArticulationXMLParser Interface Continued...
-------------------------------------------------------------------------------------------------------
]]

--- Creates an FCStrings object of the plugin names.
--- @return FCStrings
function ArticulationXMLParser:CreatePluginStrings()
    local strings = finale.FCStrings()
    for i=1, #self.plugins do
        strings:AddCopy(self.plugins[i]:CreateNameString())
    end
    return strings
end

--- Returns an XMLPlugin object given a numerical index.
--- @param id integer
--- @return XMLPlugin
function ArticulationXMLParser:GetPlugin(id)
    return self.plugins[id]
end

--- Returns an XMLInstrument object given plugin and instrument numerical indeces.
--- @param plugin_id integer
--- @param inst_id integer
--- @return XMLInstrument
function ArticulationXMLParser:GetInstrument(plugin_id, inst_id)
    return self:GetPlugin(plugin_id):GetInstrument(inst_id)
end

--- Returns an XMLArticulation object given plugin, instrument, and articulation numerical indeces.
--- @param plugin_id integer
--- @param inst_id integer
--- @param art_id integer
--- @return XMLArticulation
function ArticulationXMLParser:GetArticulation(plugin_id, inst_id, art_id)
    return self:GetInstrument(plugin_id, inst_id):GetArticulation(art_id)
end

-- Debug function to print the parser's plugin, instrument, and articulation information.
function ArticulationXMLParser:DebugDump()
    print('---XML PARSER---')
    for i=1, #self.paths do
        self.plugins[i]:DebugDump()
    end
end

return ArticulationXMLParser