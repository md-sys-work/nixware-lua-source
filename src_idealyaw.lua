engine.execute_client_cmd("clear")
ffi.cdef[[
    struct c_color { unsigned char clr[4]; };
    struct vec3_t { float x, y, z; };
    typedef void(__thiscall* add_box_overlay_t)(void*, const struct vec3_t&, const struct vec3_t&, const struct vec3_t&, struct vec3_t const&, int, int, int, int, float);

    void* CreateFileA(const char* lpFileName, unsigned long dwDesiredAccess, unsigned long dwShareMode, unsigned long lpSecurityAttributes, unsigned long dwCreationDisposition, unsigned long dwFlagsAndAttributes, void* hTemplateFile);
    bool ReadFile(void* hFile, char* lpBuffer, unsigned long nNumberOfBytesToRead, unsigned long* lpNumberOfBytesRead, int lpOverlapped);
    bool WriteFile(void* hFile, char* lpBuffer, unsigned long nNumberOfBytesToWrite, unsigned long* lpNumberOfBytesWritten, void* lpOverlapped);
    unsigned long GetFileSize(void* hFile, unsigned long* lpFileSizeHigh);
    bool CreateDirectoryA(const char* lpPathName, void* lpSecurityAttributes);
    void* CloseHandle(void *hFile);

    typedef struct _OVERLAPPED {
        unsigned long* Internal;
        unsigned long* InternalHigh;
        union {
            struct {
                unsigned long Offset;
                unsigned long OffsetHigh;
            } DUMMYSTRUCTNAME;
            void* Pointer;
        } DUMMYUNIONNAME;
        void*    hEvent;
    } OVERLAPPED, *LPOVERLAPPED;
]]

local gui = {
    chooser = ui.add_combo_box("Terminal selection", "luaterm", {"Aimbot", "Anti-aim", "Visuals", "Miscellaneous", "Config"}, 0),

    rage = {
        adaptive_l = ui.add_check_box("Adaptive lethal system", "luaadptlt", false),
        adaptive_l_list = ui.add_multi_combo_box("Parameters", "luaadptl", {"Body aim", "Skip unsafe hitboxes", "Skip corner points"}, {false, false, false}),
        adaptive_dt = ui.add_check_box("Adaptive DT hitscan", "luaadpths", false),
        adaptive_dt_list = ui.add_multi_combo_box("Parameters", "luaadptdtl", {"Body aim"}, {false}),
        body_disablers = ui.add_check_box("Conditions body aim disablers", "luabodydis", false),
        body_disablers_list = ui.add_multi_combo_box("Parameters", "luabodylist", {"Static desync", "In air", "Target resolved", "Target is shooting"}, {false, false, false, false}),
    },

    antiaim = {
        mode = ui.add_combo_box("Mode", "lua_modeaa", {"Builder", "Presets"}, 0),
        tweaks = ui.add_multi_combo_box("Antiaim tweaks", "lua_aatwk", {"Disable on warmup", "Disable on round end", "On use", "Freestanding"}, {false, false, false, false}),
        freestand_bind = ui.add_key_bind("Freestanding yaw", "lua_frstyaw", 0, 2),
        --freestand_opt = ui.add_multi_combo_box("Freestanding options", "lua_frstwk", {"Disable jitter yaw"}, {false}),
        presets = ui.add_combo_box("Presets", "lua_presets", {"Low Degree Tank", "Jitter #1", "Jitter #2", "ABF Static"}, 1),
        condition = ui.add_combo_box("Condition", "luacond", {"Shared", "Standing", "Air", "Moving", "Slowwalking", "Crouch", "Air-Crouch", "Roll", "Legit AA"}, 0)
    },

    visuals = {
        vis_chooser = ui.add_combo_box("\n\n", "lua_vischoose", {"World", "UI", "Models"}, 0)
    },

    world = {
        impacts = ui.add_combo_box("Aimbot impacts", "lua_aimp", {"Primordial", "Default"}, 0),
        impacts_color_c = ui.add_color_edit("Impacts color client", "lua_cimpc", true, color_t.new(200, 200, 255, 150)),
        impacts_color_s = ui.add_color_edit("Impacts color server", "lua_cimps", true, color_t.new(200, 200, 255, 150))
    },

    models = {
        rag_type = ui.add_combo_box("Ragdoll type", "lua_ragdolls", {"Default", "Slide fade-out", "Astronaut"}, 0),
    },

    misc = {
        weapon_tweaks = ui.add_multi_combo_box("Weapon actions", "lua_wact", {"Fast switch", "Fast reload"}, {false, false}),
        move_tweaks = ui.add_multi_combo_box("Movement actions", "lua_mact", {"Fast ladder"}, {false}),
        hud_tweaks = ui.add_multi_combo_box("Hud actions", "lua_hactions", {"Preserve killfeed", "Reset chat after round end"}, {false, false})
    },

    config = {
        style = ui.add_check_box("Get menu style", "lua_stl", false)
    }
}

local variables = {
    colors = {
        gray = color_t.new(220, 220, 220, 255),
        acid = color_t.new(195, 255, 63, 200),
        dark_blue = color_t.new(99, 150, 255, 180),
        yellow = color_t.new(255, 236, 0, 235),
        red_yellow = color_t.new(255, 158, 5, 235),
        orange = color_t.new(234, 81, 1, 235)
    },

    script = {
        version = "1.0.0",
        update_log = {}
    },

    active_tab = nil,
    aa_conditions = {"Shared", "Standing", "Air", "Moving", "Slowwalking", "Crouch", "Air-Crouch", "Roll", "Legit AA"},
    aa_conditions_short = {"Shared", "ST", "Air", "Moving", "SW", "Crouch", "A-Crouch", "Roll", "Legit"},
    handler_builder = {},
    wmsg = {[[
██╗██████╗ ███████╗ █████╗ ██╗  ██╗   ██╗ █████╗ ██╗    ██╗
██║██╔══██╗██╔════╝██╔══██╗██║  ╚██╗ ██╔╝██╔══██╗██║    ██║
██║██║  ██║█████╗  ███████║██║   ╚████╔╝ ███████║██║ █╗ ██║
██║██║  ██║██╔══╝  ██╔══██║██║    ╚██╔╝  ██╔══██║██║███╗██║
██║██████╔╝███████╗██║  ██║███████╗██║   ██║  ██║╚███╔███╔╝
╚═╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝   ╚═╝  ╚═╝ ╚══╝╚══╝ 
]],
    },
    pos = {}
}

for i = 1, #variables.aa_conditions do
    variables.handler_builder[i] = {
        enable_condition = ui.add_check_box("["..variables.aa_conditions_short[i].."] Enable Condition", i.."enable_condition", false),
        at_target = ui.add_check_box("["..variables.aa_conditions_short[i].."] At target", i.."at_target", false),
        pitch = ui.add_combo_box("["..variables.aa_conditions_short[i].."] Pitch", i.."pitch", {"None", "Down", "Zero", "Up"}, 0),
        yaw = ui.add_combo_box("["..variables.aa_conditions_short[i].."] Yaw", i.."yaw", {"None", "Backwards", "Left", "Right"}, 0),
        yaw_type = ui.add_combo_box("["..variables.aa_conditions_short[i].."] Yaw type", i.."yaw_type", {"Static", "Jitter"}, 0),
        yaw_jitter = ui.add_slider_int("["..variables.aa_conditions_short[i].."] Yaw jitter", i.."yaw_jitter", -90, 90, 0),
        yaw_desync = ui.add_slider_int("["..variables.aa_conditions_short[i].."] Yaw desync", i.."yaw_desync", 0, 60, 0)
    }    
end

local gui_objects = {
    antiaim = {
        disabler = ui.get_check_box("antihit_antiaim_enable"),
        antihit_antiaim_pitch = ui.get_combo_box("antihit_antiaim_pitch"),
        antihit_antiaim_yaw = ui.get_combo_box("antihit_antiaim_yaw"),
        antihit_antiaim_desync_length = ui.get_slider_int("antihit_antiaim_desync_length"),
        antihit_antiaim_desync_type = ui.get_combo_box("antihit_antiaim_desync_type"),
        antihit_antiaim_at_targets = ui.get_check_box("antihit_antiaim_at_targets"),
        antihit_antiaim_yaw_jitter = ui.get_slider_int("antihit_antiaim_yaw_jitter")
    }
}

local netvars = {
    m_hActiveWeapon = se.get_netvar("DT_BaseCombatCharacter", "m_hActiveWeapon"),
    m_iItemDefinitionIndex = se.get_netvar("DT_BaseAttributableItem", "m_iItemDefinitionIndex"),
    m_VecOrigin = se.get_netvar("DT_BaseEntity", "m_vecOrigin")
}

entity_t.get_weapon_index = function(p)
    local active_weapon = entitylist.get_entity_from_handle(p:get_prop_int(netvars.m_hActiveWeapon)):get_prop_int(netvars.m_iItemDefinitionIndex)
    return active_weapon
end

origin = {}
origin.get_nearest_target = function()
    local local_player = entitylist.get_local_player()
    local local_player_pos = local_player:get_prop_vector(netvars.m_VecOrigin)
    local nearest_distance, nearest_entity
    local players = entitylist.get_players(0)
    for i = 1, #players do
        local player = players[i]
        local target = player:get_prop_vector(netvars.m_VecOrigin)
        local distance = local_player_pos:dist_to(target)
        if (not nearest_distance or distance < nearest_distance) and player:is_alive() and not player:is_dormant() then
            nearest_entity = player
            nearest_distance = distance
        end
    end
    return nearest_entity
end

origin.get_freestand_side = function(ctx)
    local local_player = entitylist.get_local_player()
    if not local_player or not local_player:is_alive() then return 1 end
    local pos = local_player:get_prop_vector(netvars.m_VecOrigin)

    local targeted_player = origin.get_nearest_target()
    if not targeted_player then return 1 end

    local yaw = ctx.viewangles.yaw
    local fractions = {}
    local player_origin = targeted_player:get_prop_vector(netvars.m_VecOrigin)
    player_origin.z = targeted_player:get_player_hitbox_pos(0).z

    for i = yaw - 90, yaw + 90, 45 do
        if i ~= yaw then
            local rad = math.rad(i)
            local cos, sin = math.cos(rad), math.sin(rad)
            local new_head_pos = pos + vec3_t.new(200 * cos, 200 * sin, 0)
            local dest = pos + vec3_t.new(7028 * cos, 7028 * sin, 0)
            local trace1 = trace.line(local_player:get_index(), 0x46004003, new_head_pos, player_origin)
            local trace2 = trace.line(local_player:get_index(), 0x46004003, pos, dest)
            fractions[#fractions + 1] = {i, trace1.fraction / 2 + trace2.fraction / 2}
        end
    end

    table.sort( fractions, function(a, b) return a[2] > b[2] end)

    local side = 1
    if fractions[1][2] - fractions[#fractions][2] < 0.5 then return 1 end
    if fractions[1][2] < 0.1 then return 1 end
    if yaw - fractions[1][1] > 0 then
        side = 2
    else
        side = 3
    end

    local trace_safe = trace.line(local_player:get_index(), 0x46004003, local_player:get_player_hitbox_pos(0), player_origin)

    if trace_safe.fraction > 5 then
        side = 1
    end

    return side
end 

filesystem = {}
filesystem.mkdir = function(path)
    ffi.C.CreateDirectoryA(path, nil)
end

filesystem.readfile = function(path_to_file)
    local pfile = ffi.cast("void*", ffi.C.CreateFileA(path_to_file, 0xC0000000, 0x3, 0, 0x4, 0x80, nil))
    local size = ffi.C.GetFileSize(pfile, nil)
    local buff = ffi.new("char[" ..(size + 1).. "]")

    ffi.C.ReadFile(pfile, buff, size, nil, 0)
    ffi.C.CloseHandle(pfile)

    buff = ffi.string(buff)

    if #buff == 0 then return false end

    return buff
end

filesystem.writefile = function(path_to_file, _string) -- working for table\overlapped\overflow table (for kawasaki paster blyat)
    if type(_string) ~= 'string' then
        _string = tostring(_string)
    end

    local pfile = ffi.cast("void*", ffi.C.CreateFileA(path_to_file, 0xC0000000, 0x00000003, 0, 0x2, 0x0, nil))
    local overlapped = ffi.new("OVERLAPPED")
    overlapped.DUMMYUNIONNAME.DUMMYSTRUCTNAME.Offset = 0xFFFFFFFF
    overlapped.DUMMYUNIONNAME.DUMMYSTRUCTNAME.OffsetHigh = 0xFFFFFFFF
    ffi.C.WriteFile(pfile, ffi.cast("char*", _string), string.len(_string), nil, ffi.cast("void*", overlapped))
    ffi.C.CloseHandle(pfile)

    return true
end

filesystem.writefile_via_io = function(path, text)
    local file = io.open(path, "a+")
    file:write(text)
    file:close()
end

client.color_print = function(color, text)
    console_color = ffi.new("struct c_color")
    engine_cvar = ffi.cast("void***", se.create_interface("vstdlib.dll", "VEngineCvar007"))
    console_print = ffi.cast("void(__cdecl*)(void*, const struct c_color&, const char*, ...)", engine_cvar[0][25])

    console_color.clr[0] = color.red * 255
    console_color.clr[1] = color.green * 255
    console_color.clr[2] = color.blue * 255
    console_color.clr[3] = color.alpha * 255
    console_print(engine_cvar, console_color, text)
end

client.multi_cprint = function(...)
    local args = {...}
    local length = #args
  
    if length % 2 ~= 0 then error("multicprint criticals odds", 2) end

    length = length /2
    for index = 1, length do
        local text = args[index]
        local color = args[length + index]
    
        local type_of_text = type(text)
        if type_of_text ~= 'string' then error("nowhere finded string data", 2) end

        client.color_print(color, text)
    end
end

se.get_part_of_day = function()
    local curtime = os.date("%X", os.time())

    if curtime > "00:00:00" and curtime < "04:59:59" then
        return {_string = "night", color = variables.colors.dark_blue}
    elseif curtime > "05:59:59" and curtime < "11:59:59" then
        return {_string = "morning", color = variables.colors.red_yellow}
    elseif curtime > "12:59:59" and curtime < "17:59:59" then
        return {_string = "day", color = variables.colors.yellow}
    elseif curtime > "18:59:59" and curtime < "23:59:59" then
        return {_string = "evening", color = variables.colors.orange}
    end
end

renderer.add_box_overlay = function()

end -- useless

filesystem.mkdir("./nix/idealyaw")
local gui_callback = {
    filesystem.writefile_via_io("./nix/idealyaw/debug.ini", "["..os.date("%X", os.time()).."] initializing gui_callback...\n"),
    switch_system = function()
        local value = gui.chooser:get_value()
        local n_tabs = {"rage", "aa", "vis", "misc", "cfg"}
        variables.active_tab = n_tabs[value + 1]

        for _, i in pairs(gui.rage) do
            i:set_visible(value == 0)
        end

        for _, i in pairs(gui.antiaim) do
            i:set_visible(value == 1)
        end

        for _, i in pairs(gui.visuals) do
            i:set_visible(value == 2)
        end

        for _, i in pairs(gui.misc) do
            i:set_visible(value == 3)
        end

        for _, i in pairs(gui.config) do
            i:set_visible(value == 4)
        end
    end,

    parent_settings = function()
        local a_value = gui.rage.adaptive_l:get_value()
        local b_value = gui.rage.adaptive_dt:get_value()
        local c_value = gui.rage.body_disablers:get_value()
        local d_value = gui.antiaim.mode:get_value()
        local e_value = gui.antiaim.tweaks:get_value(3)
        local f_value = gui.visuals.vis_chooser:get_value()
        gui.rage.adaptive_l_list:set_visible(variables.active_tab == "rage" and a_value == true)
        gui.rage.adaptive_dt_list:set_visible(variables.active_tab == "rage" and b_value == true)
        gui.rage.body_disablers_list:set_visible(variables.active_tab == "rage" and c_value == true)
        gui.antiaim.presets:set_visible(variables.active_tab == "aa" and d_value == 1)
        gui.antiaim.freestand_bind:set_visible(variables.active_tab == "aa" and e_value == true)
        gui.antiaim.condition:set_visible(variables.active_tab == "aa" and d_value == 0)
        --gui.antiaim.freestand_opt:set_visible(variables.active_tab == "aa" and e_value == true)
        for _, i in pairs(gui.world) do
            i:set_visible(variables.active_tab == "vis" and f_value == 0)
        end

        for _, i in pairs(gui.models) do
            i:set_visible(variables.active_tab == "vis" and f_value == 2)
        end
    end,

    get_media = function()
        local a_value = gui.config.style:get_value()
        if a_value then
            client.notify("Style code copied to clipboard")
            gui.config.style:set_value(false)
        end
    end,

    antiaim_builder_controller = function()
        local a_state = gui.antiaim.mode:get_value()
        local b_state = gui.antiaim.condition:get_value()
        local c_state = gui.chooser:get_value()

        for i = 1, #variables.aa_conditions do
            local id = i - 1
            variables.handler_builder[i].enable_condition:set_visible(c_state == 1 and b_state == id and a_state == 0)
            variables.handler_builder[i].at_target:set_visible(c_state == 1 and b_state == id and a_state == 0)
            variables.handler_builder[i].pitch:set_visible(c_state == 1 and b_state == id and a_state == 0)
            variables.handler_builder[i].yaw:set_visible(c_state == 1 and b_state == id and a_state == 0)
            variables.handler_builder[i].yaw_type:set_visible(c_state == 1 and b_state == id and a_state == 0)
            variables.handler_builder[i].yaw_jitter:set_visible(c_state == 1 and b_state == id and a_state == 0)
            variables.handler_builder[i].yaw_desync:set_visible(c_state == 1 and b_state == id and a_state == 0)
        end
    end,

    console_welcome_msg = function()
        client.multi_cprint(
            variables.wmsg[1].."\n\n",
            "welcome back to ", "idealyaw\n",
            "version: ", variables.script.version.."\n",
            "name: ", client.get_username().."\n",
            "current time: ", os.date("%X", os.time()), " - ", se.get_part_of_day()._string.."\n\n",

            variables.colors.acid, 
            variables.colors.gray,
            variables.colors.acid,
            variables.colors.gray,
            variables.colors.acid,
            variables.colors.gray,
            variables.colors.acid,
            variables.colors.gray,
            variables.colors.acid,
            variables.colors.gray,
            se.get_part_of_day().color
        )
    end,
    filesystem.writefile_via_io("./nix/idealyaw/debug.ini", "["..os.date("%X", os.time()).."] initialized gui_callback\n")
}

local function_callback = {
    filesystem.writefile_via_io("./nix/idealyaw/debug.ini", "["..os.date("%X", os.time()).."] initializing create_move hook...\n"),
    create_move = {
        adaptive_doubletap_hitscan = function()
            if not gui.rage.adaptive_dt:get_value() then return end
            if entitylist.get_local_player():get_weapon_index() ~= 38 or 11 then end

            -- body aim on dt
            local players_array_t = entitylist.get_players(0)
            for i = 1, #players_array_t do
                local entity = players_array_t[i]
                local player_idx = entity:get_index()
                ragebot.override_hitscan(player_idx, 0, not gui.rage.adaptive_dt_list:get_value(0))
            end
        end,

        freestanding = function(ctx)
            local side = gui.antiaim.freestand_bind:is_active() and origin.get_freestand_side(ctx) or 1
            gui_objects.antiaim.antihit_antiaim_yaw:set_value(not gui.antiaim.tweaks:get_value(3) and 1 or side)
        end,

        antiaim_presets = function()
            local a_state = gui.antiaim.mode:get_value()
            local b_state = gui.antiaim.presets:get_value()
            if a_state ~= 1 then return end

            if b_state == 0 then
                gui_objects.antiaim.antihit_antiaim_desync_length:set_value(50)
                gui_objects.antiaim.antihit_antiaim_desync_type:set_value(1)
                gui_objects.antiaim.antihit_antiaim_yaw_jitter:set_value(15)
            elseif b_state == 1 then
                gui_objects.antiaim.antihit_antiaim_desync_length:set_value(60)
                gui_objects.antiaim.antihit_antiaim_desync_type:set_value(1)
                gui_objects.antiaim.antihit_antiaim_yaw_jitter:set_value(-17)
            elseif b_state == 2 then
                gui_objects.antiaim.antihit_antiaim_desync_length:set_value(60)
                gui_objects.antiaim.antihit_antiaim_desync_type:set_value(1)
                gui_objects.antiaim.antihit_antiaim_yaw_jitter:set_value(33)
            elseif b_state == 3 then
                gui_objects.antiaim.antihit_antiaim_desync_length:set_value(50)
                gui_objects.antiaim.antihit_antiaim_desync_type:set_value(0)
                gui_objects.antiaim.antihit_antiaim_yaw_jitter:set_value(2)
            end
        end,
    },

    filesystem.writefile_via_io("./nix/idealyaw/debug.ini", "["..os.date("%X", os.time()).."] initialized create_move hook\n"),
    paint = {
        render_impact = function()
            local voidptr = ffi.typeof('void***')
            local debug_overlay = ffi.cast(voidptr, se.create_interface('engine.dll', 'VDebugOverlay004'))
            local add_box_overlay = ffi.cast('add_box_overlay_t', debug_overlay[0][1])


            function call_impact(x, y, z, clr)
                local a_value = gui.world.impacts:get_value()
                local position = ffi.new('struct vec3_t')
                position.x = x; position.y = y; position.z = z
                local mins = ffi.new('struct vec3_t')
                mins.x = -4; mins.y = -4; mins.z = -4;
                local maxs = ffi.new('struct vec3_t')
                maxs.x = 4; maxs.y = 4; maxs.z = 4;
                local ori = ffi.new('struct vec3_t')
                mins.x = 0; mins.y = 0; mins.z = 0;

                if a_value == 0 then
                    alpha = 0
                else
                    alpha = clr.alpha * 255
                end

                add_box_overlay(debug_overlay, position, mins, maxs, ori, clr.red * 255, clr.green * 255, clr.blue * 255, alpha * 255, 5)
            end
        end,
    },

    frame_stage = {
        ragdolls = function(ctx)
            if gui.models.rag_type:get_value() == 0 then return end
            se.get_convar("cl_ragdoll_gravity"):set_int(gui.models.rag_type:get_value() == 1 and 600 or -9999)
            se.get_convar("cl_ragdoll_physics_enable"):set_int(gui.models.rag_type:get_value() == 2 and 1 or 0)
        end,
    },
}

client.register_callback("frame_stage_notify", function(ctx)
    if ctx == 5 then -- fired after FRAME_STAGE_RENDER_START
        gui_callback.switch_system()
        gui_callback.parent_settings()
        gui_callback.get_media() -- не юзать
        gui_callback.antiaim_builder_controller()

        function_callback.frame_stage.ragdolls()
    end
end)

client.register_callback("create_move", function(ctx)
    function_callback.create_move.adaptive_doubletap_hitscan()
    function_callback.create_move.freestanding(ctx)
end)

client.register_callback("paint", function(ctx)
    function_callback.create_move.antiaim_presets()
    function_callback.paint.render_impact()
end)

function client_impact(event)
   call_impact(event.aim_point.x, event.aim_point.y, event.aim_point.z, gui.world.impacts_color_c:get_value())
end

function server_impact(event)
    local event_index = engine.get_player_for_user_id(event:get_int("userid", 0))
    local lp_index = entitylist.get_local_player():get_index()
    if event_index == lp_index then
        call_impact(event:get_float("x", 0), event:get_float("y", 0), event:get_float("z", 0), gui.world.impacts_color_s:get_value())
    end
end

client.register_callback("bullet_impact", server_impact)
client.register_callback("shot_fired", client_impact)
gui_callback.console_welcome_msg()
collectgarbage("collect")
