-- Auto generated file, do not edit!
--[=====[
[[SND Metadata]]
author: Erisen
version: 1.0.0
description: >-
  Wondrous Tails Manager


  Uses Auto Duty to run duties relevant to your weekly bingo
plugin_dependencies:
- vnavmesh
- AutoDuty
- visland
plugins_to_disable:
- TextAdvance
- YesAlready
configs:
  GearsetName:
    description: Gearset name to use for duties. Leave blank to use current gear.
  DebugMessages:
    default: false
    description: Show debug logs
    type: bool

[[End Metadata]]
--]=====]
--[[
================================================================================
  BEGIN IMPORT: wt_doer.lua
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
    get_shared_data("YesAlready.StopRequests", "System.Collections.Generic.HashSet`1[System.String]"):Add("EriSND")
end

function resume_pyes()
    if pyes_pause_count == nil then
        return
    end
    pyes_pause_count = pyes_pause_count - 1
    if pyes_pause_count == 0 then
        get_shared_data("YesAlready.StopRequests", "System.Collections.Generic.HashSet`1[System.String]"):Remove(
            "EriSND")
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
            if node == nil or not node:find(expected_text) then
                log_debug("Expected yesno text '" .. expected_text .. "' didnt match actual text:", node)
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
    for known_char, _ in pairs(private_char_info) do
        known_char = known_char:upper()
        if known_char == char then
            return title_case(known_char)
        end
        if known_char:match("^" .. char .. " ") then
            return title_case(known_char)
        end
        if known_char:match(char) then
            table.insert(potential_char, known_char)
        end
    end
    if #potential_char == 1 then
        return title_case(potential_char[1])
    elseif #potential_char > 1 then
        log_debug("Ambiguous character name", char, "candidates:", table.concat(potential_char, ", "))
        return title_case(char)
    else
        log_debug("Unknown character name", char)
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

    log_debug("Changing to character", target)

    if Player.Entity.Name == char and luminia_row_checked("World", Player.Entity.HomeWorld).Name == world then
        log_debug("Already on target character", target)
        return
    end

    IPC.Lifestream.ExecuteCommand(target)

    repeat
        CheckTimeout(max_time, ti, "ZoneTransition", "Waiting for lifestream to start")
        wait(.1)
    until IPC.Lifestream.IsBusy()

    repeat
        CheckTimeout(max_time, ti, "ZoneTransition", "Waiting for lifestream to finish")
        wait(10)
    until not IPC.Lifestream.IsBusy()
    log_debug("Lifestream done")

    repeat
        CheckTimeout(max_time, ti, "ZoneTransition", "Waiting for zone transition to end")
        wait(5)
    until IsPlayerAvailable()

    log_debug("relog done")
    wait_ready(max_time, 2)
    log_debug("Ready!")
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
        log_debug("Not a text node", CallerName(false), "NodeType:", n.NodeType, "NodeId:", n.Id, name, menu, index)
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
            log_debug("List item", entry)
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
    yield("/qst stop")
    IPC.Lifestream.Abort()
    IPC.visland.StopRoute()
    IPC.vnavmesh.Stop()
    luanet.error(logify(message, ...))
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

function log_(level, logger, ...)
    if debug_level >= level then
        logger(...)
    end
end

function log_debug(...)
    log_(LEVEL_DEBUG, log, ...)
end

function log_debug_array(...)
    log_(LEVEL_DEBUG, log_array, ...)
end

function log_debug_table(...)
    log_(LEVEL_DEBUG, log_table, ...)
end

function log_debug_list(...)
    log_(LEVEL_DEBUG, log_list, ...)
end

function logify(first, ...)
    local rest = table.pack(...)
    local message = tostring(first)
    for i = 1, rest.n do
        message = message .. ' ' .. tostring(rest[i])
    end
    return message
end

function log(...)
    local msg = logify(...)
    Svc.Chat:Print(msg)
    Dalamud.Log(msg)
end

function log_count(list, c)
    for i = 0, c - 1 do
        log(tostring(i) .. ': ' .. tostring(list[i]))
    end
end

function log_iterable(it)
    log('---', it, '---')
    for i in luanet.each(it) do
        log(i)
    end
    log('--- end ---')
end

function log_list(list)
    local c = list.Count
    if c == nil then
        log("Not a list (No Count property)", list)
    else
        log_count(list, c)
    end
end

function log_array(array)
    local c = array.Length
    if c == nil then
        log("Not a array (No Length property)", array)
    else
        log_count(array, c)
    end
end

function log_table(list)
    for i, v in pairs(list) do
        log(tostring(i) .. ': ' .. tostring(v))
    end
end

-----------------------
-- Timeout Functions --
-----------------------


global_wait_info = {
    current_timed_function = nil,
    current_timed_start = 0
}

function ResetTimeout()
    global_wait_info = {
        current_timed_function = CallerName(),
        current_timed_start = os.clock()
    }
    return global_wait_info
end

function CheckTimeout(max_duration, wait_info, caller_name, ...)
    wait_info = default(wait_info, global_wait_info)
    if wait_info == global_wait_info and CallerName() ~= wait_info.current_timed_function then
        wait_info = ResetTimeout()
    end
    max_duration = default(max_duration, 30)
    if os.clock() > wait_info.current_timed_start + max_duration then
        StopScript("Max duration reached", default(caller_name, CallerName(false)), ...)
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
  BEGIN IMPORT: path_helpers.lua
================================================================================
]]

-- Skipped import: utils.lua
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
    log_(LEVEL_VERBOSE, log, "Making list of type", t)
    local l = Activator.CreateInstance(t)
    log_(LEVEL_VERBOSE, log, "List made", l)
    local args = table.pack(...)
    for i = 1, args.n do
        l:Add(args[i])
    end
    log_(LEVEL_VERBOSE, log, "Initial items added")
    log_(LEVEL_VERBOSE, log_iterable, l)
    return l
end

function make_set(content_type, ...)
    local t = Type.GetType(("System.Collections.Generic.HashSet`1[%s]"):format(content_type))
    log_(LEVEL_VERBOSE, log, "Making set of type", t)
    local l = Activator.CreateInstance(t)
    log_(LEVEL_VERBOSE, log, "Set made", l)
    local args = table.pack(...)
    for i = 1, args.n do
        l:Add(args[i])
    end
    log_(LEVEL_VERBOSE, log, "Initial items added")
    log_(LEVEL_VERBOSE, log_iterable, l)
    return l
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

function assembly_name(inputstr)
    for str in string.gmatch(inputstr, "[^%.]+") do
        return str
    end
end

function load_type(type_path, assembly)
    assembly = default(assembly, assembly_name(type_path))
    log_(LEVEL_VERBOSE, log, "Loading assembly", assembly)
    luanet.load_assembly(assembly)
    log_(LEVEL_VERBOSE, log, "Wrapping type", type_path)
    local type_var = luanet.import_type(type_path)
    log_(LEVEL_VERBOSE, log, "Wrapped type", type_var)
    return type_var, luanet.ctype(type_var)
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
            local constructed = nil
            local success, err = pcall(function()
                constructed = m:MakeGenericMethod(genericArgsArr)
            end)
            if success then
                return constructed
            else
                StopScript("Error constructing generic method", CallerName(false), err)
            end
        end
    end
    StopScript("No generic method found", CallerName(false), "No matching generic method found for", method_name, "with",
        #genericTypes, "generic args")
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
        log_(LEVEL_VERBOSE, log, "IPC already loaded", ipc_signature)
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
        log_(LEVEL_DEBUG, log, "loaded action IPC", ipc_signature)
        ipc_cache_actions[ipc_signature] = subscriber
    else
        log_(LEVEL_DEBUG, log, "loaded function IPC", ipc_signature)
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
            log_(LEVEL_VERBOSE, log, "Releasing shared data", t)
            Svc.PluginInterface:RelinquishData(t)
        end
        shared_data_cache = {}
    else
        log_(LEVEL_VERBOSE, log, "Releasing shared data", tag)
        Svc.PluginInterface:RelinquishData(tag)
        shared_data_cache[tag] = nil
    end
end
--[[
================================================================================
  END IMPORT: hard_ipc.lua
================================================================================
]]

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
        log_debug("Already in", current_town)
    else
        log_debug("Moving to", town, "from", current_town)
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
            log_debug("Already nearer to", x, y, z, "than to aethernet", shard_name)
        elseif shard_name == shard then
            log_debug("Nearest shard is already", shard_name)
        else
            log_debug("Walking to shard", nearest_shard.DataId, shard_name, "to warp to", shard)
            WalkTo(nearest_shard.Position, nil, nil, 7)
            yield("/li " .. tostring(shard))
            ZoneTransition()
        end
    end

    WalkTo(x, y, z)
end

local aether_info = nil
function load_aether_info()
    if aether_info == nil then
        local t = os.clock()
        aether_info = {}
        local sheet = Excel.GetSheet("Aetheryte")
        for r = 0, sheet.Count - 1 do
            if os.clock() - t > 1.0 / 20.0 then
                wait(0)
                t = os.clock()
            end
            local row = sheet[r]
            if row.IsAetheryte and Instances.Telepo:IsAetheryteUnlocked(r) then
                aether_info[row.RowId] = {
                    AetherId = row.RowId,
                    Name = row.PlaceName.Name,
                    TerritoryId = row.Territory.RowId,
                    Position = Instances.Telepo:GetAetherytePosition(r)
                }
            end
        end
    end
    return aether_info
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

function move_near_point(spot, radius, fly)
    fly = default(fly, false)
    local distance = random_real(0, radius)
    local angle = random_real(0, math.pi * 2)
    local target = Vector3(spot.X + distance * math.sin(angle), spot.Y, spot.Z + distance * math.cos(angle))
    local result, fly_result
    target.Y = target.Y + 0.5
    if fly then
        log_(LEVEL_DEBUG, log, "Looking for mesh point in range", radius, "of", target)
        fly_result = IPC.vnavmesh.NearestPoint(target, radius, radius)
    end
    log_(LEVEL_DEBUG, log, "Looking for floor point in range", radius, "of", target)
    result = IPC.vnavmesh.PointOnFloor(target, false, radius)

    if result == nil or (fly and fly_result == nil) then
        log_(LEVEL_ERROR, log, "No valid point found in range", radius, "of", spot, "searched from", target)
        return false
    end
    log_(LEVEL_DEBUG, log, "Found point in area", result, fly_result)
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

function walk_path(path, fly, range, stop_if_stuck, ref_point)
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
                log_(LEVEL_ERROR, log, "Antistuck triggered!")
                IPC.vnavmesh.Stop()
            end
            last_pos = cur_pos
        end
        wait(0.1)
    end
end

function land_and_dismount()
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
    local vec_waypoints = {}
    log_debug("Setting up")
    log_debug_table(vec_waypoints)
    log_debug_table(waypoints)
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
    log_debug("Calling moveto")
    log_debug_table(vec_waypoints)
    local list_waypoints = make_list("System.Numerics.Vector3", table.unpack(vec_waypoints))
    log_debug(list_waypoints)
    log_debug_list(list_waypoints)
    IPC.vnavmesh.MoveTo(list_waypoints, fly)
end

function xyz_to_vec3(x, y, z)
    if y ~= nil and z ~= nil then
        return Vector3(x, y, z)
    elseif y ~= nil or z ~= nil then
        StopScript("Invalid coordinates for WalkTo", CallerName(false), "Must provide either vec3 or x,y,z", "x:", x,
            "y:", y, "z:", z)
    else
        return x
    end
end

function WalkTo(x, y, z, range)
    local pos = xyz_to_vec3(x, y, z)
    local ti = ResetTimeout()
    local p
    if range ~= nil then
        p = pathfind_with_tolerance(pos, false, range)
    else
        p = await(IPC.vnavmesh.Pathfind(Entity.Player.Position, pos, false))
    end
    if p.Count == 0 then
        StopScript("No path found", CallerName(false), "x:", x, "y:", y, "z:", z, "range:", range)
    end
    IPC.vnavmesh.MoveTo(p, false)
    while (IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()) do
        CheckTimeout(30, ti, CallerName(false), "Waiting for pathfind")
        if range ~= nil and Vector3.Distance(Entity.Player.Position, pos) <= range then
            IPC.vnavmesh.Stop()
        end
        wait(0.1)
    end
end

function pathfind_with_tolerance(vec3, fly, tolerance)
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
    log_debug("Not casting")
    repeat
        CheckTimeout(30, ti, "ZoneTransition", "Waiting for zone transition to start")
        wait(0.1)
    until not IsPlayerAvailable()
    log_debug("Teleport started")
    repeat
        CheckTimeout(30, ti, "ZoneTransition", "Waiting for lifestream to finish")
        wait(0.1)
    until not IPC.Lifestream.IsBusy()
    log_debug("Lifestream done")
    repeat
        CheckTimeout(30, ti, "ZoneTransition", "Waiting for zone transition to end")
        while IPC.vnavmesh.BuildProgress() > 0 do
            CheckTimeout(10 * 60, ti, "ZoneTransition", "Waiting for navmesh to finish building")
            wait(0.1)
        end
        wait(0.1)
    until IsPlayerAvailable()
    log_debug("Teleport done")

    wait_ready(30, 2)
    log_debug("Ready!")
end

function IsNearThing(thing, distance)
    distance = default(distance, 4)
    thing = tostring(thing)
    local entity = get_closest_entity(thing)
    return entity ~= nil and entity.Name == thing and entity.DistanceTo <= distance
end

function RunVislandRoute(route_b64, wait_message)
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


ALL_INVENTORIES = {
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
            log_(LEVEL_INFO, log, "Gearset", gearset_name, "equipped")
            if update_after then
                Player.Gearset:Update()
            end
            return true
        end
    end
    log_(LEVEL_ERROR, log, "Gearset", gearset_name, "not found")
    return false
end

function equip_classjob(classjob_abrev, update_after)
    update_after = default(update_after, false)
    classjob_abrev = classjob_abrev:upper()
    local ti = ResetTimeout()
    for gs in luanet.each(Player.Gearsets) do
        if luminia_row_checked("ClassJob", gs.ClassJob).Abbreviation == classjob_abrev then
            gearset_name = gs.Name
            log_(LEVEL_INFO, log, "Equipping gearset", gearset_name, "for class/job", classjob_abrev)
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
            log_(LEVEL_VERBOSE, log, "Gearset", gearset_name, "equipped")
            if update_after then
                Player.Gearset:Update()
            end
            return true
        end
    end
    log_(LEVEL_ERROR, log, "No gearset found for class/job", classjob_abrev)
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

function move_items(source_inv, dest_inv, lowest_item_id, highest_item_id)
    highest_item_id = default(highest_item_id, lowest_item_id)
    lowest_item_id = default(lowest_item_id, 0)
    highest_item_id = default(highest_item_id, 999999999)
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
                if lowest_item_id <= item.ItemId and item.ItemId <= highest_item_id then
                    local need_move = true
                    while dest_idx <= #dest_inv and need_move do
                        if destinv.FreeSlots > 0 then
                            log("Moving", item.ItemId, "from", source_inv[source_idx], "to", dest_inv[dest_idx])
                            item:MoveItemSlot(dest_inv[dest_idx])
                            need_move = false
                            wait(0)
                        else
                            log_(LEVEL_INFO, log, "No space to move item to", dest_inv[dest_idx])
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
--[[
================================================================================
  END IMPORT: inventory_buddy.lua
================================================================================
]]


local fixed_members = { "Graha", "Yshtola" } -- allrounder + DPS
local support_fill = "Krile"                 -- if youre support add another DPS Graha fills the other support role
local dps_fill = "Thancred"                  -- if youre dps add tank and Graha fills healer

local duty_blacklist = {}
function reset_blacklist()
    duty_blacklist = {
        --447, -- Limitless Blue, doesnt touch the hookshots, should work now with the path
        577, -- P1T6 ex, no module support, falls off the platform
        --720, -- emanation ex, no module support, sometimes works, depends if the vril mech is used too fast
        748, -- Phantom train, gets caught by the ghosties and gets stuck
    }
end

function do_wt(gearset)
    reset_blacklist()
    if gearset ~= nil then
        equip_gearset(gearset)
    end
    if not Player.Bingo.HasWeeklyBingoJournal or Player.Bingo.IsWeeklyBingoExpired then
        get_wt()
    end
    while wt_count() < 9 do
        if not wt_duty() then
            log("No Possible Duties", default(CallerName(false), FunctionInfo(true)),
                "Failed to find a duty to fill out wt bingo", wt_count(), 'of 9 done')
            return false
        end
    end
    log("WT Bingo completed", wt_count(), "of 9 done")
    return true
end

function log_wt()
    log("---- WT Info ----")
    for i = 0, 15 do
        local cell = Player.Bingo:GetWeeklyBingoTaskStatus(i)
        local duty = Player.Bingo:GetWeeklyBingoOrderDataRow(i)

        log("Wt item", i + 1, duty.Type, wt_item_name(duty), "Level:", extract_level(duty), duty.RowId, cell)
        local instance = wt_pick_duty(duty)
        if instance == nil then
            log("Not supported")
        else
            local instance_id = instance.TerritoryType.RowId
            local type, unsync = wt_duty_type(instance)
            if duty_executable(instance) then
                log("Using:", type, unsync, '-', instance.Name, '-', instance_id, '-',
                    IPC.AutoDuty.ContentHasPath(instance_id))
            end
        end
    end
    log("Completed:", wt_count(), "of 9")
end

function get_wt()
    RunVislandRoute(
        "H4sIAAAAAAAACu1SyW7bMBD9leKdGYNyEjjmrVAWuIVdJ3HhLOiBqSYWAZHjiqMUgaF/Dygri5trTkF54czDzJs3ywYz6wkGP0OwnoovF9wIQeGs5mbd4atkUQGFU+YCRitMbWhs1ZkLW69IzqyUVE+EfAcu7eOaXZAIc7vBnKMTxwFmgyuYvWw8OBqNR3qocA0zzLKBVriB0YNM7x+ODg/GrcINB5ocwxyMjhQubOGaCDNOL0VP+YE8BYEZKsytlPcuFDBSN6QwCUK1/S1LJ+WPxKF3sb5j7KL/qNSpzHX/d+J0qxBL/vuc5DhEmHtbxTc1O4JM4cSz0HNtId+bX7uI3jlvKMpb+5L+bMfLdz18KbzOORS9Mq3w3VVVzk1qXSt023rtJy+t5Oy9TcNIQNK7tE5ehSbvlOtd0gQunKdp3HFPFu+H0SpM4ry0Qdi/kKYNwISmqhRmREWcbhVu97E9DhdWi8c1pSUmihkX9JKfnG98B6Nb9ZH3Mvx/K/knvpVf7RMEuPS/vwQAAA==",
        "Going to Khloe")

    if Player.Bingo.HasWeeklyBingoJournal and not Player.Bingo.IsWeeklyBingoExpired then
        StopScript("AlreadyHaveWT", CallerName(false),
            "Weekly Bingo Journal already exists and is not expired, turn in first")
    end

    repeat
        local entity = get_closest_entity("Khloe Aliapoh", true)
        entity:SetAsTarget()
        entity:Interact()
        wait(.1)
        CheckTimeout(2, ti, "AcceptQuest", "Talking to Khloe Aliapoh didnt work")
        wait(.1)
    until IsAddonReady("Talk") or IsAddonReady("SelectString")

    while wait_any_addons("SelectString", "Talk") == "Talk" do
        close_talk("SelectString")
        wait(0.1)
    end

    SelectInList("Receive a new journal from Khloe.", "SelectString")

    local ti = ResetTimeout()
    repeat
        CheckTimeout(10, ti, "GetWeeklyBingoJournal", "Waiting for Weekly Bingo Journal to be received")
        close_talk()
        wait(.1)
    until not is_busy() and Player.Bingo.HasWeeklyBingoJournal
end

function wt_duty()
    for i = 0, 15 do
        local cell = Player.Bingo:GetWeeklyBingoTaskStatus(i)
        if cell ~= WeeklyBingoTaskStatus.Open then
            log_debug("Bingo cell", i, "not available", cell)
        else
            local duty = Player.Bingo:GetWeeklyBingoOrderDataRow(i)
            local content = wt_pick_duty(duty)
            if content == nil then
                log("Bingo cell", i, "not supported type", duty.Data, '-', wt_item_name(duty))
            else
                -- try to do the duty
                local instance_id = content.TerritoryType.RowId
                local type, unsync = wt_duty_type(content)
                if duty_executable(content) then
                    log("Using:", type, unsync, '-', content.Name, '-', instance_id, '-',
                        IPC.AutoDuty.ContentHasPath(instance_id))
                    run_content(type, unsync, instance_id)
                    return true
                else
                    log("Bingo cell", i, "not executable", duty.Data, '-', wt_item_name(duty))
                end
            end
        end
    end
    return false
end

function run_content(type, unsync, instance_id)
    local count = wt_count()
    local s = os.clock()
    repeat
        IPC.AutoDuty.Stop()
        InstancedContent.LeaveCurrentContent()
        if os.clock() - s > 60 then
            log_(LEVEL_ERROR, log, "Failed to queue instance", instance_id, "blacklisting it.")
            table.insert(duty_blacklist, instance_id)
            return
        end
        setup_content(type, unsync)
        IPC.AutoDuty.Run(instance_id, 1, false)
        local c = os.clock()
        repeat
            wait(1)
        until Svc.ClientState.TerritoryType == instance_id or os.clock() - c > 15
    until Svc.ClientState.TerritoryType == instance_id
    repeat
        wait(1)
    until IPC.AutoDuty.IsStopped()
    if count == wt_count() then
        log_debug("Duty failed? Still in instance?", Svc.ClientState.TerritoryType, instance_id)
        table.insert(duty_blacklist, instance_id)
        if Svc.ClientState.TerritoryType == instance_id then
            InstancedContent.LeaveCurrentContent()
        end
        wait_ready()
    end
end

function setup_content(type, unsync)
    IPC.AutoDuty.SetConfig("autoDutyModeEnum", "Looping")
    if type == "Dungeons" and unsync then
        IPC.AutoDuty.SetConfig("dutyModeEnum", "Regular")
        IPC.AutoDuty.SetConfig("Unsynced", "True")
    elseif type == "Dungeons" and not unsync then
        IPC.AutoDuty.SetConfig("Unsynced", "False")
        IPC.AutoDuty.SetConfig("dutyModeEnum", "Trust")
        local command = String[4]
        command[0] = "set"
        command[1] = fixed_members[1]
        command[2] = fixed_members[2]
        if Player.Job.IsDPS then
            command[3] = dps_fill
        else
            command[3] = support_fill
        end
        log_(LEVEL_INFO, log, "Setting trust members to")
        log_(LEVEL_INFO, log_array, command)
        IPC.AutoDuty.SetConfig("SelectedTrustMembers", command)
    elseif type == "Raids" and unsync then
        IPC.AutoDuty.SetConfig("dutyModeEnum", "Raid")
        IPC.AutoDuty.SetConfig("Unsynced", "True")
    elseif type == "Trials" and unsync then
        IPC.AutoDuty.SetConfig("dutyModeEnum", "Trial")
        IPC.AutoDuty.SetConfig("Unsynced", "True")
    else
        StopScript("NotImplemented", CallerName(false), "Duty type", type, unsync, "not configured")
    end
end

function duty_executable(content)
    local instance_id = content.TerritoryType.RowId
    local type, unsync = wt_duty_type(content)
    if not unsync and type ~= "Dungeons" then
        log_debug("Not supported", content.Name, "type", type, "must be unsynced but allow undersized is", unsync)
        return false
    elseif type == "Trials" and content.ClassJobLevelRequired > 70 then
        log_debug("Not supported", content.Name, "type", type, "dont work well above level 70 but needs",
            content.ClassJobLevelRequired)
        return false
    elseif not IPC.AutoDuty.ContentHasPath(instance_id) then
        log_debug("Not supported", content.Name, "- No autoduty path")
        return false
    elseif list_contains(duty_blacklist, instance_id) then
        log("Blacklisted duty,", content.Name, '-', instance_id, "has been blacklisted")
        return false
    end
    return true
end

function get_duty_row(duty_id)
    local duty = Excel.GetRow("InstanceContent", duty_id)
    if duty == nil then
        return StopScript("InvalidDuty", CallerName(false), "no duty with ID", duty_id)
    end
    return duty.ContentFinderCondition
end

function get_content_row(content_id)
    local duty = Excel.GetRow("TerritoryType", content_id)
    if duty == nil then
        return StopScript("InvalidDuty", CallerName(false), "no duty with territory ID", content_id)
    end
    return duty.ContentFinderCondition
end

function wt_pick_high_level_duty(level)
    if level == 50 then
        --return get_content_row(350)  --Haukke Manor Hard, not stable, runs into walls in candle hall
        return get_content_row(387) --Sastasha Hard
    elseif level == 70 then
        return get_content_row(742) --Hell's Lid
    elseif level == 90 then
        --return get_content_row(973)  --The Dead Ends, not stable, first boss has mechanic requiring 2 players
        --return get_content_row(976)  --Smileton, no bossmod support
        return get_content_row(1070) --The Fell Court of Troia
    elseif level == 100 then
        return get_content_row(1266) --The Underkeep
    end
    StopScript("NotImplemented", nil, "High level duty Lv.", level, "is not implemented")
end

function wt_pick_leveling_duty(level)
    if level == 1 then
        return get_content_row(1040) -- Haukke Manor
    elseif level == 51 then
        return get_content_row(434)  -- Dusk Vigil
    elseif level == 81 then
        return get_content_row(952)  -- Tower of Zot
    end
    StopScript("NotImplemented", nil, "Leveling duty Lv.", level, "is not implemented")
end

function extract_level(duty)
    local name = wt_item_name(duty)
    local s, e = name:find("Lv%. %d+")
    if s == nil then
        return nil
    end
    -- skip the "Lv. "
    s = s + 4
    return tonumber(name:sub(s, e))
end

local UNSUPPORTED_RAID_IDS = {
    26, 27, 28, 29, 30, -- Alliance raids by expansion
    23, 24,             -- Eden
    31, 32, 33, 37,     -- Pandora
    34, 35, 38, 36      -- AAC
}

function raid_id_to_duty(raid_id)
    if list_contains(UNSUPPORTED_RAID_IDS, raid_id) then
        return nil
    elseif raid_id == 2 then
        -- Binding Coil of Bahamut
        return get_content_row(242) -- Turn 2
    elseif raid_id == 4 then
        -- Final Coil of Bahamut
        return get_content_row(195) -- Turn 3
    elseif raid_id == 5 then
        -- Alexander: The Father
        return get_content_row(442) -- Fist of the Father
    elseif raid_id == 6 then
        -- Alexander: The Son
        return get_content_row(520) -- Fist of the Son
    elseif raid_id == 7 then
        -- Alexander: The Creator
        return get_content_row(580) -- Eyes of the Creator
    elseif raid_id == 8 then
        -- Deltascape
        return get_content_row(693) -- V3
    elseif raid_id == 9 then
        -- Sigmascape
        --return get_content_row(748) -- Phantom Train
        return get_content_row(750) -- TV guy
    elseif raid_id == 10 then
        -- Alphascape
        return get_content_row(798) -- Chaos!
    elseif raid_id == 25 then
        -- Edens Promise
        return get_content_row(943) -- Litany
    end
    StopScript("NotImplemented", nil, "Raid", raid_id, "is not implemented")
end

-- I dont think they use most of these anymore, so just crash and implement it when they come up.
function wt_pick_duty(duty)
    if duty.Type == 0 then
        -- Specicfic duty, Data == duty_id
        return get_duty_row(duty.Data)
    elseif duty.Type == 1 then
        -- X0 dungeons, Data == X0
        return wt_pick_high_level_duty(extract_level(duty))
    elseif duty.Type == 2 then
        -- X1-X9 dungeons, Data == X9
        StopScript("NotImplemented")
    elseif duty.Type == 3 then
        -- Special (PvP, treasure, etc.)
        return nil
    elseif duty.Type == 4 then
        -- Normal/Alliance raids, Data == Specific raid index
        return raid_id_to_duty(duty.Data)
    elseif duty.Type == 5 then
        -- X1-Y9 Leveling dungeons, Data == Y9
        return wt_pick_leveling_duty(extract_level(duty))
    elseif duty.Type == 6 then
        -- X0,Y0 High level dungeons, Data == Y0
        return wt_pick_high_level_duty(extract_level(duty))
    elseif duty.Type == 7 then
        -- X0-Y0 Trials, Data == Y0
        StopScript("NotImplemented")
    elseif duty.Type == 8 then
        -- X0-Y0 Alliance Raids, Data == Y0
        StopScript("NotImplemented")
    elseif duty.Type == 9 then
        -- X0-Y0 Normal Raids, Data == Y0
        StopScript("NotImplemented")
    end
end

function wt_item_name(duty)
    if duty.Type == 0 then
        return get_duty_row(duty.Data).Name
    else
        return duty.Text.Description
    end
end

function wt_duty_type(content_instance)
    return content_instance.ContentType.Name, content_instance.AllowUndersized
end

function wt_count()
    local count = 0
    for i = 0, 15 do
        local cell = Player.Bingo:GetWeeklyBingoTaskStatus(i)
        if cell == WeeklyBingoTaskStatus.Claimable or cell == WeeklyBingoTaskStatus.Claimed then
            count = count + 1
        end
    end
    return count
end
--[[
================================================================================
  END IMPORT: wt_doer.lua
================================================================================
]]


local GEARSET = Config.Get("GearsetName")

if Config.Get("DebugMessages") then
    debug_level = LEVEL_DEBUG
end

if GEARSET == "" then
    GEARSET = nil
end

do_wt(GEARSET)
