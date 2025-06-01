--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module serves as a library that is used by two other modules: articulation_xml_handler.lua
    and articulation_xml_parser.lua. It defines classes for plugins, instruments, articulations, and actions.
    Plugins are defined by XML files. Each one is based on observations from existing VST plugins.
    Plugins are organized into instruments, each with its own articulations. Articulations
    each possess a number of actions, which are implemented via articulation_xml_handler.lua.

]]


local cmath = require "Lib.math_lib"

-- Library for XML parsing and handling of articulation data (static).
local articulationxmllib = {}

--[[
    Steps to Define New Action:
    (1) Define action properties in articulationxmllib.ACTIONS (articulation_xml_lib.lua)
    (2) If new data type, define data type in IsValidAction (articulation_xml_lib.lua)
    (3) Define how to interpret data from XML preset using apply_preset (articulation_xml_parser.lua)
    (4) Define Select... row button behaviour in Articulation_Dialog:RegisterHandleControlEvent(row_buttons[action_row], function) (articulation_xml_parser.lua)
    (5) Define handler process in ApplyAction (articulation_xml_handler.lua)
]]

--- @alias Actions
--- | ''
--- | 'apply_articulation_from_preset'
--- | 'notehead_mod'
--- | 'transpose'
--- | 'add_expression_to_phrase_starts'

-- Reference table of definitions for actions that can be applied to an articulation.
-- Contains the following properties:
-- xml (string), display (string), type (string), enable_edit (bool), enable_button (bool).
articulationxmllib.ACTIONS = {
    {xml = '', display = 'No Effect', enable_edit = false, enable_button = false},
    {xml = 'apply_articulation_from_preset', display = 'Apply Articulation', type = 'int', enable_edit = true, enable_button = true},
    {xml = 'notehead_mod', display = 'Notehead Mod', type = 'table', enable_edit = false, enable_button = true},
    {xml = 'transpose', display = 'Transpose', type = 'int', enable_edit = true, enable_button = false},
    {xml = 'add_expression_to_phrase_starts', display = 'Add Expression to Phrase Starts', type = 'table', enable_edit = true, enable_button = true}
}

articulationxmllib.PLUGIN_PROPERTY_DEFAULTS = {
    {name='hide_name_in_preview', value=false, type='bool'},
    {name='prioritize_in_order', value=false, type='bool'}
}

--- Check if the action's value is of a valid data type given its configuration (ACTIONS.type).
--- Returns a casted object to the correct type if possible and necessary.
--- @param key Actions
--- @param value any
--- @return boolean, any
function articulationxmllib.IsValidAction(key, value)
    for i=1,#articulationxmllib.ACTIONS do
        if key == articulationxmllib.ACTIONS[i].xml then
            if articulationxmllib.ACTIONS[i].type == 'int' then
                if type(value) == "number" or
                    type(value) == "string" and cmath.IsInteger(value) then return true, cmath.GetInteger(value)
                else return false end
            elseif articulationxmllib.ACTIONS[i].type == 'table' then
                if type(value) == "userdata" and value:ClassName() == "XMLElement" then
                    local result = {}
                    for element in xmlelements(value) do
                        result[element:Value()] = element:GetText()
                    end
                    return true, result
                elseif type(value) == "table" then
                    return true, value
                else return false end
            end
            break
        end
    end

    return false
end

--- @class XMLArticulation
--- @field private name string
--- @field private action_keys string[] Stored in xml format (not display format).
--- @field private action_values table
--- @field private plugin integer
--- @field private inst integer
--- @field private id integer
articulationxmllib.XMLArticulation = {}
articulationxmllib.XMLArticulation.__index = articulationxmllib.XMLArticulation

--- Constructor method for XMLArticulation.
--- @param name string
--- @return XMLArticulation
function articulationxmllib.XMLArticulation.New(name)
    local self = setmetatable({}, articulationxmllib.XMLArticulation)
    self.name = name
    self.action_keys = {}
    self.action_values = {}
    self.plugin = -1
    self.inst = -1
    self.id = -1
    return self
end

--[[
    Public methods
]]

--- Adds an action to the articulation's list.
--- Will fail if given an invalid action value data type.
--- @param key Actions
--- @param value any
function articulationxmllib.XMLArticulation:AddAction(key, value)
    local is_valid_action, fvalue = articulationxmllib.IsValidAction(key, value)
    if not is_valid_action then return end
    if key == '' then return end

    self.action_keys[#self.action_keys+1] = key
    self.action_values[#self.action_values+1] = fvalue
end

--- Returns an FCString containing the name of the articulation.
--- @return FCString
function articulationxmllib.XMLArticulation:CreateNameString()
    return finale.FCString(self.name)
end

--- Returns a table of actions. Each action is a table with keys 'key' and 'value'.
--- @return table[] actions actions[i].key (string), actions[i].value (any)
function articulationxmllib.XMLArticulation:GetActions()
    local actions = {}
    for i=1, #self.action_keys do
        actions[i] = {
            key = self.action_keys[i],
            value = self.action_values[i]
        }
    end
    return actions
end

--- TODO: Will be useful when adding the Edit button to Main UI
--- @param plugin integer
--- @param inst integer
--- @param id integer
function articulationxmllib.XMLArticulation:SetPath(plugin, inst, id)
    self.plugin = plugin
    self.inst = inst
    self.id = id
end

-- Debug function to print the articulation's name and actions.
function articulationxmllib.XMLArticulation:DebugDump()
    print('  [Articulation] ', self.name)
    for i=1, #self.action_keys do
        print('   [Action] ', self.action_keys[i], self.action_values[i])
    end
end



--- @class XMLInstrument
--- @field private name string
--- @field private articulations XMLArticulation[]
articulationxmllib.XMLInstrument = {}
articulationxmllib.XMLInstrument.__index = articulationxmllib.XMLInstrument

--- Constructor method for XMLInstrument.
--- @param name string
--- @return XMLInstrument
function articulationxmllib.XMLInstrument.New(name)
    local self = setmetatable({}, articulationxmllib.XMLInstrument)
    self.name = name
    self.articulations = {}
    return self
end

--- Adds an XMLArticulation object to the instrument's internal table.
--- @param articulation XMLArticulation
function articulationxmllib.XMLInstrument:AddArticulation(articulation)
    self.articulations[#self.articulations+1] = articulation
end

--- Returns an FCString containing the name of the instrument.
--- @return FCString
function articulationxmllib.XMLInstrument:CreateNameString()
    return finale.FCString(self.name)
end

--- Returns an FCStrings object of the instrument's articulation names.
--- @return FCStrings
function articulationxmllib.XMLInstrument:CreateArticulationStrings()
    local strings = finale.FCStrings()
    for i=1, #self.articulations do
        strings:AddCopy(self.articulations[i]:CreateNameString())
    end
    return strings
end

--- Returns an XMLArticulation object given a numerical index.
--- @param id integer
--- @return XMLArticulation
function articulationxmllib.XMLInstrument:GetArticulation(id)
    return self.articulations[id]
end

-- Debug function to print the instrument's name, articulations, and articulation actions.
function articulationxmllib.XMLInstrument:DebugDump()
    print(' [Instrument] ', self.name)
    for i=1, #self.articulations do
        self.articulations[i]:DebugDump()
    end
end


--- @class XMLPlugin
--- @field private name string
--- @field private properties table[]
--- @field private instruments XMLInstrument[]
articulationxmllib.XMLPlugin = {}
articulationxmllib.XMLPlugin.__index = articulationxmllib.XMLPlugin

--- Constructor method for XMLPlugin.
--- @param name string
--- @return XMLPlugin
function articulationxmllib.XMLPlugin.New(name)
    local self = setmetatable({}, articulationxmllib.XMLPlugin)
    self.name = name
    self.instruments = {}
    self.properties = articulationxmllib.PLUGIN_PROPERTY_DEFAULTS
    return self
end

--- Adds an XMLInstrument object to the plugin's internal table.
--- @param instrument XMLInstrument
function articulationxmllib.XMLPlugin:AddInstrument(instrument)
    self.instruments[#self.instruments+1] = instrument
end

--- Returns an FCString containing the name of the plugin.
--- @return FCString
function articulationxmllib.XMLPlugin:CreateNameString()
    return finale.FCString(self.name)
end

--- Returns an FCStrings object of the plugin's instrument names.
--- @return FCStrings
function articulationxmllib.XMLPlugin:CreateInstrumentStrings()
    local strings = finale.FCStrings()
    for i=1, #self.instruments do
        strings:AddCopy(self.instruments[i]:CreateNameString())
    end
    return strings
end

--- Returns an XMLInstrument object given a numerical index.
--- @param id integer
--- @return XMLInstrument
function articulationxmllib.XMLPlugin:GetInstrument(id)
    return self.instruments[id]
end

--- Returns a property value given a property name (LuaString).
--- @param name string
--- @return any
function articulationxmllib.XMLPlugin:GetProperty(name)
    for _, property in ipairs(self.properties) do
        if property.name == name then
            return property.value
        end
    end
end

--- Sets a property of the plugin. See PLUGIN_PROPERTY_DEFAULTS for valid properties.
--- @param name string
--- @param value any
function articulationxmllib.XMLPlugin:SetProperty(name, value)
    for _, property in ipairs(self.properties) do
        if property.name == name then
            --Set Value based on type
            if property.type == 'bool' then
                if value == 'true' then property.value = true
                else property.value = false end
            end
        end
    end
end

-- Debug function to print the plugin's name, instruments, articulations, and articulation actions.
function articulationxmllib.XMLPlugin:DebugDump()
    print('[Plugin] ', self.name)
    for i=1, #self.instruments do
        self.instruments[i]:DebugDump()
    end
end

return articulationxmllib