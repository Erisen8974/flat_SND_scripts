-- Auto generated file, do not edit!
--[=====[
[[SND Metadata]]
author: Erisen
version: 1.0.0
description: >-
  Moon Manager


  Control ICE through the fancy new IPCs!
plugin_dependencies:
- ICE
- vnavmesh
- AutoHook
plugins_to_disable:
- TextAdvance
- YesAlready

configs:
  MaxResearch:
    default: false
    description: Get research to cap instead of just target
  HandleRetainers:
    default: true
    description: Interact with summoning bell when AR is ready.
  GambaLimit:
    default: 8000
    description: Lunar Credits to start start spinning the wheel. Must configure ICE to do gamba! 0 to disable.
    min: 0
    max: 10000

  RelicJobs:
    description: Jobs abbreviations to cycle through completing the relic. Dont add any to only run on current job.
    is_choice: false
    choices: ["FSH", "BTN", "MIN"]

  DebugMessages:
    default: false
    description: Show debug logs
[[End Metadata]]
--]=====]

--[[
================================================================================
  BEGIN IMPORT: moon_man.lua
================================================================================
]]

--[[
================================================================================
  BEGIN IMPORT: utils.lua
================================================================================
]]

--[[
================================================================================
  BEGIN IMPORT: legacy_interface.lua
================================================================================
]]

---------------------------
------- Legacy Glue -------
---------------------------
import("System.Numerics")



function IsAddonReady(name)
    local a = Addons.GetAddon(name)
    if a == nil then
        return false
    end
    return a.Exists and a.Ready
end

function GetTargetName()
    local t = Entity.Target
    if t == nil then
        return nil
    end
    return t.Name
end

function GetCharacterCondition(cond)
    return Svc.Condition[cond]
end

function GetDistanceToPoint(x, y, z)
    if Entity == nil then
        return nil
    end
    if Entity.Player == nil then
        return nil
    end
    if Entity.Player.Position == nil then
        return nil
    end
    return Vector3.Distance(Entity.Player.Position, Vector3(x, y, z))
end

function IsPlayerAvailable()
    return not is_busy()
end

function PathMoveTo(x, y, z, fly)
    running_vnavmesh = true
    IPC.vnavmesh.PathfindAndMoveTo(Vector3(x, y, z), fly)
end

function GetNodeText(name, ...)
    local a = Addons.GetAddon(name)
    if not a.Ready then
        StopScript("Bad addon", CallerName(false), name)
    end
    local n = a:GetNode(...)
    if tostring(n.NodeType):find("Text:") == nil then
        StopScript("Not a text node", CallerName(false), "NodeType:", n.NodeType, "NodeId:", n.Id, name, ...)
    end
    return n.Text
end

function HasStatusId(status_id)
    for s in luanet.each(Player.Status) do
        if s.StatusId == status_id then
            return true
        end
    end
    return false
end

function GetStatusStackCount(status_id)
    for s in luanet.each(Player.Status) do
        if s.StatusId == status_id then
            return s.Param
        end
    end
    return 0
end
--[[
================================================================================
  END IMPORT: legacy_interface.lua
================================================================================
]]


import 'System.Numerics'

-- if present load the character info
pcall(require, 'private/char_info')


SCRIPT_TAG = "[EriSND]"

-----------------------
-- General Utilities --
-----------------------

function default(value, default_value)
    if value == nil then return default_value end
    return value
end

function wait(duration)
    yield('/wait ' .. string.format("%.1f", duration))
end

function pause_pyes()
    pyes_pause_count = default(pyes_pause_count, 0)
    pyes_pause_count = pyes_pause_count + 1
    get_shared_data("YesAlready.StopRequests", "System.Collections.Generic.HashSet`1[System.String]"):Add(SCRIPT_TAG)
end

function resume_pyes()
    if pyes_pause_count == nil then
        return
    end
    pyes_pause_count = pyes_pause_count - 1
    if pyes_pause_count == 0 then
        get_shared_data("YesAlready.StopRequests", "System.Collections.Generic.HashSet`1[System.String]"):Remove(
            SCRIPT_TAG)
        release_shared_data("YesAlready.StopRequests")
    end
end

function find_after(msg, target, after)
    e, s = msg:reverse():find(after:reverse())
    if e == nil then
        return nil -- cant find something after something if the second thing doesnt exist!
    end
    return string.find(msg, target, -e)
end

function get_chat_messages(tab)
    local chat = GetNodeText("ChatLogPanel_" .. tostring(tab), 1, 2, 3)
    if chat == 2 then
        StopScript("Error getting chat log")
    end
    return chat
end

function wait_message(after, timeout, ...)
    local ti = ResetTimeout()
    local messages = { ... }
    local found = false

    timeout = default(timeout, 10)
    repeat
        CheckTimeout(timeout, ti, CallerName(false), "Waiting for message '" .. after .. "' followed by", ...)
        wait(.1)
        for i = 1, #messages do
            if find_after(get_chat_messages(3), messages[i], after) then
                found = true
            end
        end
    until found
end

function open_addon(addon, base_addon, ...)
    wait_any_addons(base_addon)
    local ti = ResetTimeout()
    while not IsAddonReady(addon) do
        CheckTimeout(1, ti, CallerName(false), "Opening addon", addon)
        if not IsAddonReady(base_addon) then
            StopScript("open_addon failed", CallerName(false), "Failed opening", addon,
                "base addon missing or not ready",
                base_addon)
        end
        SafeCallback(base_addon, ...)
        wait(0.1)
    end
    while not IsAddonReady(addon) do
        CheckTimeout(1, ti, CallerName(false), "Waiting for addon ready", addon)
        wait(0.1)
    end
end

function confirm_addon(addon, ...)
    local ti = ResetTimeout()
    while IsAddonReady(addon) do
        CheckTimeout(1, ti, CallerName(false), "Confirming addon", addon)
        SafeCallback(addon, ...)
        wait(0.1)
    end
end

function talk(who, what_addon)
    what_addon = default(what_addon, "SelectString")
    repeat
        local entity = Entity.GetEntityByName(who)
        if entity then
            entity:Interact()
        end
        wait(.5)
    until IsAddonReady(what_addon)
end

function close_yes_no(accept, expected_text)
    accept = default(accept, false)
    if IsAddonReady("SelectYesno") then
        if expected_text ~= nil then
            local node = GetNodeText("SelectYesno", 1, 2)
            if node == nil or not node:upper():find(expected_text:upper()) then
                log_(LEVEL_DEBUG, _text, "Expected yesno text '" .. expected_text .. "' didnt match actual text:", node)
                return
            end
        end
        if accept then
            SafeCallback("SelectYesno", true, 0)
        else
            SafeCallback("SelectYesno", true, 1)
        end
    end
end

function close_talk(first, ...)
    local ti = ResetTimeout()
    while (first ~= nil and not any_addons_ready(first, ...)) or (first == nil and GetCharacterCondition(32)) do
        yield("/click Talk Click")
        CheckTimeout(60, ti, CallerName(false), "Finishing talking")
        wait(.1)
    end
end

function close_addon(addon)
    local ti = ResetTimeout()
    while IsAddonReady(addon) do
        CheckTimeout(1, ti, CallerName(false), "Closing addon", addon)
        SafeCallback(addon, true, -1)
        wait(0)
    end
end

function any_addons_ready(...)
    target_addons = { ... }
    for _, v in pairs(target_addons) do
        if IsAddonReady(v) then
            return v
        end
    end
    return nil
end

function wait_any_addons(...)
    local ti = ResetTimeout()
    while true do
        ready = any_addons_ready(...)
        if ready ~= nil then
            return ready
        end
        CheckTimeout(30, ti, CallerName(false), "Waiting for addons", ...)
        wait(0.1)
    end
end

function open_retainer_bell()
    OpenShop("Summoning Bell", "RetainerList")
    if IPC.AutoRetainer.AreAnyRetainersAvailableForCurrentChara() then
        repeat
            wait(1)
        until not IPC.AutoRetainer.IsBusy()
    end
    wait_any_addons("RetainerList")
end

function title_case(str)
    local title = str:gsub("(%a)([%w']*)", function(first, rest) return first:upper() .. rest:lower() end)
    return title
end

---------------------------------------------------------
-------- Character utils if char data was loaded --------
---------------------------------------------------------

function char_cannonical_name(char)
    if char == nil then
        return nil
    end
    if private_char_info == nil then
        return title_case(char)
    end
    char = char:upper()
    potential_char = {}
    for known_char, known_char_info in pairs(private_char_info) do
        known_char = known_char:upper()
        if known_char == char then
            return title_case(known_char)
        end
        if known_char:match("^" .. char .. " ") then
            return title_case(known_char)
        end
        if known_char_info.ReferenceNames ~= nil then
            for _, ref_name in pairs(known_char_info.ReferenceNames) do
                if ref_name:upper() == char then
                    return title_case(known_char)
                end
            end
        end
        if known_char:match(char) then
            table.insert(potential_char, known_char)
        end
    end
    if #potential_char == 1 then
        return title_case(potential_char[1])
    elseif #potential_char > 1 then
        log_(LEVEL_DEBUG, _text, "Ambiguous character name", char, "candidates:", table.concat(potential_char, ", "))
        return title_case(char)
    else
        log_(LEVEL_DEBUG, _text, "Unknown character name", char)
        return title_case(char)
    end
end

function get_char_info(char)
    if char == nil then
        return nil
    end
    if private_char_info == nil then
        return nil
    end
    char = char_cannonical_name(char)
    return private_char_info[char]
end

function char_homeworld(char)
    local char_info = get_char_info(char)
    if char_info == nil then
        return nil
    end
    return char_info.Homeworld
end

function change_character(char, world, max_time)
    max_time = default(max_time, 10 * 60)
    local ti = ResetTimeout()
    char = char_cannonical_name(char)
    world = title_case(default(world, char_homeworld(char)))

    local target = string.format("%s@%s", char, world)

    log_(LEVEL_DEBUG, _text, "Changing to character", target)

    if Player.Entity.Name == char and luminia_row_checked("World", Player.Entity.HomeWorld).Name == world then
        log_(LEVEL_DEBUG, _text, "Already on target character", target)
        return
    end

    running_lifestream = true
    IPC.Lifestream.ExecuteCommand(target)

    repeat
        CheckTimeout(max_time, ti, "ZoneTransition", "Waiting for lifestream to start")
        wait(.1)
    until IPC.Lifestream.IsBusy()

    repeat
        CheckTimeout(max_time, ti, "ZoneTransition", "Waiting for lifestream to finish")
        wait(10)
    until not IPC.Lifestream.IsBusy()
    log_(LEVEL_DEBUG, _text, "Lifestream done")

    repeat
        CheckTimeout(max_time, ti, "ZoneTransition", "Waiting for zone transition to end")
        wait(5)
    until IsPlayerAvailable()

    log_(LEVEL_DEBUG, _text, "relog done")
    wait_ready(max_time, 2)
    log_(LEVEL_DEBUG, _text, "Ready!")
end

function is_busy()
    return Player.IsBusy or GetCharacterCondition(6) or GetCharacterCondition(26) or GetCharacterCondition(27) or
        GetCharacterCondition(43) or
        GetCharacterCondition(45) or GetCharacterCondition(51) or GetCharacterCondition(32) or
        not (GetCharacterCondition(1) or GetCharacterCondition(4)) or
        (not IPC.vnavmesh.IsReady()) or IPC.vnavmesh.PathfindInProgress() or IPC.vnavmesh.IsRunning()
end

function wait_ready(max_wait, n_ready, stationary)
    stationary = default(stationary, true)
    n_ready = default(n_ready, 5)
    local ready_count = 0
    local ti = nil
    local p = Entity.Player.Position
    if max_wait ~= nil then
        ti = ResetTimeout()
    end
    repeat
        if ti ~= nil then
            CheckTimeout(max_wait, ti, CallerName(), "wait_ready timed out with ready count", ready_count, "and target",
                n_ready)
        end
        wait(1)
        if is_busy() or (stationary and Vector3.Distance(p, Entity.Player.Position) > 1) then
            p = Entity.Player.Position
            ready_count = 0
        else
            ready_count = ready_count + 1
        end
    until ready_count >= n_ready
end

function luminia_row_checked(table, id)
    local sheet = Excel.GetSheet(table)
    if sheet == nil then
        StopScript("Unknown sheet", CallerName(false), "sheet not found for", table)
    end
    local row = sheet:GetRow(id)
    if row == nil then
        StopScript("Unknown id", CallerName(false), "Id not found in excel data", table, id)
    end
    return row
end

function atk_data_checked(addon, index)
    local w = Addons.GetAddon(addon)
    if not (w.Exists and w.Ready) then
        StopScript("No addon", CallerName(false), "addon", addon, "not ready")
    end
    local r = w:GetAtkValue(index)
    if r == nil then
        StopScript("Bad atk index", CallerName(false), "addon", addon, "does not have index", index)
    end
    return r.ValueString
end

ListSelectionType = {
    ContextMenu = { name_offset = 6, click_offset = 0 },
    RetainerList = { name_offset = 3, click_offset = 2 },
    SelectString = { name_offset = 3 },
    SelectIconString = { name_offset = 3 },
}

-- 0 indexed
function list_index(base, index)
    if index == 0 then
        return base
    end
    return base * 10000 + 1000 + index
end

function GetListElement(menu, index)
    local a = Addons.GetAddon(menu)
    if not a.Ready then
        StopScript("Bad addon", CallerName(false), menu)
    end
    local n = nil
    if menu == "ContextMenu" then
        n = a:GetNode(1, 2, list_index(3, index), 2, 3)
    elseif menu == "RetainerList" then
        n = a:GetNode(1, 27, list_index(4, index), 2, 3)
    elseif menu == "SelectString" or menu == "SelectIconString" then
        n = a:GetNode(1, 3, list_index(5, index), 2)
    else
        StopScript("Unknown addon", CallerName(false), menu)
    end
    if tostring(n.NodeType):find("Text:") == nil then
        log_(LEVEL_DEBUG, _text, "Not a text node", CallerName(false), "NodeType:", n.NodeType, "NodeId:", n.Id, name,
            menu, index)
        return nil
    end
    return n.Text
end

function ListContents(menu)
    menu = default(menu, "ContextMenu")
    local offsets = ListSelectionType[menu]
    wait_any_addons(menu)
    local list_items = {}
    for i = 0, 21 do
        entry = GetListElement(menu, i)
        if entry == nil then break end
        if entry ~= "" then
            table.insert(list_items, entry)
        end
    end
    return list_items
end

function SelectInList(name, menu, partial_ok)
    partial_ok = default(partial_ok, false)
    local string = name
    local click
    menu = default(menu, "ContextMenu")
    local offsets = ListSelectionType[menu]
    ::Retry::
    wait_any_addons(menu)
    if string then
        for i = 0, 21 do
            local entry = GetListElement(menu, i)
            if entry == nil then break end
            log_(LEVEL_DEBUG, _text, "List item", entry)
            local match = entry:upper() == string:upper()
            if not match and partial_ok then
                match = entry:upper():find(string:upper())
            end
            if match then
                click = i
                break
            end
        end
        if click then
            if offsets.click_offset ~= nil then
                SafeCallback(menu, true, offsets.click_offset, click)
            else
                SafeCallback(menu, true, click)
            end
            if string == "Second Tier" then
                string = name
                click = nil
                menu = "AddonContextSub"
                yield("/wait 0.1")
                goto Retry
            end
        elseif string ~= "Second Tier" then
            string = "Second Tier"
            goto Retry
        end
    end
    if click then return true else return false end
end

function list_contains(table, element)
    if table == nil then
        -- A non-existant table does not contain anything
        -- This abstraction allows not initializing if there is no items in some uses
        return false
    end
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

function SafeCallback(addon, update, ...)
    pause_pyes()
    local callback_table = table.pack(...)
    if type(addon) ~= "string" then
        StopScript("addonname must be a string")
    end
    if type(update) == "boolean" then
        update = tostring(update)
    else
        StopScript("update must be a bool")
    end

    local call_command = "/callback " .. addon .. " " .. update
    for i = 1, callback_table.n do
        local value = callback_table[i]
        if type(value) == "number" then
            call_command = call_command .. " " .. tostring(value)
        else
            StopScript("Callbacks have to use numbers!")
        end
    end
    if IsAddonReady(addon) then
        yield(call_command)
    end
    resume_pyes()
end

function bool_to_string(state, true_string, false_string)
    true_string = default(true_string, "true")
    false_string = default(false_string, "false")
    if type(state) == "boolean" then
        if state then
            return true_string
        else
            return false_string
        end
    else
        StopScript("state must be a bool")
    end
end

--------------------
-- Error Handling --
--------------------

function require_plugins(plugins)
    if #plugins == 0 then
        return
    end
    for p in luanet.each(Svc.PluginInterface.InstalledPlugins) do
        for i, v in pairs(plugins) do
            if p.IsLoaded and p.InternalName == v then
                table.remove(plugins, i)
                if #plugins == 0 then
                    return
                end
                break
            end
        end
    end
    if #plugins > 0 then
        StopScript("Missing required plugins", CallerName(false), "Missing plugins:", table.concat(plugins, ", "))
    end
end

function StopScript(message, caller, ...)
    caller = default(caller, CallerName())
    log("Fatal error " .. message .. " in " .. caller .. ": ", ...)
    if default(running_questy, false) then
        yield("/qst stop")
    end
    if default(running_lifestream, false) then
        IPC.Lifestream.Abort()
    end
    if default(running_visland, false) then
        IPC.visland.StopRoute()
    end
    if default(running_vnavmesh, false) or default(running_visland, false) or default(running_lifestream, false) or default(running_questy, false) then
        IPC.vnavmesh.Stop()
    end
    luanet.error(_text(message, ...))
end

function CallerName(string)
    string = default(string, true)
    return debug_info_tostring(debug.getinfo(3), string)
end

function FunctionInfo(string)
    string = default(string, true)
    return debug_info_tostring(debug.getinfo(2), string)
end

function debug_info_tostring(debuginfo, always_string)
    string = default(string, true)
    local caller = debuginfo.name
    if caller == nil and not always_string then
        return nil
    end
    local file = debuginfo.short_src:gsub('.*\\', '') .. ":" .. debuginfo.currentline
    return tostring(caller) .. "(" .. file .. ")"
end

function caller_test()
    test2()
end

function test2()
    log(CallerName())
end

--------------------
--- Chat Logging ---
--------------------

LEVEL_VERBOSE = 9
LEVEL_DEBUG = 7
LEVEL_INFO = 5
LEVEL_ERROR = 3
LEVEL_CRITICAL = 1

debug_level = default(debug_level, LEVEL_ERROR)

function log_(level, formatter, ...)
    local msg = formatter(...)
    local msg_tagged = SCRIPT_TAG .. " " .. msg
    if LEVEL_INFO >= level then
        Dalamud.Log(msg_tagged)
    elseif LEVEL_DEBUG >= level then
        Dalamud.LogDebug(msg_tagged)
    elseif LEVEL_VERBOSE >= level then
        Dalamud.LogVerbose(msg_tagged)
    end
    if debug_level >= level then
        Svc.Chat:Print(msg)
    end
end

function _text(first, ...)
    local rest = table.pack(...)
    local message = tostring(first)
    for i = 1, rest.n do
        message = message .. ' ' .. tostring(rest[i])
    end
    return message
end

function log(...)
    log_(LEVEL_CRITICAL, _text, ...)
end

function _count(list, c, type)
    local msg = default(type, 'collection') .. ':'
    for i = 0, c - 1 do
        msg = msg .. '\n' .. tostring(i) .. ': ' .. tostring(list[i])
    end
    return msg
end

function _iterable(it)
    local msg = '---' .. tostring(it) .. '---'
    for i in luanet.each(it) do
        msg = msg .. '\n' .. tostring(i)
    end
    return msg .. '\n--- end ---'
end

function _list(list)
    local c = list.Count
    if c == nil then
        return "Not a list (No Count property): " .. tostring(list)
    else
        return _count(list, c, 'list')
    end
end

function _array(array)
    local c = array.Length
    if c == nil then
        return "Not an array (No Length property): " .. tostring(array)
    else
        return _count(array, c, 'array')
    end
end

function _table(list)
    local msg = 'table:'
    for i, v in pairs(list) do
        msg = msg .. '\n' .. tostring(i) .. ': ' .. tostring(v)
    end
    return msg
end

-----------------------
-- Timeout Functions --
-----------------------


function ResetTimeout()
    return os.clock()
end

function CheckTimeout(max_duration, wait_info, context, ...)
    if wait_info == nil then
        StopScript("wait_info is nil", CallerName(false), "Must be initialized with ResetTimeout()", "context:",
            default(context, CallerName(false)), ...)
    end
    if max_duration == nil then
        StopScript("max_duration is nil", CallerName(false), "Must be provided", "context:",
            default(context, CallerName(false)), ...)
    end
    if os.clock() > wait_info + max_duration then
        StopScript("Max duration reached", default(context, CallerName(false)), ...)
    end
end

function AlertTimeout(max_duration, wait_info, caller_name, ...)
    wait_info = default(wait_info, global_wait_info)
    if wait_info == global_wait_info and CallerName() ~= wait_info.current_timed_function then
        wait_info = ResetTimeout()
    end
    max_duration = default(max_duration, 30)
    if os.clock() > wait_info.current_timed_start + max_duration then
        log("Max duration reached", default(caller_name, CallerName(false)), ...)
        return true
    end
    return false
end
--[[
================================================================================
  END IMPORT: utils.lua
================================================================================
]]

--[[
================================================================================
  BEGIN IMPORT: luasharp.lua
================================================================================
]]

-- Skipped import: utils.lua
import "System.Linq"
import "System"


function await(o, max_wait)
    max_wait = default(max_wait, 30)
    local ti = ResetTimeout()
    while not o.IsCompleted do
        CheckTimeout(max_wait, ti, CallerName(false), "Waiting for task to complete")
        wait(0.1)
    end
    return o.Result
end

function make_list(content_type, ...)
    local t = Type.GetType(("System.Collections.Generic.List`1[%s]"):format(content_type))
    log_(LEVEL_VERBOSE, _text, "Making list of type", t)
    local l = Activator.CreateInstance(t)
    log_(LEVEL_VERBOSE, _text, "List made", l)
    local args = table.pack(...)
    for i = 1, args.n do
        l:Add(args[i])
    end
    log_(LEVEL_VERBOSE, _text, "Initial items added")
    log_(LEVEL_VERBOSE, _iterable, l)
    return l
end

function make_set(content_type, ...)
    local t = Type.GetType(("System.Collections.Generic.HashSet`1[%s]"):format(content_type))
    log_(LEVEL_VERBOSE, _text, "Making set of type", t)
    local l = Activator.CreateInstance(t)
    log_(LEVEL_VERBOSE, _text, "Set made", l)
    local args = table.pack(...)
    for i = 1, args.n do
        l:Add(args[i])
    end
    log_(LEVEL_VERBOSE, _text, "Initial items added")
    log_(LEVEL_VERBOSE, _iterable, l)
    return l
end

function make_instance_args(ctype, args_table)
    local Activator_ty = luanet.ctype(Activator)
    local CreateInstance = get_method_overload(Activator_ty, "CreateInstance",
        { Type.GetType("System.Type"), Type.GetType("System.Object[]") })

    local args = luanet.make_array(Object, args_table)
    local arg_array = luanet.make_array(Object, { ctype, args })
    local instance = CreateInstance:Invoke(nil, arg_array)
    if arg_array == instance then
        log_(LEVEL_CRITICAL, _array, args)
        log_(LEVEL_CRITICAL, _array, arg_array)
        StopScript("Failed to make instance", CallerName(false), "type:", ctype, "args:", args)
    end
    return instance
end

function deref_pointer(ptr, ctype)
    if Unsafe == nil then
        _, Unsafe = load_type("System.Runtime.CompilerServices.Unsafe", "System.Runtime")
    end
    local AsRef = get_generic_method(Unsafe, "AsRef", { ctype })
    if AsRef == nil or AsRef.Invoke == nil then
        StopScript("Failed to get AsRef method", CallerName(false), "ctype:", ctype)
    end
    local arg = luanet.make_array(Object, { ptr })
    local ref = AsRef:Invoke(nil, arg)
    if ref == arg then
        StopScript("Failed to deref pointer", CallerName(false), "pointer:", ptr, "ctype:", ctype)
    end
    return ref
end

function cs_instance(type, assembly)
    local T, T_ty = load_type(type, assembly)

    local instance = T.Instance()
    return deref_pointer(instance, T_ty)
end

function assembly_name(inputstr)
    for str in string.gmatch(inputstr, "[^%.]+") do
        return str
    end
end

function load_type(type_path, assembly)
    assembly = default(assembly, assembly_name(type_path))
    log_(LEVEL_VERBOSE, _text, "Loading assembly", assembly)
    luanet.load_assembly(assembly)
    log_(LEVEL_VERBOSE, _text, "Wrapping type", type_path)
    local type_var = luanet.import_type(type_path)
    log_(LEVEL_VERBOSE, _text, "Wrapped type", type_var)
    return type_var, luanet.ctype(type_var)
end

function load_type_(type_path, assembly)
    assembly = default(assembly, assembly_name(type_path))
    local assembly_handle = nil
    for i in luanet.each(AppDomain.CurrentDomain:GetAssemblies()) do
        if i.FullName:match(assembly .. ",") then
            if assembly_handle ~= nil then
                StopScript("Multiple assemblies found matching name", CallerName(false), "assembly:", assembly)
            end
            assembly_handle = i
        end
    end
    if assembly_handle == nil then
        StopScript("Assembly not found", CallerName(false), "assembly:", assembly)
    end
    local type_found = nil
    for i in luanet.each(assembly_handle.ExportedTypes) do
        if i.FullName == type_path then
            if type_found ~= nil then
                StopScript("Multiple types found matching name", CallerName(false), "type_path:", type_path)
            end
            type_found = i
        end
    end
    if type_found == nil then
        StopScript("Type not found", CallerName(false), "type_path:", type_path)
    end
    return type_found
end

function get_method(type, method_name, binding)
    local method = type:GetMethod(method_name, make_binding_flags(binding))
    if method == nil then
        StopScript("Method not found", CallerName(false), "type:", type, "method_name:", method_name)
    end
    return method
end

function get_field(type, field_name, binding)
    local field = type:GetField(field_name, make_binding_flags(binding))
    if field == nil then
        StopScript("Field not found", CallerName(false), "type:", type, "field_name:", field_name)
    end
    return field
end

function get_property(type, property_name, binding)
    local property = type:GetProperty(property_name, make_binding_flags(binding))
    if property == nil then
        StopScript("Property not found", CallerName(false), "type:", type, "property_name:", property_name)
    end
    return property
end

function dump_object_info(object, show_what)
    log("--- info for object ---")
    log("Object:", object)
    local type = object:GetType()
    dump_type_info(type, show_what, object)
end

function dump_type_info(type, show_what, object)
    show_what = default(show_what, { properties = true, public = true, instance = true })
    if object == nil then log("--- info for type ---") end
    log("Type:", type)

    local binding_flags = make_binding_flags(show_what)
    log("BindingFlags:", binding_flags)

    if default(show_what.properties, false) then
        local props = type:GetProperties(binding_flags)
        log(props.Length, "Properties")
        for i = 0, props.Length - 1, 1 do
            log(tostring(i) .. ':', props[i].Name, '---', props[i]:GetValue(object))
        end
    end

    if default(show_what.fields, false) then
        local fields = type:GetFields(binding_flags)
        log(fields.Length, "Fields")
        for i = 0, fields.Length - 1, 1 do
            log(tostring(i) .. ':', fields[i].Name, '---', fields[i].FieldType, '---', fields[i]:GetValue(object))
        end
    end

    if default(show_what.methods, false) then
        local meth = type:GetMethods(binding_flags)
        log(meth.Length, "Methods")
        for i = 0, meth.Length - 1, 1 do
            local extra = ""
            if meth[i].IsGenericMethodDefinition then
                extra = "<" .. tostring(meth[i]:GetGenericArguments().Length) .. ">"
            end
            log(tostring(i) .. ':', meth[i].Name .. extra)
        end
    end

    if default(show_what.constructors, false) then
        local ctors = type:GetConstructors(binding_flags)
        log(ctors.Length, "Constructors")
        for i = 0, ctors.Length - 1, 1 do
            log(tostring(i) .. ':', ctors[i].Name)
        end
    end

    if default(show_what.members, false) then
        local members = type:GetMembers(binding_flags)
        log(members.Length, "Members")
        for i = 0, members.Length - 1, 1 do
            log(tostring(i) .. ':', members[i].Name)
        end
    end

    if default(show_what.nestedtypes, false) then
        local nested = type:GetNestedTypes(binding_flags)
        log(nested.Length, "NestedTypes")
        for i = 0, nested.Length - 1, 1 do
            log(tostring(i) .. ':', nested[i].Name)
        end
    end

    log("--- end info ---")
end

function make_binding_flags(bindings)
    if BindingFlags == nil then
        BindingFlags = load_type('System.Reflection.BindingFlags')
    end

    bindings = default(bindings, {})

    local flags = 0
    if default(bindings.public, true) then
        flags = flags | BindingFlags.Public.value__
    end
    if default(bindings.private, false) then
        flags = flags | BindingFlags.NonPublic.value__
    end
    if default(bindings.instance, true) then
        flags = flags | BindingFlags.Instance.value__
    end
    if default(bindings.static, false) then
        flags = flags | BindingFlags.Static.value__
    end
    return luanet.enum(BindingFlags, flags)
end

function make_calling_conventions(callingConventions)
    if CallingConventions == nil then
        CallingConventions = load_type('System.Reflection.CallingConventions')
    end

    callingConventions = default(callingConventions, {})

    local flags = 0
    if default(callingConventions.standard, false) then
        flags = flags | CallingConventions.Standard.value__
    end
    if default(callingConventions.varargs, false) then
        flags = flags | CallingConventions.VarArgs.value__
    end
    if default(callingConventions.any, false) then
        flags = flags | CallingConventions.Any.value__
    end
    if default(callingConventions.hasthis, false) then
        flags = flags | CallingConventions.HasThis.value__
    end
    if default(callingConventions.explicitthis, false) then
        flags = flags | CallingConventions.ExplicitThis.value__
    end
    return luanet.enum(CallingConventions, flags)
end

--- ########################
--- ####### Generics #######
--- ########################
function get_generic_method(targetType, method_name, genericTypes)
    local genericArgsArr = luanet.make_array(Type, genericTypes)
    local methods = targetType:GetMethods()
    for i = 0, methods.Length - 1 do
        local m = methods[i]
        if m.Name == method_name and m.IsGenericMethodDefinition and m:GetGenericArguments().Length == genericArgsArr.Length then
            return m:MakeGenericMethod(genericArgsArr)
        end
    end
    StopScript("No generic method found", CallerName(false), "No matching generic method found for", method_name, "with",
        #genericTypes, "generic args")
end

function get_method_overload(targetType, method_name, paramTypes)
    local methods = targetType:GetMethods()
    for i = 0, methods.Length - 1 do
        local m = methods[i]
        if m.Name == method_name then
            local params = m:GetParameters()
            if params.Length == #paramTypes then
                local match = true
                for j = 0, params.Length - 1 do
                    if params[j].ParameterType ~= paramTypes[j + 1] then
                        match = false
                        break
                    end
                end
                if match then
                    return m
                end
            end
        end
    end
    StopScript("No method overload found", CallerName(false), "No matching overload found for", method_name, "with",
        #paramTypes, "parameters")
end
--[[
================================================================================
  END IMPORT: luasharp.lua
================================================================================
]]

--[[
================================================================================
  BEGIN IMPORT: hard_ipc.lua
================================================================================
]]

-- Skipped import: utils.lua
-- Skipped import: luasharp.lua
import "System"

ipc_cache_actions = {}
ipc_cache_functions = {}

shared_data_cache = {}

function require_ipc(ipc_signature, result_type, arg_types)
    if ipc_cache_actions[ipc_signature] ~= nil or ipc_cache_functions[ipc_signature] ~= nil then
        log_(LEVEL_VERBOSE, _text, "IPC already loaded", ipc_signature)
        return
    end
    arg_types = default(arg_types, {})
    arg_types[#arg_types + 1] = default(result_type, 'System.Object')
    for i, v in pairs(arg_types) do
        if type(v) ~= 'string' then
            StopScript("Bad argument", CallerName(false), "argument types shound be strings")
        end
        arg_types[i] = Type.GetType(v)
    end
    local method = get_generic_method(Svc.PluginInterface:GetType(), 'GetIpcSubscriber', arg_types)
    if method.Invoke == nil then
        StopScript("GetIpcSubscriber not found", CallerName(false), "No IPC subscriber for", #arg_types, "arguments")
    end
    local sig = luanet.make_array(Object, { ipc_signature })
    local subscriber = method:Invoke(Svc.PluginInterface, sig)
    if subscriber == nil then
        StopScript("IPC not found", CallerName(false), "signature:", ipc_signature)
    end
    if result_type == nil then
        log_(LEVEL_DEBUG, _text, "loaded action IPC", ipc_signature)
        ipc_cache_actions[ipc_signature] = subscriber
    else
        log_(LEVEL_DEBUG, _text, "loaded function IPC", ipc_signature)
        ipc_cache_functions[ipc_signature] = subscriber
    end
end

function invoke_ipc(ipc_signature, ...)
    local function_subscriber = ipc_cache_functions[ipc_signature]
    local action_subscriber = ipc_cache_actions[ipc_signature]
    if function_subscriber == nil and action_subscriber == nil then
        StopScript("IPC not ready", CallerName(false), "signature:", ipc_signature, "is not loaded")
    end
    if function_subscriber ~= nil then
        local result = function_subscriber:InvokeFunc(...)
        if result == function_subscriber then
            StopScript("Function IPC failed", CallerName(false), "signature:", ipc_signature)
        end
        return result
    end
    -- otherwise its action IPC

    local result = action_subscriber:InvokeAction(...)
    if result == action_subscriber then
        StopScript("IPC failed", CallerName(false), "signature:", ipc_signature)
    end
end

function get_shared_data(tag, data_type)
    if shared_data_cache[tag] ~= nil then
        return shared_data_cache[tag]
    end
    local method = get_generic_method(Svc.PluginInterface:GetType(), 'GetData', { Type.GetType(data_type) })
    local sig = luanet.make_array(Object, { tag })
    local so = method:Invoke(Svc.PluginInterface, sig)
    if so == sig then
        return nil
    end
    shared_data_cache[tag] = so
    return so
end

function release_shared_data(tag)
    if tag == nil then
        for t, _ in pairs(shared_data_cache) do
            log_(LEVEL_VERBOSE, _text, "Releasing shared data", t)
            Svc.PluginInterface:RelinquishData(t)
        end
        shared_data_cache = {}
    else
        log_(LEVEL_VERBOSE, _text, "Releasing shared data", tag)
        Svc.PluginInterface:RelinquishData(tag)
        shared_data_cache[tag] = nil
    end
end
--[[
================================================================================
  END IMPORT: hard_ipc.lua
================================================================================
]]

--[[
================================================================================
  BEGIN IMPORT: path_helpers.lua
================================================================================
]]

-- Skipped import: utils.lua
-- Skipped import: luasharp.lua
-- Skipped import: hard_ipc.lua
import "System.Numerics"
import "System"

local WALK_THRESHOLD = 35
local FLY_THRESHOLD = 100

function TownPath(town, x, y, z, shard, dest_town, ...)
    local alt_zones = { town, dest_town, ... }
    dest_town = default(dest_town, town)
    wait_ready(10, 1)
    local current_town = luminia_row_checked("TerritoryType", Svc.ClientState.TerritoryType).PlaceName.Name
    if list_contains(alt_zones, current_town) then
        log_(LEVEL_DEBUG, _text, "Already in", current_town)
    else
        log_(LEVEL_DEBUG, _text, "Moving to", town, "from", current_town)
        repeat
            yield("/tp " .. tostring(town))
            wait(1)
        until Player.Entity.IsCasting
        ZoneTransition()
    end

    if shard ~= nil then
        local nearest_shard = closest_aethershard()
        local shard_name = luminia_row_checked("Aetheryte", nearest_shard.DataId).AethernetName.Name
        if current_town == dest_town and path_distance_to(Vector3(x, y, z)) < path_distance_to(nearest_shard.Position) then
            log_(LEVEL_DEBUG, _text, "Already nearer to", x, y, z, "than to aethernet", shard_name)
        elseif shard_name == shard then
            log_(LEVEL_DEBUG, _text, "Nearest shard is already", shard_name)
        else
            log_(LEVEL_DEBUG, _text, "Walking to shard", nearest_shard.DataId, shard_name, "to warp to", shard)
            WalkTo(nearest_shard.Position, nil, nil, 7)
            running_lifestream = true
            yield("/li " .. tostring(shard))
            ZoneTransition()
        end
    end

    WalkTo(x, y, z)
end

local aether_info = nil
local net_info = nil
function load_aether_info()
    if aether_info == nil then
        local t = os.clock()
        aether_info = {}
        net_info = {}
        local sheet = Excel.GetSheet("Aetheryte")
        for r = 0, sheet.Count - 1 do
            if os.clock() - t > 1.0 / 10.0 then
                wait(0)
                t = os.clock()
            end
            local row = sheet[r]
            if Instances.Telepo:IsAetheryteUnlocked(r) then
                if row.IsAetheryte then
                    aether_info[row.RowId] = {
                        AetherId = row.RowId,
                        Name = row.PlaceName.Name,
                        TerritoryId = row.Territory.RowId,
                        Position = Instances.Telepo:GetAetherytePosition(r)
                    }
                end
                if row.AethernetName.RowId ~= 0 then
                    net_info[row.RowId] = {
                        Group = row.AethernetGroup,
                        Name = row.AethernetName.Name,
                        TerritoryId = row.Territory.RowId,
                        Position = Instances.Telepo:GetAetherytePosition(r),
                        Invisible = row.Invisible
                    }
                end
            end
        end
    end
    return aether_info, net_info
end

function nearest_aetherite(territory_id, goal_point)
    local closest = nil
    local distance = nil
    for _, row in pairs(load_aether_info()) do
        if row.TerritoryId == territory_id then
            local d = Vector3.Distance(goal_point, row.Position)
            if closest == nil or d < distance then
                closest = row
                distance = d
            end
        end
    end

    return closest
end

function random_real(lower, upper)
    if not default(random_is_seeded, false) then
        random_is_seeded = true
        math.randomseed()
    end
    return math.random() * (upper - lower) + lower
end

function warp_near_point(spot, radius, territory_id, fly)
    fly = default(fly, false)
    if Svc.ClientState.TerritoryType ~= territory_id then
        local a = nearest_aetherite(territory_id, spot)
        if a == nil then
            StopScript("NoAetheryte", CallerName(false), "No aetherite found for", territory_id)
        end
        repeat
            Instances.Telepo:Teleport(a.AetherId, 0) -- IDK what the sub index is. if things break its probably that.
            wait(1)
        until Player.Entity.IsCasting
        ZoneTransition()
    end
    move_near_point(spot, radius, fly)
    land_and_dismount()
end

function net_near_point(spot, radius, fly)
    fly = default(fly, false)
    move_near_point(spot, radius, fly)
    land_and_dismount()
end

function move_near_point(spot, radius, fly)
    running_vnavmesh = true
    fly = default(fly, false)
    local distance = random_real(0, radius)
    local angle = random_real(0, math.pi * 2)
    local target = Vector3(spot.X + distance * math.sin(angle), spot.Y, spot.Z + distance * math.cos(angle))
    local result, fly_result
    target.Y = target.Y + 0.5
    if fly then
        log_(LEVEL_DEBUG, _text, "Looking for mesh point in range", radius, "of", target)
        fly_result = IPC.vnavmesh.NearestPoint(target, radius, radius)
    end
    log_(LEVEL_DEBUG, _text, "Looking for floor point in range", radius, "of", target)
    result = IPC.vnavmesh.PointOnFloor(target, false, radius)

    if result == nil or (fly and fly_result == nil) then
        log_(LEVEL_ERROR, _text, "No valid point found in range", radius, "of", spot, "searched from", target)
        return false
    end
    log_(LEVEL_DEBUG, _text, "Found point in area", result, fly_result)
    local path, fly_path
    if fly_result == nil or Vector3.Distance(Player.Entity.Position, result) < FLY_THRESHOLD then
        path = pathfind_with_tolerance(result, false, radius)
    end
    if fly_result ~= nil and (path == nil or path_length(path) > FLY_THRESHOLD) then
        fly_path = pathfind_with_tolerance(fly_result, true, radius)
        walk_path(fly_path, true, radius, 0.01, spot)
    else
        walk_path(path, false, radius, 0.01, spot)
    end
    return true
end

function jump_to_point(p, runup, retry)
    running_vnavmesh = true
    p = xyz_to_vec3(table.unpack(p))
    runup = default(runup, .1)
    retry = default(retry, false)
    local start_pos = Player.Entity.Position
    local last_pos = Player.Entity.Position
    local stuck = nil
    custom_path(false, { p })
    repeat
        wait(0)
        if Vector3.Distance(last_pos, Player.Entity.Position) < 0.01 then
            if stuck == nil then
                stuck = os.clock()
            elseif os.clock() - stuck > .25 then
                log("Didnt move from start pos, jumping anyway")
                break
            end
        else
            last_pos = Player.Entity.Position
            stuck = nil
        end
    until Vector3.Distance(Player.Entity.Position, start_pos) > runup or not IPC.vnavmesh.IsRunning()
    if not IPC.vnavmesh.IsRunning() then
        StopScript("Failed to jump", CallerName(false), "to point", p)
    end
    Actions.ExecuteGeneralAction(2)
    local retries = 0
    while IPC.vnavmesh.IsRunning() or Player.IsBusy do
        wait(0.1)
        if Vector3.Distance(last_pos, Player.Entity.Position) < 0.01 then
            if stuck == nil then
                stuck = os.clock()
            elseif os.clock() - stuck > .25 then
                if retry and retries < 5 then
                    log("Stuck during jump, retrying", retries + 1)
                    retries = retries + 1
                    Actions.ExecuteGeneralAction(2)
                else
                    StopScript("Stuck during jump", CallerName(false), "to point", p, "Landed at", Player.Entity
                        .Position)
                end
            end
        else
            last_pos = Player.Entity.Position
            stuck = nil
        end
    end
    if Vector3.Distance(Player.Entity.Position, p) > 3.0 then
        StopScript("Missed jump", CallerName(false), "to point", p, "Landed at", Player.Entity.Position)
    end
    custom_path(false, { p })
    while IPC.vnavmesh.IsRunning() or Player.IsBusy do
        wait(0.1)
    end
    if Vector3.Distance(Player.Entity.Position, p) > 3.0 then
        StopScript("Fell during reposition", CallerName(false), "to point", p, "Landed at", Player.Entity.Position)
    end
end

function move_to_point(p)
    running_vnavmesh = true
    p = xyz_to_vec3(table.unpack(p))
    custom_path(false, { p })
    local last_pos = Player.Entity.Position
    local stuck = nil
    while IPC.vnavmesh.IsRunning() or Player.IsBusy do
        wait(0.1)
        if Vector3.Distance(last_pos, Player.Entity.Position) < 0.01 then
            if stuck == nil then
                stuck = os.clock()
            elseif os.clock() - stuck > .25 then
                StopScript("Stuck during walk", CallerName(false), "to point", p, "Landed at", Player.Entity.Position)
            end
        else
            last_pos = Player.Entity.Position
            stuck = nil
        end
    end
end

function walk_path(path, fly, range, stop_if_stuck, ref_point)
    running_vnavmesh = true
    stop_if_stuck = default(stop_if_stuck, false)
    ref_point = default(ref_point, path[path.Count - 1])
    local ti = ResetTimeout()
    IPC.vnavmesh.MoveTo(path, fly)
    if not GetCharacterCondition(4) and (fly or path_length(path) > WALK_THRESHOLD) then
        Actions.ExecuteGeneralAction(9)
    end
    local last_pos
    while (IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()) do
        CheckTimeout(60, ti, CallerName(false), "Waiting for pathfind")
        local cur_pos = Player.Entity.Position
        if range ~= nil and Vector3.Distance(Entity.Player.Position, ref_point) <= range then
            IPC.vnavmesh.Stop()
        end
        if not fly or GetCharacterCondition(4) then
            if stop_if_stuck and Vector3.Distance(last_pos, cur_pos) < stop_if_stuck then
                log_(LEVEL_ERROR, _text, "Antistuck triggered!")
                IPC.vnavmesh.Stop()
            end
            last_pos = cur_pos
        end
        wait(0.1)
    end
end

function land_and_dismount()
    running_vnavmesh = true
    if not GetCharacterCondition(4) then
        return
    end
    if GetCharacterCondition(77) then
        local floor = IPC.vnavmesh.NearestPoint(Player.Entity.Position, 20, 20)
        IPC.vnavmesh.PathfindAndMoveTo(floor, true)
        local t = os.clock()
        while (IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()) and os.clock() - t < 2 do
            wait(.1)
        end
        IPC.vnavmesh.Stop()
    end
    while GetCharacterCondition(4) do
        Actions.ExecuteGeneralAction(23)
        wait(.1)
    end
end

function custom_path(fly, waypoints)
    running_vnavmesh = true
    local vec_waypoints = {}
    log_(LEVEL_DEBUG, _text, "Setting up")
    log_(LEVEL_DEBUG, _table, vec_waypoints)
    log_(LEVEL_DEBUG, _table, "Waypoints:", waypoints)
    for i, waypoint in pairs(waypoints) do
        if type(waypoint) == "table" then
            local x, y, z = table.unpack(waypoint)
            vec_waypoints[i] = Vector3(x, y, z)
        elseif type(waypoint) == "userdata" then -- it better be a vector3
            vec_waypoints[i] = waypoint
        else
            StopScript("Invalid waypoint type", CallerName(false), "Type:", type(waypoint))
        end
    end
    log_(LEVEL_DEBUG, _text, "Calling moveto")
    log_(LEVEL_DEBUG, _table, vec_waypoints)
    local list_waypoints = make_list("System.Numerics.Vector3", table.unpack(vec_waypoints))
    log_(LEVEL_DEBUG, _text, "List waypoints:", list_waypoints)
    log_(LEVEL_DEBUG, _list, list_waypoints)
    IPC.vnavmesh.MoveTo(list_waypoints, fly)
end

function xyz_to_vec3(x, y, z)
    if y ~= nil and z ~= nil then
        log_(LEVEL_VERBOSE, _text, "Converting coordinates to vector3", x, y, z)
        return Vector3(x, y, z)
    elseif y ~= nil or z ~= nil then
        StopScript("Invalid coordinates for WalkTo", CallerName(false), "Must provide either vec3 or x,y,z", "x:", x,
            "y:", y, "z:", z)
    else
        log_(LEVEL_VERBOSE, _text, "Assuming provided value is already a vector3:", x)
        return x
    end
end

function WalkTo(x, y, z, range)
    running_vnavmesh = true
    local pos = xyz_to_vec3(x, y, z)
    local ti = ResetTimeout()
    local p
    if range ~= nil then
        log_(LEVEL_VERBOSE, _text, "Finding path to", pos, "with range", range)
        p = pathfind_with_tolerance(pos, false, range)
    else
        log_(LEVEL_VERBOSE, _text, "Finding path to", pos)
        p = await(IPC.vnavmesh.Pathfind(Entity.Player.Position, pos, false))
    end
    if p.Count == 0 then
        StopScript("No path found", CallerName(false), "x:", x, "y:", y, "z:", z, "range:", range)
    end
    log_(LEVEL_VERBOSE, _text, "Walking to", pos, "with range", range)
    IPC.vnavmesh.MoveTo(p, false)
    while (IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()) do
        CheckTimeout(30, ti, CallerName(false), "Waiting for pathfind")
        if range ~= nil and Vector3.Distance(Entity.Player.Position, pos) <= range then
            log_(LEVEL_VERBOSE, _text, "Stopping path because within range", range, "of target")
            IPC.vnavmesh.Stop()
        end
        wait(0.1)
    end
    log_(LEVEL_VERBOSE, _text, "Arrived at", pos)
end

function pathfind_with_tolerance(vec3, fly, tolerance)
    running_vnavmesh = true
    require_ipc('vnavmesh.Nav.PathfindWithTolerance',
        'System.Threading.Tasks.Task`1[System.Collections.Generic.List`1[System.Numerics.Vector3]]',
        {
            'System.Numerics.Vector3',
            'System.Numerics.Vector3',
            'System.Boolean',
            'System.Single'
        }
    )
    return await(invoke_ipc('vnavmesh.Nav.PathfindWithTolerance', Entity.Player.Position, vec3, fly, tolerance))
end

function ZoneTransition()
    local ti = ResetTimeout()
    repeat
        CheckTimeout(30, ti, "ZoneTransition", "Waiting for zone transition to start")
        wait(0.1)
    until not Player.Entity.IsCasting
    log_(LEVEL_DEBUG, _text, "Not casting")
    repeat
        CheckTimeout(30, ti, "ZoneTransition", "Waiting for zone transition to start")
        wait(0.1)
    until not IsPlayerAvailable()
    log_(LEVEL_DEBUG, _text, "Teleport started")
    repeat
        CheckTimeout(30, ti, "ZoneTransition", "Waiting for lifestream to finish")
        wait(0.1)
    until not IPC.Lifestream.IsBusy()
    log_(LEVEL_DEBUG, _text, "Lifestream done")
    repeat
        CheckTimeout(30, ti, "ZoneTransition", "Waiting for zone transition to end")
        while IPC.vnavmesh.BuildProgress() > 0 do
            CheckTimeout(10 * 60, ti, "ZoneTransition", "Waiting for navmesh to finish building")
            wait(0.1)
        end
        wait(0.1)
    until IsPlayerAvailable()
    log_(LEVEL_DEBUG, _text, "Teleport done")
    wait_ready(30, 2)
    log_(LEVEL_DEBUG, _text, "Ready!")
end

function IsNearThing(thing, distance)
    distance = default(distance, 4)
    thing = tostring(thing)
    local entity = get_closest_entity(thing)
    return entity ~= nil and entity.Name == thing and entity.DistanceTo <= distance
end

function RunVislandRoute(route_b64, wait_message)
    running_visland = true
    local ti = ResetTimeout()
    wait_message = default(wait_message, "Running route")
    log(wait_message)
    IPC.visland.StopRoute()

    IPC.visland.StartRoute(route_b64, true)
    if not IPC.visland.IsRouteRunning() then
        StopScript("Failed to start route", CallerName(), "Is visland enabled?")
    end
    repeat
        CheckTimeout(5 * 60, ti)
        log(wait_message)
        yield("/wait 1")
    until not IPC.visland.IsRouteRunning()
end

function StartRouteToTarget()
    running_vnavmesh = true
    if not HasTarget() then
        log("No target to route to")
        return false
    end
    local ti = ResetTimeout()

    yield("/vnav movetarget")
    repeat
        wait(.1)
        CheckTimeout(30, ti)
    until PathIsRunning()
end

function RouteToTarget()
    StartRouteToTarget()
    local ti = ResetTimeout()

    while PathIsRunning() do
        CheckTimeout(5 * 60, ti)
        wait(.5)
    end
end

function RouteToObject(object_name, distance)
    local ti = ResetTimeout()
    while not IsNearThing(object_name, distance) do
        if not PathIsRunning() and GetTargetName() == object_name then
            StartRouteToTarget()
        end
        wait(.1)
        CheckTimeout(30, ti)
    end

    PathStop()
end

---@return EntityWrapper
function get_closest_entity(name, critical)
    critical = default(critical, false)
    if EntityWrapper == nil then
        EntityWrapper = load_type('SomethingNeedDoing.LuaMacro.Wrappers.EntityWrapper')
    end
    local closest = raw_closest_thing(by_name(name), direct_distance)
    if critical and closest == nil then
        StopScript("No entity found", CallerName(false), "Name:", name)
    end
    return EntityWrapper(closest)
end

function closest_aethershard(critical)
    critical = default(critical, true)
    local closest = raw_closest_thing(is_aethershard, path_dist_to_obj(Player.CanFly))
    if critical and closest == nil then
        StopScript("No aethershard found", CallerName(false))
    end
    return closest
end

---------------
--- Support ---
---------------

function raw_closest_thing(filter, distance_function)
    distance_function = default(distance_function, direct_distance)
    local closest = nil
    local distance = nil
    for i = 0, Svc.Objects.Length - 1 do
        local obj = Svc.Objects[i]
        if filter(obj) then
            local t_distance = distance_function(obj)
            if closest == nil then
                closest = obj
                distance = t_distance
            elseif t_distance < distance then
                closest = obj
                distance = t_distance
            end
        end
    end
    return closest
end

function path_distance_to(vec3, fly)
    fly = default(fly, false)
    path = await(IPC.vnavmesh.Pathfind(Entity.Player.Position, vec3, fly))
    if path.Count == 0 then -- if theres no path use the cartesian distance
        return Vector3.Distance(Entity.Player.Position, vec3)
    end
    return path_length(path)
end

function path_length(path)
    local dist = 0
    local prev_point = Entity.Player.Position
    for point in luanet.each(path) do
        dist = dist + Vector3.Distance(prev_point, point)
        prev_point = point
    end
    return dist
end

function path_dist_to_obj(fly)
    return function(obj)
        return path_distance_to(obj.Position, fly)
    end
end

function direct_distance(obj)
    return Vector3.Distance(Entity.Player.Position, obj.Position)
end

function is_alive(obj)
    return obj ~= nil and not obj.IsDead
end

function by_name(name)
    return function(obj)
        return obj ~= nil and obj.Name.TextValue == name
    end
end

function is_aethershard(obj)
    if obj == nil then
        return false
    end
    if SvcObjectsKind == nil then
        SvcObjectsKind = load_type("Dalamud.Game.ClientState.Objects.Enums.ObjectKind")
    end
    return obj.ObjectKind == SvcObjectsKind.Aetheryte
end

function xz_to_floor(X, Z)
    local position = Vector3(X, 1000, Z)
    local floor_point = IPC.vnavmesh.NearestPoint(position, 0, 2000)
    return floor_point
end

function xz_to_landable(X, Z, range)
    range = default(range, 20)
    local position = Vector3(X, 1000, Z)
    local floor_point = IPC.vnavmesh.PointOnFloor(position, false, range)
    return floor_point
end
--[[
================================================================================
  END IMPORT: path_helpers.lua
================================================================================
]]

--[[
================================================================================
  BEGIN IMPORT: inventory_buddy.lua
================================================================================
]]

-- Skipped import: utils.lua
-- Skipped import: luasharp.lua


ALL_INVENTORY = {
    InventoryType.Inventory1,
    InventoryType.Inventory2,
    InventoryType.Inventory3,
    InventoryType.Inventory4,
}

ALL_ARMORY = {
    InventoryType.ArmoryHead,
    InventoryType.ArmoryBody,
    InventoryType.ArmoryHands,
    InventoryType.ArmoryLegs,
    InventoryType.ArmoryFeets,
    InventoryType.ArmoryEar,
    InventoryType.ArmoryNeck,
    InventoryType.ArmoryWrist,
    InventoryType.ArmoryRings,
    InventoryType.ArmoryMainHand,
    InventoryType.ArmoryOffHand,
}

ALL_RETAINER = {
    InventoryType.RetainerPage1,
    InventoryType.RetainerPage2,
    InventoryType.RetainerPage3,
    InventoryType.RetainerPage4,
    InventoryType.RetainerPage5,
    InventoryType.RetainerPage6,
    InventoryType.RetainerPage7,
}

ALL_EQUIPMENT = {
    InventoryType.EquippedItems,
    InventoryType.ArmoryHead,
    InventoryType.ArmoryBody,
    InventoryType.ArmoryHands,
    InventoryType.ArmoryLegs,
    InventoryType.ArmoryFeets,
    InventoryType.ArmoryEar,
    InventoryType.ArmoryNeck,
    InventoryType.ArmoryWrist,
    InventoryType.ArmoryRings,
    InventoryType.ArmoryMainHand,
    InventoryType.ArmoryOffHand,
}

NUM_GEARSETS = 100

item_info_list = {
    -- ARR Maps
    TimewornLeatherMap = { itemId = 6688, itemName = "Timeworn Leather Map" },
    TimewornGoatskinMap = { itemId = 6689, itemName = "Timeworn Goatskin Map" },
    TimewornToadskinMap = { itemId = 6690, itemName = "Timeworn Toadskin Map" },
    TimewornBoarskinMap = { itemId = 6691, itemName = "Timeworn Boarskin Map" },
    TimewornPeisteskinMap = { itemId = 6692, itemName = "Timeworn Peisteskin Map" },

    -- Heavensward Maps
    TimewornArchaeoskinMap = { itemId = 12241, itemName = "Timeworn Archaeoskin Map" },
    TimewornWyvernskinMap = { itemId = 12242, itemName = "Timeworn Wyvernskin Map" },
    TimewornDragonskinMap = { itemId = 12243, itemName = "Timeworn Dragonskin Map" },

    -- Stormblood Maps
    TimewornGaganaskinMap = { itemId = 17835, itemName = "Timeworn Gaganaskin Map" },
    TimewornGazelleskinMap = { itemId = 17836, itemName = "Timeworn Gazelleskin Map" },

    -- Shadowbringers Maps
    TimewornGliderskinMap = { itemId = 26744, itemName = "Timeworn Gliderskin Map" },
    TimewornZonureskinMap = { itemId = 26745, itemName = "Timeworn Zonureskin Map" },

    -- Endwalker Maps
    TimewornSaigaskinMap = { itemId = 36611, itemName = "Timeworn Saigaskin Map" },
    TimewornKumbhiraskinMap = { itemId = 36612, itemName = "Timeworn Kumbhiraskin Map" },
    TimewornOphiotauroskinMap = { itemId = 39591, itemName = "Timeworn Ophiotauroskin Map" },

    -- Dawntrail Maps
    TimewornLoboskinMap = { itemId = 43556, itemName = "Timeworn Loboskin Map" },
    TimewornBraaxskinMap = { itemId = 43557, itemName = "Timeworn Br'aaxskin Map" },


    -- Raid Utils
    Moqueca = { itemId = 44178, recipeId = 35926, itemName = "Moqueca" },
    Grade2GemdraughtofDexterity = { itemId = 44163, recipeId = 35919, itemName = "Grade 2 Gemdraught of Dexterity" },
    Grade2GemdraughtofIntelligence = { itemId = 44165, recipeId = 35921, itemName = "Grade 2 Gemdraught of Intelligence" },

    SquadronSpiritbondingManual = { itemId = 14951, buffId = 1083, itemName = "Squadron Spiritbonding Manual" },
    SuperiorSpiritbondPotion = { itemId = 27960, buffId = 49, itemName = "Superior Spiritbond Potion" }, --This is just medicated



    -- precrafts:
    SanctifiedWater = { itemId = 44051, recipeId = 5661, itemName = "Sanctified Water" },
    CoconutMilk = { itemId = 36082, recipeId = 5287, itemName = "Coconut Milk" },
    TuraliCornOil = { itemId = 43976, recipeId = 5590, itemName = "Turali Corn Oil" },



    -- Hunt bills
    EliteMarkBill = { itemId = 2001362, itemName = "Elite Mark Bill" },
    EliteClanMarkBill = { itemId = 2001703, itemName = "Elite Clan Mark Bill" },
    EliteVeteranClanMarkBill = { itemId = 2002116, itemName = "Elite Veteran Clan Mark Bill" },
    EliteClanNutsyMarkBill = { itemId = 2002631, itemName = "Elite Clan Nutsy Mark Bill" },
    EliteGuildshipMarkBill = { itemId = 2003093, itemName = "Elite Guildship Mark Bill" },
    EliteDawnHuntBill = { itemId = 2003512, itemName = "Elite Dawn Hunt Bill" },
}



function normalize_item_name(name)
    return name:gsub("%W", "")
end

function get_item_name_from_id(id)
    return luminia_row_checked("item", id).Name
end

function get_item_info(item_name)
    local item_info = item_info_list[normalize_item_name(item_name)]
    if item_info == nil then
        StopScript("No information for item", item_name)
    end
    return item_info
end

function get_item_info_by_id(item_id)
    for _, item_info in pairs(item_info_list) do
        if item_info.itemId == item_id then
            return item_info
        end
    end
end

function venture_count()
    return Inventory.GetItemCount(21072)
end

function equip_gearset(gearset_name, update_after)
    update_after = default(update_after, false)
    local ti = ResetTimeout()
    for gs in luanet.each(Player.Gearsets) do
        if gs.Name == gearset_name then
            repeat
                CheckTimeout(10, ti, CallerName(false), "Couldnt equip gearset:", gearset_name)
                gs:Equip()
                wait_ready(10, 1)
            until Player.Gearset.Name == gearset_name
            log_(LEVEL_INFO, _text, "Gearset", gearset_name, "equipped")
            if update_after then
                Player.Gearset:Update()
            end
            return true
        end
    end
    log_(LEVEL_ERROR, _text, "Gearset", gearset_name, "not found")
    return false
end

function equip_classjob(classjob_abrev, update_after)
    update_after = default(update_after, false)
    classjob_abrev = classjob_abrev:upper()
    local ti = ResetTimeout()
    for gs in luanet.each(Player.Gearsets) do
        if luminia_row_checked("ClassJob", gs.ClassJob).Abbreviation == classjob_abrev then
            gearset_name = gs.Name
            log_(LEVEL_INFO, _text, "Equipping gearset", gearset_name, "for class/job", classjob_abrev)
            repeat
                CheckTimeout(10, ti, CallerName(false), "Couldnt equip gearset:", gearset_name)
                gs:Equip()
                wait(0.3)
                yesno = Addons.GetAddon("SelectYesno")
                wait(0.3)
                if yesno.Ready then
                    close_yes_no(true,
                        "registered to this gear set could not be found in your Armoury Chest. Replace it with")
                end
                wait(0.4)
            until Player.Gearset.Name == gearset_name
            wait_ready(10, 1)
            log_(LEVEL_VERBOSE, _text, "Gearset", gearset_name, "equipped")
            if update_after then
                Player.Gearset:Update()
            end
            return true
        end
    end
    log_(LEVEL_ERROR, _text, "No gearset found for class/job", classjob_abrev)
    return false
end

function move_to_inventory(item)
    for _, destination in pairs(ALL_INVENTORIES) do
        if Inventory.GetInventoryContainer(destination).FreeSlots > 0 then
            item:MoveItemSlot(destination)
            return true
        end
    end
    return false
end

function item_id_range(lowest_item_id, highest_item_id, in_range)
    highest_item_id = default(highest_item_id, lowest_item_id)
    lowest_item_id = default(lowest_item_id, 0)
    highest_item_id = default(highest_item_id, 999999999)
    in_range = default(in_range, true)
    return function(target_item)
        if lowest_item_id <= target_item.ItemId and target_item.ItemId <= highest_item_id then
            return in_range
        end
        return not in_range
    end
end

RaptureGearsetModule_GearsetItemIndex = load_type(
    "FFXIVClientStructs.FFXIV.Client.UI.Misc.RaptureGearsetModule+GearsetItemIndex")

function resolve_gearset_ids(number)
    RaptureGearsetModule = cs_instance("FFXIVClientStructs.FFXIV.Client.UI.Misc.RaptureGearsetModule")
    if not RaptureGearsetModule:IsValidGearset(number) then
        return nil
    end
    if RaptureGearsetModule_GearsetEntry == nil then
        _, RaptureGearsetModule_GearsetEntry = load_type(
            "FFXIVClientStructs.FFXIV.Client.UI.Misc.RaptureGearsetModule+GearsetEntry")
    end
    local gearset_ptr = RaptureGearsetModule:GetGearset(number)
    if gearset_ptr == nil then
        return nil
    end
    local gs = deref_pointer(gearset_ptr, RaptureGearsetModule_GearsetEntry)
    function _resolve_gearset_ids__get_item_id(slot)
        local itemId = gs:GetItem(slot).ItemId
        if itemId == 0 then
            return nil
        end
        return itemId
    end

    return {
        MainHand = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.MainHand),
        OffHand = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.OffHand),
        Head = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.Head),
        Body = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.Body),
        Hands = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.Hands),
        Legs = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.Legs),
        Feet = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.Feet),
        Ears = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.Ears),
        Neck = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.Neck),
        Wrists = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.Wrists),
        LeftRing = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.RingLeft),
        RightRing = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex.RingRight),
    }
end

function resolve_gearset_items(number)
    local gearset_ids = resolve_gearset_ids(number)
    if gearset_ids == nil then
        return nil
    end
    local items = {}
    for slot, _ in pairs(gearset_ids) do
        items[slot] = nil
    end
    for _, container in pairs(ALL_EQUIPMENT) do
        local inv = Inventory.GetInventoryContainer(container)
        for item in luanet.each(inv.Items) do
            local itemId = item.ItemId
            if item.IsHighQuality then
                itemId = itemId + 1000000
            end
            for slot, gid in pairs(gearset_ids) do
                if itemId == gid then
                    gearset_ids[slot] = nil
                    items[slot] = item
                    break
                end
            end
        end
    end
    for slot, gid in pairs(gearset_ids) do
        if gid ~= nil then
            log_(LEVEL_ERROR, _text, "Did not find item for slot", slot, "with id", gid, "in gearset", number)
        end
    end
    return items
end

function item_in_gearset(in_gearset)
    in_gearset = default(in_gearset, true)
    return function(item)
        for idx = 0, NUM_GEARSETS - 1 do
            gs = resolve_gearset_items(idx)
            if gs ~= nil then
                for _, gsi in pairs(gs) do
                    if gsi.ItemId == item.ItemId
                        and gsi.Slot == item.Slot
                        and gsi.Container == item.Container
                        and gsi.IsHighQuality == item.IsHighQuality
                    then
                        return in_gearset
                    end
                end
            end
        end
        return not in_gearset
    end
end

function move_items(source_inv, dest_inv, pred)
    if type(source_inv) ~= "table" then
        source_inv = { source_inv }
    end
    if type(dest_inv) ~= "table" then
        dest_inv = { dest_inv }
    end
    local source_idx = 1
    local dest_idx = 1
    local destinv = nil
    while source_idx <= #source_inv do
        local sourceinv = Inventory.GetInventoryContainer(source_inv[source_idx])
        if sourceinv == nil then
            StopScript("No inventory", CallerName(false), source_inv[source_idx])
        else
            destinv = Inventory.GetInventoryContainer(dest_inv[dest_idx])
            if destinv == nil then
                StopScript("No inventory", CallerName(false), dest_inv[dest_idx])
            end
            for item in luanet.each(sourceinv.Items) do
                if pred(item) then
                    local need_move = true
                    while dest_idx <= #dest_inv and need_move do
                        if destinv.FreeSlots > 0 then
                            log("Moving", item.ItemId, "from", source_inv[source_idx], "to", dest_inv[dest_idx])
                            item:MoveItemSlot(dest_inv[dest_idx])
                            need_move = false
                            wait(0)
                        else
                            log_(LEVEL_INFO, _text, "No space to move item to", dest_inv[dest_idx])
                            dest_idx = dest_idx + 1
                            if dest_idx <= #dest_inv then
                                destinv = Inventory.GetInventoryContainer(dest_inv[dest_idx])
                                if destinv == nil then
                                    StopScript("No inventory", CallerName(false), dest_inv[dest_idx])
                                end
                            end
                        end
                    end
                    if need_move then
                        return false -- found an item to move with no space available
                    end
                end
            end
        end
        source_idx = source_idx + 1
    end
    return true -- all items if any were able to be moved
end

function open_map(map_name, partial_ok)
    partial_ok = default(partial_ok, false)
    local ready = false
    repeat
        local addon = Addons.GetAddon("SelectIconString")
        if addon.Ready then
            title = addon:GetAtkValue(0)
            if title ~= nil then
                title = title.ValueString
            end
            if title == "Decipher" then
                ready = true
            else
                log_(LEVEL_ERROR, _text, "SelectIconString found with unexpected title:", title)
                close_addon("SelectIconString")
            end
        end
        if not ready then
            Actions.ExecuteGeneralAction(19)
            wait(0.5)
        end
    until ready
    if not SelectInList(map_name, "SelectIconString", partial_ok) then
        log_(LEVEL_ERROR, _text, "Map", map_name, "not found in map list")
        return false
    end
    wait_any_addons("SelectYesno")
    close_yes_no(true, map_name)
    wait_ready(10, 1)
end

function collect_reward_mail()
    if not Addons.GetAddon("LetterList").Ready then
        StopScript("LetterList addon not ready")
    end
    local count = tonumber(Addons.GetAddon("LetterList"):GetNode(1, 22, 23).Text:match("(.-)/"))
    repeat
        open_addon("LetterViewer", "LetterList", true, 0, 0)
        SafeCallback("LetterViewer", true, 1)
        repeat wait(0) until Addons.GetAddon("LetterViewer"):GetNode(1, 32, 2, 3).IsVisible
        repeat wait(0) until not Addons.GetAddon("LetterViewer"):GetNode(1, 32, 2, 3).IsVisible
        wait(.1)
        SafeCallback("LetterViewer", true, 2)
        wait_any_addons("SelectYesno")
        SafeCallback("SelectYesno", true, 0)
        local l = count
        repeat
            wait(0)
            count = tonumber(Addons.GetAddon("LetterList"):GetNode(1, 22, 23).Text:match("(.-)/"))
        until l ~= count
        wait(.1)
    until count == 0
    close_addon("LetterList")
end
--[[
================================================================================
  END IMPORT: inventory_buddy.lua
================================================================================
]]



-- Cool NPCs
-- Researchingway - tools
-- Orbitingway - gamba
-- Summoning Bell - summoning bell...
-- Mesouaidonque - da goods!

local WALK_THRESHOLD = 100
local RETURN_TO_SPOT = true
local RETURN_RADIUS = 3
local start_spot = Player.Entity.Position
local GAMBA_TIME = 8000
local PROCESS_RETAINERS = true


function ice_only_mission(s)
    local ICE_SETMISSION = 'ICE.OnlyMissions'
    require_ipc(ICE_SETMISSION, nil, { 'System.Collections.Generic.HashSet`1[System.UInt32]' })
    invoke_ipc(ICE_SETMISSION, s)
end

function ice_enable()
    local ICE_ENABLE = 'ICE.Enable'
    require_ipc(ICE_ENABLE)
    invoke_ipc(ICE_ENABLE)
end

function ice_disable()
    local ICE_DISABLE = 'ICE.Disable'
    require_ipc(ICE_DISABLE)
    invoke_ipc(ICE_DISABLE)
end

function ice_current_state()
    local ICE_CURRENTSTATE = 'ICE.CurrentState'
    require_ipc(ICE_CURRENTSTATE, 'System.String')
    return invoke_ipc(ICE_CURRENTSTATE)
end

function ice_is_running()
    local ICE_ISRUNNING = 'ICE.IsRunning'
    require_ipc(ICE_ISRUNNING, 'System.Boolean')
    return invoke_ipc(ICE_ISRUNNING)
end

function ice_change_bool(name, value)
    local ICE_CHANGEBOOL = 'ICE.ChangeSetting'
    require_ipc(ICE_CHANGEBOOL, nil, { 'System.String', 'System.Boolean' })
    invoke_ipc(ICE_CHANGEBOOL, name, value)
end

function ice_change_number(name, value)
    local ICE_CHANGENUM = 'ICE.ChangeSettingAmount'
    require_ipc(ICE_CHANGENUM, nil, { 'System.String', 'System.UInt32' })
    invoke_ipc(ICE_CHANGENUM, name, value)
end

--[[
    Expected settings:
        OnlyGrabMission: bool
        StopAfterCurrent: bool
        XPRelicGrind: bool

        StopOnceHitCosmoCredits: bool
        CosmoCreditsCap: number

        StopOnceHitLunarCredits: bool
        LunarCreditsCap: number
--]]
function ice_setting(name, value)
    if type(name) ~= "string" then
        StopScript("Bad setting name type", CallerName(false), "Settings names are strings, not", type(name), name)
    end
    if type(value) == "boolean" then
        log_(LEVEL_DEBUG, _text, "Setting boolean", name, "to", value)
        ice_change_bool(name, value)
    elseif type(value) == "number" then
        log_(LEVEL_DEBUG, _text, "Setting number", name, "to", value)
        ice_change_number(name, value)
    else
        StopScript("Bad setting type", CallerName(false), "Unexpected settings type", type(value), value)
    end
end

function start_ice_once()
    if ice_is_running() then
        return false
    end
    ice_enable()
    ice_setting('StopAfterCurrent', true)
    return true
end

function set_missions(...)
    s = make_set('System.UInt32', ...)
    log_(LEVEL_DEBUG, _iterable, s)
    ice_only_mission(s)
end

function on_moon()
    return list_contains({ 1237, 1291 }, Svc.ClientState.TerritoryType)
end

function return_to_craft()
    log_(LEVEL_VERBOSE, _text, "Craft return? Is crafter:", Player.Job.IsCrafter, "Setting enabled:", RETURN_TO_SPOT)
    if RETURN_TO_SPOT and Player.Job.IsCrafter then
        move_near_point(start_spot, RETURN_RADIUS)
    end
end

function path_to_moon_thing(thing, distance)
    distance = default(distance, 3)
    if not on_moon() then
        log_(LEVEL_INFO, _text, "Must be on moon to path to moon thing")
        return false
    end
    local e = get_closest_entity(thing)
    local path = nil
    local path_len = WALK_THRESHOLD
    if e.Position ~= nil then
        path = pathfind_with_tolerance(e.Position, false, distance)
        path_len = path_length(path)
    end
    if path_len >= WALK_THRESHOLD then
        log_(LEVEL_INFO, _text, "Too far away or not found, returning to base")
        Actions.ExecuteAction(42149)
        ZoneTransition()
        e = get_closest_entity(thing, true)
        path = pathfind_with_tolerance(e.Position, false, distance)
    end
    walk_path(path, false, distance)
end

function moon_talk(who)
    path_to_moon_thing(who)
    local e = get_closest_entity(who, true)
    e:SetAsTarget()
    e:Interact()
    close_talk("SelectString", "SelectIconString", "RetainerList")
end

function report_research(class)
    moon_talk("Researchingway")
    SelectInList("Report research data.", "SelectString")
    SelectInList(class.Name, "SelectIconString", true)
    local yesno
    repeat
        yesno = Addons.GetAddon("SelectYesno")
        wait(0)
    until yesno.Exists and yesno.Ready
    if yesno:GetAtkValue(8).ValueString == "Report research data." then
        SafeCallback("SelectYesno", true, 0)
    end
    close_talk()
end

function start_gamba()
    moon_talk("Orbitingway")
    SelectInList('Draw a cosmic fortune', "SelectString", true)
    SelectInList('Yes.', "SelectString")
    repeat
        wait(1)
    until ice_current_state() == "Gambling"
    repeat
        wait(1)
    until ice_current_state() == "Idle"
    close_talk()
end

--stage1_range = 45591-45689
--stage2_range = 49009-49063

function item_is_lunar(item_id)
    return item_id_range(45591, 45689)(item_id)
        or item_id_range(49009, 49063)(item_id)
end

function move_lunar_weapons()
    move_items(ALL_INVENTORIES, InventoryType.ArmoryMainHand, item_is_lunar)
end

--[[
    Broken cause gearset.items isnt valid...
    local wep_id = nil
    log_(LEVEL_VERBOSE, _text, "Items for gearset:", gs.Name, gs.BannerIndex, gs.IsValid)
    for item in luanet.each(gs.Items) do
        log_(LEVEL_VERBOSE, _text, "--", item.ItemId, item.Container)
        if item.Container == InventoryType.ArmoryMainHand then
            wep_id = item.ItemId
        end
    end
    if wep_id == nil then
        log_(LEVEL_ERROR, _text, "Main hand weapon not in gearset. Assuming not stellar.")
        return false
    end
    log_(LEVEL_DEBUG, _text, "Mainhand item id is", wep_id)
--]]

function turnin_mission()
    open_addon("WKSMissionInfomation", "WKSHud", true, 11)
    confirm_addon("WKSMissionInfomation", true, 11)
end

function is_moon_tool_equiped()
    for item in luanet.each(Inventory.GetInventoryContainer(InventoryType.EquippedItems).Items) do
        if item_is_lunar(item.ItemId) then
            return true
        end
    end
    return false
end

function equip_some_other_job(initial_gs)
    for gs in luanet.each(Player.Gearsets) do
        if gs.ClassJob ~= initial_gs.ClassJob then
            repeat
                gs:Equip()
                wait_ready(10, 1)
            until Player.Gearset.ClassJob ~= initial_gs.ClassJob
            return true
        end
    end
    return false
end

function reapply_gearset(gs)
    local yesno = nil
    repeat
        gs:Equip()
        wait(0.3)
        yesno = Addons.GetAddon("SelectYesno")
        wait(0.3)
        if yesno.Ready then
            close_yes_no(true,
                "registered to this gear set could not be found in your Armoury Chest. Replace it with")
        end
        wait(0.4)
    until Player.Gearset.BannerIndex == gs.BannerIndex
    wait_ready(10, 1)
end

function report_research_safe()
    local initial_gs = Player.Gearset
    local initial_job = Player.Job

    local need_swap = is_moon_tool_equiped()
    if need_swap then
        if not equip_some_other_job(initial_gs) then
            StopScript("No Other Job", CallerName(false),
                "Need to change gearset to hand in tool but no gearsets for other jobs were found")
        end
    end
    report_research(initial_job)
    wait_ready(10, 1)
    if need_swap then
        move_lunar_weapons()
        wait(1)
        reapply_gearset(initial_gs)
        --Player.Gearset:Update()
    end
end

known_fissions = {
    [988] = { Setup = Vector3(404.64, 29.07, -78.85), Fish = Vector3(394.01, 27.56, -74.69), ReturnDist = 500 },
    [986] = { Setup = Vector3(207.61, 133.72, -753.43), Fish = Vector3(213.55, 133.50, -746.50), ReturnDist = 550 },
}


function moon_path_to_fish(fish)
    running_vnavmesh = true
    if Vector3.Distance(Player.Entity.Position, fish.Fish) < 2 then
        return -- already here
    end
    local path = await(IPC.vnavmesh.Pathfind(Player.Entity.Position, fish.Setup, false))
    if path_length(path) > fish.ReturnDist then
        log_(LEVEL_INFO, _text, "Too far away, returning to base")
        Actions.ExecuteAction(42149)
        ZoneTransition()
        path = await(IPC.vnavmesh.Pathfind(Player.Entity.Position, fish.Setup, false))
    end
    walk_path(path, false)
    Actions.ExecuteGeneralAction(23)
    custom_path(false, { fish.Fish })
end

function start_fisher_mission(number)
    if ice_current_state() ~= "Idle" then
        StopScript("Invalid State", CallerName(false), "ICE should be idle to initialize proplerly")
    end
    set_missions(number)

    local locs = known_fissions[number]
    if locs ~= nil then
        moon_path_to_fish(locs)
    end

    ice_setting("OnlyGrabMission", true)
    ice_setting("StopAfterCurrent", true)
    ice_setting("XPRelicGrind", false)
    ice_setting("StopOnceHitCosmoCredits", false)
    ice_setting("StopOnceHitLunarCredits", false)

    log_(LEVEL_INFO, _text, "ICE Configured, starting mission")

    ice_enable()

    while ice_current_state() ~= "ManualMode" do
        wait(1)
    end

    ice_disable()

    log_(LEVEL_INFO, _text, "ICE started mission, running AH")

    repeat
        IPC.AutoHook.DeleteAllAnonymousPresets()
        IPC.AutoHook.SetPluginState(true)
        IPC.AutoHook.CreateAndSelectAnonymousPreset(
            "AH4_H4sIAAAAAAAACq2U227bMAyGX2XgtQ3Yjk/xXRo0RYG0K5ruqtgFI9OxEFfKJLlrV+TdB/nQxDkswNC7hBS//ydF+QMmtZFT1EZPixVkH3AtcFnRpKogM6omBx6JoTYTwV/QcCmmKBh9Jqdl/XIuhdrMuaAdNO9TtzlkQTp24EFxqbh5h8x34FZfv7Gqzinfhe35bcu6k5KVFtb8CM5h49SBm81TqUiXssoh8z1vIPRvpXPIPYB30aqdyhl/oe+FFwz2EFlVxIzldIX+/rHgsgupco5VD4j9cAAIu2Mzrsvrd9J7QtGBwygaOIz7G8E1LUpemCvkjU8b0H1gYZCtNWTR5xSPufvUcUd9QMNJMNrzEx/WxcOJBX2p4n9oiqbdk171sDo4mPeoq34qseK41jN8lcoCBoG+nZEzjD8Sk6+kIPPtkE6vz8UrH1qcLOUrQVZgpfu7vOKrG3xpZjIRq4qU7v3YPcghGyVeeNToQCPd2vV+Mwq7l24v6UkufuPmVpia2xd8g1z0o3N9B+a1ojvSGlcEGYAD940JuJeCwGkJ7xuCzM7wBG8utflv3oMiTacdggtn8q1ik9/5WWyIGYXVtFaKhPmiLg+oX9brSbdHHZ9Ub061C7IwcmOfNherhaFN84Xdee+WaKK+xvI+rvHwQ/BfNVkueGkU+cxnbk7F0g1Z4LkpGy3dPGSYsDgpkmUKWwfmXJvvhdXQkD3/7APdZ38XsE21/1sHncc7KcW3GWozVE/GoyLBNHKTlI3dMMxTF0cUu0WY5vk4xsCjArZ/AT3TAGUHBwAA"
        )
        --IDK which is better cast or ahstart. ahstart
        Engines.Native.Run('/ahstart')
        --Actions.ExecuteAction(289)
        wait(0.1)
    until GetCharacterCondition(43)

    wait_ready(nil, 2)

    turnin_mission()
end

function get_relic_exp(max)
    if Addons.GetAddon("WKSToolCustomize").Ready then
        close_addon("WKSToolCustomize")
        wait(5)
    end
    max = default(max, false)
    open_addon("WKSToolCustomize", "WKSHud", true, 15)
    local addon = Addons.GetAddon("WKSToolCustomize")
    if not addon.Exists or not addon.Ready then
        StopScript("No WKS Tool", CallerName(false), "Failed to get the research screen")
    end
    local completed = true
    local EXP_COUNT = 5
    local exp_needed = {}
    for i = 1, EXP_COUNT do
        local current = tonumber(addon:GetAtkValue(80 + i).ValueString)
        local base_target = tonumber(addon:GetAtkValue(90 + i).ValueString)
        local max_target = tonumber(addon:GetAtkValue(100 + i).ValueString)
        if base_target == nil then
            break
        end
        if base_target ~= 0 then
            completed = false
        end
        if max then
            exp_needed[i] = max_target - current
        else
            exp_needed[i] = base_target - current
        end
    end
    close_addon("WKSToolCustomize")
    return exp_needed, completed
end

function get_lunar_credits()
    local addon = Addons.GetAddon("WKSHud")
    if not addon.Exists or not addon.Ready then
        StopScript("No WKS Hud", CallerName(false), "Failed to get the HUD")
    end

    return tonumber(addon:GetAtkValue(6).ValueString)
end

function do_upkeep()
    log_(LEVEL_DEBUG, _text, "Doing upkeep")
    log_(LEVEL_DEBUG, _text, "GAMBA_TIME:", GAMBA_TIME, "PROCESS_RETAINERS:", PROCESS_RETAINERS)
    if GAMBA_TIME > 0 and get_lunar_credits() >= GAMBA_TIME then
        log_(LEVEL_DEBUG, _text, "Starting gamba")
        start_gamba()
    end
    if PROCESS_RETAINERS and IPC.AutoRetainer.AreAnyRetainersAvailableForCurrentChara() then
        log_(LEVEL_DEBUG, _text, "Processing retainers")
        moon_talk("Summoning Bell")
        repeat
            wait(1)
        until not IPC.AutoRetainer.IsBusy()
        close_addon("RetainerList")
        close_talk()
    end
end

function fish_relic(max)
    log_(LEVEL_DEBUG, _text, "Fish relic, Gamba limit:", GAMBA_TIME, "Max research:", max, "Handle retainers:",
        PROCESS_RETAINERS)
    repeat
        do_upkeep()
        local exp, finished = get_relic_exp(max)
        local ready = true
        for t, need in pairs(exp) do
            if need > 0 then
                ready = false
                log_(LEVEL_INFO, _text, "Need", need, "type", t, "research")
                if t == 1 or t == 2 then
                    start_fisher_mission(986)
                elseif t == 3 or t == 4 or t == 5 then
                    start_fisher_mission(988)
                else
                    StopScript("Bad State", CallerName(false), "Unexpected research type", t)
                end
                break
            end
        end
        if ready and not finished then
            report_research_safe()
        end
    until finished and ready
end

function gather_relic(max)
    log_(LEVEL_DEBUG, _text, "Gather relic, Gamba limit:", GAMBA_TIME, "Max research:", max, "Handle retainers:",
        PROCESS_RETAINERS)
    repeat
        local finished, ready, exp = false, false, nil
        if ice_is_running() then
            wait(1)
        else
            do_upkeep()
            exp, finished = get_relic_exp(max)
            ready = true
            for t, need in pairs(exp) do
                if need > 0 then
                    ready = false
                    log_(LEVEL_INFO, _text, "Need", need, "type", t, "research")

                    ice_setting("OnlyGrabMission", false)
                    ice_setting("StopAfterCurrent", true)
                    ice_setting("XPRelicGrind", true)
                    ice_setting("StopOnceHitCosmoCredits", false)
                    ice_setting("StopOnceHitLunarCredits", false)

                    start_ice_once()
                    break
                end
            end
            if ready and not finished then
                report_research_safe()
            end
        end
    until finished and ready
end

function run_mission(relic_max, gamba_time, process_retainers)
    relic_max = default(relic_max, false)
    GAMBA_TIME = default(gamba_time, GAMBA_TIME)
    PROCESS_RETAINERS = default(process_retainers, PROCESS_RETAINERS)

    local finished, ready, exp = false, false, nil
    do_upkeep()
    exp, finished = get_relic_exp(relic_max)
    ready = true
    for t, need in pairs(exp) do
        if need > 0 then
            ready = false
            log_(LEVEL_INFO, _text, "Need", need, "type", t, "research")

            ice_setting("OnlyGrabMission", false)
            ice_setting("StopAfterCurrent", true)
            ice_setting("XPRelicGrind", true)
            ice_setting("StopOnceHitCosmoCredits", false)
            ice_setting("StopOnceHitLunarCredits", false)

            start_ice_once()
            break
        end
    end
    if ready and not finished then
        report_research_safe()
    end
end
--[[
================================================================================
  END IMPORT: moon_man.lua
================================================================================
]]


GAMBA_TIME = Config.Get("GambaLimit")
PROCESS_RETAINERS = Config.Get("HandleRetainers")
local MAX_RESEARCH = Config.Get("MaxResearch")
local JOBS_LIST = Config.Get("RelicJobs")

if Config.Get("DebugMessages") then
    debug_level = LEVEL_DEBUG
end


log_(LEVEL_INFO, _text, "Gamba limit:", GAMBA_TIME, "Max research:", MAX_RESEARCH, "Handle retainers:",
    PROCESS_RETAINERS)

function run_current_job()
    local current_job = Player.Job
    log_(LEVEL_INFO, _text, "Starting auto relic on job", current_job.Name, "(" .. current_job.Abbreviation .. ")")
    if current_job.Abbreviation == "FSH" then
        fish_relic(MAX_RESEARCH)
    elseif current_job.IsGatherer then
        gather_relic(MAX_RESEARCH)
    elseif current_job.IsCrafter then
        log_(LEVEL_ERROR, _text, "Crafters arent supported yet")                                  --craft_relic(MAX_RESEARCH)
    else
        log_(LEVEL_ERROR, _text, "Invalid job", current_job.Name, "only gatherers are supported") -- update message when crafters are supported
    end

    log_(LEVEL_INFO, _text, "Finished auto relic on job", current_job.Name, "(" .. current_job.Abbreviation .. ")")
end

if JOBS_LIST.Count == 0 then
    run_current_job()
else
    for job in luanet.each(JOBS_LIST) do
        equip_classjob(job)
        run_current_job()
    end
end
