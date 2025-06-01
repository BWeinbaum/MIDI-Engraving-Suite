--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module is referenced mainly by the Assign Staves to Instruments subtask. It is
    responsible for reading XML data from plugin definition files.

]]

local artxml = require "Lib.articulation_xml_lib"
local preset = require "Lib.preset_browser_lib"
local cmath = require "Lib.math_lib"


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

        local plugin = self:AddPlugin(doc:FirstChildElement('plugin'):FirstChildElement('plugin-name'):GetText())
        -- Instrument Level
        for inst_element in xmlelements(doc:FirstChildElement()) do
            if inst_element:Value() == 'instrument' then
                local inst = artxml.XMLInstrument.New(inst_element:FirstChildElement('instrument-name'):GetText())
                -- Articulation Level
                for art_element in xmlelements(inst_element) do
                    if art_element:Value() == 'articulation' then
                        local art = artxml.XMLArticulation.New(art_element:FirstChildElement('articulation-name'):GetText())
                        -- Action Level
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

--- Creates a dialog window for selecting articulations. Takes one optional parameter:
--- instrument_staff_count ; for assigning an articulation staff to a multistaff instrument (defaults to 1).
--- Returns two variables:
--- (1) A new XMLArticulation object based on the dialog selections and
--- (2) a number value indicating the offset of the instrument to assign the staff to (only applicable in the case of a multistaff instrument).
--- @param instrument_staff_count integer?
--- @return XMLArticulation?, integer?
function ArticulationXMLParser:DisplayDialog(instrument_staff_count)
    instrument_staff_count = instrument_staff_count or 1

    Articulation_Dialog = finale.FCCustomLuaWindow()
    local str = finale.FCString('Select Staff Articulation')
    Articulation_Dialog:SetTitle(str)

    local using_preset = false
    local preset_popup_values = {}
    local preset_edit_values = {}

    local plugin_static = Articulation_Dialog:CreateStatic(0, 0)
    str.LuaString = 'Plug-ins' --- @type string
    plugin_static:SetText(str)
    local plugin_listbox = Articulation_Dialog:CreateListBox(0, 15)
    plugin_listbox:SetWidth(125)
    plugin_listbox:SetHeight(300)
    plugin_listbox:SetStrings(self:CreatePluginStrings())

    local instrument_static = Articulation_Dialog:CreateStatic(135, 0)
    str.LuaString = 'Instruments'
    instrument_static:SetText(str)
    local instrument_listbox = Articulation_Dialog:CreateListBox(135, 15)
    instrument_listbox:SetWidth(125)
    instrument_listbox:SetHeight(300)

    local articulation_static = Articulation_Dialog:CreateStatic(270, 0)
    str.LuaString = 'Articulations'
    articulation_static:SetText(str)
    local articulation_listbox = Articulation_Dialog:CreateListBox(270, 15)
    articulation_listbox:SetWidth(125)
    articulation_listbox:SetHeight(300)

    local preview_static = Articulation_Dialog:CreateStatic(405, 0)
    preview_static:SetWidth(290)

    Articulation_Dialog:CreateHorizontalLine(405, 18, 290)

    local selected_plugin = self:GetPlugin(plugin_listbox:GetSelectedItem() + 1)
    if selected_plugin ~= nil then
        instrument_listbox:SetStrings(selected_plugin:CreateInstrumentStrings())
    end
    local selected_instrument --- @type XMLInstrument
    if selected_plugin ~= nil then
        selected_instrument = selected_plugin:GetInstrument(instrument_listbox:GetSelectedItem() + 1)
    end
    local selected_articulation --- @type XMLArticulation
    if selected_instrument ~= nil then
        articulation_listbox:SetStrings(selected_instrument:CreateArticulationStrings())
        using_preset = true
        selected_articulation = selected_instrument:GetArticulation(articulation_listbox:GetSelectedItem() + 1)
    end

    -- Additional controls for dealing with multistaff instruments.
    local assign_to_static, staff_destination_radio_button_group
    if instrument_staff_count > 1 then
        assign_to_static = Articulation_Dialog:CreateStatic(360, 350)
        str.LuaString = 'Assign to:'
        assign_to_static:SetText(str)
    end
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

    -- Updates the preview display based on the selected articulation.
    local function update_preview()
        --[[E.g.
            Preset: No Articulation
            Custom
            Preset: Spiccato (Violin I) (from BBC Symphony Orchestra) ]]
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

    local options = finale.FCStrings()
    for i=1, #artxml.ACTIONS do
        options:AddCopy(finale.FCString(artxml.ACTIONS[i].display))
    end

    local row_statics = {} -- Table of static controls numbering each row (1., 2., 3., etc.)
    local row_popups = {} -- Table of popup controls for selecting an action for each row.
    local row_edits = {} -- Table of edit controls for entering values for each row. (if applicable)
    local row_buttons = {} -- Table of buttons for creating value selection dialogs for each row. (if applicable)
    local row_data = {} -- 2D Table containing output data for each row. Elements of the first row are either nil (if meant to be read from the row's edit control) or a table.

    --- Update enable state of row controls and text content of edits based on popup selection of a specific row.
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

    for action_row = 1, 9 do
        local y_pos = 31 * action_row
        row_statics[action_row] = Articulation_Dialog:CreateStatic(405, y_pos + 2)
        str.LuaString = action_row.."."
        row_statics[action_row]:SetText(str)

        row_popups[action_row] = Articulation_Dialog:CreatePopup(422, y_pos)
        row_popups[action_row]:SetWidth(150)
        row_popups[action_row]:SetHeight(50)
        row_popups[action_row]:SetStrings(options)

        row_edits[action_row] = Articulation_Dialog:CreateEdit(585, y_pos)
        row_edits[action_row]:SetWidth(50)

        row_buttons[action_row] = Articulation_Dialog:CreateButton(645, y_pos)
        row_buttons[action_row]:SetWidth(50)
        row_buttons[action_row]:SetEnable(false)
        str.LuaString = 'Select...'
        row_buttons[action_row]:SetText(str)

        Articulation_Dialog:RegisterHandleControlEvent(row_popups[action_row],
            function()
                update_row_controls(action_row)
                -- If the preset value is different from the current selection, then the preset is no longer being used.
                -- Update the preview to reflect this.
                if row_popups[action_row]:GetSelectedItem() ~= preset_popup_values[action_row] then
                    using_preset = false
                    row_data[action_row] = nil
                    update_preview()
                end
            end
        )

        Articulation_Dialog:RegisterHandleControlEvent(row_edits[action_row],
            function()
                -- If the edit value is different from the current selection, then the preset is no longer being used.
                -- Update the preview to reflect this.
                row_edits[action_row]:GetText(str)
                if str.LuaString ~= preset_edit_values[action_row] then
                    using_preset = false
                    update_preview()
                end
            end
        )

        -- Select... button behaviour
        Articulation_Dialog:RegisterHandleControlEvent(row_buttons[action_row],
            function()
                local selected_action = artxml.ACTIONS[row_popups[action_row]:GetSelectedItem() + 1].display
                row_edits[action_row]:GetText(str)
                if selected_action == 'Apply Articulation' then
                    -- Use the built-in Finale articulation selection dialog.
                    local fui = finenv.UI()
                    local curr_art = cmath.GetInteger(str.LuaString)
                    if curr_art == nil or not (curr_art > 0) then curr_art = 1 end

                    local result = fui:DisplayArticulationDialog(curr_art)
                    if result ~= 0 then
                        str.LuaString = result..''
                        row_edits[action_row]:SetText(str)
                    end
                elseif selected_action == 'Notehead Mod' then
                    -- Create custom dialog for notehead selection.
                    -- Separate notehead selections should be possible for the four distinct notehead duration types.
                    Notehead_Dialog = finale.FCCustomLuaWindow()
                    str.LuaString = 'Notehead Symbol Selection'
                    Notehead_Dialog:SetTitle(str)

                    local notehead_edits = {
                        Notehead_Dialog:CreateEdit(100, 0),
                        Notehead_Dialog:CreateEdit(100, 30),
                        Notehead_Dialog:CreateEdit(100, 60),
                        Notehead_Dialog:CreateEdit(100, 90)
                    }
                    local notehead_buttons = {
                        Notehead_Dialog:CreateButton(160, 0),
                        Notehead_Dialog:CreateButton(160, 30),
                        Notehead_Dialog:CreateButton(160, 60),
                        Notehead_Dialog:CreateButton(160, 90)
                    }

                    local double_whole_static = Notehead_Dialog:CreateStatic(0, 2)
                    str.LuaString = 'Double Whole'
                    double_whole_static:SetText(str)
                    notehead_edits[1]:SetWidth(50)

                    notehead_buttons[1]:SetWidth(50)
                    str.LuaString = 'Select...'
                    notehead_buttons[1]:SetText(str)

                    local whole_static = Notehead_Dialog:CreateStatic(0, 32)
                    str.LuaString = 'Whole'
                    whole_static:SetText(str)
                    notehead_edits[2]:SetWidth(50)
                    notehead_buttons[2]:SetWidth(50)
                    str.LuaString = 'Select...'
                    notehead_buttons[2]:SetText(str)

                    local half_static = Notehead_Dialog:CreateStatic(0, 62)
                    str.LuaString = 'Half'
                    half_static:SetText(str)
                    notehead_edits[3]:SetWidth(50)
                    notehead_buttons[3]:SetWidth(50)
                    str.LuaString = 'Select...'
                    notehead_buttons[3]:SetText(str)
                    
                    local quarter_static = Notehead_Dialog:CreateStatic(0, 92)
                    str.LuaString = 'Quarter (+8th, etc.)'
                    quarter_static:SetText(str)
                    notehead_edits[4]:SetWidth(50)
                    notehead_buttons[4]:SetWidth(50)
                    str.LuaString = 'Select...'
                    notehead_buttons[4]:SetText(str)

                    if row_data[action_row] ~= nil then
                        if type(row_data[action_row]) == 'table' then
                            for i=1,4 do
                                str.LuaString = row_data[action_row][i]..""
                                local dec_var = cmath.GetInteger(str.LuaString)
                                if dec_var ~= nil and dec_var > 0 then
                                    str.LuaString = cmath.DecimalToHex(dec_var)
                                end
                                notehead_edits[i]:SetText(str)
                            end
                        end
                    end
                    
                    for i=1,4 do
                        Notehead_Dialog:RegisterHandleControlEvent(notehead_buttons[i],
                            function()
                                local fui = finenv.UI()
                                local curr_symbol
                                notehead_edits[i]:GetText(str)
                                local hextest
                                str.LuaString, hextest = string.gsub(str.LuaString, '0x', '')
                                if hextest == 1 and cmath.IsHexadecimal(str.LuaString) then
                                    str.LuaString = cmath.HexToDecimal(str.LuaString)..''
                                end
                                curr_symbol = cmath.GetInteger(str.LuaString)
                                if dec_var == nil or not (curr_symbol > 0) then curr_symbol = 57504 end
                                local music_font_pref = finale.FCFontPrefs()
                                music_font_pref:Load(finale.FONTPREF_MUSIC)
                                local result = fui:DisplaySymbolDialog(music_font_pref:CreateFontInfo(), curr_symbol)
                                if result ~= 0 then
                                    str.LuaString = cmath.DecimalToHex(result)
                                    notehead_edits[i]:SetText(str)
                                end
                            end
                        )
                    end

                    Notehead_Dialog:RegisterHandleOkButtonPressed(
                        function()
                            for i=1,4 do
                                notehead_edits[i]:GetText(str)
                                local val = str.LuaString
                                if IsInteger(val) and val+0 > 0 then
                                    val = cmath.DecimalToHex(val+0)
                                end
                                if row_data[action_row] ~= nil and val ~= row_data[action_row][i] then
                                    using_preset = false
                                    update_preview()
                                end

                                row_data[action_row] = {}
                                row_data[action_row][i] = val
                            end
                        end
                    )

                    Notehead_Dialog:CreateOkButton()
                    Notehead_Dialog:CreateCancelButton()
                    if Notehead_Dialog:ExecuteModal(nil) == 1 then
                        for i=1,4 do
                            notehead_edits[i]:GetText(str)
                            row_data[action_row][i] = str.LuaString
                        end
                    end
                elseif selected_action == 'Add Expression to Phrase Starts' then
                    -- Use the built-in Finale expression selection dialog.
                    local fui = finenv.UI()
                    local curr_exp = cmath.GetInteger(str.LuaString)
                    if curr_exp == nil or not (curr_exp > 0) then curr_exp = 1 end

                    local result, result_isshape = fui:DisplayExpressionDialog(curr_exp, false)
                    if result ~= 0 and not result_isshape then
                        str.LuaString = result..''
                        row_edits[action_row]:SetText(str)
                    end
                end
            end
        )
    end

    --- Apply information from the actions of an XMLArticulation object to the dialog controls.
    --- @param articulation XMLArticulation
    local function apply_preset(articulation)
        using_preset = true
        if articulation == nil then return end

        -- Returns the index of the action in the popup control that matches the given action.
        local function find_action_popup_index(action)
            for i=1, #artxml.ACTIONS do
                if action.key == artxml.ACTIONS[i].xml then
                    return i - 1
                end
            end
            return 0
        end

        --Iterate through the articulation for actions and update controls to match
        local actions = articulation:GetActions()
        for i=1, 9 do
            if i <= #actions then
                preset_popup_values[i] = find_action_popup_index(actions[i])
                row_popups[i]:SetSelectedItem(preset_popup_values[i])
                str.LuaString = ""
                if actions[i].key == 'apply_articulation_from_preset' then
                    str.LuaString = preset.FindArticulationDef(cmath.GetInteger(actions[i].value) or 0)..'' -- TODO: If preset does not exist, this will crash the plugin. Should just not do anything.
                    -- row_data[i] is set to nil if it is meant to be read from the row's edit control.
                    row_data[i] = nil
                elseif actions[i].key == 'notehead_mod' then
                    row_data[i] = {}
                    row_data[i][1] = actions[i].value['double-whole']
                    row_data[i][2] = actions[i].value['whole']
                    row_data[i][3] = actions[i].value['half']
                    row_data[i][4] = actions[i].value['quarter']
                elseif actions[i].key == 'transpose' then
                    str.LuaString = actions[i].value..""
                    row_data[i] = nil
                elseif actions[i].key == 'add_expression_to_phrase_starts' then
                    --TODO: Handle Shape Expressions (maybe)
                    local text_exp_def = preset.FindTextExpressionDef(actions[i].value['category'], actions[i].value['text'], true)
                    if text_exp_def ~= nil then str.LuaString = text_exp_def.ItemNo end
                end
                preset_edit_values[i] = str.LuaString
                row_edits[i]:SetText(str)
            else
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

    Articulation_Dialog:RegisterHandleControlEvent(plugin_listbox,
        function()
            selected_plugin = self:GetPlugin(plugin_listbox:GetSelectedItem() + 1)
            if selected_plugin == nil then return end
            instrument_listbox:SetStrings(selected_plugin:CreateInstrumentStrings())
            selected_instrument = selected_plugin:GetInstrument(instrument_listbox:GetSelectedItem() + 1)
            if selected_instrument ~= nil then
                articulation_listbox:SetStrings(selected_instrument:CreateArticulationStrings())
            else
                articulation_listbox:Clear()
            end
        end
    )

    Articulation_Dialog:RegisterHandleControlEvent(instrument_listbox,
        function()
            selected_plugin = self:GetPlugin(plugin_listbox:GetSelectedItem() + 1)
            if selected_plugin == nil then return end
            selected_instrument = selected_plugin:GetInstrument(instrument_listbox:GetSelectedItem() + 1)
            if selected_instrument == nil then return end
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

    --- Create a new XMLArticulation object based on the dialog selections.
    --- @return XMLArticulation
    local function create_articulation_from_selection()
        if using_preset then
            -- Use preset but set path for Edit button
            selected_articulation:SetPath(plugin_listbox:GetSelectedItem() + 1, instrument_listbox:GetSelectedItem() + 1, articulation_listbox:GetSelectedItem() + 1)
            return selected_articulation
        else
            -- Create a new XMLArticulation object from the dialog selections
            local result = artxml.XMLArticulation.New('Custom')
            for i=1,9 do
                if row_data[i] == nil then
                    row_edits[i]:GetText(str)
                    if artxml.ACTIONS[row_popups[i]:GetSelectedItem() + 1].type == "table" then
                        -- Parser takes a table from preset, but handler only needs a single variable 
                        local values_table = {}
                        values_table['result'] = str.LuaString
                        result:AddAction(artxml.ACTIONS[row_popups[i]:GetSelectedItem() + 1].xml, values_table)
                    else
                        -- Both parser and handler take a single variable
                        result:AddAction(artxml.ACTIONS[row_popups[i]:GetSelectedItem() + 1].xml, str.LuaString)
                    end
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
    if Articulation_Dialog:ExecuteModal(nil) == 1 then
        if instrument_staff_count == 1 then
            return create_articulation_from_selection(), 0
        else
            return create_articulation_from_selection(), staff_destination_radio_button_group:GetSelectedItem()
        end
    end
end

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