local _, ns = ...;

-- For a list of sound IDs, go to:
-- https://github.com/Gethe/wow-ui-source/blob/live/SharedXML/SoundKitConstants.lua
local WHISPER_SOUND = 3081; -- SOUNDKIT.TELL_MESSAGE

-- Built-in keyword groups, in the order they are highlighted (after your name).
-- AceDB always restores these from the defaults, so deleting one sets "deleted = true" instead.
ns.BUILTIN_GROUPS = { "healer", "tank", "dps" };

ns.defaults = {
  profile = {
    enabled = true;

    playerName = {
      enabled = true;
      matchFullName = true;
      matchForename = true;
      matchSurname = true;
      color = { r = 1; g = 0.04; b = 0.78; };
      sound = true;
      soundId = WHISPER_SOUND;
      upperCase = false; -- if true, text will be converted to upper-case (in chat only for you!)
    };

    groups = {
      healer = {
        enabled = true;
        name = "Healer";
        words = "healers, healer, healz, heal, healing"; -- comma separated words to highlight
        color = { r = 0.1; g = 1; b = 0.1; };
        sound = false;
        soundId = WHISPER_SOUND;
        upperCase = false;
        matchInLinks = false; -- if true, words inside links (e.g. shift-clicked items) are also highlighted
        matchMode = "partial"; -- "partial", "exact" or "whole" (see ns.MATCH_MODES)
      };
      tank = {
        enabled = true;
        name = "Tank";
        words = "tanks, tank, tanking";
        color = { r = 1; g = 0.1; b = 0.1; };
        sound = false;
        soundId = WHISPER_SOUND;
        upperCase = false;
        matchInLinks = false; -- if true, words inside links (e.g. shift-clicked items) are also highlighted
        matchMode = "partial"; -- "partial", "exact" or "whole" (see ns.MATCH_MODES)
      };
      dps = {
        enabled = true;
        name = "DPS";
        words = "dps";
        color = { r = 1; g = 1; b = 0; };
        sound = false;
        soundId = WHISPER_SOUND;
        upperCase = false;
        matchInLinks = false; -- if true, words inside links (e.g. shift-clicked items) are also highlighted
        matchMode = "partial"; -- "partial", "exact" or "whole" (see ns.MATCH_MODES)
      };
      -- template for custom groups added in the options menu
      ["*"] = {
        enabled = true;
        name = "";
        words = "";
        color = { r = 1; g = 1; b = 1; };
        sound = false;
        soundId = WHISPER_SOUND;
        upperCase = false;
        matchInLinks = false; -- if true, words inside links (e.g. shift-clicked items) are also highlighted
        matchMode = "partial"; -- "partial", "exact" or "whole" (see ns.MATCH_MODES)
        custom = true;
        created = 0;
      };
    };

    nextCustomId = 1;
  };
};

-- Sound presets shown in the options dropdown (sound kit IDs).
ns.SOUND_PRESETS = {
  { id = 3081; label = "Whisper" }, -- SOUNDKIT.TELL_MESSAGE
  { id = 18019; label = "Battle.net Toast" }, -- SOUNDKIT.UI_BNET_TOAST
  { id = 8959; label = "Raid Warning" }, -- SOUNDKIT.RAID_WARNING
  { id = 8960; label = "Ready Check" }, -- SOUNDKIT.READY_CHECK
  { id = 37666; label = "Boss Whisper Warning" }, -- SOUNDKIT.UI_RAID_BOSS_WHISPER_WARNING
  { id = 3175; label = "Map Ping" }, -- SOUNDKIT.MAP_PING
  { id = 880; label = "Party Invite" }, -- SOUNDKIT.IG_PLAYER_INVITE
  { id = 12889; label = "Alarm Clock" }, -- SOUNDKIT.ALARM_CLOCK_WARNING_3
};

-- Word matching styles for keyword groups, e.g. for the word "heal" in the message "health":
ns.MATCH_MODES = {
  { key = "partial"; label = "Matched letters only" }, -- highlights "heal" inside "health"
  { key = "exact"; label = "Exact word only" }, -- "health" is ignored; only "heal" on its own matches
  { key = "whole"; label = "Whole word containing the match" }, -- highlights all of "health"
};
