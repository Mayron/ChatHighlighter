local addonName, ns = ...;

local _G = _G;
local pairs, ipairs, type, tonumber = _G.pairs, _G.ipairs, _G.type, _G.tonumber;
local unpack, PlaySound, CreateColor = _G.unpack, _G.PlaySound, _G.CreateColor;
local UnitName, canaccessvalue = _G.UnitName, _G.canaccessvalue;
local strsplit, strtrim, tinsert, sort = _G.strsplit, _G.strtrim, _G.tinsert, _G.table.sort;

-- Ordered list of highlight entries built from the saved settings by ns:CompileSettings().
-- Each entry: { word1, word2, ...; color = { r, g, b }; sound = soundId or false; upperCase = bool }
ns.compiled = {};

-- WoW Forever characters have a forename and a surname.
function ns:GetPlayerNameParts()
  local forename, surname = UnitName("player");
  if (surname == "") then surname = nil; end

  local fullName;
  if (forename and surname) then
    local separator = _G.Constants and _G.Constants.CharacterNameSeparatorConsts
      and _G.Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " ";
    fullName = forename .. separator .. surname;
  end

  return forename, surname, fullName;
end

-- Custom group IDs (keys of profile.groups flagged as custom), sorted by creation order.
function ns:GetCustomGroupIds()
  local ids = {};
  for id, group in pairs(self.db.profile.groups) do
    if (type(group) == "table" and group.custom) then
      tinsert(ids, id);
    end
  end

  local groups = self.db.profile.groups;
  sort(ids, function(a, b) return (groups[a].created or 0) < (groups[b].created or 0) end);
  return ids;
end

local function ParseWords(words)
  local list = {};
  if (type(words) ~= "string") then return list; end

  for _, word in ipairs({ strsplit(",", words) }) do
    word = strtrim(word):lower();
    if (word ~= "") then
      tinsert(list, word);
    end
  end

  return list;
end

local function CreateEntry(words, setting)
  if (#words == 0) then return nil; end

  local c = setting.color;
  words.color = { c.r, c.g, c.b };
  words.sound = setting.sound and tonumber(setting.soundId) or false;
  words.upperCase = setting.upperCase;
  words.matchInLinks = setting.matchInLinks ~= false; -- the player name has no such setting
  words.matchMode = setting.matchMode or "partial";
  return words;
end

function ns:CompileSettings()
  local compiled = {};
  self.compiled = compiled;

  if (not (self.db and self.db.profile.enabled)) then return end
  local profile = self.db.profile;

  -- your name first, so keyword highlighting cannot break it up; the full name is listed
  -- first so it wins over a forename/surname match at the same position.
  local nameSetting = profile.playerName;
  if (nameSetting.enabled) then
    local forename, surname, fullName = self:GetPlayerNameParts();
    local words = {};
    if (fullName and nameSetting.matchFullName) then tinsert(words, fullName:lower()); end
    if (forename and (nameSetting.matchForename or not surname)) then tinsert(words, forename:lower()); end
    if (surname and nameSetting.matchSurname) then tinsert(words, surname:lower()); end
    tinsert(compiled, CreateEntry(words, nameSetting));
  end

  for _, id in ipairs(ns.BUILTIN_GROUPS) do
    local group = profile.groups[id];
    if (group.enabled and not group.deleted) then
      tinsert(compiled, CreateEntry(ParseWords(group.words), group));
    end
  end

  for _, id in ipairs(self:GetCustomGroupIds()) do
    local group = profile.groups[id];
    if (group.enabled) then
      tinsert(compiled, CreateEntry(ParseWords(group.words), group));
    end
  end
end

local eventFrame = _G.CreateFrame("Frame");
eventFrame:RegisterEvent("ADDON_LOADED");
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:SetScript("OnEvent", function(self, event, arg1)
  if (event == "ADDON_LOADED") then
    if (arg1 ~= addonName) then return end
    self:UnregisterEvent("ADDON_LOADED");

    ns.db = _G.LibStub("AceDB-3.0"):New("ChatHighlighterDB", ns.defaults, true);
    ns:SetupOptions();
  end

  ns:CompileSettings();
end);

local CHANNEL_PATTERNS = {
  "(|Hchannel:.-|h%[.-%]|h |Hplayer:.-|h%[.-%]|h: )(.*)";
  "(|Hplayer:.-|h%[.-%]|h.-: )(.*)"};

-- Escape sequences that must never be edited: hidden link data, colour codes, textures and atlases.
local ESCAPE_PATTERNS = { "|H.-|h", "|c%x%x%x%x%x%x%x%x", "|r", "|T.-|t", "|A.-|a" };
-- A whole link including its visible text, e.g. |Hitem:...|h[Healing Potion]|h
local LINK_PATTERNS = { "|H.-|h.-|h" };

local function FindRanges(msg, patterns)
  local ranges = {};

  for _, pattern in ipairs(patterns) do
    local pos = 1;
    while (true) do
      local s, e = msg:find(pattern, pos);
      if (not s) then break end
      ranges[#ranges + 1] = { s, e };
      pos = e + 1;
    end
  end

  return ranges;
end

-- Returns the end of the range overlapping [startId, endId], if any.
local function GetOverlappingRangeEnd(ranges, startId, endId)
  local rangeEnd;
  for _, range in ipairs(ranges) do
    if (startId <= range[2] and endId >= range[1] and (not rangeEnd or range[2] > rangeEnd)) then
      rangeEnd = range[2];
    end
  end
  return rangeEnd;
end

-- Finds the first acceptable match of a single word, depending on the match mode:
--   "partial": the matched letters only (e.g. "heal" inside "health")
--   "exact":   only when the word is not part of a larger word ("health" is skipped)
--   "whole":   the match is expanded to the whole word containing it (all of "health")
local function FindWord(query, word, init, matchMode, isWordChar)
  local s, e = query:find(word, init, true);

  if (matchMode == "exact") then
    while (s and (isWordChar(s - 1) or isWordChar(e + 1))) do
      s, e = query:find(word, s + 1, true);
    end
  elseif (matchMode == "whole" and s) then
    while (isWordChar(s - 1)) do s = s - 1; end
    while (isWordChar(e + 1)) do e = e + 1; end
  end

  return s, e;
end

-- Earliest match of any word in the entry; at the same start, the longest match wins.
local function GetStartAndEnd(query, entry, init, isWordChar)
  local smallestStartId, smallestEndId;

  for _, w in ipairs(entry) do
    local startId, endId = FindWord(query, w:lower(), init, entry.matchMode, isWordChar);

    if (startId and endId) then
      if (not smallestStartId or startId < smallestStartId) then
        smallestStartId = startId;
        smallestEndId = endId;
      elseif (smallestStartId == startId and smallestEndId < endId) then
        smallestEndId = endId;
      end
    end
  end

  return smallestStartId, smallestEndId;
end

local function SetTextColorByRGB(text, r, g, b)
  if (not (r and g and b)) then return text; end
  local color = CreateColor(r, g, b);
  return color:WrapTextInColorCode(text);
end

local function HighlightSubStringsByRGB(msg, entry, r, g, b)
  local searchFrom = 1;
  local changed = false;

  while (true) do
    local escapes = FindRanges(msg, ESCAPE_PATTERNS);

    -- letters, digits and multi-byte (non-English) characters count as part of a word;
    -- escape sequences such as colour codes do not.
    local function isWordChar(pos)
      if (pos < 1 or pos > #msg or GetOverlappingRangeEnd(escapes, pos, pos)) then return false; end
      local byte = msg:byte(pos);
      return byte >= 128 or (byte >= 48 and byte <= 57) or (byte >= 65 and byte <= 90) or (byte >= 97 and byte <= 122);
    end

    local startId, endId = GetStartAndEnd(msg:lower(), entry, searchFrom, isWordChar);
    if (not (startId and endId)) then break end

    local protectedEnd = GetOverlappingRangeEnd(escapes, startId, endId);
    if (not entry.matchInLinks) then
      local linkEnd = GetOverlappingRangeEnd(FindRanges(msg, LINK_PATTERNS), startId, endId);
      if (linkEnd and (not protectedEnd or linkEnd > protectedEnd)) then
        protectedEnd = linkEnd;
      end
    end

    if (protectedEnd) then
      searchFrom = protectedEnd + 1; -- skip over the link/escape sequence
    else
      local found = msg:sub(startId, endId);
      found = SetTextColorByRGB(entry.upperCase and found:upper() or found, r, g, b);
      msg = msg:sub(1, startId - 1) .. found .. msg:sub(endId + 1);
      searchFrom = startId + #found;
      changed = true;
    end
  end

  return msg, changed;
end

-- Newer clients (e.g. WoW Forever) read the "showTimestamps" setting through ChatFrameUtil;
-- older clients store the format in the CHAT_TIMESTAMP_FORMAT global.
local function TimestampsEnabled()
  local ChatFrameUtil = _G.ChatFrameUtil;
  if (ChatFrameUtil and ChatFrameUtil.GetTimestampFormat) then
    return ChatFrameUtil.GetTimestampFormat() ~= nil;
  end
  return _G.CHAT_TIMESTAMP_FORMAT ~= nil;
end

local function HighlightText(text, highlighted)
  local time, prefix, body, playSound, changed;
  local hasTimestamp = TimestampsEnabled();

  for _, pattern in ipairs(CHANNEL_PATTERNS) do
    if (hasTimestamp) then
      time, prefix, body = text:match("^(.-)" .. pattern);
    else
      prefix, body = text:match("^" .. pattern);
    end

    if (prefix and body) then
      body = body:trim();

      -- highlight words of interest:
      for _, value in ipairs(highlighted) do
        body, changed = HighlightSubStringsByRGB(body, value, unpack(value.color));

        if (changed and type(value.sound) == "number" and not playSound) then
          playSound = value.sound; -- first sound only
        end
      end

      if (time) then
        text = time .. prefix .. body;
      else
        text = prefix .. body;
      end

      -- stop at the first matching pattern, otherwise a channel message (with a timestamp
      -- in front) also matches the second pattern and gets highlighted twice
      break;
    end
  end

  if (playSound) then
    PlaySound(playSound);
  end

  return text;
end

local function NewAddMessage(self, text, ...)
  if (not text) then return; end

  -- secret (restricted) chat text cannot be inspected by addons, so pass it through untouched
  if (not canaccessvalue or canaccessvalue(text)) then
    text = HighlightText(text, ns.compiled);
  end

  self:oldAddMessage(text, ...);
end

for _, chatFrameName in ipairs(_G.CHAT_FRAMES) do
  local chatFrame = _G[chatFrameName];

  if (chatFrame:GetID() ~= 2) then
    -- if not combat log...
    chatFrame.oldAddMessage = chatFrame.AddMessage;
    chatFrame.AddMessage = NewAddMessage;
  end
end