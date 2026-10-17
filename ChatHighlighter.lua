local _G = _G;
local pairs, ipairs, type = _G.pairs, _G.ipairs, _G.type;
local unpack, PlaySound, CreateColor = _G.unpack, _G.PlaySound, _G.CreateColor;
local UnitName, canaccessvalue = _G.UnitName, _G.canaccessvalue;

-- For a list of sound IDs, go to:
-- https://github.com/Gethe/wow-ui-source/blob/live/SharedXML/SoundKitConstants.lua

-- remove the Shaman Pink class color back to retail.
local shamanColor = _G.RAID_CLASS_COLORS["SHAMAN"];
shamanColor:SetRGB(0.0, 0.44, 0.87);
shamanColor.colorStr = shamanColor:GenerateHexColor();

local playerNameSetting = {
  -- your character's name (filled in by UpdatePlayerName below)
  color = { 1, 0.04, 0.78 }; -- r, g, b values
  sound = 3081; -- whisper received sound: https://github.com/Gethe/wow-ui-source/blob/live/SharedXML/SoundKitConstants.lua#L71
  upperCase = false; -- if true, text will be convered to upper-case (dps becomes DPS in chat only for you!)
};

local settings = {
  playerNameSetting; -- checked first so keyword highlighting cannot break up your name
  {
    "healers", "healer", "healz", "heal", "healing"; -- words to search for and apply highlighting to
    color = { 0.1; 1; 0.1; }; -- r, g, b values
    sound = false; -- either false or a sound ID from the link above
    upperCase = false; -- if true, text will be convered to upper-case (dps becomes DPS in chat only for you!)
  },
  {
    "tanks", "tank", "tanking"; -- words to search for and apply highlighting to
    color = { 1; 0.1; 0.1; }; -- r, g, b values
    sound = false; -- either false or a sound ID from the link above
    upperCase = false; -- if true, text will be convered to upper-case (dps becomes DPS in chat only for you!)
  },
  {
    "dps"; -- words to search for and apply highlighting to
    color = { 1; 1; 0; }; -- r, g, b values
    sound = false; -- either false or a sound ID from the link above
    upperCase = false; -- if true, text will be convered to upper-case (dps becomes DPS in chat only for you!)
  },
};

-- WoW Forever characters have a forename and a surname (e.g. "Mayron Tidefury").
-- Match the full name, plus the forename and surname on their own. The full name wins when
-- present (longest match at the same position), and only one sound plays per message.
local function UpdatePlayerName()
  local forename, surname = UnitName("player");
  if (not forename) then return end

  for i = #playerNameSetting, 1, -1 do
    playerNameSetting[i] = nil;
  end

  if (surname and surname ~= "") then
    local separator = _G.Constants and _G.Constants.CharacterNameSeparatorConsts
      and _G.Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " ";
    playerNameSetting[1] = forename .. separator .. surname;
    playerNameSetting[2] = forename;
    playerNameSetting[3] = surname;
  else
    playerNameSetting[1] = forename;
  end
end

UpdatePlayerName();

local eventFrame = _G.CreateFrame("Frame");
eventFrame:RegisterEvent("PLAYER_LOGIN");
eventFrame:SetScript("OnEvent", UpdatePlayerName);

local CHANNEL_PATTERNS = {
  "(|Hchannel:.-|h%[.-%]|h |Hplayer:.-|h%[.-%]|h: )(.*)";
  "(|Hplayer:.-|h%[.-%]|h.-: )(.*)"};

local function GetStartAndEnd(query, word)
  if (type(word) == "table") then
    local startId, endId;
    local smallestStartId, smallestEndId;

    for _, w in ipairs(word) do
      startId, endId = query:find(w:lower(), 1, true);

      if (startId and endId) then
        if (not smallestStartId or startId < smallestStartId) then
          smallestStartId = startId;
          smallestEndId = endId;
        elseif (smallestStartId and smallestStartId == startId and smallestEndId < endId) then
          smallestEndId = endId;
        end
      end
    end

    return smallestStartId, smallestEndId;
  end

  return query:find(word:lower(), 1, true);
end

local function SetTextColorByRGB(text, r, g, b)
  if (not (r and g and b)) then return text; end
  local color = CreateColor(r, g, b);
  return color:WrapTextInColorCode(text);
end

local function HighlightSubStringsByRGB(msg, word, upperCase, r, g, b)
  local query = msg:lower();
  local offset = 0;

  while (true) do
    local startId, endId = GetStartAndEnd(query, word);
    if (not (startId and endId)) then break end

    local pre = msg:sub(0, startId - 1 + offset) -- everything before
    local found = msg:sub(startId + offset, endId + offset);
    found = SetTextColorByRGB(upperCase and found:upper() or found, r, g, b);
    local post = msg:sub(endId + 1 + offset, #msg); -- everything after

    query = post:lower();
    offset = (#(pre .. found));

    msg = pre .. found .. post;
  end

  return msg, offset > 0;
end

local function HighlightText(text, highlighted)
  local time, prefix, body, playSound, changed;

  for _, pattern in ipairs(CHANNEL_PATTERNS) do
    if (_G.CHAT_TIMESTAMP_FORMAT) then
      time, prefix, body = text:match("(.-)" .. pattern);
    else
      prefix, body = text:match("^" .. pattern);
    end

    if (prefix and body) then
      body = body:trim();

      -- highlight words of interest:
      for _, value in ipairs(highlighted) do
        body, changed = HighlightSubStringsByRGB(body, value, value.upperCase, unpack(value.color));

        if (changed and type(value.sound) == "number" and not playSound) then
          playSound = value.sound; -- first sound only
        end
      end

      if (time) then
        text = time .. prefix .. body;
      else
        text = prefix .. body;
      end
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
    text = HighlightText(text, settings);
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