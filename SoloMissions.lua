local SOLO_MISSIONS <const> = gui.add_tab("Solo Missions")

function locals.set_bits(scriptName, index, ...)
    local value = locals.get_int(scriptName, index)
    for _, bit in ipairs({ ... }) do
        value = value | (1 << bit)
    end
    locals.set_int(scriptName, index, value)
end

local function GetBuildNumber()
    local pBnum = memory.scan_pattern("8B C3 33 D2 C6 44 24 20"):add(0x24):rip()
    return pBnum:get_string()
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

local TARGET_BUILD <const> = "3725.0"
local CURRENT_BUILD <const> = GetBuildNumber()
local FMMC_LAUNCHER <const> = "fmmc_launcher"

local SoloMissions = false
local patchEnabled = false
local casinoHeistPatch = nil

-- search in fmmc_launcher.c
local scrGlobals = {
    nextContentID = 4718592 + 114029,          -- "nrcid" ... StringCopy(Global_...[... /*6*/]
    minNumParticipants = 4718592 + 3536,       -- Global_... = "minNu"
    numPlayersPerTeam = 4718592 + 3542,        -- regex: else\n.*?HUD::ADD_TEXT_COMPONENT_INTEGER\(Global_.*?
    criticalMinimumForTeam = 4718592 + 185505, -- "tcmin" ... Global_...[...] = 0;
    numberOfTeams = 4718592 + 3539,            -- Global_... = "dtn"
    maxNumberOfTeams = 4718592 + 3540,         -- Global_.*?.f_.*? = DATAFILE::DATADICT_GET_INT\(dict, "tnum"\);
}
local function MissionHeaderMinPlayers(index)
    return 794954 + 4 + 1 + index * 95 + 75 -- [5] = -1279529723; ... Global_... = 1;
end

local scrLocals = {
    ["fmmc_launcher"] = {
        minPlayers = 20054 + 15,       -- regex: Local_.*?.f_.*? = 1;\n.*?Global_.*?.f_.*? = 1;
        missionVariation = 20054 + 34, -- regex: HUD_MG_TENNIS.+?\s+.+?Local_\d+?\.f_\d+? \+ 1
    },
    ["fm_mission_controller"] = {
        serverBitSet = 19791 + 1,
        serverBitSet2 = 19791 + 2,
        nextMission = 19791 + 1062,   -- regex: (Local_\d+?\.f_\d+?) < 6 && \1 >= 0
        teamScore = 19791 + 1232 + 1, -- regex: < 4\)\s+?{\s+?(Local_\d+?\.f_\d+?\[.+?\]) = \(?\1 \+ .+?\)?;
    },
    ["fm_mission_controller_2020"] = {
        serverBitSet = 55789 + 1,
        serverBitSet2 = 55789 + 2,
        nextMission = 55789 + 1589,   -- regex: same as above
        teamScore = 55789 + 1776 + 1, -- regex: same as above
    }
}


SOLO_MISSIONS:add_imgui(function()
    if CURRENT_BUILD ~= TARGET_BUILD then
        ImGui.Text("SoloMissions is outdated.")
        return
    end

    if not IsOnline() then
        ImGui.Text("Unavailable in Single Player.")
        return
    end

    SoloMissions, _ = ImGui.Checkbox("Solo Missions", SoloMissions)

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

    patchEnabled, Clicked = ImGui.Checkbox(
        ("%s Patch"):format(patchEnabled and "Disable" or "Enable"),
        patchEnabled
    )

    if Clicked then
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
    end

    ImGui.Dummy(1, 10)
    ImGui.Text("Allows you to set up the final planning board.")
    ImGui.Text("Make sure it's enabled before launching the heist\nand disabled after completing the heist.")
    ImGui.Text("It is not recommended to keep it enabled continuously.")
end)


if CURRENT_BUILD == TARGET_BUILD then -- don't create the thread if the script is outdated
    script.register_looped("SOLO_MISSIONS", function()
        if SoloMissions then
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
end

event.register_handler(menu_event.ScriptsReloaded, function()
    if casinoHeistPatch then
        casinoHeistPatch:disable_patch()
    end
end)
