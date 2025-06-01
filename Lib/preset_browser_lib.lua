--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module serves as a library that is primarily used by articulation_xml_parser.lua. It lists
    basic fields about the default order of articulations when creating a new document in Finale. It
    exists to simplify the process of writing out a new XML file for interpretting input from a VST plugin.

]]

-- Libray for accessing Finale's preset articulations and text expressions (static).
local preset = {}

--- @alias FCString unknown
--- @alias FCStrings unknown
--- @alias FCMusicRegion unknown
--- @alias FCNoteEntry unknown
--- @alias FCNoteEntryLayer unknown
--- @alias FCStaff unknown
--- @alias FCStaves unknown
--- @alias FCStaffNamePosition unknown
--- @alias FCStaffList unknown
--- @alias FCGroup unknown
--- @alias FCGroups unknown
--- @alias FCFontInfo unknown
--- @alias FCSystemStaves unknown
--- @alias FCTempoElement unknown
--- @alias FCTextExpressionDef unknown
--- @alias FCCtrlCheckbox unknown
--- @alias XMLDocument unknown

preset.FINEART = {
    STACCATO = 1,
    STACCATISSIMO = 2,
    TENUTO = 3,
    LOURE = 4,
    ACCENT = 5,
    ACCENT_STACCATO = 6,
    ACCENT_TENUTO = 7,
    MARCATO = 8,
    MARCATO_STACCATO = 9,
    MORDENT = 10,
    DOUBLE_MORDENT = 11,
    INVERTED_MORDENT = 12,
    TURN = 13,
    ONE = 14,
    TWO = 15,
    THREE = 16,
    FOUR = 17,
    FIVE = 18,
    TRILL = 19,
    TRILL_FLAT = 20,
    TRILL_SHARP = 21,
    TRILL_NATURAL = 22,
    OPEN = 23,
    CLOSED = 24,
    HALF_CLOSED = 25,
    UP_BOW = 26,
    DOWN_BOW = 27,
    CHANGE_BOW_DIRECTION_INDETERMINATE = 28,
    MUTE_ON = 29,
    FERMATA = 30,
    FERMATA_SHORT = 31,
    FERMATA_LONG = 32,
    TREMOLO_1 = 33,
    TREMOLO_2 = 34,
    TREMOLO_3 = 35,
    BUZZ_ROLL = 36,
    CAESURA = 37,
    BREATH_MARK_COMMA = 38,
    BREATH_MARK_CHECK = 39,
    DIAMOND = 40,
    GLISSANDO_WIGGLE_SEGMENT = 41,
    PEDAL_DOWN = 42,
    PEDAL_UP = 43,
    LAISSEZ_VIBRER = 44,
    ARPEGGIO = 45,
    GRACE_NOTE = 46,
    PARENTHESIS_OPEN = 47,
    PARENTHESIS_CLOSE = 48,
    UNSTRESS = 49,
    SNAP_PIZZICATO = 50,
    THUMB_POSITION = 51,
    BUZZ_PIZZICATO = 52,
    STRESS = 53,
    JETE = 54,
    TRIPLE_TONGUE = 55,
    DOUBLE_TONGUE = 56,
    WITH_FINGERNAILS = 57,
    SCOOP = 58,
    FALL_ROUGH_SHORT = 59,
    FALL_ROUGH_MEDIUM = 60,
    LIFT_ROUGH_SHORT = 61,
    LIFT_ROUGH_MEDIUM = 62,
    LIP_FALL_SHORT = 63,
    DOIT_SHORT = 64,
    FALL_SMOOTH_SHORT = 65,
    LIFT_SMOOTH_SHORT = 66
}

local preset_main_symbol_char = {
    0xE4A2,--STACCATO
    0xE4A8,--STACCATISSIMO
    0xE4A4,--TENUTO
    0xE4B2,--LOURE
    0xE4A0,--ACCENT
    0xE4B0,--ACCENT_STACCATO
    0xE4B4,--ACCENT_TENUTO
    0xE4AC,--MARCATO
    0xE4AE,--MARCATO_STACCATO
    0xE56C,--MORDENT
    0xE56E,--DOUBLE_MORDENT
    0xE56D,--INVERTED_MORDENT
    0xE567,--TURN
    0x0031,--ONE
    0x0032,--TWO
    0x0033,--THREE
    0x0034,--FOUR
    0x0035,--FIVE
    0xE566,--TRILL
    0xF5B2,--TRILL_FLAT
    0xF5B4,--TRILL_SHARP
    0xF5B3,--TRILL_NATURAL
    0xE614,--OPEN
    0xE5E5,--CLOSED
    0xE5E6,--HALF_CLOSED
    0xE612,--UP_BOW
    0xE610,--DOWN_BOW
    0xE626,--CHANGE_BOW_DIRECTION_INDETERMINATE
    0xE616,--MUTE_ON
    0xE4C0,--FERMATA
    0xE4C4,--FERMATA_SHORT
    0xE4C6,--FERMATA_LONG
    0xE220,--TREMOLO_1
    0xE221,--TREMOLO_2
    0xE222,--TREMOLO_3
    0xE22A,--BUZZ_ROLL
    0xE4D1,--CAESURA
    0xE4CE,--BREATH_MARK_COMMA
    0xE4CF,--BREATH_MARK_CHECK
    0xE0DA,--DIAMOND
    0xEAAF,--GLISSANDO_WIGGLE_SEGMENT
    0xE650,--PEDAL_DOWN
    0xE655,--PEDAL_UP
    0xE4BA,--LAISSEZ_VIBRER
    0xF700,--ARPEGGIO
    0xE560,--GRACE_NOTE
    0xE0F5,--PARENTHESIS_OPEN
    0xE0F6,--PARENTHESIS_CLOSE
    0xE4B8,--UNSTRESS
    0xE631,--SNAP_PIZZICATO
    0xE624,--THUMB_POSITION
    0xE632,--BUZZ_PIZZICATO
    0xE4B6,--STRESS
    0xE620,--JETE
    0xE5F2,--TRIPLE_TONGUE
    0xE5F0,--DOUBLE_TONGUE
    0xE636,--WITH_FINGERNAILS
    0xE5D0,--SCOOP
    0xE5DD,--FALL_ROUGH_SHORT
    0xE5DE,--FALL_ROUGH_MEDIUM
    0xE5D1,--LIFT_ROUGH_SHORT
    0xE5D2,--LIFT_ROUGH_MEDIUM
    0xE5D7,--LIP_FALL_SHORT
    0xE5D4,--DOIT_SHORT
    0xE5DA,--FALL_SMOOTH_SHORT
    0xE5EC--LIFT_SMOOTH_SHORT
}

local preset_flipped_symbol_char = {
    0xE4A3,--STACCATO
    0xE4A9,--STACCATISSIMO
    0xE4A5,--TENUTO
    0xE4B3,--LOURE
    0xE4A1,--ACCENT
    0xE4B1,--ACCENT_STACCATO
    0xE4B5,--ACCENT_TENUTO
    0xE4AD,--MARCATO
    0xE4AF,--MARCATO_STACCATO
    0xE56C,--MORDENT
    0xE56E,--DOUBLE_MORDENT
    0xE56D,--INVERTED_MORDENT
    0xE567,--TURN
    0x0031,--ONE
    0x0032,--TWO
    0x0033,--THREE
    0x0034,--FOUR
    0x0035,--FIVE
    0xE566,--TRILL
    0xF5B2,--TRILL_FLAT
    0xF5B4,--TRILL_SHARP
    0xF5B3,--TRILL_NATURAL
    0xE614,--OPEN
    0xE5E5,--CLOSED
    0xE5E6,--HALF_CLOSED
    0xE612,--UP_BOW
    0xE610,--DOWN_BOW
    0xE626,--CHANGE_BOW_DIRECTION_INDETERMINATE
    0xE617,--MUTE_ON
    0xE4C1,--FERMATA
    0xE4C5,--FERMATA_SHORT
    0xE4C7,--FERMATA_LONG
    0xE220,--TREMOLO_1
    0xE221,--TREMOLO_2
    0xE222,--TREMOLO_3
    0xE22A,--BUZZ_ROLL
    0xE4D1,--CAESURA
    0xE4CE,--BREATH_MARK_COMMA
    0xE4CF,--BREATH_MARK_CHECK
    0xE0DA,--DIAMOND
    0xEAAF,--GLISSANDO_WIGGLE_SEGMENT
    0xE650,--PEDAL_DOWN
    0xE655,--PEDAL_UP
    0xE4BB,--LAISSEZ_VIBRER
    0xF700,--ARPEGGIO
    0xE560,--GRACE_NOTE
    0xE0F5,--PARENTHESIS_OPEN
    0xE0F6,--PARENTHESIS_CLOSE
    0xE4B9,--UNSTRESS
    0xE630,--SNAP_PIZZICATO
    0xE625,--THUMB_POSITION
    0xE632,--BUZZ_PIZZICATO
    0xE4B7,--STRESS
    0xE621,--JETE
    0xE5F3,--TRIPLE_TONGUE
    0xE5F1,--DOUBLE_TONGUE
    0xE636,--WITH_FINGERNAILS
    0xE5D0,--SCOOP
    0xE5DD,--FALL_ROUGH_SHORT
    0xE5DE,--FALL_ROUGH_MEDIUM
    0xE5D1,--LIFT_ROUGH_SHORT
    0xE5D2,--LIFT_ROUGH_MEDIUM
    0xE5D7,--LIP_FALL_SHORT
    0xE5D4,--DOIT_SHORT
    0xE5DA,--FALL_SMOOTH_SHORT
    0xE5EC--LIFT_SMOOTH_SHORT
}

--- Returns the ItemNo of the articulation definition from a given preset number.
--- Preset number comes from the default order of the Finale articulation selection dialog (see table: fineart).
--- Matches presets to articulation definitions based on the main and flipped symbol characters.
--- @param preset_number integer
--- @return integer?
function preset.FindArticulationDef(preset_number)
    local art_defs = finale.FCArticulationDefs()
    art_defs:LoadAll()
    for art_def in each(art_defs) do
        if art_def:GetMainSymbolChar() == preset_main_symbol_char[preset_number]
            and art_def:GetFlippedSymbolChar() == preset_flipped_symbol_char[preset_number] then
                return art_def.ItemNo
        end
    end
end

--- Returns the FCTextExpressionDef object from the given category (integer) and name (LuaString).
--- Optional third parameter: create_if_not_found (boolean) - creates the FCTextExpressionDef if not found (default: false).
--- @param category integer|string
--- @param name any LuaString or FCString
--- @param create_if_not_found? boolean
--- @return FCTextExpressionDef?
function preset.FindTextExpressionDef(category, name, create_if_not_found)
    create_if_not_found = create_if_not_found or false
    if type(category) == "string" then
        local cat_defs = finale.FCCategoryDefs()
        cat_defs:LoadAll()
        local cat_def = cat_defs:FindName(finale.FCString(category))
        category = cat_def.ItemNo
    end
    if category == nil then return end
    if type(name) == "userdata" and name:ClassName() == "FCString" then
        name:TrimEnigmaTags()
        name = name.LuaString
    end


    local text_defs = finale.FCTextExpressionDefs()
    text_defs:LoadAll()
    for text_def in each(text_defs) do
        local text_def_string = text_def:CreateTextString()
        text_def_string:TrimEnigmaTags()
        if text_def:GetCategoryID() == category and text_def_string.LuaString == name then
            return text_def
        end
    end

    --Create FCTextExpressionDef if not found
    if create_if_not_found then
        local text_def = finale.FCTextExpressionDef()
        local str = finale.FCString()
        local category_def = finale.FCCategoryDef()
        category_def:Load(category)
        str.LuaString = name
        text_def:AssignToCategory(category_def)
        text_def:SaveNewTextBlock(str)
        text_def:SaveNew()
        return text_def
    end
end

return preset