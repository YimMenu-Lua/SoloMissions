local TAB = gui.add_tab("Solo Missions")

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

function locals.set_bits(scriptName, index, ...)
    local value = locals.get_int(scriptName, index)
    if not value then return end
    for _, bit in ipairs({ ... }) do
        value = value | (1 << bit)
    end
    locals.set_int(scriptName, index, value)
end

-- ======================
-- Globals 
-- ======================

local scrGlobals = {
    minNumParticipants     = 4718592 + 3536,
    numPlayersPerTeam      = 4718592 + 3542,
    criticalMinimumForTeam = 4718592 + 185505,
    numberOfTeams          = 4718592 + 3539,
    maxNumberOfTeams       = 4718592 + 3540,
    nextContentID          = 4718592 + 114029
}

local function MissionHeaderMinPlayers(index)
    return 794954 + 4 + 1 + index * 95 + 75
end

-- ======================
-- Locals 
-- ======================

local scrLocals = {
    ["fmmc_launcher"] = {
        minPlayers       = 20054 + 15,
        missionVariation = 20054 + 34
    },
    ["fm_mission_controller"] = {
        serverBitSet  = 19791 + 1,
        serverBitSet2 = 19791 + 2,
        nextMission   = 19791 + 1062,
        teamScore     = 19791 + 1232 + 1
    },
    ["fm_mission_controller_2020"] = {
        serverBitSet  = 55789 + 1,
        serverBitSet2 = 55789 + 2,
        nextMission   = 55789 + 1589,
        teamScore     = 55789 + 1776 + 1
    }
}

-- ======================
-- UI
-- ======================

local SoloEnabled = false
local AutoReady = false

TAB:add_imgui(function()
    if not IsOnline() then
        ImGui.Text("Unavailable in Single Player.")
        return
    end

    SoloEnabled, _ = ImGui.Checkbox("Enable Solo Missions", SoloEnabled)
    AutoReady, _  = ImGui.Checkbox("Auto-Ready", AutoReady)

    ImGui.Separator()

    if ImGui.Button("Skip Checkpoint") then
        local m = GetMissionScript()
        if m then
            locals.set_bits(m, scrLocals[m].serverBitSet2, 17)
        end
    end

    if ImGui.Button("Instant Finish") then
        local m = GetMissionScript()
        if m then
            for i = 0, 5 do
                globals.set_string(scrGlobals.nextContentID + 1 + i * 6, "", 0)
            end
            locals.set_int(m, scrLocals[m].nextMission, 5)
            locals.set_int(m, scrLocals[m].teamScore, 999999)
            locals.set_bits(m, scrLocals[m].serverBitSet, 9, 16)
        end
    end

    ImGui.SameLine()

    if ImGui.Button("Force Fail") then
        local m = GetMissionScript()
        if m then
            locals.set_bits(m, scrLocals[m].serverBitSet, 16, 20)
        end
    end
end)

-- ======================
-- MAIN SOLO LOOP 
-- ======================

script.register_looped("SOLO_MISSIONS_FINAL", function()
    if not SoloEnabled then return end
    if not IsOnline() then return end

    -- ===== Planning Boards (Casino / Apartment) =====
    if script.is_active("fmmc_launcher") then
        local variation = locals.get_int(
            "fmmc_launcher",
            scrLocals["fmmc_launcher"].missionVariation
        )

        if variation and variation > 0 then
            -- min players
            locals.set_int(
                "fmmc_launcher",
                scrLocals["fmmc_launcher"].minPlayers,
                1
            )

            globals.set_int(MissionHeaderMinPlayers(variation), 1)

            -- HARD limits (Casino-safe)
            globals.set_int(4718592 + 3539, 1)      -- numberOfTeams
            globals.set_int(4718592 + 3540, 1)      -- maxTeams
            globals.set_int(4718592 + 3542 + 1, 1)  -- playersPerTeam
            globals.set_int(4718592 + 185951 + 1, 0)

            -- Auto Ready (optional)
            if AutoReady then
                for i = 0, 3 do
                    globals.set_int(1882572 + 1 + (i * 315) + 43 + 11 + 1, 1)
                end
            end
        end
    end

    globals.set_int(scrGlobals.minNumParticipants, 1)
    globals.set_int(scrGlobals.numPlayersPerTeam + 1, 1)
    globals.set_int(scrGlobals.criticalMinimumForTeam + 1, 0)
    globals.set_int(scrGlobals.numberOfTeams, 1)
    globals.set_int(scrGlobals.maxNumberOfTeams, 1)
end)

-- ======================
-- BLACK SCREEN PROTECTION
-- ======================

local WasInLauncher = false

script.register_looped("SOLO_BLACKSCREEN_GUARD", function()
    if not SoloEnabled then return end
    if not IsOnline() then return end

    local inLauncher = script.is_active("fmmc_launcher")

    if inLauncher then
        WasInLauncher = true
    end

        if WasInLauncher and not inLauncher then
        SoloEnabled = false
        WasInLauncher = false
        util.toast("Solo Missions auto-disabled (Black Screen protection)")
    end
end)
