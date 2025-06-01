--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module is referenced mainly by the Assign Staves to Instruments subtask. It is
    responsible for reading data from finale.xml.

]]

local cmath = require "Lib.math_lib"

--- Class for parsing and interpretting the file Finale.instruments after converting said file to XML.
--- @class FinaleInstrumentXMLParser
--- @field private path string -- The path to the Finale.instruments file.
--- @field private filters boolean[][] -- A 2D array of booleans representing the instrument filters.
--- @field private filter_count integer -- The number of filters defined in Finale.instruments.
--- @field private instrument_families string[] -- An array of strings containing the instrument family names.
--- @field private family_count integer -- The number of instrument families defined in Finale.instruments.
--- @field private instrument_family_assignments integer[] -- An array of integers representing the family assignments of each instrument (using family IDs as defined in Finale.instruments).
--- @field private instruments string[] -- An array of strings containing the full names of the instruments.
--- @field private instrument_count integer -- The number of instruments defined in Finale.instruments.
--- @field private filtered_instruments integer[] -- An array of integers representing the instruments that are a part of the selected filter. Stores indeces of instruments from self.instruments.
--- @field private visible_instruments integer[] -- An array of integers representing the instruments that both are a part of the selected filter and family and also pass the current text filter. Stores indeces of instruments from self.instruments.
local FinaleInstrumentXMLParser = {}
FinaleInstrumentXMLParser.__index = FinaleInstrumentXMLParser

--[[
    Helper methods
]]

--- Returns a tinyxml2 XMLDocument object. Make sure to remember to close the document when done
--- using it via XMLDocument::Close().
--- @return XMLDocument
local function get_xml_document(self) -- TODO: Make private (helper method)
    -- Load XML
    local doc = tinyxml2.XMLDocument()
    doc:LoadFile(self.path)

    -- Error Handling
    if doc:Error() then
        error(doc:ErrorStr())
    end
    local root = doc:RootElement()
    if not root then
        error("No root element found in file: " .. path)
    end
    return doc
end

--- Returns the number of filters defined in Finale.instruments
--- @return integer
local function calc_filter_count(self)
    local doc = get_xml_document(self)
    local result = self.filter_count or nil
    if result ~= nil then return result end

    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "sqlite_sequence" then
            for sequence in xmlelements(root_element) do
                if sequence:FirstChildElement("name"):GetText() == "instrument_filters" then
                    result = sequence:FirstChildElement("seq"):GetText()
                end
            end
            break
        end
    end
    doc:Clear()
    result = cmath.GetInteger(result or 0) or 0
    self.filter_count = result
    return result
end

--- Returns the number of instrument families defined in Finale.instruments
--- @return integer
local function calc_family_count(self)
    local doc = get_xml_document(self)
    local result = self.family_count or nil
    if result ~= nil then return result end

    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "sqlite_sequence" then
            for sequence in xmlelements(root_element) do
                if sequence:FirstChildElement("name"):GetText() == "instrument_families" then
                    result = sequence:FirstChildElement("seq"):GetText()
                end
            end
            break
        end
    end
    doc:Clear()
    result = cmath.GetInteger(result or 0) or 0
    self.family_count = result
    return result
end

--- Returns the number of instruments defined in Finale.instruments
--- @return integer
local function calc_instrument_count(self)
    local doc = get_xml_document(self)
    local result = self.instrument_count or nil
    if result ~= nil then return result end

    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "sqlite_sequence" then
            for sequence in xmlelements(root_element) do
                if sequence:FirstChildElement("name"):GetText() == "instruments" then
                    result = sequence:FirstChildElement("seq"):GetText()
                end
            end
            break
        end
    end
    doc:Clear()
    result = cmath.GetInteger(result or 0) or 0
    self.instrument_count = result
    return result
end

--- Constructor for FinaleInstrumentXMLParser class.
--- @param path string
--- @return FinaleInstrumentXMLParser
function FinaleInstrumentXMLParser.Init(path)
    local self = setmetatable({}, FinaleInstrumentXMLParser)

    self.path = path

    local doc = get_xml_document(self)

    -- Initialize filters.
    local filter = {}
    local filter_count = calc_filter_count(self)
    local instrument_count = calc_instrument_count(self)
    for i=1, filter_count do
        filter[i] = {}
        for j=1, instrument_count do
            if i==1 then -- 'All'
                filter[i][j] = true
            else -- Others
                filter[i][j] = false
            end
        end
    end
    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "instrument_filters_instruments" then
            for element in xmlelements(root_element) do
                local filter_no = cmath.GetInteger(element:FirstChildElement("filter_id"):GetText())
                local inst_no = cmath.GetInteger(element:FirstChildElement("instrument_id"):GetText())

                if filter_no ~= nil and inst_no ~= nil then
                    filter[filter_no][inst_no] = true
                end
            end
            break
        end
    end
    self.filters = filter

    -- Move instrument family names to main memory.
    local instrument_families = {}
    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "instrument_families" then
            for element in xmlelements(root_element) do
                local family_no = cmath.GetInteger(element:FirstChildElement("family_id"):GetText())
                local family_name = element:FirstChildElement("family_name"):GetText()

                if family_no ~= nil then
                    instrument_families[family_no] = family_name
                end
            end
            break
        end
    end
    self.instrument_families = instrument_families

    -- Move instrument family assignments to main memory.
    local instrument_family_assignments = {}
    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "instrument_families_instrument" then
            for element in xmlelements(root_element) do
                local inst_no = cmath.GetInteger(element:FirstChildElement("instrument_id"):GetText())
                local family_no = cmath.GetInteger(element:FirstChildElement("family_id"):GetText())
                
                if inst_no ~= nil and family_no ~= nil then
                    instrument_family_assignments[inst_no] = family_no
                end
            end
            break
        end
    end
    self.instrument_family_assignments = instrument_family_assignments

    -- Move instrument full names to main memory.
    local instruments = {}
    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "instruments" then
            for element in xmlelements(root_element) do
                local inst_no = cmath.GetInteger(element:FirstChildElement("instrument_id"):GetText())
                local inst_name = element:FirstChildElement("instrument_name"):GetText()

                if inst_no ~= nil then
                    instruments[inst_no] = inst_name
                end
            end
            break
        end
    end
    self.instruments = instruments
    self.filtered_instruments = {} --Used to determine what families to display.
    self.visible_instruments = {}

    doc:Clear()

    return self
end

--[[
    Public Methods
]]

--- Loads a TreeInstrument object (from assign_articulation_staves.lua) from the Finale.instruments XML file given an instrument_id parameter.
--- @param instrument_id integer
--- @param instrument TreeInstrument
function FinaleInstrumentXMLParser:LoadInstrumentFromXML(instrument_id, instrument)
    if instrument == nil or instrument:ClassName() ~= "TreeInstrument" then return end

    local doc = get_xml_document(self)
    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "instruments" then
            for element in xmlelements(root_element) do
                if element:FirstChildElement("instrument_id"):GetText() == tostring(instrument_id) then
                    instrument:SetUUID(element:FirstChildElement("instrument_uuid"):GetText())
                    if element:FirstChildElement("clef_3"):GetText() ~= "None" then
                        instrument:SetStaffCount(3)
                    elseif element:FirstChildElement("clef_2"):GetText() ~= "None" then
                        instrument:SetStaffCount(2)
                    else
                        instrument:SetStaffCount(1)
                    end
                    break
                end
            end
        end
        if root_element:Value() == "table" and root_element:Attribute("name") == "staff_or_group_names" then
            for element in xmlelements(root_element) do
                if element:FirstChildElement("instrument_id"):GetText() == tostring(instrument_id) then
                    instrument:SaveNewFullNameString(finale.FCString(element:FirstChildElement("full_name"):GetText()))
                    instrument:SaveNewAbbreviatedNameString(finale.FCString(element:FirstChildElement("abbreviated_name"):GetText()))
                    break
                end
            end
            break
        end
    end
    doc:Clear()
end

--- Returns an FCStrings object of all of the names of the filters from Finale.instruments.
--- @return FCStrings
function FinaleInstrumentXMLParser:CreateFilterStrings()
    local strings = finale.FCStrings()
    local doc = get_xml_document(self)

    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "instrument_filters" then
            for filter_element in xmlelements(root_element) do
                strings:AddCopy(finale.FCString(filter_element:FirstChildElement("filter_name"):GetText()))
            end
            break
        end
    end

    doc:Clear()
    
    return strings
end

--- Returns an FCStrings object containing all family names with at least one visible instrument
--- given the present filters (group filter and search bar filter). Takes no parameters, but should
--- be passed AFTER FinaleInstrumentXMLParser::CreateInstrumentStrings.
--- @return FCStrings
function FinaleInstrumentXMLParser:CreateFamilyStrings()
    local strings = finale.FCStrings()
    local family_visible = {}
    for i=1, calc_family_count(self) do
        family_visible[i] = false
    end
    for i=1, #self.filtered_instruments do
        local family = self.instrument_family_assignments[self.filtered_instruments[i]]
        if not family_visible[family] then
            family_visible[family] = true
        end
    end
    for i=1, #family_visible do
        if family_visible[i] then
            strings:AddCopy(finale.FCString(self.instrument_families[i]))
        end
    end

    return strings
end

--- Returns an FCStrings object containing the full names of all of the instruments belonging
--- to a particular filter and family as defined by Finale.instruments. If family == 0, then
--- all families will be considered. You can limit the result to only instruments containing
--- a substring search_filter.
--- @param filter integer
--- @param family integer
--- @param search_filter string
--- @return FCStrings
function FinaleInstrumentXMLParser:CreateInstrumentStrings(filter, family, search_filter)
    filter = filter or 1
    family = family or 0
    search_filter = search_filter or nil

    local strings = finale.FCStrings()
    local filtered_instruments = {}
    local visible_instruments = {}
    for i=1, #self.instruments do
        if self.filters[filter][i] then
            if search_filter == nil then
                filtered_instruments[#filtered_instruments+1] = i
                if family == 0 or self.instrument_family_assignments[i] == family then
                    strings:AddCopy(str)
                    visible_instruments[#visible_instruments+1] = i
                end
            else
                local str = finale.FCString(self.instruments[i])
                local comparison_str = string.lower(str.LuaString)
                search_filter = search_filter:lower()
                if comparison_str:match(search_filter) ~= nil then
                    filtered_instruments[#filtered_instruments+1] = i
                    if family == 0 or self.instrument_family_assignments[i] == family then
                        strings:AddCopy(str)
                        visible_instruments[#visible_instruments+1] = i
                    end
                end
            end
        end
    end
    self.filtered_instruments = filtered_instruments
    self.visible_instruments = visible_instruments
    return strings
end

--- Returns the family_ID of an instrument family (as defined by Finale.instruments) from a family_name LuaString argument.
--- If the family_name is not found, returns 0.
--- @param family_name string
--- @return integer
function FinaleInstrumentXMLParser:FindFamily(family_name)
    for i=1, #self.instrument_families do
        if self.instrument_families[i] == family_name then
            return i
        end
    end

    return 0
end

--- Returns a table of visible instruments by their instrument_ids.
--- @return integer[]
function FinaleInstrumentXMLParser:GetVisibleInstrumentsTable()
    return self.visible_instruments
end

--- Returns the number of staves an instrument possesses (as defined by Finale.instruments) given its UUID. Returns 0 if UUID is invalid.
--- @param uuid string
--- @return integer
function FinaleInstrumentXMLParser:GetInstrumentStaffCountFromUUID(uuid)
    if (type(uuid) ~= "string") then return 0 end

    local doc = get_xml_document(self)
    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "instruments" then
            for element in xmlelements(root_element) do
                if element:FirstChildElement("instrument_uuid"):GetText() == uuid then
                    if element:FirstChildElement("clef_3"):GetText() ~= "None" then
                        return 3
                    elseif element:FirstChildElement("clef_2"):GetText() ~= "None" then
                        return 2
                    else
                        return 1
                    end
                end
            end
        end
    end

    return 0
end

--- Returns an instrument family by ID (as defined by Finale.instruments) based on the instrument's UUID. Returns 0 if UUID is invalid.
--- @param uuid string
--- @return integer
function FinaleInstrumentXMLParser:GetInstrumentFamilyFromUUID(uuid)
    if (type(uuid) ~= "string") then return 0 end

    local doc = get_xml_document(self)
    for root_element in xmlelements(doc:RootElement()) do
        if root_element:Value() == "table" and root_element:Attribute("name") == "instruments" then
            for element in xmlelements(root_element) do
                if element:FirstChildElement("instrument_uuid"):GetText() == uuid then
                    local instrument_id = cmath.GetInteger(element:FirstChildElement("instrument_id"):GetText())
                    return self.instrument_family_assignments[instrument_id]
                end
            end
        end
    end

    return 0
end

return FinaleInstrumentXMLParser