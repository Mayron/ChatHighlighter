local _, ns = ...;

local _G = _G;
local LibStub = _G.LibStub;
local ipairs, tonumber, tostring, format = _G.ipairs, _G.tonumber, _G.tostring, _G.format;
local strtrim, PlaySound, CopyTable = _G.strtrim, _G.PlaySound, _G.CopyTable;

local APP_NAME = "ChatHighlighter";
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

local CUSTOM_SOUND = "custom";
local newGroupName = "";

-- Call after any settings change so chat highlighting and the options panel update.
local function Refresh()
  ns:CompileSettings();
  AceConfigRegistry:NotifyChange(APP_NAME);
end

local function IsPreset(soundId)
  for _, preset in ipairs(ns.SOUND_PRESETS) do
    if (preset.id == soundId) then return true; end
  end
  return false;
end

local function GetSoundValues()
  local values, sorting = {}, {};
  for _, preset in ipairs(ns.SOUND_PRESETS) do
    local key = tostring(preset.id);
    values[key] = preset.label;
    sorting[#sorting + 1] = key;
  end
  values[CUSTOM_SOUND] = "Custom (enter an ID)";
  sorting[#sorting + 1] = CUSTOM_SOUND;
  return values, sorting;
end

-- Options shared by "Your Name" and every keyword group. getSetting returns the saved table.
local function AddAppearanceAndSoundOptions(args, getSetting, startOrder)
  local soundValues, soundSorting = GetSoundValues();
  local function soundDisabled() return not (getSetting().enabled and getSetting().sound); end

  args.color = {
    type = "color";
    name = "Colour";
    order = startOrder;
    get = function()
      local c = getSetting().color;
      return c.r, c.g, c.b;
    end;
    set = function(_, r, g, b)
      local c = getSetting().color;
      c.r, c.g, c.b = r, g, b;
      Refresh();
    end;
  };
  args.upperCase = {
    type = "toggle";
    name = "Upper-case";
    desc = "Convert matched text to upper-case (only in your chat window).";
    order = startOrder + 1;
    get = function() return getSetting().upperCase; end;
    set = function(_, value) getSetting().upperCase = value; Refresh(); end;
  };
  args.soundHeader = {
    type = "header";
    name = "Sound";
    order = startOrder + 2;
  };
  args.sound = {
    type = "toggle";
    name = "Play sound";
    desc = "Play a sound when a message contains a match. Only one sound plays per message.";
    order = startOrder + 3;
    get = function() return getSetting().sound; end;
    set = function(_, value) getSetting().sound = value; Refresh(); end;
  };
  args.soundPreset = {
    type = "select";
    name = "Sound";
    order = startOrder + 4;
    values = soundValues;
    sorting = soundSorting;
    disabled = soundDisabled;
    get = function()
      local soundId = getSetting().soundId;
      return IsPreset(soundId) and tostring(soundId) or CUSTOM_SOUND;
    end;
    set = function(_, value)
      if (value ~= CUSTOM_SOUND) then
        getSetting().soundId = tonumber(value);
        Refresh();
      end
    end;
  };
  args.soundId = {
    type = "input";
    name = "Sound kit ID";
    desc = "Any sound kit ID, see SoundKitConstants.lua in the Blizzard interface code.";
    order = startOrder + 5;
    width = "half";
    disabled = soundDisabled;
    get = function() return tostring(getSetting().soundId or ""); end;
    validate = function(_, value)
      local id = tonumber(value);
      if (id and id > 0 and id == math.floor(id)) then return true; end
      return "Sound kit ID must be a positive whole number.";
    end;
    set = function(_, value) getSetting().soundId = tonumber(value); Refresh(); end;
  };
  args.soundTest = {
    type = "execute";
    name = "Test";
    order = startOrder + 6;
    width = "half";
    disabled = soundDisabled;
    func = function()
      local id = tonumber(getSetting().soundId);
      if (id) then PlaySound(id); end
    end;
  };
end

local function CreatePlayerNameOptions()
  local function getSetting() return ns.db.profile.playerName; end
  local function notEnabled() return not getSetting().enabled; end

  local args = {
    description = {
      type = "description";
      name = "Highlight your character's name when it is mentioned in chat.";
      order = 1;
    };
    enabled = {
      type = "toggle";
      name = "Enable";
      order = 2;
      width = "full";
      get = function() return getSetting().enabled; end;
      set = function(_, value) getSetting().enabled = value; Refresh(); end;
    };
    matchFullName = {
      type = "toggle";
      name = function()
        local _, _, fullName = ns:GetPlayerNameParts();
        return format("Full name (%s)", fullName or "");
      end;
      order = 3;
      width = "full";
      hidden = function() return not select(2, ns:GetPlayerNameParts()); end;
      get = function() return getSetting().matchFullName; end;
      set = function(_, value) getSetting().matchFullName = value; Refresh(); end;
    };
    matchForename = {
      type = "toggle";
      name = function() return format("Forename on its own (%s)", (ns:GetPlayerNameParts()) or ""); end;
      order = 4;
      width = "full";
      hidden = function() return not select(2, ns:GetPlayerNameParts()); end;
      get = function() return getSetting().matchForename; end;
      set = function(_, value) getSetting().matchForename = value; Refresh(); end;
    };
    matchSurname = {
      type = "toggle";
      name = function() return format("Surname on its own (%s)", select(2, ns:GetPlayerNameParts()) or ""); end;
      order = 5;
      width = "full";
      hidden = function() return not select(2, ns:GetPlayerNameParts()); end;
      get = function() return getSetting().matchSurname; end;
      set = function(_, value) getSetting().matchSurname = value; Refresh(); end;
    };
  };

  AddAppearanceAndSoundOptions(args, getSetting, 10);

  return {
    type = "group";
    name = "Your Name";
    order = 2;
    disabled = function(info) return info.type ~= "group" and info[#info] ~= "enabled" and notEnabled(); end;
    args = args;
  };
end

local function CreateGroupOptions(id, order)
  local function getSetting() return ns.db.profile.groups[id]; end
  local isCustom = getSetting().custom;

  local args = {
    enabled = {
      type = "toggle";
      name = "Enable";
      order = 1;
      width = "full";
      get = function() return getSetting().enabled; end;
      set = function(_, value) getSetting().enabled = value; Refresh(); end;
    };
    name = {
      type = "input";
      name = "Group name";
      order = 2;
      hidden = not isCustom;
      get = function() return getSetting().name; end;
      validate = function(_, value)
        if (strtrim(value) == "") then return "Group name cannot be empty."; end
        return true;
      end;
      set = function(_, value) getSetting().name = strtrim(value); Refresh(); end;
    };
    words = {
      type = "input";
      name = "Words";
      desc = "Comma separated words to highlight, e.g. \"tanks, tank, tanking\". Matching ignores case.";
      order = 3;
      width = "full";
      multiline = 3;
      get = function() return getSetting().words; end;
      set = function(_, value) getSetting().words = value; Refresh(); end;
    };
    matchMode = {
      type = "select";
      name = "Match style";
      desc = "How words are matched, e.g. for the word \"heal\" in \"health\":\n\n"
        .. "|cffffd100Matched letters only:|r highlights \"heal\" inside \"health\".\n"
        .. "|cffffd100Exact word only:|r ignores \"health\"; only \"heal\" on its own matches.\n"
        .. "|cffffd100Whole word containing the match:|r highlights all of \"health\".";
      order = 3.5;
      width = "double";
      values = function()
        local values = {};
        for _, mode in ipairs(ns.MATCH_MODES) do values[mode.key] = mode.label; end
        return values;
      end;
      sorting = function()
        local sorting = {};
        for _, mode in ipairs(ns.MATCH_MODES) do sorting[#sorting + 1] = mode.key; end
        return sorting;
      end;
      get = function() return getSetting().matchMode; end;
      set = function(_, value) getSetting().matchMode = value; Refresh(); end;
    };
    matchInLinks = {
      type = "toggle";
      name = "Match inside links";
      desc = "Highlight words inside links, such as item names shift-clicked into chat. Turn off to leave links untouched.";
      order = 4;
      width = "full";
      get = function() return getSetting().matchInLinks; end;
      set = function(_, value) getSetting().matchInLinks = value; Refresh(); end;
    };
  };

  AddAppearanceAndSoundOptions(args, getSetting, 10);

  args.manageHeader = {
    type = "header";
    name = "";
    order = 30;
  };

  args.delete = {
    type = "execute";
    name = "Delete group";
    order = 32;
    disabled = false; -- usable even when the group is turned off
    confirm = true;
    confirmText = isCustom and "Delete this keyword group?"
      or "Delete this built-in keyword group? It can be restored from the General tab.";
    func = function()
      if (isCustom) then
        ns.db.profile.groups[id] = nil;
      else
        -- AceDB would restore a removed built-in group from the defaults, so flag it instead
        getSetting().deleted = true;
      end
      AceConfigDialog:SelectGroup(APP_NAME, "general");
      Refresh();
    end;
  };

  if (not isCustom) then
    args.reset = {
      type = "execute";
      name = "Reset to defaults";
      order = 31;
      disabled = false;
      confirm = true;
      confirmText = "Reset this keyword group to its default words, colour and sound?";
      func = function()
        ns.db.profile.groups[id] = CopyTable(ns.defaults.profile.groups[id]);
        Refresh();
      end;
    };
  end

  return {
    type = "group";
    name = function()
      local name = getSetting().name;
      return (name and name ~= "") and name or "Unnamed";
    end;
    order = order;
    disabled = function(info) return info.type ~= "group" and info[#info] ~= "enabled" and not getSetting().enabled; end;
    args = args;
  };
end

local function CreateGeneralOptions()
  return {
    type = "group";
    name = "General";
    order = 1;
    args = {
      description = {
        type = "description";
        name = "Chat Highlighter colours your name and chosen keywords in chat channels, and can play a sound when they appear.";
        order = 1;
      };
      enabled = {
        type = "toggle";
        name = "Enable Chat Highlighter";
        order = 2;
        width = "full";
        get = function() return ns.db.profile.enabled; end;
        set = function(_, value) ns.db.profile.enabled = value; Refresh(); end;
      };
      addHeader = {
        type = "header";
        name = "Add keyword group";
        order = 10;
      };
      newGroupName = {
        type = "input";
        name = "Group name";
        desc = "Name of the new keyword group, e.g. \"Summon\".";
        order = 11;
        get = function() return newGroupName; end;
        set = function(_, value) newGroupName = value; end;
      };
      addGroup = {
        type = "execute";
        name = "Add";
        order = 12;
        width = "half";
        disabled = function() return strtrim(newGroupName) == ""; end;
        func = function()
          local profile = ns.db.profile;
          local index = profile.nextCustomId;
          local id = "custom" .. index;

          local group = profile.groups[id]; -- created from the "*" template
          group.name = strtrim(newGroupName);
          group.created = index;
          profile.nextCustomId = index + 1;
          newGroupName = "";

          Refresh();
          AceConfigDialog:SelectGroup(APP_NAME, id);
        end;
      };
      restoreBuiltins = {
        type = "execute";
        name = "Restore deleted groups";
        desc = "Bring back any deleted built-in keyword groups (Healer, Tank, DPS) with their default settings.";
        order = 13;
        width = "double";
        hidden = function()
          for _, id in ipairs(ns.BUILTIN_GROUPS) do
            if (ns.db.profile.groups[id].deleted) then return false; end
          end
          return true;
        end;
        func = function()
          local groups = ns.db.profile.groups;
          for _, id in ipairs(ns.BUILTIN_GROUPS) do
            if (groups[id].deleted) then
              groups[id] = CopyTable(ns.defaults.profile.groups[id]);
            end
          end
          Refresh();
        end;
      };
      resetHeader = {
        type = "header";
        name = "";
        order = 20;
      };
      resetAll = {
        type = "execute";
        name = "Reset all settings";
        desc = "Restore every setting to its default and delete custom keyword groups.";
        order = 21;
        confirm = true;
        confirmText = "Reset all Chat Highlighter settings to their defaults? Custom keyword groups will be deleted.";
        func = function()
          ns.db:ResetProfile();
          Refresh();
        end;
      };
    };
  };
end

local function GetOptions()
  local args = {
    general = CreateGeneralOptions();
    playerName = CreatePlayerNameOptions();
  };

  local order = 10;
  for _, id in ipairs(ns.BUILTIN_GROUPS) do
    if (not ns.db.profile.groups[id].deleted) then
      args[id] = CreateGroupOptions(id, order);
      order = order + 1;
    end
  end

  for _, id in ipairs(ns:GetCustomGroupIds()) do
    args[id] = CreateGroupOptions(id, order);
    order = order + 1;
  end

  return {
    type = "group";
    name = "Chat Highlighter";
    childGroups = "tab";
    args = args;
  };
end

local function OpenOptions()
  if (ns.categoryId and _G.Settings and _G.Settings.OpenToCategory) then
    _G.Settings.OpenToCategory(ns.categoryId);
  else
    AceConfigDialog:Open(APP_NAME);
  end
end

-- Called from ChatHighlighter.lua once the saved variables are loaded.
function ns:SetupOptions()
  AceConfigRegistry:RegisterOptionsTable(APP_NAME, GetOptions);
  local _, categoryId = AceConfigDialog:AddToBlizOptions(APP_NAME, "Chat Highlighter");
  self.categoryId = categoryId;

  _G.SLASH_CHATHIGHLIGHTER1 = "/chathighlighter";
  _G.SLASH_CHATHIGHLIGHTER2 = "/chl";
  _G.SlashCmdList.CHATHIGHLIGHTER = OpenOptions;
end
