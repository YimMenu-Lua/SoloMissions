local SOLO_MISSIONS <const> = gui.add_tab("Solo Missions")

function locals.set_bits(scriptName, index, ...)
    local value = locals.get_int(scriptName, index)
    for _, bit in ipairs({ ... }) do
        value = value | (1 << bit)
    end
    locals.set_int(scriptName, index, value)
end

local function IsOnline()
    return network.is_session_started() and not script.is_active("maintransition")
end

local function GetMissionScript()
    if script.is_active("fm_mission_controller") then
        return "fm_mission_controller"
    end
    if script.is_active("fm_mission_controller_2020") then
        return "fm_mission_controller_2020"
    end
    return nil
end

local FMMC_LAUNCHER <const> = "fmmc_launcher"
local FREEMODE <const> = "freemode"

----------------------------------------
-- VARIABLES
----------------------------------------

local TARGET_VERSION <const> = "1.72-3725"

-- search in fmmc_launcher.c
local scrGlobals = {
    minNumParticipants = 4718592 + 3536,       -- regex: Global_\d+\.f_\d+\s?=.+?"minNu"
    numberOfTeams = 4718592 + 3539,            -- regex: Global_\d+\.f_\d+\s?=.+?"dtn"
    maxNumberOfTeams = 4718592 + 3540,         -- regex: Global_\d+\.f_\d+\s?=.+?"tnum"
    numPlayersPerTeam = 4718592 + 3542,        -- regex: else\s+?{\s+?HUD::ADD_TEXT_COMPONENT_INTEGER\(Global_
    nextContentID = 4718592 + 132821,          -- regex: "nrcid"[^{}]+?Global_\d+\.f_\d+\[
    criticalMinimumForTeam = 4718592 + 185951, -- regex: "tcmin"[^}]+?Global_\d+\.f_\d+\[
}

local function MissionHeaderMinPlayers(index)
    return 794954 + 4 + 1 + index * 95 + 75 -- regex: -1279529723;[\s\S]+?Global_.+= 1;
end

local scrLocals = {
    ["fmmc_launcher"] = {
        minPlayers = 20054 + 15,       -- regex: Local_\d+\.f_\d+ = 1;\s+Global_\d+\.f_\d+ = 1;
        missionVariation = 20054 + 34, -- regex: HUD_MG_TENNIS.+\s+.+?Local_\d+\.f_\d+ \+ 1
    },
    ["fm_mission_controller"] = {
        serverBitSet = 19791 + 1,
        serverBitSet2 = 19791 + 2,
        nextMission = 19791 + 1062,   -- regex: (Local_\d+\.f_\d+) < 6 && \1 >= 0
        teamScore = 19791 + 1232 + 1, -- regex: < 4\)\s+?{\s+?(Local_\d+\.f_\d+\[.+?\]) = \(?\1 \+ .+?\)?;\s+if
    },
    ["fm_mission_controller_2020"] = {
        serverBitSet = 55789 + 1,
        serverBitSet2 = 55789 + 2,
        nextMission = 55789 + 1589,   -- regex: same as above
        teamScore = 55789 + 1776 + 1, -- regex: same as above
    }
}

----------------------------------------
-- SOLO MISSION
----------------------------------------

local soloEnabled = false
local patchEnabled = false
local casinoHeistPatch = nil

SOLO_MISSIONS:add_imgui(function()
    if not IsOnline() then
        ImGui.Text("Unavailable in Single Player.")
        return
    end

    ImGui.Text("Compatible Game Version: " .. TARGET_VERSION)
    ImGui.Text("Please check your game version before using!")

    ImGui.Dummy(1, 10)
    ImGui.SeparatorText("Solo Missions")
    ImGui.Spacing()

    soloEnabled, _ = ImGui.Checkbox("Enable Solo Missions", soloEnabled)

    ImGui.Spacing()

    if ImGui.Button("Skip to Next Checkpoint") then
        local mscript = GetMissionScript()
        if not mscript then return end

        locals.set_bits(mscript, scrLocals[mscript].serverBitSet2, 17)
    end

    if ImGui.Button("Instant Finish") then
        local mscript = GetMissionScript()
        if not mscript then return end

        for i = 0, 5 do
            globals.set_string(scrGlobals.nextContentID + 1 + i * 6, "", 0)
        end

        locals.set_int(mscript, scrLocals[mscript].nextMission, 5)
        locals.set_int(mscript, scrLocals[mscript].teamScore, 999999)
        locals.set_bits(mscript, scrLocals[mscript].serverBitSet, 9, 16)
    end

    ImGui.SameLine()

    if ImGui.Button("Force Fail") then
        local mscript = GetMissionScript()
        if not mscript then return end

        locals.set_bits(mscript, scrLocals[mscript].serverBitSet, 16, 20)
    end

    ImGui.Dummy(1, 10)
    ImGui.SeparatorText("Casino Heist Patch")
    ImGui.Spacing()

    patchEnabled, Clicked = ImGui.Checkbox("Enable Patch", patchEnabled)

    if Clicked then
        script.run_in_fiber(function()
            if patchEnabled then
                if casinoHeistPatch then
                    casinoHeistPatch:enable_patch()
                    return
                end

                casinoHeistPatch = scr_patch:new(
                    "fmmc_launcher",
                    "SCJJAT",
                    "2D 01 03 00 00 5D ? ? ? 2A 06 56 05 00 5D ? ? ? 20 2A 06 56 05 00 5D",
                    5,
                    { 0x71, 0x2E, 0x01, 0x01 }
                )
            else
                if casinoHeistPatch then
                    casinoHeistPatch:disable_patch()
                end
            end
        end)
    end

    ImGui.Dummy(1, 10)
    ImGui.BulletText("Allows you to set up the final planning board.")
    ImGui.BulletText("Make sure it's enabled before launching the heist\nand disabled after completing the heist.")
    ImGui.BulletText("It is not recommended to keep it enabled continuously.")
end)

----------------------------------------
-- MISSION LAUNCHER
----------------------------------------

local MISSION_LAUNCHER <const> = SOLO_MISSIONS:add_tab("  > Mission Launcher")

local fmMissionId = 0
local fmVariation = 0
local fmSubVariation = 0
local missionId = ""

MISSION_LAUNCHER:add_imgui(function()
    if not IsOnline() then
        ImGui.Text("Unavailable in Single Player.")
        return
    end

    ImGui.TextColored(0.9, 0, 0, 1, "WARNING!")
    ImGui.TextColored(0.9, 0, 0, 1, "These are advanced features and might not work well.\nIncorrect use may cause game script errors or even game crashes!")

    --------------------------------
    -- LAUNCH FREEMODE MISSION
    --------------------------------

    ImGui.Spacing()
    ImGui.SeparatorText("Launch Freemode Mission")
    ImGui.Spacing()

    fmMissionId, _ = ImGui.InputInt("Freemode Mission ID", fmMissionId, 1)
    fmVariation, _ = ImGui.InputInt("Freemode Mission Variation", fmVariation, 1)
    fmSubVariation, _ = ImGui.InputInt("Freemode Mission Sub-Variation", fmSubVariation, 1)

    if ImGui.Button("Check Mission Name") then
        script.run_in_fiber(function()
            if fmMissionId < -1 or fmVariation < -1 or fmSubVariation < -1 then return end
            if NETWORK.NETWORK_IS_ACTIVITY_SESSION() then return end

            local name = scr_function.call_script_function(FREEMODE, "get_freemode_mission_name",
                "2D 03 06 00 00 38 00 65 ? 96 00 00 00 ? ? 1A 00 00 00", "string", {
                    { "int", fmMissionId },
                    { "int", fmVariation },
                    { "int", fmSubVariation }
                })


            if not name or name == "" then
                name = "Invalid mission"
            end
            gui.show_message("Check Mission Name", tostring(name))
        end)
    end

    ImGui.SameLine()
    ImGui.Text("Check if the mission is valid")

    if ImGui.Button("Launch Freemode Mission") then
        script.run_in_fiber(function()
            if fmMissionId < -1 or fmVariation < -1 or fmSubVariation < -1 then return end
            if NETWORK.NETWORK_IS_ACTIVITY_SESSION() then return end

            scr_function.call_script_function(FREEMODE, "request_launch_gb_mission",
                "2D 03 05 00 00 38 01 70 58", "void", {
                    { "int", fmMissionId },
                    { "int", fmVariation },
                    { "int", fmSubVariation }
                })
        end)
    end

    ImGui.SameLine()

    if ImGui.Button("Clear Freemode Mission") then
        script.run_in_fiber(function()
            if NETWORK.NETWORK_IS_ACTIVITY_SESSION() then return end

            scr_function.call_script_function(FREEMODE, "clear_gb_mission",
                "2D 02 04 00 00 38 00 38 01 5D ? ? ? 2C 01 ? ? 5D ? ? ? 56", "void", {
                    { "bool", true },
                    { "bool", false }
                })
        end)
    end

    ImGui.Spacing()
    ImGui.BulletText("Most missions require you to be a boss to launch.")
    ImGui.BulletText("Some missions require you to own the corresponding property to launch.")
    ImGui.BulletText("If you fail to launch try clearing mission to reset.")

    --------------------------------
    -- LAUNCH MISSION
    --------------------------------

    ImGui.Dummy(1, 10)
    ImGui.SeparatorText("Launch Mission")
    ImGui.Spacing()

    missionId, _ = ImGui.InputText("Mission ID/Hash", missionId, 64)

    ImGui.SameLine()

    if ImGui.Button("Paste") then
        missionId = ImGui.GetClipboardText()
    end

    if ImGui.Button("Launch Mission") then
        script.run_in_fiber(function()
            if missionId == "" then return end

            local missionHash = tonumber(missionId)
            if not missionHash then
                missionHash = joaat(missionId)
            end

            if not script.is_active(FMMC_LAUNCHER) then return end
            if NETWORK.NETWORK_IS_ACTIVITY_SESSION() then return end

            local index = MISC.GET_CONTENT_ID_INDEX(missionHash)
            if index == -1 then return end

            stats.set_packed_stat_bool(17, true) -- close matchmaking

            scr_function.call_script_function(FMMC_LAUNCHER, "launch_v2_corona",
                "2D 09 19 00 00 38 01", "void", {
                    { "int",  -1 },    -- iSeries
                    { "int",  index }, -- iArrayPos
                    { "bool", false }, -- bOnCall
                    { "int",  -1 },    -- iPlaylistType
                    { "bool", false }, -- bSkipSkyCam
                    { "bool", false }, -- bSetExitVector
                    { "bool", false }, -- bFromWall
                    { "bool", true },  -- bSetSkipWarning
                    { "int",  -1 }     -- iForceJobEntryType
                })
        end)
    end

    ImGui.Spacing()
    ImGui.BulletText("Some jobs require you to be a boss and own the corresponding property.")
    ImGui.BulletText("Unstable! You might get kicked, or the game could even crash.")
end)


----------------------------------------
-- LOOP
----------------------------------------

script.register_looped("SOLO_MISSIONS", function()
    if soloEnabled then
        if script.is_active(FMMC_LAUNCHER) then
            local index = locals.get_int(FMMC_LAUNCHER, scrLocals[FMMC_LAUNCHER].missionVariation)
            if index > 0 then
                locals.set_int(FMMC_LAUNCHER, scrLocals[FMMC_LAUNCHER].minPlayers, 1)
                globals.set_int(MissionHeaderMinPlayers(index), 1)
            end
        end

        globals.set_int(scrGlobals.minNumParticipants, 1)
        globals.set_int(scrGlobals.numPlayersPerTeam + 1, 1)
        globals.set_int(scrGlobals.criticalMinimumForTeam + 1, 0)
        globals.set_int(scrGlobals.numberOfTeams, 1)
        globals.set_int(scrGlobals.maxNumberOfTeams, 1)
    end
end)

event.register_handler(menu_event.ScriptsReloaded, function()
    if casinoHeistPatch then
        casinoHeistPatch:disable_patch()
    end
end)
