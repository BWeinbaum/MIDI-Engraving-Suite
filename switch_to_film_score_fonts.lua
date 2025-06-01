--[[

    Copyright (c) 2024 Brendan Weinbaum.
    All rights reserved.

    This module is responsible for carrying out the subtask of superimposing formatting preferences
    onto an existing musical document. In the future, it will save and read data as template files.

]]

function plugindef()
    -- This function and the 'finaleplugin' namespace
    -- are both reserved for the plug-in definition.
    finaleplugin.Author = "Brendan Weinbaum"
    finaleplugin.Version = "0.1.0-alpha.3"
    finaleplugin.Date = "Aug 2024"
    finaleplugin.Copyright = "Copyright (c) 2024 Brendan Weinbaum. All rights reserved."
    return "Superimpose Template", "Superimpose Template", "Superimpose details of a template onto the score."
end


local midi = require "Lib.midi_engraving_lib"
local FinaleInstrumentXMLParser = require "Lib.finale_instrument_xml_parser"

local current_directory = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])")
local finale_xml_parser = FinaleInstrumentXMLParser.Init(current_directory .. 'Lib/Data/finale.xml')
-- Purposefully not using the parser initialize method to save on time at program start.
-- Data is pulled from Finale.instruments dynamically while the program runs.

-- Default config. TODO: Replace by reading from XML file.
local config = {

    RESIZE_TABLOID = true,

    -- LETTER-SIZE CONFIG --
    -- Title/M-Number for First Page
    FONTNAME_TITLE = "Palatino Linotype",
    SIZE_TITLE = 26,
    BOLD_TITLE = true,
    ITALIC_TITLE = false,
    UNDERLINE_TITLE = false,
    STRIKEOUT_TITLE = false,
    XOFFSET_TITLE = 0,
    YOFFSET_TITLE = -72,
    HALIGN_TITLE = finale.TEXTHORIZALIGN_CENTER,
    VALIGN_TITLE = finale.TEXTVERTALIGN_TOP,
    PAGEEDGEREF_TITLE = true,
    CAPITALIZE_TITLE = true,
    REPEAT_TITLE = true,

    -- Title/M-Number for Subsequent Pages
    FONTNAME_TITLE_SUBSEQUENT = "Palatino Linotype",
    SIZE_TITLE_SUBSEQUENT = 12,
    BOLD_TITLE_SUBSEQUENT = true,
    ITALIC_TITLE_SUBSEQUENT = false,
    UNDERLINE_TITLE_SUBSEQUENT = false,
    STRIKEOUT_TITLE_SUBSEQUENT = false,
    XOFFSET_TITLE_SUBSEQUENT = -144,
    YOFFSET_TITLE_SUBSEQUENT = -72,
    HALIGN_TITLE_SUBSEQUENT = finale.TEXTHORIZALIGN_RIGHT,
    VALIGN_TITLE_SUBSEQUENT = finale.TEXTVERTALIGN_TOP,
    PAGEEDGEREF_TITLE_SUBSEQUENT = true,
    --TODO: Functionality for horizontal alignment, vertical alignment, and page edge ref
    --TODO: Redo algorithm to first remove all text blocks with fileinfo and make new ones.

    -- Subtitle/Cue Title
    FONTNAME_SUBTITLE = "Palatino Linotype",
    SIZE_SUBTITLE = 13,
    BOLD_SUBTITLE = true,
    ITALIC_SUBTITLE = true,
    UNDERLINE_SUBTITLE = false,
    STRIKEOUT_SUBTITLE = false,
    XOFFSET_SUBTITLE = 0,
    YOFFSET_SUBTITLE = -179,
    HALIGN_SUBTITLE = finale.TEXTHORIZALIGN_CENTER,
    VALIGN_SUBTITLE = finale.TEXTVERTALIGN_TOP,
    PAGEEDGEREF_SUBTITLE = true,
    BOUNDARIES_SUBTITLE = "\"",

    -- Description/Film Title
    FONTNAME_DESCRIPTION = "Palatino Linotype",
    SIZE_DESCRIPTION = 12,
    BOLD_DESCRIPTION = true,
    ITALIC_DESCRIPTION = false,
    UNDERLINE_DESCRIPTION = false,
    STRIKEOUT_DESCRIPTION = false,
    XOFFSET_DESCRIPTION = 144,
    YOFFSET_DESCRIPTION = -72,
    HALIGN_DESCRIPTION = finale.TEXTHORIZALIGN_LEFT,
    VALIGN_DESCRIPTION = finale.TEXTVERTALIGN_TOP,
    PAGEEDGEREF_DESCRIPTION = true,
    REPEAT_DESCRIPTION = true,
    CAPITALIZE_DESCRIPTION = true,

    -- Score/Part Name
    FONTNAME_PARTNAME = "Palatino Linotype",
    SIZE_PARTNAME = 12,
    BOLD_PARTNAME = false,
    ITALIC_PARTNAME = false,
    UNDERLINE_PARTNAME = false,
    STRIKEOUT_PARTNAME = false,
    XOFFSET_PARTNAME = 144,
    YOFFSET_PARTNAME = -130,
    HALIGN_PARTNAME = finale.TEXTHORIZALIGN_LEFT,
    VALIGN_PARTNAME = finale.TEXTVERTALIGN_TOP,
    PAGEEDGEREF_PARTNAME = true,
    SCORENAME = 'Score in C',

    -- Composer
    FONTNAME_COMPOSER = "Palatino Linotype",
    SIZE_COMPOSER = 12,
    BOLD_COMPOSER = false,
    ITALIC_COMPOSER = false,
    UNDERLINE_COMPOSER = false,
    STRIKEOUT_COMPOSER = false,
    XOFFSET_COMPOSER = -144,
    YOFFSET_COMPOSER = -167,
    HALIGN_COMPOSER = finale.TEXTHORIZALIGN_RIGHT,
    VALIGN_COMPOSER = finale.TEXTVERTALIGN_TOP,
    PAGEEDGEREF_COMPOSER = true,

    -- Arranger/Orchestrator
    FONTNAME_ARRANGER = "Palatino Linotype",
    SIZE_ARRANGER = 12,
    BOLD_ARRANGER = false,
    ITALIC_ARRANGER = true,
    UNDERLINE_ARRANGER = false,
    STRIKEOUT_ARRANGER = false,
    XOFFSET_ARRANGER = -144,
    YOFFSET_ARRANGER = -219,
    HALIGN_ARRANGER = finale.TEXTHORIZALIGN_RIGHT,
    VALIGN_ARRANGER = finale.TEXTVERTALIGN_TOP,
    PAGEEDGEREF_ARRANGER = true,

    -- Full Staff Names
    FONTNAME_FULLSTAFF = "Palatino Linotype",
    SIZE_FULLSTAFF = 12,
    BOLD_FULLSTAFF = false,
    ITALIC_FULLSTAFF = false,
    UNDERLINE_FULLSTAFF = false,
    STRIKEOUT_FULLSTAFF = false,

    -- Abbreviated Staff Names
    FONTNAME_ABRVSTAFF = "Palatino Linotype",
    SIZE_ABRVSTAFF = 12,
    BOLD_ABRVSTAFF = false,
    ITALIC_ABRVSTAFF = false,
    UNDERLINE_ABRVSTAFF = false,
    STRIKEOUT_ARVSTAFF = false,

    -- Group Names
    FONTNAME_FULLGROUP = "Palatino Linotype",
    SIZE_FULLGROUP = 12,
    BOLD_FULLGROUP = false,
    ITALIC_FULLGROUP = false,
    UNDERLINE_FULLGROUP = false,
    STRIKEOUT_FULLGROUP = false,

    -- Abbreviated Group Names
    FONTNAME_ABRVGROUP = "Palatino Linotype",
    SIZE_ABRVGROUP = 12,
    BOLD_ABRVGROUP = false,
    ITALIC_ABRVGROUP = false,
    UNDERLINE_ABRVGROUP = false,
    STRIKEOUT_ABRVGROUP = false,

    -- Page Numbers
    FONTNAME_PAGE = "Palatino Linotype",
    SIZE_PAGE = 12,
    BOLD_PAGE = true,
    ITALIC_PAGE = false,
    UNDERLINE_PAGE = false,
    STRIKEOUT_PAGE = false,
    XOFFSET_PAGE = 0,
    YOFFSET_PAGE = -72,
    HALIGN_PAGE = finale.TEXTHORIZALIGN_CENTER,
    VALIGN_PAGE = finale.TEXTVERTALIGN_TOP,
    PAGEEDGEREF_PAGE = true,
    BOUNDARIES_PAGE = "-",

    -- Default Text Block
    FONTNAME_DEF = "Palatino Linotype",
    SIZE_DEF = 12,
    BOLD_DEF = false,
    ITALIC_DEF = false,
    UNDERLINE_DEF = false,
    STRIKEOUT_DEF = false,

    -- Prefs
    PREFS_BEAM_COMMON_TIME_EIGHTHS = false,
    PREFS_HIDE_DEFAULT_WHOLE_RESTS = true,

    -- Page Margins
    PAGE_TOPMARGIN = 144,
    PAGE_BOTTOMMARGIN = 144,
    PAGE_LEFTMARGIN = 144,
    PAGE_RIGHTMARGIN = 144,
    PAGE_USEFACINGPAGES = false,
    RIGHTPAGE_TOPMARGIN = 0,
    RIGHTPAGE_BOTTOMMARGIN = 0,
    RIGHTPAGE_LEFTMARGIN = 0,
    RIGHTPAGE_RIGHTMARGIN = 0,
    PAGE_USEFIRSTPAGETOPMARGIN = false,
    FIRSTPAGE_TOPMARGIN = 0,

    -- System Margins
    SYSTEM_TOPMARGIN = 107,
    SYSTEM_BOTTOMMARGIN = 48,
    SYSTEM_LEFTMARGIN = 144,
    SYSTEM_RIGHTMARGIN = 0,
    SYSTEM_USEFIRSTSYSTEMMARGINS = true,
    FIRSTSYSTEM_TOPMARGIN = 288,
    FIRSTSYSTEM_LEFTMARGIN = 334,

    -- Staff List and Vertical Space
    STAFFLIST_TOP = true,
    STAFFLIST_BOTTOM = false,
    STAFFLIST_UUIDS_ONCE = {finale.FFUUID_VIOLINSECTION},
    VERTICAL_SPACE_PERCENT = 167,

    -- Tempo Expression Category Settings
    CAT_TEMPO_TEXT_FONTNAME = "Palatino Linotype",
    CAT_TEMPO_TEXT_SIZE = 24,
    CAT_TEMPO_TEXT_BOLD = true,
    CAT_TEMPO_TEXT_ITALIC = false,
    CAT_TEMPO_TEXT_UNDERLINE = false,
    CAT_TEMPO_TEXT_STRIKEOUT = false,
    CAT_TEMPO_MUSIC_FONTNAME = "Finale Maestro",
    CAT_TEMPO_MUSIC_SIZE = 24,
    CAT_TEMPO_MUSIC_BOLD = false,
    CAT_TEMPO_MUSIC_ITALIC = false,
    CAT_TEMPO_MUSIC_UNDERLINE = false,
    CAT_TEMPO_MUSIC_STRIKEOUT = false,
    CAT_TEMPO_NUMBER_FONTNAME = "Palatino Linotype",
    CAT_TEMPO_NUMBER_SIZE = 24,
    CAT_TEMPO_NUMBER_BOLD = true,
    CAT_TEMPO_NUMBER_ITALIC = false,
    CAT_TEMPO_NUMBER_UNDERLINE = false,
    CAT_TEMPO_NUMBER_STRIKEOUT = false,

    -- Tempo Alterations Category Settings
    CAT_TALTER_TEXT_FONTNAME = "Palatino Linotype",
    CAT_TALTER_TEXT_SIZE = 18,
    CAT_TALTER_TEXT_BOLD = false,
    CAT_TALTER_TEXT_ITALIC = true,
    CAT_TALTER_TEXT_UNDERLINE = false,
    CAT_TALTER_TEXT_STRIKEOUT = false,
    CAT_TALTER_MUSIC_FONTNAME = "Finale Maestro",
    CAT_TALTER_MUSIC_SIZE = 24,
    CAT_TALTER_MUSIC_BOLD = false,
    CAT_TALTER_MUSIC_ITALIC = false,
    CAT_TALTER_MUSIC_UNDERLINE = false,
    CAT_TALTER_MUSIC_STRIKEOUT = false,

    -- Expressions Category Settings
    CAT_EXPRESSIONS_TEXT_FONTNAME = "Palatino Linotype",
    CAT_EXPRESSIONS_TEXT_SIZE = 12,
    CAT_EXPRESSIONS_TEXT_BOLD = false,
    CAT_EXPRESSIONS_TEXT_ITALIC = true,
    CAT_EXPRESSIONS_TEXT_UNDERLINE = false,
    CAT_EXPRESSIONS_TEXT_STRIKEOUT = false,
    CAT_EXPRESSIONS_MUSIC_FONTNAME = "Finale Maestro",
    CAT_EXPRESSIONS_MUSIC_SIZE = 24,
    CAT_EXPRESSIONS_MUSIC_BOLD = false,
    CAT_EXPRESSIONS_MUSIC_ITALIC = false,
    CAT_EXPRESSIONS_MUSIC_UNDERLINE = false,
    CAT_EXPRESSIONS_MUSIC_STRIKEOUT = false,

    -- Technique Text Category Settings
    CAT_TECHNIQUE_TEXT_FONTNAME = "Palatino Linotype",
    CAT_TECHNIQUE_TEXT_SIZE = 12,
    CAT_TECHNIQUE_TEXT_BOLD = false,
    CAT_TECHNIQUE_TEXT_ITALIC = false,
    CAT_TECHNIQUE_TEXT_UNDERLINE = false,
    CAT_TECHNIQUE_TEXT_STRIKEOUT = false,
    CAT_TECHNIQUE_MUSIC_FONTNAME = "Finale Maestro",
    CAT_TECHNIQUE_MUSIC_SIZE = 24,
    CAT_TECHNIQUE_MUSIC_BOLD = false,
    CAT_TECHNIQUE_MUSIC_ITALIC = false,
    CAT_TECHNIQUE_MUSIC_UNDERLINE = false,
    CAT_TECHNIQUE_MUSIC_STRIKEOUT = false
}

-- CONFIG ENDS HERE --

-- Resizes all pages to tabloid and alters default page size settings to match.
local function resize_tabloid()
    local page_format_prefs = finale.FCPageFormatPrefs()
    page_format_prefs:LoadScore()
    page_format_prefs:SetPageWidth(3168)
    page_format_prefs:SetPageHeight(4896)
    page_format_prefs:SetPageScaling(100)
    page_format_prefs:Save()

    local pages = finale.FCPages()
    pages:LoadAll()
    for page in each(pages) do
        page:SetWidth(page_format_prefs:GetPageWidth())
        page:SetHeight(page_format_prefs:GetPageHeight())
        page:SetPercent(page_format_prefs:GetPageScaling())
    end
    pages:SaveAll()
end

--- Returns an FCFontInfo object based on the given parameters.
--- @param name FCString
--- @param size integer
--- @param bold boolean
--- @param italic boolean
--- @param underline boolean
--- @param strikeout boolean
--- @return FCFontInfo?
local function create_font_info(name, size, bold, italic, underline, strikeout)
    if not name then return nil end
    if not size then return nil end
    bold = bold or false
    italic = italic or false
    underline = underline or false
    strikeout = strikeout or false
    
    local fontinfo = finale.FCFontInfo()
    fontinfo:SetNameString(name)
    fontinfo:SetSize(size)
    fontinfo:SetBold(bold)
    fontinfo:SetItalic(italic)
    fontinfo:SetUnderline(underline)
    fontinfo:SetStrikeOut(strikeout)
    return fontinfo
end

-- For all staves in the score, this method changes their names to reflect the staff name font preferences.
local function reset_staff_names()
    local staves = finale.FCStaves()
	staves:LoadAll()

    local fullstaff_prefs = finale.FCFontPrefs()
    local abrvstaff_prefs = finale.FCFontPrefs()
    fullstaff_prefs:Load(finale.FONTPREF_STAFFNAME)
    abrvstaff_prefs:Load(finale.FONTPREF_ABRVSTAFFNAME)
    local fullstaff_font = fullstaff_prefs:CreateFontInfo():CreateEnigmaString(nil)
    local abrvstaff_font = abrvstaff_prefs:CreateFontInfo():CreateEnigmaString(nil)

	for staff in each(staves) do
        local fullstaff_name = staff:CreateTrimmedFullNameString()
        local abrvstaff_name = staff:CreateTrimmedAbbreviatedNameString()
        local new_fullstaff_name = finale.FCString()
        local new_abrvstaff_name = finale.FCString()

        new_fullstaff_name:AppendString(fullstaff_font)
        new_fullstaff_name:AppendString(fullstaff_name)
        new_abrvstaff_name:AppendString(abrvstaff_font)
        new_abrvstaff_name:AppendString(abrvstaff_name)

        staff:SaveFullNameString(new_fullstaff_name)
        staff:SaveAbbreviatedNameString(new_abrvstaff_name)
	end
end

-- For all groups in the score, this method changes their names to reflect the group name font preferences.
local function reset_group_names()
    local groups = finale.FCGroups()
    groups:LoadAll()

    local fullgroup_prefs = finale.FCFontPrefs()
    local abrvgroup_prefs = finale.FCFontPrefs()
    fullgroup_prefs:Load(finale.FONTPREF_GROUPNAME)
    abrvgroup_prefs:Load(finale.FONTPREF_ABRVGROUPNAME)
    local fullgroup_font = fullgroup_prefs:CreateFontInfo():CreateEnigmaString(nil)
    local abrvgroup_font = abrvgroup_prefs:CreateFontInfo():CreateEnigmaString(nil)

    for g in each(groups) do
        if g:HasFullName() then
            local fullgroup_name = g:CreateTrimmedFullNameString()
            local new_fullgroup_name = finale.FCString()
            new_fullgroup_name:AppendString(fullgroup_font)
            new_fullgroup_name:AppendString(fullgroup_name)
            g:SaveNewFullNameBlock(new_fullgroup_name)
            g:Save()
        end

        if g:HasAbbreviatedName() then
            local abrvgroup_name = g:CreateAbbreviatedNameString()
            abrvgroup_name:TrimEnigmaTags()
            local new_abrvgroup_name = finale.FCString()
            new_abrvgroup_name:AppendString(abrvgroup_font)
            new_abrvgroup_name:AppendString(abrvgroup_name)
            g:SaveNewAbbreviatedNameBlock(new_abrvgroup_name)
            g:Save()
        end
    end
end

-- Handles transformation from the Assign Staves algorithm to cleaner, default Finale format.
local function transfer_instrument_names()
    local groups = finale.FCGroups()
    groups:LoadAll()
    for group in eachbackwards(groups) do
        if group:GetStartStaff() == group:GetEndStaff() and midi.IsValidInstrument(group) then
            midi.HandleGroupConsolidation(group)
        elseif midi.IsValidMultistaffDetectionGroup(group) then
            if midi.IsMultistaffDoneCombining(group) then
                local staves_in_multistaff_instrument_group = midi.GetStavesFromGroup(group)
                for staff in each(staves_in_multistaff_instrument_group) do
                    staff:SetShowScoreStaffNames(false)
                    staff:Save()
                end
            end
        end
    end
end

-- Updates all text blocks in the document to match the font preferences.
-- Includes updates to positioning for title, subtitle, description, part name, composer, arranger, and page number.
local function reset_text_blocks()
    local page_texts = finale.FCPageTexts()
    page_texts:LoadAll()

    -- Remove Existing File Info Page Texts
    for pt in eachbackwards(page_texts) do
        local text_string = pt:CreateTextString()
        local enigma_tags = text_string:CreateEnigmaStrings()
        for tag in each(enigma_tags) do
            if tag:IsEnigmaFileInfoTitle() or
                tag:IsEnigmaFileInfoSubtitle() or
                tag:IsEnigmaFileInfoComposer() or
                tag:IsEnigmaFileInfoArranger() or
                tag.LuaString == "^description()" or
                tag.LuaString == "^partname()" or
                tag.LuaString == "^page(0)" then
                    local tb = pt:CreateTextBlock()
                    tb:DeepDeleteData()
                    pt:DeleteData()
            end
        end
    end

    -- Create New Ones
    local function create_page_text(font_info, text, xoffset, yoffset, halign, valign, pageedgeref, save_loc, first_page)
        if font_info == nil then return end
        first_page = first_page or nil
        local page_text = finale.FCPageText()
        local str = font_info:CreateEnigmaString(nil)
        str:AppendLuaString(text)
        page_text:SaveNewTextBlock(str)
        page_text:SetHorizontalPos(xoffset)
        page_text:SetVerticalPos(yoffset)
        page_text:SetHorizontalAlignment(halign)
        page_text:SetVerticalAlignment(valign)
        page_text:SetPageEdgeRef(pageedgeref)
        if first_page ~= nil then page_text:SetFirstPage(first_page) end
        page_text:SaveNew(save_loc)
    end

    local file_info_text = finale.FCFileInfoText()
    local info_read = finale.FCString()
    local font_info = create_font_info(finale.FCString(config.FONTNAME_TITLE), config.SIZE_TITLE, config.BOLD_TITLE, config.ITALIC_TITLE, config.UNDERLINE_TITLE, config.STRIKEOUT_TITLE)
    create_page_text(font_info, '^title()', config.XOFFSET_TITLE, config.YOFFSET_TITLE, config.HALIGN_TITLE, config.VALIGN_TITLE, config.PAGEEDGEREF_TITLE, 1)
    if config.REPEAT_TITLE then
        font_info = create_font_info(finale.FCString(config.FONTNAME_TITLE_SUBSEQUENT), config.SIZE_TITLE_SUBSEQUENT, config.BOLD_TITLE_SUBSEQUENT, config.ITALIC_TITLE_SUBSEQUENT, config.UNDERLINE_TITLE_SUBSEQUENT, config.STRIKEOUT_TITLE_SUBSEQUENT)
        create_page_text(font_info, '^title()', config.XOFFSET_TITLE_SUBSEQUENT, config.YOFFSET_TITLE_SUBSEQUENT, config.HALIGN_TITLE_SUBSEQUENT, config.VALIGN_TITLE_SUBSEQUENT, config.PAGEEDGEREF_TITLE_SUBSEQUENT, 0, 2)
    end

    font_info = create_font_info(finale.FCString(config.FONTNAME_SUBTITLE), config.SIZE_SUBTITLE, config.BOLD_SUBTITLE, config.ITALIC_SUBTITLE, config.UNDERLINE_SUBTITLE, config.STRIKEOUT_SUBTITLE)
    file_info_text:LoadSubtitle()
    file_info_text:GetText(info_read)
    
    if info_read.LuaString ~= '' then create_page_text(font_info, config.BOUNDARIES_SUBTITLE .. '^subtitle()' .. config.BOUNDARIES_SUBTITLE, config.XOFFSET_SUBTITLE, config.YOFFSET_SUBTITLE, config.HALIGN_SUBTITLE, config.VALIGN_SUBTITLE, config.PAGEEDGEREF_SUBTITLE, 1) end
    info_read.LuaString = ''

    font_info = create_font_info(finale.FCString(config.FONTNAME_DESCRIPTION), config.SIZE_DESCRIPTION, config.BOLD_DESCRIPTION, config.ITALIC_DESCRIPTION, config.UNDERLINE_DESCRIPTION, config.STRIKEOUT_DESCRIPTION)
    if config.REPEAT_DESCRIPTION then create_page_text(font_info, '^description()', config.XOFFSET_DESCRIPTION, config.YOFFSET_DESCRIPTION, config.HALIGN_DESCRIPTION, config.VALIGN_DESCRIPTION, config.PAGEEDGEREF_DESCRIPTION, 0)
    else create_page_text(font_info, '^description()', config.XOFFSET_DESCRIPTION, config.YOFFSET_DESCRIPTION, config.HALIGN_DESCRIPTION, config.VALIGN_DESCRIPTION, config.PAGEEDGEREF_DESCRIPTION, 1) end

    font_info = create_font_info(finale.FCString(config.FONTNAME_PARTNAME), config.SIZE_PARTNAME, config.BOLD_PARTNAME, config.ITALIC_PARTNAME, config.UNDERLINE_PARTNAME, config.STRIKEOUT_PARTNAME)
    create_page_text(font_info, '^partname()', config.XOFFSET_PARTNAME, config.YOFFSET_PARTNAME, config.HALIGN_PARTNAME, config.VALIGN_PARTNAME, config.PAGEEDGEREF_PARTNAME, 1)

    font_info = create_font_info(finale.FCString(config.FONTNAME_COMPOSER), config.SIZE_COMPOSER, config.BOLD_COMPOSER, config.ITALIC_COMPOSER, config.UNDERLINE_COMPOSER, config.STRIKEOUT_COMPOSER)
    create_page_text(font_info, '^composer()', config.XOFFSET_COMPOSER, config.YOFFSET_COMPOSER, config.HALIGN_COMPOSER, config.VALIGN_COMPOSER, config.PAGEEDGEREF_COMPOSER, 1)

    font_info = create_font_info(finale.FCString(config.FONTNAME_ARRANGER), config.SIZE_ARRANGER, config.BOLD_ARRANGER, config.ITALIC_ARRANGER, config.UNDERLINE_ARRANGER, config.STRIKEOUT_ARRANGER)
    file_info_text:LoadArranger()
    file_info_text:GetText(info_read)
    
    if info_read.LuaString ~= '' then create_page_text(font_info, 'orch. ' .. '^arranger()', config.XOFFSET_ARRANGER, config.YOFFSET_ARRANGER, config.HALIGN_ARRANGER, config.VALIGN_ARRANGER, config.PAGEEDGEREF_ARRANGER, 1) end

    font_info = create_font_info(finale.FCString(config.FONTNAME_PAGE), config.SIZE_PAGE, config.BOLD_PAGE, config.ITALIC_PAGE, config.UNDERLINE_PAGE, config.STRIKEOUT_PAGE)
    create_page_text(font_info, config.BOUNDARIES_PAGE .. ' ^page(0) ' .. config.BOUNDARIES_PAGE, config.XOFFSET_PAGE, config.YOFFSET_PAGE, config.HALIGN_PAGE, config.VALIGN_PAGE, config.PAGEEDGEREF_PAGE, 0, 2)
end

-- Adjusts the margins of the score and their preferences.
local function fix_margins()
    local page_format_prefs = finale.FCPageFormatPrefs()

    page_format_prefs:LoadScore()
    page_format_prefs:SetLeftPageTopMargin(config.PAGE_TOPMARGIN)
    page_format_prefs:SetLeftPageBottomMargin(config.PAGE_BOTTOMMARGIN)
    page_format_prefs:SetLeftPageLeftMargin(config.PAGE_LEFTMARGIN)
    page_format_prefs:SetLeftPageRightMargin(config.PAGE_RIGHTMARGIN)
    page_format_prefs:SetUseFacingPages(config.PAGE_USEFACINGPAGES)
    page_format_prefs:SetRightPageTopMargin(config.RIGHTPAGE_TOPMARGIN)
    page_format_prefs:SetRightPageBottomMargin(config.RIGHTPAGE_BOTTOMMARGIN)
    page_format_prefs:SetRightPageLeftMargin(config.RIGHTPAGE_LEFTMARGIN)
    page_format_prefs:SetRightPageRightMargin(config.RIGHTPAGE_RIGHTMARGIN)
    page_format_prefs:SetUseFirstPageTopMargin(config.PAGE_USEFIRSTPAGETOPMARGIN)
    page_format_prefs:SetFirstPageTopMargin(config.FIRSTPAGE_TOPMARGIN)
    page_format_prefs:SetSystemTop(config.SYSTEM_TOPMARGIN)
    page_format_prefs:SetSystemBottom(config.SYSTEM_BOTTOMMARGIN)
    page_format_prefs:SetSystemLeft(config.SYSTEM_LEFTMARGIN)
    page_format_prefs:SetSystemRight(config.SYSTEM_RIGHTMARGIN)
    page_format_prefs:SetUseFirstSystemMargins(config.SYSTEM_USEFIRSTSYSTEMMARGINS)
    page_format_prefs:SetFirstSystemTop(config.FIRSTSYSTEM_TOPMARGIN)
    page_format_prefs:SetFirstSystemLeft(config.FIRSTSYSTEM_LEFTMARGIN)
    page_format_prefs:Save()

    local first_page = finale.FCPage()
    first_page:Load(1)
    first_page:UpdateLayout(true)

    local systems = finale.FCStaffSystems()
    systems:LoadAll()
    for system in each(systems) do
        if system.ItemNo ~= 1 or not config.SYSTEM_USEFIRSTSYSTEMMARGINS then
            system:SetTopMargin(page_format_prefs:GetSystemTop())
            system:SetLeftMargin(page_format_prefs:GetSystemLeft())
        else
            system:SetTopMargin(page_format_prefs:GetFirstSystemTop())
            system:SetLeftMargin(page_format_prefs:GetFirstSystemLeft())
        end
        system:SetBottomMargin(page_format_prefs:GetSystemBottom())
        system:SetRightMargin(page_format_prefs:GetSystemRight())
    end
    systems:SaveAll()
end

--- Returns an FCStaffList object after loading the information from config onto the Staff List with the item number argument.
--- @param item_no integer
--- @param mode integer
--- @return FCStaffList?
local function load_staff_list(item_no, mode)
    local staff_list = finale.FCStaffList()
    staff_list:SetMode(mode) -- Move to config
    local staff_list_exists = staff_list:Load(item_no)

    if not staff_list_exists then return end
    
    if config.STAFFLIST_TOP then staff_list:AddTopStaff()
    else staff_list:RemoveTopStaff() end
    if config.STAFFLIST_BOTTOM then staff_list:AddBottomStaff()
    else staff_list:RemoveBottomStaff() end

    local staff_list_staff_count = staff_list:GetStaffCount()
    for i=0, staff_list_staff_count - 1 do
        staff_list:RemoveStaff(staff_list:GetStaff(i))
    end
    
    for i=1, #config.STAFFLIST_UUIDS_ONCE do
        -- Search score for first instance of UUID and add to staff list
        local staves = finale.FCStaves()
        midi.LoadStaves(staves)
        for staff in each(staves) do
            if staff:GetInstrumentUUID() == config.STAFFLIST_UUIDS_ONCE[i] then
                staff_list:AddStaff(staff.ItemNo)
                break
            end
        end
    end

    staff_list:Save()

    return staff_list
end

--- Creates vertical spaces in the score based on staves included in the FCStaffList argument.
--- Excludes the top and bottom staves.
--- @param staff_list FCStaffList FCStaffList
local function create_vertical_spaces(staff_list)
    if staff_list == nil then return end
    local destinations = {} -- Table of numbers representing the staff CMPERs where a vertical space should be created.

    -- Not the most effective method of filling the table, but FCStaffList:GetStaff() does not
    -- appear to work.
    local staves = finale.FCStaves()
    midi.LoadStaves(staves)
    for staff in each(staves) do
        if staff_list:IncludesStaff(staff.ItemNo) then
            destinations[#destinations+1] = staff.ItemNo
        end
    end
    
    local systems = finale.FCStaffSystems()
    systems:LoadAll()
    for system in each(systems) do
        local sys_staves = system:CreateSystemStaves()
        for i=1, #destinations do
            print(destinations[i])
            local des_sys_staff = sys_staves:FindStaff(destinations[i])
            -- Apply distance change
            if des_sys_staff ~= nil then
                midi.MoveSystemStaves(sys_staves, des_sys_staff.ItemInci, config.VERTICAL_SPACE_PERCENT, true)
            end
        end
    end
end

-- Creates groups for instruments of the same UUID and groups for instruments of the same family.
local function autogroup_instruments()
    -- UUID must be single-staff and not Unknown.
    local function uuid_is_groupable(uuid)
        if uuid == finale.FFUUID_UNKNOWN then return false end
        if finale_xml_parser:GetInstrumentStaffCountFromUUID(uuid) > 1 then return false end
        return true
    end

    --- Creates an FCGroup representing a single instrument (pairs the instrument's articulation staves).
    --- @param group_start integer
    --- @param group_end integer
    local function create_instrument_group(group_start, group_end)
        local groups = finale.FCGroups()
        groups:LoadAll()
        local new_id
        if groups:GetCount() > 0 then new_id = groups:GetItemAt(groups:GetCount() - 1).ItemID + 1
        else new_id = 1 end
        local instrument_group = finale.FCGroup()
        instrument_group:SetStartStaff(group_start)
        instrument_group:SetEndStaff(group_end)
        instrument_group:SetStartMeasure(1)
        instrument_group:SetEndMeasure(32767)
        instrument_group:SetBracketStyle(finale.GRBRAC_DESK)
        instrument_group:SetBracketHorizontalPos(-28)
        instrument_group:SaveNew(new_id)
    end

    -- Group by UUID --
    local staves = finale.FCStaves()
    midi.LoadStaves(staves)
    local group_UUID, group_start, group_end, loop_index = "", nil, nil, 0
    for staff in each(staves) do
        local staff_UUID = staff:GetInstrumentUUID()

        if staff_UUID ~= group_UUID then
            -- Create group for previous span of staves
            if group_start ~= nil and uuid_is_groupable(group_UUID) then
                group_end = staves:GetItemAt(loop_index - 1).ItemNo
                if group_start ~= group_end then -- Only for multiple staves of the same UUID.
                    create_instrument_group(group_start, group_end)
                end
            end
            
            -- Start new span of staves
            group_start = staff.ItemNo
            group_UUID = staff_UUID
        end
        
        loop_index = loop_index + 1
    end
    -- Create group for last span of staves if multiple
    group_end = staves:GetItemAt(staves:GetCount() - 1).ItemNo
    if group_start ~= nil and group_start ~= group_end then create_instrument_group(group_start, group_end) end


    -- Group by Family --
    local function create_family_group(group_start, group_end)
        local groups = finale.FCGroups()
        groups:LoadAll()
        local new_id = groups:GetItemAt(groups:GetCount() - 1).ItemID + 1
        local instrument_group = finale.FCGroup()
        instrument_group:SetStartStaff(group_start)
        instrument_group:SetEndStaff(group_end)
        instrument_group:SetStartMeasure(1)
        instrument_group:SetEndMeasure(32767)
        instrument_group:SetBracketStyle(finale.GRBRAC_CURVEDCHORUS)
        instrument_group:SetBracketHorizontalPos(-12)
        instrument_group:SaveNew(new_id)
    end

    -- Create a table of instrument families for all of the staves
    local families = {}
    for staff in each(staves) do
        families[staff.ItemNo] = finale_xml_parser:GetInstrumentFamilyFromUUID(staff:GetInstrumentUUID())
    end

    local function check_group_uuids(group_start, group_end)
        local group = finale.FCGroup()
        group:SetStartStaff(group_start)
        group:SetEndStaff(group_end)
        group:SetStartMeasure(1)
        group:SetEndMeasure(32767)
        local staves_to_check = midi.GetStavesFromGroup(group)
        for staff in each(staves_to_check) do
            if not uuid_is_groupable(staff:GetInstrumentUUID()) then return false end
        end
        return true
    end

    -- Create groups based on the family table
    group_family, group_start, group_end, loop_index = "", nil, nil, 0
    for staff in each(staves) do
        if families[staff.ItemNo] ~= group_family then
            -- Create group for previous span of staves
            if group_start ~= nil then
                group_end = staves:GetItemAt(loop_index - 1).ItemNo
                if group_start ~= group_end and check_group_uuids(group_start, group_end) then -- Only for multiple staves of the same UUID.
                    create_family_group(group_start, group_end)
                end
            end
            
            -- Start new span of staves
            group_start = staff.ItemNo
            group_family = families[staff.ItemNo]
        end
        
        loop_index = loop_index + 1
    end
    -- Create group for last span of staves if multiple
    group_end = staves:GetItemAt(staves:GetCount() - 1).ItemNo
    if group_start ~= nil and group_start ~= group_end then create_family_group(group_start, group_end) end
end

--- Changes the font preferences for an expression category defined by the cat_id argument.
--- @param cat_id integer
--- @param text_font FCFontInfo FCFontInfo
--- @param music_font FCFontInfo FCFontInfo
--- @param number_font FCFontInfo FCFontInfo
local function change_expression_category_font_prefs(cat_id, text_font, music_font, number_font)
    local category_def = finale.FCCategoryDef()
    category_def:Load(cat_id)
    if text_font ~= nil then category_def:SetTextFontInfo(text_font) end
    if music_font ~= nil then category_def:SetMusicFontInfo(music_font) end
    if number_font ~= nil then category_def:SetNumberFontInfo(number_font) end
    category_def:Save()
end

-- Hides Default Whole Rests.
local function hide_default_whole_rests()
    local staves = finale.FCStaves()
    staves:LoadAll()
    for staff in each(staves) do
        staff:SetDisplayEmptyRests(not config.PREFS_HIDE_DEFAULT_WHOLE_RESTS)
    end
    staves:SaveAll()
end

-- Applies measure number preferences. TODO: Should be changed to receive info from CONFIG.
local function apply_measure_number_prefs()
    local measure_number_region = finale.FCMeasureNumberRegion()
    measure_number_region:Load(1)
    measure_number_region:SetStartMeasure(1)
    measure_number_region:SetEndMeasure(999)
    measure_number_region:SetShowOnTopStaff(false, false)
    measure_number_region:SetShowMultiples(true, false)
    measure_number_region:SetShowOnBottomStaff(true, false)
    measure_number_region:SetShowOnSystemStart(false, false)
    measure_number_region:SetMultipleValue(1)
    measure_number_region:SetMultipleStartMeasure(1)

    local number_font_info = finale.FCFontInfo()
    local font_name = finale.FCString()
    font_name.LuaString = "Trebuchet MS"
    number_font_info:SetNameString(font_name)
    number_font_info:SetSize(22)
    number_font_info:SetBold(true)

    measure_number_region:SetMultipleFontInfo(number_font_info, false)
    measure_number_region:SetMultipleAlignment(finale.MNALIGN_CENTER, false)
    measure_number_region:SetMultipleJustification(finale.MNJUSTIFY_CENTER, false)
    measure_number_region:SetMultipleHorizontalPosition(0, false)
    measure_number_region:SetMultipleVerticalPosition(-300)

    measure_number_region:Save()

    local staves = finale.FCStaves()
    midi.LoadStaves(staves)
    local index = 1
    for staff in each(staves) do
        if index ~= staves:GetCount() then
            staff:SetShowMeasureNumbers(false)
        end
        index = index + 1
    end
    staves:SaveAll()
end

-- Adjusts miscellaneous preferences such as concert pitch and beaming common time eighths.
local function apply_misc_prefs()
    local part_scope_prefs = finale.FCPartScopePrefs()
    part_scope_prefs:LoadFirst()
    part_scope_prefs:SetDisplayInConcertPitch(true)
    part_scope_prefs:Save()


    local misc_prefs = finale.FCMiscDocPrefs()
    misc_prefs:LoadFirst()
    misc_prefs:SetBeamedCommonTimeEights(config.PREFS_BEAM_COMMON_TIME_EIGHTHS)
    misc_prefs:Save()

    local full_doc_region = finale.FCMusicRegion()
    full_doc_region:SetFullDocument()
    full_doc_region:RebeamMusic()
end

--- Launches the dialog for the user to input the score information.
--- @return FCString[]?
local function init_ui()
    Init_Dialog = finale.FCCustomLuaWindow()

    local str = finale.FCString()

    str.LuaString = "Score Information"
    Init_Dialog:SetTitle(str)

    local fit = finale.FCFileInfoText()

    local mnumber_static = Init_Dialog:CreateStatic(0, 3)
    str.LuaString = "M-Number"
    mnumber_static:SetText(str)
    local mnumber_edit = Init_Dialog:CreateEdit(80, 0)
    mnumber_edit:SetWidth(135)
    fit:LoadTitle()
    mnumber_edit:SetText(fit:CreateString())
    local mnumber_info_button = Init_Dialog:CreateButton(220,0)
    mnumber_info_button:SetWidth(20)
    mnumber_info_button:SetHeight(20)
    str.LuaString = "?"
    mnumber_info_button:SetText(str)

    local cuetitle_static = Init_Dialog:CreateStatic(0, 33)
    str.LuaString = "Cue Title"
    cuetitle_static:SetText(str)
    local cuetitle_edit = Init_Dialog:CreateEdit(80, 30)
    cuetitle_edit:SetWidth(160)
    fit:LoadSubtitle()
    cuetitle_edit:SetText(fit:CreateString())

    local filmname_static = Init_Dialog:CreateStatic(0, 63)
    str.LuaString = "Name of Film"
    filmname_static:SetText(str)
    local filmname_edit = Init_Dialog:CreateEdit(80, 60)
    filmname_edit:SetWidth(160)
    fit:LoadDescription()
    filmname_edit:SetText(fit:CreateString())

    local composer_static = Init_Dialog:CreateStatic(0, 93)
    str.LuaString = "Composer"
    composer_static:SetText(str)
    local composer_edit = Init_Dialog:CreateEdit(80, 90)
    composer_edit:SetWidth(160)
    fit:LoadComposer()
    composer_edit:SetText(fit:CreateString())

    local orchestrator_static = Init_Dialog:CreateStatic(0, 123)
    str.LuaString = "Orchestrator"
    orchestrator_static:SetText(str)
    local orchestrator_edit = Init_Dialog:CreateEdit(80, 120)
    orchestrator_edit:SetWidth(160)
    fit:LoadArranger()
    orchestrator_edit:SetText(fit:CreateString())

    local ensemble_static = Init_Dialog:CreateStatic(0, 153)
    str.LuaString = "Ensemble"
    ensemble_static:SetText(str)
    local ensemble_edit = Init_Dialog:CreateEdit(80, 150)
    ensemble_edit:SetWidth(135)
    local parts = finale.FCParts()
    parts:LoadAll()
    for part in each(parts) do
        if part:IsScore() then
            local part_name = part:CreateCustomTextString()
            part_name:TrimEnigmaTags()
            if part_name:ContainsLuaString(config.SCORENAME..' - ') then
                local result = finale.FCString()
                part_name:SplitAt(12, nil, result, false)
                ensemble_edit:SetText(result)
            end
            break
        end
    end

    local ensemble_info_button = Init_Dialog:CreateButton(220,150)
    ensemble_info_button:SetWidth(20)
    ensemble_info_button:SetHeight(20)
    str.LuaString = "?"
    ensemble_info_button:SetText(str)

    Init_Dialog:RegisterHandleControlEvent(mnumber_info_button,
        function()
            finenv.UI():AlertInfo("M Numbers (or Music Numbers) are essentially identification numbers for organizing your music. The format includes two numbers separated by the letter m. The first number is the reel number, and the second is the cue number. Since most film today is digital, you can apply the first number according to your own metric (such as act number or 20 minute interval). E.g., 1m1, 1m2, 2m3 etc.", "Apply Film Scoring Format - M Number")
        end
    )

    Init_Dialog:RegisterHandleControlEvent(ensemble_info_button,
        function()
            finenv.UI():AlertInfo("If writing for ensembles of varying sizes over the course of a film, use this parameter to specify the instrumentation of this particular cue. e.g., \"A\" Orchestra, \"B\" Orchestra, etc.", "Apply Film Scoring Format - Ensemble")
        end
    )

    Init_Dialog:CreateOkButton()
    Init_Dialog:CreateCancelButton()
    local result = Init_Dialog:ExecuteModal(nil)
    if result == 1 then
        local results = {finale.FCString(),finale.FCString(),finale.FCString(),finale.FCString(),finale.FCString(),finale.FCString()}
        mnumber_edit:GetText(results[1])
        cuetitle_edit:GetText(results[2])
        filmname_edit:GetText(results[3])
        composer_edit:GetText(results[4])
        orchestrator_edit:GetText(results[5])
        ensemble_edit:GetText(results[6])
        if config.CAPITALIZE_TITLE then results[1].LuaString = string.upper(results[1].LuaString) end
        if config.CAPITALIZE_DESCRIPTION then results[3].LuaString = string.upper(results[3].LuaString) end
        return results
    else return end
end

-- Launches the dialog for the user to select staves to display large time signatures.
-- Will be automatic in the future.
local function time_sig_ui()
    Time_Sig_Dialog = finale.FCCustomLuaWindow()

    local str = finale.FCString()

    str.LuaString = "Large Time Signatures"
    Time_Sig_Dialog:SetTitle(str)

    local desc_static = Time_Sig_Dialog:CreateStatic(0,0)
    str.LuaString = "Select staves to display large time signature."
    desc_static:SetWidth(250)
    desc_static:SetText(str)

    local staff_checkboxes = {}

    local staves = finale.FCStaves()
    midi.LoadStaves(staves)
    local index = 0
    for staff in each(staves) do
        staff_checkboxes[staff.ItemNo] = Time_Sig_Dialog:CreateCheckbox(20, 24+(index*14))
        staff_checkboxes[staff.ItemNo]:SetWidth(250)
        str = staff:CreateDisplayFullNameString()
        staff_checkboxes[staff.ItemNo]:SetText(str)
        index = index + 1
    end

    Time_Sig_Dialog:CreateOkButton()
    Time_Sig_Dialog:CreateCancelButton()
    local result = Time_Sig_Dialog:ExecuteModal(nil)
    if result == 1 then
        local results = {}
        for staff in each(staves) do
            if staff_checkboxes[staff.ItemNo]:GetCheck() == 1 then
                results[#results+1] = staff.ItemNo
            end
        end
        if #results == 0 then return end
        return results
    end
end

--- Creates large time signatures for the selected staves.
--- Parameter: time_sig_staves is a table of ItemNos for the staves to display large time signatures.
--- @param time_sig_staves integer[]
local function create_large_time_signatures(time_sig_staves)
    -- Step 1,2
    local staves = finale.FCStaves()
    staves:LoadAll()
    for staff in each(staves) do
        staff:SetShowTimeSignatures(false)
    end
    staves:SaveAll()

    --Step 3,4,5
    local sig_font_info = finale.FCFontInfo()
    local font_str_name = finale.FCString()
    font_str_name.LuaString = "Engraver Time"
    sig_font_info:SetNameString(font_str_name)
    sig_font_info:SetSize(48)
    sig_font_info:SaveFontPrefs(finale.FONTPREF_TIMESIG)

    --Step 6,7
    local distance_prefs = finale.FCDistancePrefs()
    distance_prefs:LoadFirst()
    distance_prefs:SetTimeSigTopVertical(-15)
    distance_prefs:SetTimeSigBottomVertical(-360)
    distance_prefs:Save()

    --Step 8,9,10
    for i=1, #time_sig_staves do
        local staff = finale.FCStaff()
        staff:Load(time_sig_staves[i])
        
        staff:SetShowTimeSignatures(true)
        staff:Save()
    end
end

-- EXECUTION BEGINS HERE --
local info = init_ui()
if info ~= nil then
    local fit = finale.FCFileInfoText()
    fit:SetText(info[1])
    fit:SaveAsTitle()

    fit:SetText(info[2])
    fit:SaveAsSubtitle()

    fit:SetText(info[3])
    fit:SaveAsDescription()

    fit:SetText(info[4])
    fit:SaveAsComposer()

    fit:SetText(info[5])
    fit:SaveAsArranger()

    local parts = finale.FCParts()
    parts:LoadAll()
    for part in each(parts) do
        if part:IsScore() then
            local part_name = finale.FCString(config.SCORENAME)
            if info[6].LuaString ~= '' then
                part_name:AppendLuaString(' - ' .. info[6].LuaString)
            end
            part:SaveCustomTextString(part_name)
            part:Save()
            break
        end
    end

    if config.RESIZE_TABLOID then resize_tabloid() end

    create_font_info(finale.FCString(config.FONTNAME_FULLSTAFF), config.SIZE_FULLSTAFF, config.BOLD_FULLSTAFF, config.ITALIC_FULLSTAFF, config.UNDERLINE_FULLSTAFF, config.STRIKEOUT_FULLSTAFF):SaveFontPrefs(finale.FONTPREF_STAFFNAME)
    create_font_info(finale.FCString(config.FONTNAME_ABRVSTAFF), config.SIZE_ABRVSTAFF, config.BOLD_ABRVSTAFF, config.ITALIC_ABRVSTAFF, config.UNDERLINE_ABRVSTAFF, config.STRIKEOUT_ABRVSTAFF):SaveFontPrefs(finale.FONTPREF_ABRVSTAFFNAME)
    create_font_info(finale.FCString(config.FONTNAME_FULLGROUP), config.SIZE_FULLGROUP, config.BOLD_FULLGROUP, config.ITALIC_FULLGROUP, config.UNDERLINE_FULLGROUP, config.STRIKEOUT_FULLGROUP):SaveFontPrefs(finale.FONTPREF_GROUPNAME)
    create_font_info(finale.FCString(config.FONTNAME_ABRVGROUP), config.SIZE_ABRVGROUP, config.BOLD_ABRVGROUP, config.ITALIC_ABRVGROUP, config.UNDERLINE_ABRVGROUP, config.STRIKEOUT_ABRVGROUP):SaveFontPrefs(finale.FONTPREF_ABRVGROUPNAME)
    create_font_info(finale.FCString(config.FONTNAME_DEF), config.SIZE_DEF, config.BOLD_DEF, config.ITALIC_DEF, config.UNDERLINE_DEF, config.STRIKEOUT_DEF):SaveFontPrefs(finale.FONTPREF_TEXTBLOCK)

    reset_staff_names()
    reset_group_names()
    transfer_instrument_names()
    reset_text_blocks()
    fix_margins()
    load_staff_list(1, finale.SLMODE_CATEGORY_SCORE)
    local staff_list = load_staff_list(1, finale.SLMODE_SCORE)
    create_vertical_spaces(staff_list)
    autogroup_instruments()
    change_expression_category_font_prefs(
        finale.DEFAULTCATID_TEMPOMARKS,
        create_font_info(finale.FCString(config.CAT_TEMPO_TEXT_FONTNAME), config.CAT_TEMPO_TEXT_SIZE, config.CAT_TEMPO_TEXT_BOLD, config.CAT_TEMPO_TEXT_ITALIC, config.CAT_TEMPO_TEXT_UNDERLINE, config.CAT_TEMPO_TEXT_STRIKEOUT),
        create_font_info(finale.FCString(config.CAT_TEMPO_MUSIC_FONTNAME), config.CAT_TEMPO_MUSIC_SIZE, config.CAT_TEMPO_MUSIC_BOLD, config.CAT_TEMPO_MUSIC_ITALIC, config.CAT_TEMPO_MUSIC_UNDERLINE, config.CAT_TEMPO_MUSIC_STRIKEOUT),
        create_font_info(finale.FCString(config.CAT_TEMPO_NUMBER_FONTNAME), config.CAT_TEMPO_NUMBER_SIZE, config.CAT_TEMPO_NUMBER_BOLD, config.CAT_TEMPO_NUMBER_ITALIC, config.CAT_TEMPO_NUMBER_UNDERLINE, config.CAT_TEMPO_NUMBER_STRIKEOUT)
    )
    change_expression_category_font_prefs(
        finale.DEFAULTCATID_TEMPOALTERATIONS,
        create_font_info(finale.FCString(config.CAT_TALTER_TEXT_FONTNAME), config.CAT_TALTER_TEXT_SIZE, config.CAT_TALTER_TEXT_BOLD, config.CAT_TALTER_TEXT_ITALIC, config.CAT_TALTER_TEXT_UNDERLINE, config.CAT_TALTER_TEXT_STRIKEOUT),
        create_font_info(finale.FCString(config.CAT_TALTER_MUSIC_FONTNAME), config.CAT_TALTER_MUSIC_SIZE, config.CAT_TALTER_MUSIC_BOLD, config.CAT_TALTER_MUSIC_ITALIC, config.CAT_TALTER_MUSIC_UNDERLINE, config.CAT_TALTER_MUSIC_STRIKEOUT),
        nil
    )
    change_expression_category_font_prefs(
        finale.DEFAULTCATID_EXPRESSIVETEXT,
        create_font_info(finale.FCString(config.CAT_EXPRESSIONS_TEXT_FONTNAME), config.CAT_EXPRESSIONS_TEXT_SIZE, config.CAT_EXPRESSIONS_TEXT_BOLD, config.CAT_EXPRESSIONS_TEXT_ITALIC, config.CAT_EXPRESSIONS_TEXT_UNDERLINE, config.CAT_EXPRESSIONS_TEXT_STRIKEOUT),
        create_font_info(finale.FCString(config.CAT_EXPRESSIONS_MUSIC_FONTNAME), config.CAT_EXPRESSIONS_MUSIC_SIZE, config.CAT_EXPRESSIONS_MUSIC_BOLD, config.CAT_EXPRESSIONS_MUSIC_ITALIC, config.CAT_EXPRESSIONS_MUSIC_UNDERLINE, config.CAT_EXPRESSIONS_MUSIC_STRIKEOUT),
        nil
    )
    change_expression_category_font_prefs(
        finale.DEFAULTCATID_TECHNIQUETEXT,
        create_font_info(finale.FCString(config.CAT_TECHNIQUE_TEXT_FONTNAME), config.CAT_TECHNIQUE_TEXT_SIZE, config.CAT_TECHNIQUE_TEXT_BOLD, config.CAT_TECHNIQUE_TEXT_ITALIC, config.CAT_TECHNIQUE_TEXT_UNDERLINE, config.CAT_TECHNIQUE_TEXT_STRIKEOUT),
        create_font_info(finale.FCString(config.CAT_TECHNIQUE_MUSIC_FONTNAME), config.CAT_TECHNIQUE_MUSIC_SIZE, config.CAT_TECHNIQUE_MUSIC_BOLD, config.CAT_TECHNIQUE_MUSIC_ITALIC, config.CAT_TECHNIQUE_MUSIC_UNDERLINE, config.CAT_TECHNIQUE_MUSIC_STRIKEOUT),
        nil
    )

    hide_default_whole_rests()
    apply_measure_number_prefs()
    apply_misc_prefs()

    local time_sig = time_sig_ui()
    if time_sig ~= nil then
        create_large_time_signatures(time_sig)
    end
end