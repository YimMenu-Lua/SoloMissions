local SOLO_MISSIONS <const> = gui.add_tab("Solo Missions")

local function SET_BIT(value, position)
    return (value | (1 << position))
end

local function GetBuildNumber()
    local pBnum = memory.scan_pattern("8B C3 33 D2 C6 44 24 20"):add(0x24):rip()
    return pBnum:get_string()
end

local function IsOnline()
    return network.is_session_started()
    and not script.is_active("maintransition")
end

local TARGET_BUILD <const> = "3504"
local CURRENT_BUILD <const> = GetBuildNumber()
local FMMC_LAUNCHER <const> = "fmmc_launcher"
local FM_MISSION_CONTROLLER <const> = "fm_mission_controller"
local FM_MISSION_CONTROLLER_2020 <const> = "fm_mission_controller_2020"

local SoloMissions = false
local patch_enabled = false
local casino_heist_patch = nil

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
        if script.is_active(FM_MISSION_CONTROLLER) then
            local value = locals.get_int(FM_MISSION_CONTROLLER, 19783 + 2) -- if \(func_....?\(.*?Global_.*?\.f_.*?\) && !.*?\(.?Local_.....?\.f_1, 16\)\)
            value = SET_BIT(value, 17)
            locals.set_int(FM_MISSION_CONTROLLER, 19783 + 2, value)
        elseif script.is_active(FM_MISSION_CONTROLLER_2020) then
            local value = locals.get_int(FM_MISSION_CONTROLLER_2020, 52171 + 2)
            value = SET_BIT(value, 17)
            locals.set_int(FM_MISSION_CONTROLLER_2020, 52171 + 2, value)
        end
    end

    if ImGui.Button("Instant Finish") then
        for i = 0, 5 do
            globals.set_string(4718592 + 128791 + 1 + i * 6, "") -- if \(NETWORK::UGC_QUERY_BY_CONTENT_ID\(&\(Global_4......?\.f_1.....?\[0 /\*6\*/\]\), true, func_.*?\(iParam2\)\)\)
        end

        if script.is_active(FM_MISSION_CONTROLLER) then
            locals.set_int(FM_MISSION_CONTROLLER, 19783 + 1062, 5)
            locals.set_int(FM_MISSION_CONTROLLER, 19783 + 1232 + 1, 999999)

            local value = locals.get_int(FM_MISSION_CONTROLLER, 19783 + 1)
            value = SET_BIT(value, 9)
            value = SET_BIT(value, 16)
            locals.set_int(FM_MISSION_CONTROLLER, 19783 + 1, value)
        elseif script.is_active(FM_MISSION_CONTROLLER_2020) then
            locals.set_int(FM_MISSION_CONTROLLER_2020, 52171 + 1589, 5)
            locals.set_int(FM_MISSION_CONTROLLER_2020, 52171 + 1776 + 1, 999999)

            local value = locals.get_int(FM_MISSION_CONTROLLER_2020, 52171 + 1)
            value = SET_BIT(value, 9)
            value = SET_BIT(value, 16)
            locals.set_int(FM_MISSION_CONTROLLER_2020, 52171 + 1, value)
        end
    end

    ImGui.SameLine()

    if ImGui.Button("Force Fail") then
        if script.is_active(FM_MISSION_CONTROLLER) then
            local value = locals.get_int(FM_MISSION_CONTROLLER, 19783 + 1)
            value = SET_BIT(value, 16)
            value = SET_BIT(value, 20)
            locals.set_int(FM_MISSION_CONTROLLER, 19783 + 1, value)
        elseif script.is_active(FM_MISSION_CONTROLLER_2020) then
            local value = locals.get_int(FM_MISSION_CONTROLLER_2020, 52171 + 1)
            value = SET_BIT(value, 16)
            value = SET_BIT(value, 20)
            locals.set_int(FM_MISSION_CONTROLLER_2020, 52171 + 1, value)
        end
    end

    ImGui.Dummy(1, 10)
    ImGui.SeparatorText("Casino Heist Patch")
    ImGui.Spacing()

    patch_enabled, Clicked = ImGui.Checkbox(
        ("%s Patch"):format(patch_enabled and "Disable" or "Enable"),
        patch_enabled
    )

    if Clicked then
        if patch_enabled then
            if casino_heist_patch then
                casino_heist_patch:enable_patch()
                return
            end

            casino_heist_patch = scr_patch:new(
                "fmmc_launcher",
                "SCJJAT",
                "2D 01 03 00 00 5D ? ? ? 2A 06 56 05 00 5D ? ? ? 20 2A 06 56 05 00 5D",
                5,
                { 0x71, 0x2E, 0x01, 0x01 }
            )
        else
            if casino_heist_patch then
                casino_heist_patch:disable_patch()
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
                local iArrayPos = locals.get_int(FMMC_LAUNCHER, 19875 + 34) -- Local_1....?\.f_..? = Global_2.....?\.f_....?\[iVar11\];

                if iArrayPos > 0 then
                    locals.set_int(FMMC_LAUNCHER, 19875 + 15, 1)
                    globals.set_int(794744 + 4 + 1 + iArrayPos * 89 + 69, 1) -- if \(iVar0 != -1 && BitTest\(Global_......?\.f_.?\[iVar0 /\*89\*/\]\.f_..?, 13\)\)
                end
            end

            globals.set_int(4718592 + 3523, 1) -- Global_4......?\.f_....? = DATAFILE::DATADICT_GET_INT\(iVar1, "minNu"\);
            globals.set_int(4718592 + 3529 + 1, 1) -- Global_4......?\.f_....?\[bVar0\] = DATAFILE::DATAARRAY_GET_INT\(iVar2, bVar0\);
            globals.set_int(4718592 + 180865 + 1, 0) -- StringCopy\(&cVar420, "tmrsp", 8\);
            globals.set_int(4718592 + 3526, 1) -- Global_4......?\.f_....? = DATAFILE::DATADICT_GET_INT\(iVar1, "dtn"\);
            globals.set_int(4718592 + 3527, 1)
        end
    end)
end

event.register_handler(menu_event.ScriptsReloaded, function()
    if casino_heist_patch then
        casino_heist_patch:disable_patch()
    end
end)
