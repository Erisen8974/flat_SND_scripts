-- Auto generated file, do not edit!
--[=====[
[[SND Metadata]]
author: Erisen
version: 1.0.0
description: >-
  Jump up kugane tower
plugin_dependencies:
- vnavmesh
configs:
  LampJump:
    default: false
    description: Jump to the lamp
    type: bool

[[End Metadata]]
--]=====]


--[[
================================================================================
  BEGIN IMPORT: utils.lua
================================================================================
]]

if ___UTILS_IMPORTED then -- stop if importing circular dependencies
    return
end
___UTILS_IMPORTED = true
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
    if Player == nil then
        return nil
    end
    if Player.Entity == nil then
        return nil
    end
    if Player.Entity.Position == nil then
        return nil
    end
    return Vector3.Distance(Player.Entity.Position, Vector3(x, y, z))
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
        error("Bad addon", name)
    end
    local n = a:GetNode(...)
    if tostring(n.NodeType):find("Text:") == nil then
        error("Not a text node", "NodeType:", n.NodeType, "NodeId:", n.Id, name, ...)
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

--[[
================================================================================
  BEGIN IMPORT: extra_ipcs.lua
================================================================================
]]

-- Skipped import: utils.lua
--[[
================================================================================
  BEGIN IMPORT: hard_ipc.lua
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
        CheckTimeout(max_wait, ti, "Waiting for task to complete")
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
        error("Failed to make instance", "type:", ctype, "args:", args)
    end
    return instance
end

function deref_pointer(ptr, ctype)
    if Unsafe == nil then
        _, Unsafe = load_type("System.Runtime.CompilerServices.Unsafe", "System.Runtime")
    end
    local AsRef = get_generic_method(Unsafe, "AsRef", { ctype })
    if AsRef == nil or AsRef.Invoke == nil then
        error("Failed to get AsRef method", "ctype:", ctype)
    end
    local arg = luanet.make_array(Object, { ptr })
    local ref = AsRef:Invoke(nil, arg)
    if ref == arg then
        error("Failed to deref pointer", "pointer:", ptr, "ctype:", ctype)
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

function _field(o, field, ...)
    if field == nil then
        return o
    end
    local t = o:GetType()
    local f = get_field(t, field, { private = true, static = true }, false)
    if f == nil then
        f = get_property(t, field, { private = true, static = true }, false)
        if f == nil then
            error("field or property not found", o, field)
        end
    end
    local res = f:GetValue(o)
    if res == o then
        error("could not get value", o, field)
    end
    return _field(res, ...)
end

function get_plugin_instance(plugin_name, required)
    local plugin = get_plugin_raw(plugin_name, required, true)
    if plugin ~= nil then
        return _field(plugin, "instance")
    end
end

function get_plugin_raw(plugin_name, required, need_loaded)
    need_loaded = default(need_loaded, true)
    required = default(required, true)
    local DalamudReflector = load_type("ECommons.Reflection.DalamudReflector")
    local pluginManager = DalamudReflector.GetPluginManager()
    for plugin in luanet.each(pluginManager.InstalledPlugins) do
        if plugin.Name == plugin_name then
            if plugin.IsLoaded or not need_loaded then
                return plugin
            end
        end
    end
    if required then
        error("Plugin not found", plugin_name)
    end
end

LOADED_ASSEMBLIES = {}
TYPE_CACHE = {}

function load_type(type_path, assembly)
    assembly = default(assembly, assembly_name(type_path))
    if not list_contains(LOADED_ASSEMBLIES, assembly) then
        log_(LEVEL_VERBOSE, _text, "Loading assembly", assembly)
        luanet.load_assembly(assembly)
        table.insert(LOADED_ASSEMBLIES, assembly)
    end
    if not TYPE_CACHE[type_path] then
        log_(LEVEL_VERBOSE, _text, "Loading type", type_path)
        local type_var = luanet.import_type(type_path)
        log_(LEVEL_VERBOSE, _text, "Loaded type", type_var)
        TYPE_CACHE[type_path] = type_var
    end
    type_var = TYPE_CACHE[type_path]
    return type_var, luanet.ctype(type_var)
end

--[[ this didnt work...
function load_type_(type_path, assembly)
    assembly = default(assembly, assembly_name(type_path))
    local assembly_handle = nil
    for i in luanet.each(AppDomain.CurrentDomain:GetAssemblies()) do
        if i.FullName:match(assembly .. ",") then
            if assembly_handle ~= nil then
                StopScript("Multiple assemblies found matching name", "assembly:", assembly)
            end
            assembly_handle = i
        end
    end
    if assembly_handle == nil then
        StopScript("Assembly not found", "assembly:", assembly)
    end
    local type_found = nil
    for i in luanet.each(assembly_handle.ExportedTypes) do
        if i.FullName == type_path then
            if type_found ~= nil then
                StopScript("Multiple types found matching name", "type_path:", type_path)
            end
            type_found = i
        end
    end
    if type_found == nil then
        StopScript("Type not found", "type_path:", type_path)
    end
    return type_found
end
--]]

function get_method(type, method_name, binding)
    local method = type:GetMethod(method_name, make_binding_flags(binding))
    if method == nil then
        error("Method not found", "type:", type, "method_name:", method_name)
    end
    return method
end

function get_field(type, field_name, binding, required)
    required = default(required, true)
    local field = type:GetField(field_name, make_binding_flags(binding))
    if field == nil then
        if required then
            error("Field not found", "type:", type, "field_name:", field_name)
        end
        return nil
    end
    return field
end

function get_property(type, property_name, binding, required)
    required = default(required, true)
    local property = type:GetProperty(property_name, make_binding_flags(binding))
    if property == nil then
        if required then
            error("Property not found", "type:", type, "property_name:", property_name)
        end
        return nil
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
    error("No generic method found", "No matching generic method found for", method_name, "with",
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
    error("No method overload found", "No matching overload found for", method_name, "with",
        #paramTypes, "parameters")
end
--[[
================================================================================
  END IMPORT: luasharp.lua
================================================================================
]]

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
            error("Bad argument", "argument types should be strings")
        end
        arg_types[i] = Type.GetType(v)
    end
    local method = get_generic_method(Svc.PluginInterface:GetType(), 'GetIpcSubscriber', arg_types)
    if method.Invoke == nil then
        error("GetIpcSubscriber not found", "No IPC subscriber for", #arg_types, "arguments")
    end
    local sig = luanet.make_array(Object, { ipc_signature })
    local subscriber = method:Invoke(Svc.PluginInterface, sig)
    if subscriber == nil then
        error("IPC not found", "signature:", ipc_signature)
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
        error("IPC not ready", "signature:", ipc_signature, "is not loaded")
    end
    if function_subscriber ~= nil then
        local result = function_subscriber:InvokeFunc(...)
        if result == function_subscriber then
            error("Function IPC failed", "signature:", ipc_signature)
        end
        return result
    end
    -- otherwise its action IPC

    local result = action_subscriber:InvokeAction(...)
    if result == action_subscriber then
        error("IPC failed", "signature:", ipc_signature)
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

NORMAL_SADDLEBAG = {
    InventoryType.SaddleBag1,
    InventoryType.SaddleBag2,
}

PREMIUM_SADDLEBAG = {
    InventoryType.PremiumSaddleBag1,
    InventoryType.PremiumSaddleBag2,
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
        error("No information for item", item_name)
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
                CheckTimeout(10, ti, "Couldnt equip gearset:", gearset_name)
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
                CheckTimeout(10, ti, "Couldnt equip gearset:", gearset_name)
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
    for _, destination in pairs(ALL_INVENTORY) do
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

_RaptureGearsetModule_GearsetItemIndex = nil

local function RaptureGearsetModule_GearsetItemIndex()
    if _RaptureGearsetModule_GearsetItemIndex == nil then
        _RaptureGearsetModule_GearsetItemIndex = load_type(
            "FFXIVClientStructs.FFXIV.Client.UI.Misc.RaptureGearsetModule+GearsetItemIndex")
    end
    return _RaptureGearsetModule_GearsetItemIndex
end

function current_gearset_index()
    local RaptureGearsetModule = cs_instance("FFXIVClientStructs.FFXIV.Client.UI.Misc.RaptureGearsetModule")
    return RaptureGearsetModule.CurrentGearsetIndex
end

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
        MainHand = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().MainHand),
        OffHand = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().OffHand),
        Head = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().Head),
        Body = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().Body),
        Hands = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().Hands),
        Legs = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().Legs),
        Feet = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().Feet),
        Ears = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().Ears),
        Neck = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().Neck),
        Wrists = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().Wrists),
        LeftRing = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().RingLeft),
        RightRing = _resolve_gearset_ids__get_item_id(RaptureGearsetModule_GearsetItemIndex().RingRight),
    }
end

-- dont preserve too long cause it can change, but its a little slow to generate
_GEARSET_CACHE = {}
_GEARSET_LAST_UPDATE = os.clock()
_GEARSET_MISSING_OKAY = false

function reset_gearset_cache()
    _GEARSET_CACHE = {}
    _GEARSET_LAST_UPDATE = os.clock()
end

function resolve_gearset_items(number)
    if _GEARSET_LAST_UPDATE + 10 <= os.clock() then
        reset_gearset_cache()
    end
    if _GEARSET_CACHE[number] == nil then
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
                long_task_delay()
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
                if not _GEARSET_MISSING_OKAY then
                    error("GearsetItemNotFound", "Did not find item for slot", slot, "with id", gid,
                        "in gearset", number)
                end
            end
        end
        _GEARSET_CACHE[number] = items
    end
    return _GEARSET_CACHE[number]
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

function itemid_gs_submittable(itemid)
    local item_row = luminia_row_checked("item", itemid)
    return item_row.Rarity > 1 and item_row.EquipSlotCategory.RowId ~= 0
end

function item_gs_submittable(item)
    return itemid_gs_submittable(item.ItemId)
end

function is_item_job(job)
    return function(item)
        local cat = luminia_row_checked("item", item.ItemId).ClassJobCategory
        if cat.RowId == 0 then
            return nil
        end
        return cat[job]
    end
end

function max_item_level(max_level)
    return function(item)
        local equip_level = luminia_row_checked("item", item.ItemId).LevelEquip
        return equip_level <= max_level
    end
end

function is_item_equip_slot(slot)
    return function(item)
        local cat = luminia_row_checked("item", item.ItemId).EquipSlotCategory
        if cat.RowId == 0 then
            return nil
        end
        return cat[slot] == 1
    end
end

function pred_all(...)
    local pred_list = table.pack(...)
    return function(item)
        for i = 1, pred_list.n do
            local p = pred_list[i]
            local r = p(item)
            log_(LEVEL_VERBOSE, _text, "Checking predicate number", i, "result", r)
            if not r then
                return false
            end
        end
        return true
    end
end

function pred_any(...)
    local pred_list = table.pack(...)
    return function(item)
        for i = 1, pred_list.n do
            if pred_list[i](item) then
                return true
            end
        end
        return false
    end
end

function restock_crystals(target)
    local need_restock = false
    local can_restock = false
    for slot = 0, 17 do
        if Inventory.GetInventoryItemBySlot(InventoryType.Crystals, slot).Count < target then
            need_restock = true
            if Inventory.GetInventoryItemBySlot(InventoryType.Crystals, slot).Count > 0 then
                can_restock = true
            end
        end
    end

    if not need_restock then
        return true
    end

    if not can_restock then
        return false
    end

    open_addon("InventoryRetainer", "SelectString", true, 0)

    local fully_stocked = true
    for slot = 0, 17 do
        if not __restock_crystals(slot, target) then
            fully_stocked = false
        end
    end

    close_addon("InventoryRetainer")
    return fully_stocked
end

function __restock_crystals(slot, target)
    local cur = Inventory.GetInventoryItemBySlot(InventoryType.Crystals, slot).Count
    if cur >= target then
        return true
    end
    local need = target - cur
    local avail = Inventory.GetInventoryItemBySlot(InventoryType.RetainerCrystals, slot).Count
    if avail <= need then
        if avail > 0 then
            Inventory.GetInventoryItemBySlot(InventoryType.RetainerCrystals, slot):MoveItemSlot(InventoryType.Crystals)
        end
        return avail == need
    end
    move_partial_stack(InventoryType.RetainerCrystals, slot, need)
    return true
end

function move_partial_stack(src_inv, src_slot, count)
    if not any_addons_ready("InventoryRetainer") then
        error("RetainerInvNotOpen", "Must have the retainer inventory panel open")
    end
    local available = Inventory.GetInventoryItemBySlot(src_inv, src_slot).Count
    if available <= count then
        error("NotEnoughItems", "Requested partial move", count, "but slot only has", available)
    end
    local menu_entry = "Retrieve Quantity"
    if list_contains({ InventoryType.Crystals, InventoryType.RetainerCrystals }, src_inv) then
        menu_entry = "Retrieve from Retainer"
    end
    pause_pyes()
    local inst = cs_instance("FFXIVClientStructs.FFXIV.Client.UI.Agent.AgentInventoryContext")
    --- just ignore all those extra args, the context menu is completely invalid anyway...
    inst:OpenForItemSlot(src_inv, src_slot, 0, 0)
    --- danger zone: if the context menu goes away other than the callback in SelectInList the game will crash...
    if not SelectInList(menu_entry) then
        close_addon("AddonContextSub")
        close_addon("ContextMenu")
        resume_pyes()
        return
    end
    --- perfectly safe :)
    wait_any_addons("InputNumeric")
    SafeCallback("InputNumeric", true, count)
    resume_pyes()
end

function move_items(source_inv, dest_inv, pred, count)
    count = default(count, -1)
    if source_inv == nil or dest_inv == nil then
        error("Source and destination inventories must be provided")
    end
    if type(source_inv) ~= "table" then
        source_inv = { source_inv }
    end
    if type(dest_inv) ~= "table" then
        dest_inv = { dest_inv }
    end
    pred = default(pred, function() return true end)
    local source_idx = 1
    local dest_idx = 1
    local destinv = nil
    while source_idx <= #source_inv do
        local sourceinv = Inventory.GetInventoryContainer(source_inv[source_idx])
        if sourceinv == nil then
            error("No inventory", source_inv[source_idx])
        else
            destinv = Inventory.GetInventoryContainer(dest_inv[dest_idx])
            if destinv == nil then
                error("No inventory", dest_inv[dest_idx])
            end
            for item in luanet.each(sourceinv.Items) do
                long_task_delay()
                if pred(item) then
                    local need_move = true
                    while dest_idx <= #dest_inv and need_move do
                        if destinv.FreeSlots > 0 then
                            log("Moving", item.ItemId, "from", source_inv[source_idx], "to", dest_inv[dest_idx])
                            item:MoveItemSlot(dest_inv[dest_idx])
                            if count > 0 then
                                count = count - 1
                                if count == 0 then
                                    return true -- moved all requested items
                                end
                            end
                            need_move = false
                        else
                            log_(LEVEL_INFO, _text, "No space to move item to", dest_inv[dest_idx])
                            dest_idx = dest_idx + 1
                            if dest_idx <= #dest_inv then
                                destinv = Inventory.GetInventoryContainer(dest_inv[dest_idx])
                                if destinv == nil then
                                    error("No inventory", dest_inv[dest_idx])
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
    return count <= 0 -- all items if any were able to be moved
end

function make_armory_space(amount, armory_slots, allowed_move)
    armory_slots = default(armory_slots, ALL_ARMORY)
    local success = true
    for _, slot in pairs(armory_slots) do
        local inv = Inventory.GetInventoryContainer(slot)
        local needed = amount - inv.FreeSlots
        if needed > 0 then
            log_(LEVEL_INFO, _text, "Need to move", needed, "items out of armory slot", slot)
            if not move_items(slot, ALL_INVENTORY, allowed_move, needed) then
                success = false
                log_(LEVEL_ERROR, _text, "Couldnt move items out of armory slot", slot)
            end
        end
    end
    return success
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
        error("LetterList addon not ready")
    end
    wait(1)
    local count = tonumber(Addons.GetAddon("LetterList"):GetNode(1, 22, 23).Text:match("(.-)/20"))
    log_(LEVEL_INFO, _text, "Starting to collect reward mail, count:", count)
    if count == 0 or count == nil then
        log_(LEVEL_INFO, _text, "Error or no mail")
        return
    end
    repeat
        open_addon("LetterViewer", "LetterList", true, 0, 0)
        SafeCallback("LetterViewer", true, 1)
        repeat wait(.1) until Addons.GetAddon("LetterViewer"):GetNode(1, 32, 2, 3).IsVisible
        repeat wait(.1) until not Addons.GetAddon("LetterViewer"):GetNode(1, 32, 2, 3).IsVisible
        wait(.1)
        SafeCallback("LetterViewer", true, 2)
        wait_any_addons("SelectYesno")
        SafeCallback("SelectYesno", true, 0)
        local l = count
        repeat
            wait(.1)
            count = tonumber(Addons.GetAddon("LetterList"):GetNode(1, 22, 23).Text:match("(.-)/20"))
        until l ~= count
        log_(LEVEL_INFO, _text, "Collected reward mail, remaining count:", count)
        wait(.1)
    until count == 0
    close_addon("LetterList")
end

function entrust_glamours()
    lifestream_command_blocking("inn")
    local p1 = Entity.GetEntityByName("Armoire")
    if p1 == nil then
        error("Armoire Missing", "Couldn't find Armoire entity")
    end
    p1 = p1.Position
    if p1 == nil then
        error("Armoire Missing", "Couldn't find Armoire entity position")
    end
    local p2 = Entity.GetEntityByName("Glamour Dresser")
    if p2 == nil then
        error("Glamour Dresser Missing", "Couldn't find Glamour Dresser entity")
    end
    p2 = p2.Position
    if p2 == nil then
        error("Glamour Dresser Missing", "Couldn't find Glamour Dresser entity position")
    end
    local mid = (p1 + p2) / 2
    move_near_point(mid, 2)
    OpenShop('Armoire', 'Cabinet', { SelectString = { 0 } })
    glamourlog_block('store', 5)
    close_addons({ 'Cabinet' })
    OpenShop('Glamour Dresser', 'MiragePrismPrismBox', {})
    glamourlog_block('store', 5)
    close_addons({ 'MiragePrismPrismBox' })
end
--[[
================================================================================
  END IMPORT: inventory_buddy.lua
================================================================================
]]

import "System"


local GBR = 'GatherBuddyReborn'
local GBR_ENABLED = GBR .. '.IsAutoGatherEnabled'
local GBR_WAITING = GBR .. '.IsAutoGatherWaiting'
local GBR_SET_AUTO_GATHER = GBR .. '.SetAutoGatherEnabled'

function gbr_gather(max_time)
    require_ipc(GBR_SET_AUTO_GATHER, nil, { 'System.Boolean' })
    invoke_ipc(GBR_SET_AUTO_GATHER, true)
    wait_gbr_idle(max_time)
    invoke_ipc(GBR_SET_AUTO_GATHER, false)
end

function wait_gbr_idle(max_wait)
    require_ipc(GBR_WAITING, 'System.Boolean', {})
    require_ipc(GBR_ENABLED, 'System.Boolean', {})
    local ti = nil
    if max_wait ~= nil then
        ti = ResetTimeout()
    end
    repeat
        if ti ~= nil then
            CheckTimeout(max_wait, ti, "wait_gbr_idle timed out")
        end
        wait(1)
        local waiting = invoke_ipc(GBR_WAITING)
        local enabled = invoke_ipc(GBR_ENABLED)
    until not enabled or waiting
end

local STYLIST = 'Stylist'
local STYLIST_IS_BUSY = STYLIST .. '.IsBusy'
local STYLIST_UPDATE_CURRENT_GEARSET = STYLIST .. '.UpdateCurrentGearset'

function stylist_update_current_gearset()
    reset_gearset_cache()
    Player.Gearset:Update()
    require_ipc(STYLIST_IS_BUSY, 'System.Boolean', {})
    require_ipc(STYLIST_UPDATE_CURRENT_GEARSET, nil, { 'System.Boolean' })
    local ti = ResetTimeout()
    invoke_ipc(STYLIST_UPDATE_CURRENT_GEARSET, true)
    repeat
        CheckTimeout(30, ti, "Stylist is busy")
        wait(0.5)
    until not invoke_ipc(STYLIST_IS_BUSY)
end

function stylist_update_all()
    reset_gearset_cache()
    local start = os.clock()
    Engines.Native.Run("/stylist all")
    repeat
        wait(0)
    until stylist_is_busy() or start + 1 < os.clock()

    while stylist_is_busy() do
        wait(.5)
    end
end

function stylist_is_busy()
    require_ipc(STYLIST_IS_BUSY, 'System.Boolean', {})
    return invoke_ipc(STYLIST_IS_BUSY)
end

local AUTORETAINER = 'AutoRetainer'
local AUTORETAINER_GETCONFIG = AUTORETAINER .. '.GetConfig'
local AUTORETAINER_GETCONFIG_SHUTDOWN = AUTORETAINER_GETCONFIG .. '.ShutdownOnSubExhaustion'

function autoretainer_shutdown()
    require_ipc(AUTORETAINER_GETCONFIG_SHUTDOWN, 'System.Boolean', {})
    return invoke_ipc(AUTORETAINER_GETCONFIG_SHUTDOWN)
end

function ar_is_active(buffer_time)
    buffer_time = default(buffer_time, 3 * MINUTES)
    return IPC.AutoRetainer.GetMultiModeEnabled() and (
        IPC.AutoRetainer.IsBusy() or
        ar_multi_mode_would_start(buffer_time)
    )
end

function ar_add_unconditional_sell(plan_name, itemid)
    local i = get_plugin_instance(AUTORETAINER)
    local im_settings = _field(i, "API", "Config", "AdditionalIMSettings")

    for settings in luanet.each(im_settings) do
        if settings.Name == plan_name then
            if settings.IMProtectList:Contains(itemid) then
                log_(LEVEL_ERROR, _text, "Item is in protected list", plan_name, itemid)
                return false
            end
            if settings.IMAutoVendorHard:Contains(itemid) then
                log_(LEVEL_INFO, _text, "Item is already in unconditional sell list", plan_name, itemid)
                return true
            end
            settings.IMAutoVendorHard:Add(itemid)
            log_(LEVEL_INFO, _text, "Added item to AutoRetainer unconditional sell list", plan_name, itemid)
            return true
        end
    end
    log_(LEVEL_ERROR, _text, "Failed to add item to AutoRetainer unconditional sell list, plan not found", plan_name,
        itemid)
    return false
end

function ar_multi_mode_would_start(venture_buffer)
    venture_buffer = default(venture_buffer, 60)
    local chars = IPC.AutoRetainer.GetRegisteredCharacters()
    local now = os.time()
    for cid in luanet.each(chars) do
        local char = IPC.AutoRetainer.GetOfflineCharacterData(cid)
        local next_ready = IPC.AutoRetainer.GetClosestRetainerVentureSecondsRemaining(cid)
        log_(LEVEL_VERBOSE, _text, char.Name, char.Enabled, char.AnyAwaitingProcessing, next_ready)
        if char.Enabled then
            if char.AnyAwaitingProcessing or next_ready < venture_buffer then
                return true
            end
            for sub in luanet.each(char.OfflineSubmarineData) do
                local return_time = sub.ReturnTime
                log_(LEVEL_VERBOSE, _text, "Submarine", return_time - now)
                if return_time - now < venture_buffer then
                    return true
                end
            end
        end
    end
    return false
end

local QUESTY = 'Questionable'

function _zone_has_unlocked_aetheryte()
    local zone = Svc.ClientState.TerritoryType
    local row = luminia_row_checked("TerritoryType", zone).Aetheryte.RowId
    if row == 0 then
        return false
    end
    return Instances.Telepo:IsAetheryteUnlocked(row)
end

function _questy_get_quest_controller()
    local i = get_plugin_instance(QUESTY)
    local t = i:GetType().Assembly
    local _serviceProvider = _field(i, "_serviceProvider")
    local di_t = t:GetType("Questionable.DalamudInitializer")
    local di = _serviceProvider:GetService(di_t)
    return _field(di, "_questController")
end

function _questy_get_duties()
    local i = get_plugin_instance(QUESTY)
    local t = i:GetType().Assembly
    local _serviceProvider = _field(i, "_serviceProvider")
    local duty_config_t = t:GetType("Questionable.Windows.ConfigComponents.DutyConfigComponent")
    local duty_config = _serviceProvider:GetService(duty_config_t)
    return _field(duty_config, "Configuration", "Duties")
end

function questy_stop_soon()
    local quest_controller = _questy_get_quest_controller()
    local duties = _questy_get_duties()
    duties.RunInstancedContentWithAutoDuty = false
    --quest_controller.StopAfterCurrentQuest = true
    quest_controller.StopBeforeTeleport = true
end

function questy_reenable()
    local duties = _questy_get_duties()
    duties.RunInstancedContentWithAutoDuty = true
end

function questy_stop_blocking(interval)
    local interval = default(interval, 10)
    questy_stop_soon()
    repeat wait(interval) until not IPC.Questionable.IsRunning()
    log_(LEVEL_DEBUG, _text, "Questy stopped, running multi mode")
    questy_reenable()
end

local LIFESTREAM = 'Lifestream'

function lifestream_command_blocking(command, player_ready, max_wait)
    log_(LEVEL_DEBUG, _text, "Executing Lifestream command", command)
    IPC.Lifestream.ExecuteCommand(command)

    lifestream_block(player_ready, max_wait)
end

function lifestream_block(player_ready, max_wait)
    running_lifestream = true
    player_ready = default(player_ready, true)
    repeat wait(.1) until IPC.Lifestream.IsBusy()
    log_(LEVEL_DEBUG, _text, "Lifestream command is running")
    repeat wait(1) until not IPC.Lifestream.IsBusy()
    log_(LEVEL_DEBUG, _text, "Lifestream command finished")

    if player_ready then
        wait_ready(max_wait, 1, true, .5)
        log_(LEVEL_DEBUG, _text, "Lifestream command player ready")
    end
end

local AUTODUTY = 'AutoDuty'

function ad_helper_running()
    local ad = get_plugin_instance(AUTODUTY)
    local ass = ad:GetType().Assembly
    local helper = ass:GetType("AutoDuty.Helpers.ActiveHelper")
    local m = get_method(helper, "AnyHelperRunning", { static = true })
    local arg_array = luanet.make_array(Object, {})
    local res = m:Invoke(helper, arg_array)
    return res
end

function wait_ad(command)
    local s = os.clock()
    if command then
        log_(LEVEL_DEBUG, _text, 'Executing AutoDuty command', command)
        yield("/ad " .. command)
    end
    repeat wait(.1) until ad_helper_running() or os.clock() - s > 1
    log_(LEVEL_DEBUG, _text, 'AD Started (or time)')
    repeat wait(1) until not ad_helper_running()
    log_(LEVEL_DEBUG, _text, 'AD Done')
end

local GLAMOURLOG = 'GlamourLog'
local GLAMOURLOG_IS_BUSY = GLAMOURLOG .. '.IsBusy'
local GLAMOURLOG_ENTRUST_ALL = GLAMOURLOG .. '.EntrustAll'

function glamourlog_is_busy()
    require_ipc(GLAMOURLOG_IS_BUSY, 'System.Boolean', {})
    return invoke_ipc(GLAMOURLOG_IS_BUSY)
end

function glamourlog_block(command, max_start_delay, command_frequency)
    local s = os.clock()
    local last_command = 0
    max_start_delay = default(max_start_delay, 1)
    command_frequency = default(command_frequency, 1)
    repeat
        if command and os.clock() - last_command > command_frequency then
            log_(LEVEL_DEBUG, _text, 'Executing GlamourLog command', command)
            yield("/gl " .. command)
            last_command = os.clock()
        end
        wait(.1)
    until glamourlog_is_busy() or os.clock() - s > max_start_delay
    log_(LEVEL_DEBUG, _text, 'GlamourLog Started (or time)')
    repeat wait(.1) until not glamourlog_is_busy()
    log_(LEVEL_DEBUG, _text, 'GlamourLog Done')
end

function glamourlog_entrust_all(block)
    block = default(block, false)
    require_ipc(GLAMOURLOG_ENTRUST_ALL, 'System.Boolean', {})
    local res = invoke_ipc(GLAMOURLOG_ENTRUST_ALL)
    if not res then
        log_(LEVEL_ERROR, _text, "GlamourLog EntrustAll failed")
        return false
    end
    if block then
        glamourlog_block()
    end
    return true
end
--[[
================================================================================
  END IMPORT: extra_ipcs.lua
================================================================================
]]

-- Skipped import: inventory_buddy.lua

import 'System.Numerics'

-- if present load the character info
pcall(require, 'private/char_info')


SCRIPT_TAG = "[EriSND]"
MINUTES = 60
HOURS = 60 * MINUTES

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

function is_bit_set(value, bitIndex)
    local mask = 1 << bitIndex
    local value_num = tonumber(value)
    local masked = value_num & mask
    log_(LEVEL_VERBOSE, _text, "Checking bit", bitIndex, "in value", value_num, "with mask", mask, "result:",
        masked)
    return masked ~= 0
end

function __pause_request(pause, name)
    local set = get_shared_data(name, "System.Collections.Generic.HashSet`1[System.String]")
    if set == nil then
        return
    end
    if pause then
        set:Add(SCRIPT_TAG)
    else
        set:Remove(SCRIPT_TAG)
    end
end

__PAUSE_HANDLES = {
    "YesAlready.StopRequests",
    "TextAdvance.StopRequests",
}

function pause_pyes()
    pyes_pause_count = default(pyes_pause_count, 0)
    pyes_pause_count = pyes_pause_count + 1
    for _, option in pairs(__PAUSE_HANDLES) do
        __pause_request(true, option)
    end
end

function resume_pyes()
    if pyes_pause_count == nil then
        return
    end
    pyes_pause_count = pyes_pause_count - 1
    if pyes_pause_count == 0 then
        for _, option in pairs(__PAUSE_HANDLES) do
            __pause_request(false, option)
            release_shared_data(option)
        end
    end
end

function find_after(msg, target, after)
    e, s = msg:reverse():find(after:reverse())
    if e == nil then
        return nil -- cant find something after something if the second thing doesn't exist!
    end
    return string.find(msg, target, -e)
end

function get_chat_messages(tab)
    local chat = GetNodeText("ChatLogPanel_" .. tostring(tab), 1, 2, 3)
    if chat == 2 then
        error("Error getting chat log")
    end
    return chat
end

function wait_message(after, timeout, ...)
    local ti = ResetTimeout()
    local messages = { ... }
    local found = false

    timeout = default(timeout, 10)
    wait_any_addons("ChatLogPanel_3")
    repeat
        CheckTimeout(timeout, ti, "Waiting for message '" .. after .. "' followed by", ...)
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
        CheckTimeout(3, ti, "Opening addon", addon)
        SafeCallback(base_addon, ...)
        wait(0.1)
    end
end

function confirm_addon(addon, ...)
    local ti = ResetTimeout()
    while IsAddonReady(addon) do
        CheckTimeout(3, ti, "Confirming addon", addon)
        SafeCallback(addon, ...)
        wait(0.1)
    end
end

function talk(who, what_addon)
    what_addon = default(what_addon, "SelectString")
    local ti = ResetTimeout()
    repeat
        CheckTimeout(10, ti, "Talking to", who, "to open addon", what_addon)
        local entity = get_closest_entity(who)
        entity:SetAsTarget()
        entity:Interact()
        wait(.5)
    until IsAddonReady(what_addon)
end

function close_yes_no(accept, expected_text, mandatory)
    mandatory = default(mandatory, false)
    accept = default(accept, false)
    if mandatory then
        wait_any_addons("SelectYesno")
    end
    if IsAddonReady("SelectYesno") then
        if expected_text ~= nil then
            local node = GetNodeText("SelectYesno", 1, 2)
            if node == nil or not node:upper():find(expected_text:upper()) then
                log_(LEVEL_DEBUG, _text, "Expected yesno text '" .. expected_text .. "' didn't match actual text:", node)
                if mandatory then
                    error("Wrong yesno", "Expected yesno text", expected_text,
                        "did not match actual text", node)
                end
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
        CheckTimeout(60, ti, "Finishing talking")
        wait(.1)
    end
end

function close_addon(addon)
    local ti = ResetTimeout()
    while IsAddonReady(addon) do
        CheckTimeout(1, ti, "Closing addon", addon)
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
        CheckTimeout(30, ti, "Waiting for addons", ...)
        wait(0.1)
    end
end

function open_retainer_bell()
    OpenShop("Summoning Bell", { "RetainerList", "SelectString", "RetainerGrid", "RetainerTaskAsk", "Bank" })
    while IPC.AutoRetainer.AreAnyRetainersAvailableForCurrentChara() do
        wait(1)
    end
    while IPC.AutoRetainer.IsBusy() do
        wait(1)
    end
    wait_any_addons("RetainerList")
end

function title_case(str)
    local title = str:gsub("(%a)([%w']*)", function(first, rest) return first:upper() .. rest:lower() end)
    return title
end

function close_addons(addons)
    while is_busy() do
        wait(.1)
        for _, addon in pairs(addons) do
            close_addon(addon)
        end
    end
end

---------------------------------------------------------
-------- Character utils if char data was loaded --------
---------------------------------------------------------

function char_canonical_name(char)
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
    char = char_canonical_name(char)
    return private_char_info[char]
end

function char_homeworld(char)
    local char_info = get_char_info(char)
    if char_info == nil then
        return nil
    end
    return char_info.Homeworld
end

function change_character(char, world)
    reset_gearset_cache()
    local ti = ResetTimeout()
    char = char_canonical_name(char)
    world = title_case(default(world, char_homeworld(char)))

    local target = string.format("%s@%s", char, world)

    log_(LEVEL_DEBUG, _text, "Changing to character", target)

    if Player.Entity.Name == char and luminia_row_checked("World", Player.Entity.HomeWorld).Name == world then
        log_(LEVEL_DEBUG, _text, "Already on target character", target)
        return
    end

    lifestream_command_blocking(target)
    log_(LEVEL_DEBUG, _text, "Ready!")
end

function is_busy()
    return Player.IsBusy or GetCharacterCondition(6) or GetCharacterCondition(26) or GetCharacterCondition(27) or
        GetCharacterCondition(43) or GetCharacterCondition(50) or
        GetCharacterCondition(45) or GetCharacterCondition(51) or GetCharacterCondition(32) or
        not (GetCharacterCondition(1) or GetCharacterCondition(4)) or
        (not IPC.vnavmesh.IsReady()) or IPC.vnavmesh.PathfindInProgress() or IPC.vnavmesh.IsRunning()
end

function wait_ready(max_wait, seconds_ready, stationary, interval)
    stationary = default(stationary, true)
    seconds_ready = default(seconds_ready, 5)
    interval = default(interval, 1)
    local ready_time = os.clock()
    local ti = nil
    local p = nil
    local player = Player.Entity
    if player ~= nil then
        local position = player.Position
        if position ~= nil then
            p = position
        else
            log_(LEVEL_ERROR, _text, "Player.Entity.Position is nil - init")
        end
    else
        log_(LEVEL_ERROR, _text, "Player.Entity is nil - init")
    end
    if max_wait ~= nil then
        ti = ResetTimeout()
    end
    repeat
        if ti ~= nil then
            CheckTimeout(max_wait, ti, "wait_ready timed out with ready time", os.clock() - ready_time,
                "and target", seconds_ready)
        end
        wait(interval)
        local player = Player.Entity
        if player ~= nil then
            local position = player.Position
            if position ~= nil then
                if p ~= nil then
                    ---@diagnostic disable-next-line: undefined-field  Vector3.Distance exists....
                    if is_busy() or (stationary and Vector3.Distance(p, position) > interval) then
                        log_(LEVEL_DEBUG, _text, "not ready resetting clock")
                        p = position
                        ready_time = os.clock()
                    else
                        log_(LEVEL_DEBUG, _text, "ready tick", os.clock() - ready_time, "target", seconds_ready)
                    end
                else
                    p = position
                    ready_time = os.clock()
                    log_(LEVEL_DEBUG, _text, "Initial position was nil, setting")
                end
            else
                ready_time = os.clock()
                log_(LEVEL_ERROR, _text, "Player.Entity.Position is nil")
            end
        else
            ready_time = os.clock()
            log_(LEVEL_ERROR, _text, "Player.Entity is nil")
        end
    until os.clock() - ready_time >= seconds_ready
end

function luminia_row_checked(table, id)
    local sheet = Excel.GetSheet(table)
    if sheet == nil then
        error("Unknown sheet", "sheet not found for", table)
    end
    local row = sheet:GetRow(id)
    if row == nil then
        error("Unknown id", "Id not found in excel data", table, id)
    end
    return row
end

function atk_data_checked(addon, index)
    local w = Addons.GetAddon(addon)
    if not (w.Exists and w.Ready) then
        error("No addon", "addon", addon, "not ready")
    end
    local r = w:GetAtkValue(index)
    if r == nil then
        error("Bad atk index", "addon", addon, "does not have index", index)
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
        error("Bad addon", menu)
    end
    local n = nil
    if menu == "ContextMenu" then
        n = a:GetNode(1, 2, list_index(3, index), 2, 3)
    elseif menu == "RetainerList" then
        n = a:GetNode(1, 27, list_index(4, index), 2, 3)
    elseif menu == "SelectString" or menu == "SelectIconString" then
        n = a:GetNode(1, 3, list_index(5, index), 2)
    else
        error("Unknown addon", menu)
    end
    if tostring(n.NodeType):find("Text:") == nil then
        log_(LEVEL_DEBUG, _text, "Not a text node", "NodeType:", n.NodeType, "NodeId:", n.Id, menu, index)
        log_call_trace(LEVEL_DEBUG)
        return nil
    end
    return n.Text
end

function ListContents(menu)
    menu = default(menu, "ContextMenu")
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
        -- A non-existent table does not contain anything
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

function table_keys(t)
    local keys = {}
    for k, _ in pairs(t) do
        table.insert(keys, k)
    end
    return keys
end

function list_concat(...)
    local result = {}
    local count = 0
    local lists = table.pack(...)
    for i = 1, lists.n do
        local list = lists[i]
        for j = 1, #list do
            result[count + j] = list[j]
        end
        count = count + #list
    end
    return result
end

function SafeCallback(addon, update, ...)
    pause_pyes()
    local callback_table = table.pack(...)
    if type(addon) ~= "string" then
        error("addon name must be a string")
    end
    if type(update) == "boolean" then
        update = tostring(update)
    else
        error("update must be a bool")
    end

    local call_command = "/callback " .. addon .. " " .. update
    for i = 1, callback_table.n do
        local value = callback_table[i]
        if type(value) == "number" then
            call_command = call_command .. " " .. tostring(value)
        elseif type(value) == "string" then
            call_command = call_command .. " \"" .. value .. "\""
        else
            error("Callbacks have to use numbers or strings!")
        end
    end
    log_(LEVEL_DEBUG, _text, "Calling addon with command", call_command)
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
        error("state must be a bool")
    end
end

function string_to_bool(str, truey_values, falsey_values)
    str = str:lower()
    truey_values = default(truey_values, { "true", "on", "yes" })
    falsey_values = default(falsey_values, { "false", "off", "no" })

    for _, v in pairs(truey_values) do
        if str == v:lower() then
            return true
        end
    end

    for _, v in pairs(falsey_values) do
        if str == v:lower() then
            return false
        end
    end
    error("InvalidBooleanString", str)
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
        error("Missing required plugins", "Missing plugins:", table.concat(plugins, ", "))
    end
end

function error(message, ...)
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
    if pyes_pause_count ~= nil and pyes_pause_count > 0 then
        for _, option in pairs(__PAUSE_HANDLES) do
            __pause_request(false, option)
        end
    end
    release_shared_data()
    log("Fatal error:", message, ...)
    log_call_trace(LEVEL_INFO, 1)
    luanet.error(_text(message))
end

NO_CALL_INFO = false

function log_call_trace(log_level, skip_count)
    if NO_CALL_INFO then
        log_(LEVEL_INFO, _text, "Trace disabled")
        return
    end
    log_level = default(log_level, LEVEL_VERBOSE)
    skip_count = default(skip_count, 0)
    local level = 2 + skip_count -- 0 is getinfo, 1 is this function, 2 is the caller
    while true do
        local info = debug.getinfo(level)
        if info == nil then
            break
        end
        log_(log_level, _text, debug_info_tostring(info, true))
        level = level + 1
    end
end

function debug_info_tostring(debug_info, always_string)
    log_(LEVEL_VERBOSE, _table, debug_info, "Raw debug info")
    string = default(string, true)
    local caller = debug_info.name
    if caller == nil and not always_string then
        return nil
    end
    local file = debug_info.short_src:gsub('.*\\', '') .. ":" .. debug_info.currentline
    return _text(default(caller, "<anonymous>"), "in", file)
end

function caller_test()
    test2()
end

function test2()
    error("Test error", "This is a test error")
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
    local msg_tagged = SCRIPT_TAG .. " " .. msg:gsub('\n', '\n' .. SCRIPT_TAG .. " ")
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

function _list(list, header)
    local c = list.Count
    if c == nil then
        return "Not a list (No Count property): " .. tostring(list)
    else
        return _count(list, c, default(header, 'list'))
    end
end

function _array(array, header)
    local c = array.Length
    if c == nil then
        return "Not an array (No Length property): " .. tostring(array)
    else
        return _count(array, c, default(header, 'array'))
    end
end

function _table(list, header)
    local msg = default(header, 'table:')
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

function CheckTimeout(max_duration, wait_info, ...)
    if wait_info == nil then
        error("wait_info is nil", "Must be initialized with ResetTimeout()", ...)
    end
    if max_duration == nil then
        error("max_duration is nil", "Must be provided", ...)
    end
    if os.clock() > wait_info + max_duration then
        error("Max duration reached", ...)
    end
end

function AlertTimeout(max_duration, wait_info, ...)
    if wait_info == nil then
        error("wait_info is nil", "Must be initialized with ResetTimeout()", ...)
    end
    if max_duration == nil then
        error("max_duration is nil", "Must be provided", ...)
    end
    if os.clock() > wait_info + max_duration then
        log("Max duration reached", ...)
        log_call_trace()
        return true
    end
    return false
end

-- delay for longer tasks to avoid complete game freezes
local _LAST_FRAME_TIME = os.clock()
local _MIN_FPS = 10.0
function long_task_delay(min_fps)
    min_fps = default(min_fps, _MIN_FPS)
    if os.clock() - _LAST_FRAME_TIME > 1.0 / min_fps then
        wait(0)
        _LAST_FRAME_TIME = os.clock()
    end
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
-- Skipped import: luasharp.lua
-- Skipped import: hard_ipc.lua
import "System.Numerics"
import "System"

local SPRINT_THRESHOLD = 10
local WALK_THRESHOLD = 35
local FLY_THRESHOLD = 100


local function should_fly(dist)
    --far enough
    if dist > FLY_THRESHOLD then
        return true
    end
    --already mounted, fly unless were right there
    if GetCharacterCondition(4) and dist > SPRINT_THRESHOLD then
        return true
    end
    return false
end

-- TODO: pathfind to get accurate distance, can we do that in a zone were not in?
-- TODO: Option for flight in zones that allow it
function smart_path(place_name, x, y, z)
    local mains, nets = load_aether_info()
    local goal_point = xyz_to_vec3(x, y, z)
    local nearest_shard = nil
    local shard_distance = math.maxinteger
    for _, info in pairs(nets) do
        if info.TerritoryName == place_name then
            if not info.Invisible then
                local dist = Vector3.Distance(info.Position, goal_point)
                if dist < shard_distance then
                    nearest_shard = info
                    shard_distance = dist
                end
            end
        end
    end
    local nearest_main = nil
    local main_distance = math.maxinteger
    for _, info in pairs(mains) do
        if info.TerritoryName == place_name then
            local dist = Vector3.Distance(info.Position, goal_point)
            if dist < main_distance then
                nearest_main = info
                main_distance = dist
            end
        end
    end
    if nearest_shard == nil then
        if nearest_main == nil then
            if luminia_row_checked("TerritoryType", Svc.ClientState.TerritoryType).PlaceName.Name == place_name then
                log_(LEVEL_INFO, _text, "No shard or main crystal, walking")
                WalkTo(x, y, z)
                return
            end
            error("NoRoute", "Could not find any aether crystals or shards in", place_name)
        end
        log_(LEVEL_INFO, _text, "No shard, using main crystal to", nearest_main.TerritoryName, "via", nearest_main.Name)
        TownPath(nearest_main.Name, x, y, z, nil, nearest_main.TerritoryName)
        return
    end
    if shard_distance > main_distance then
        log_(LEVEL_INFO, _text, "Main crystal closer than any shard moving to", nearest_main.TerritoryName, "via",
            nearest_main.Name)
        TownPath(nearest_main.Name, x, y, z, nil, nearest_main.TerritoryName)
        return
    end
    local dest_town = place_name
    local main_town = nil
    for _, info in pairs(mains) do
        if nearest_shard.Group == info.Group then
            main_town = info.Name
            break
        end
    end
    local others = {}
    for _, info in pairs(nets) do
        if nearest_shard.Group == info.Group and not info.Invisible then
            if not (info.TerritoryName == dest_town or
                    info.TerritoryName == main_town or
                    list_contains(others, info.TerritoryName)) then
                table.insert(others, info.TerritoryName)
            end
        end
    end
    log_(LEVEL_INFO, _text, "Aethernet routing to", nearest_shard.Name, "in", dest_town, "via", main_town)
    log_(LEVEL_DEBUG, _table, others, "Alternate locations")
    TownPath(main_town, x, y, z, nearest_shard, dest_town, table.unpack(others))
end

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
            running_lifestream = true
            IPC.Lifestream.ExecuteCommand(tostring(town))
            wait(1)
        until Player.Entity.IsCasting
        ZoneTransition()
    end

    if shard ~= nil then
        if type(shard) ~= "table" then
            local _, shards = load_aether_info()
            for _, info in pairs(shards) do
                if info.Name == shard then
                    shard = info
                    break
                end
            end
        end
        local nearest_shard = closest_aether_group_member(shard.Group)
        if nearest_shard ~= nil then
            local shard_pos = nearest_shard.Position
            local shard_dataid = nearest_shard.DataId
            local shard_name = luminia_row_checked("Aetheryte", shard_dataid).AethernetName.Name
            if current_town == dest_town and path_distance_to(Vector3(x, y, z)) < path_distance_to(shard_pos) then
                log_(LEVEL_DEBUG, _text, "Already nearer to", x, y, z, "than to aethernet", shard_name)
            elseif shard_name == shard.Name then
                log_(LEVEL_DEBUG, _text, "Nearest shard is already", shard_name)
            else
                log_(LEVEL_DEBUG, _text, "Walking to shard", shard_dataid, shard_name, "to warp to", shard.Name)
                WalkTo(shard_pos, nil, nil, 7)
                running_lifestream = true
                IPC.Lifestream.ExecuteCommand(tostring(shard.Name))
                ZoneTransition()
            end
        end
    end

    WalkTo(x, y, z)
end

local aether_info = nil
local net_info = nil
function load_aether_info()
    if aether_info == nil or net_info == nil then
        aether_info = {}
        net_info = {}
        local sheet = Excel.GetSheet("Aetheryte")
        for r = 0, sheet.Count - 1 do
            long_task_delay()
            local row = sheet[r]
            if Instances.Telepo:IsAetheryteUnlocked(r) then
                if row.IsAetheryte then
                    aether_info[row.RowId] = {
                        AetherId = row.RowId,
                        Name = row.PlaceName.Name,
                        TerritoryId = row.Territory.RowId,
                        TerritoryName = row.Territory.PlaceName.Name,
                        Position = Instances.Telepo:GetAetherytePosition(r),
                        Group = row.AethernetGroup,
                    }
                end
                if row.AethernetName.RowId ~= 0 then
                    net_info[row.RowId] = {
                        Group = row.AethernetGroup,
                        Name = row.AethernetName.Name,
                        TerritoryId = row.Territory.RowId,
                        TerritoryName = row.Territory.PlaceName.Name,
                        Position = Instances.Telepo:GetAetherytePosition(r),
                        Invisible = row.Invisible,
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
            error("NoAetheryte", "No aetherite found for", territory_id)
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
        if fly_result == nil then
            log_(LEVEL_DEBUG, _text, "No mesh point found in range", radius, "of", target, "using original target")
            fly_result = target
        end
    end
    log_(LEVEL_DEBUG, _text, "Looking for floor point in range", radius, "of", target)
    result = IPC.vnavmesh.PointOnFloor(target, false, radius)

    if result == nil and (not fly or fly_result == nil) then
        log_(LEVEL_ERROR, _text, "No valid point found in range", radius, "of", spot, "searched from", target)
        return false
    end
    log_(LEVEL_DEBUG, _text, "Found point in area", result, fly_result)
    local path, fly_path
    if fly_result == nil or not should_fly(Vector3.Distance(Player.Entity.Position, result)) then
        path = pathfind_with_tolerance(result, false, radius)
    end
    if fly_result ~= nil and (path == nil or should_fly(path_length(path))) then
        fly_path = pathfind_with_tolerance(fly_result, true, radius)
        if fly_path ~= nil then
            log_(LEVEL_DEBUG, _list, fly_path, "Flying path")
            walk_path(fly_path, true, radius, 0.01, spot)
            return true
        end
        log_(LEVEL_ERROR, _text, "Should fly, but no valid flying path found")
    end
    if path ~= nil then
        log_(LEVEL_DEBUG, _list, path, "Walking path")
        walk_path(path, false, radius, 0.01, spot)
    end
    log_(LEVEL_ERROR, _text, "No valid path found")
    return false
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
        error("Failed to jump", "to point", p)
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
                    error("Stuck during jump", "to point", p, "Landed at", Player.Entity
                        .Position)
                end
            end
        else
            last_pos = Player.Entity.Position
            stuck = nil
        end
    end
    if Vector3.Distance(Player.Entity.Position, p) > 3.0 then
        error("Missed jump", "to point", p, "Landed at", Player.Entity.Position)
    end
    custom_path(false, { p })
    while IPC.vnavmesh.IsRunning() or Player.IsBusy do
        wait(0.1)
    end
    if Vector3.Distance(Player.Entity.Position, p) > 3.0 then
        error("Fell during reposition", "to point", p, "Landed at", Player.Entity.Position)
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
                error("Stuck during walk", "to point", p, "Landed at", Player.Entity.Position)
            end
        else
            last_pos = Player.Entity.Position
            stuck = nil
        end
    end
end

function walk_path(path, fly, range, stop_if_stuck, ref_point, max_stuck_time)
    local stuck_start = os.clock()
    running_vnavmesh = true
    max_stuck_time = default(max_stuck_time, 1)
    stop_if_stuck = default(stop_if_stuck, false)
    ref_point = default(ref_point, path[path.Count - 1])
    local ti = ResetTimeout()
    IPC.vnavmesh.MoveTo(path, fly)
    if not GetCharacterCondition(4) and (fly or path_length(path) > WALK_THRESHOLD) then
        Actions.ExecuteGeneralAction(9)
    end
    local last_pos
    while (IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()) do
        CheckTimeout(60, ti, "Waiting for pathfind")
        local cur_pos = Player.Entity.Position
        if range ~= nil and Vector3.Distance(cur_pos, ref_point) <= range then
            IPC.vnavmesh.Stop()
        end
        if not fly or GetCharacterCondition(4) then
            local now = os.clock()
            if stop_if_stuck and Vector3.Distance(last_pos, cur_pos) < stop_if_stuck then
                if stuck_start + max_stuck_time < now then
                    log_(LEVEL_ERROR, _text, "Antistuck triggered!")
                    IPC.vnavmesh.Stop()
                end
            else
                stuck_start = now
                last_pos = cur_pos
            end
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
    log_(LEVEL_DEBUG, _table, waypoints, "Waypoints:")
    for i, waypoint in pairs(waypoints) do
        if type(waypoint) == "table" then
            local x, y, z = table.unpack(waypoint)
            vec_waypoints[i] = Vector3(x, y, z)
        elseif type(waypoint) == "userdata" then -- it better be a vector3
            vec_waypoints[i] = waypoint
        else
            error("Invalid waypoint type", "Type:", type(waypoint))
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
        error("Invalid coordinates for WalkTo", "Must provide either vec3 or x,y,z", "x:", x,
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
        p = await(IPC.vnavmesh.Pathfind(Player.Entity.Position, pos, false))
    end
    if p.Count == 0 then
        error("No path found", "x:", x, "y:", y, "z:", z, "range:", range)
    end
    log_(LEVEL_VERBOSE, _text, "Walking to", pos, "with range", range)
    if path_length(p) > SPRINT_THRESHOLD then
        log_(LEVEL_VERBOSE, _text, "Path is long, sprinting")
        Actions.ExecuteGeneralAction(4)
    else
        log_(LEVEL_VERBOSE, _text, "Path is short, walking normally")
    end

    IPC.vnavmesh.MoveTo(p, false)

    while (IPC.vnavmesh.IsRunning() or IPC.vnavmesh.PathfindInProgress()) do
        CheckTimeout(30, ti, "Waiting for pathfind")
        if range ~= nil and Vector3.Distance(Player.Entity.Position, pos) <= range then
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
    res = await(invoke_ipc('vnavmesh.Nav.PathfindWithTolerance', Player.Entity.Position, vec3, fly, tolerance))
    if res == nil or res.Count == 0 then
        log_(LEVEL_DEBUG, _text, "No path found to", vec3, "fly:", fly, "tolerance:", tolerance, "res:", res)
        return nil
    end
    return res
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
    wait_ready(30, .5, true, .1)
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
        error("Failed to start route", "Is visland enabled?")
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
        error("No entity found", "Name:", name)
    end
    return EntityWrapper(closest)
end

function closest_aether_group_member(group)
    return raw_closest_thing(aether_group(group), path_dist_to_obj(Player.CanFly))
end

function closest_aethershard(critical)
    critical = default(critical, true)
    local closest = raw_closest_thing(is_aethershard, path_dist_to_obj(Player.CanFly))
    if critical and closest == nil then
        error("No aethershard found")
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
    path = await(IPC.vnavmesh.Pathfind(Player.Entity.Position, vec3, fly))
    if path.Count == 0 then -- if theres no path use the cartesian distance
        return Vector3.Distance(Player.Entity.Position, vec3)
    end
    return path_length(path)
end

function path_length(path)
    local dist = 0
    local prev_point = Player.Entity.Position
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
    return Vector3.Distance(Player.Entity.Position, obj.Position)
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

function aether_group(group)
    return function(obj)
        if not is_aethershard(obj) then return false end
        _, shards = load_aether_info()
        local shard = shards[obj.DataId]
        return shard ~= nil and shard.Group == group
    end
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



if Player.Entity.Position.Y < 20 then
    WalkTo(-41.7, 14, -37.3)
    jump_to_point({ -40.9, 15.5, -35.2 })
    move_to_point({ -41.1, 15.4, -35.3 })
    jump_to_point({ -39.7, 17.2, -37.5 }, .2)
    jump_to_point({ -36.2, 17.4, -39.2 })
    move_to_point({ -36.6, 17.4, -39.3 })
    jump_to_point({ -34.5, 19.2, -39.0 })
    move_to_point({ -33.8, 19.2, -38.4 })
    jump_to_point({ -30.1, 20.9, -38.5 }, .3)
    jump_to_point({ -33.1, 24.0, -41.7 })
else
    log("Higher than start")
end


if Player.Entity.Position.Y < 30 then
    --first landing
    WalkTo(-41, 25.6, -78)
    jump_to_point({ -43.1, 26.6, -78.2 })
    jump_to_point({ -48.8, 26.6, -80.9 })
    jump_to_point({ -51.8, 27.7, -81.7 })
    move_to_point({ -48.6, 27.7, -81.7 })
    jump_to_point({ -52.3, 28.3, -81.7 })
    jump_to_point({ -53.7, 30.0, -81.0 })
    move_to_point({ -54.0, 30.0, -82.7 })
    jump_to_point({ -54.2, 32.7, -78.8 })
else
    log("Higher than first landing")
end


if Player.Entity.Position.Y < 48 then
    --second landing
    WalkTo(-46.1, 40.4, -70.7)
    jump_to_point({ -46.6, 42.1, -70.2 })
    jump_to_point({ -49.5, 43.8, -70.5 })
    jump_to_point({ -52.6, 45.3, -70.4 })
    jump_to_point({ -49.2, 47.1, -70.4 })
    move_to_point({ -49.0, 47.1, -70.9 })
    jump_to_point({ -46.5, 48.9, -70.9 })
    jump_to_point({ -46.6, 51.6, -69.5 }, nil, true)
else
    log("Higher than second landing")
end


if Player.Entity.Position.Y < 57 then
    --third landing
    WalkTo(-52.6, 52.0, -67.5)
    jump_to_point({ -54.3, 53.6, -66.6 })
    jump_to_point({ -57.0, 54.8, -63.2 })
    jump_to_point({ -56.0, 56.1, -58.9 })
    jump_to_point({ -54.7, 57.7, -58.8 })
else
    log("Higher than third landing")
end


if Player.Entity.Position.Y < 89 then
    --posts
    jump_to_point({ -54.9, 59.5, -55.5 })
    jump_to_point({ -54.5, 61.3, -58.0 })
    jump_to_point({ -54.5, 62.8, -56.8 })
    jump_to_point({ -54.9, 64.3, -59.5 })
    jump_to_point({ -55.5, 65.9, -62.0 })
    move_to_point({ -52.1, 67.1, -65.6 })
    --more posts
    jump_to_point({ -49.0, 68.4, -65.5 })
    jump_to_point({ -47.0, 70.2, -65.5 })
    jump_to_point({ -45.5, 72.0, -65.8 })
    jump_to_point({ -48.4, 73.5, -65.8 }, .2)
    jump_to_point({ -50.3, 75.1, -66.0 })
    jump_to_point({ -47.2, 76.4, -65.9 }, .2)
    jump_to_point({ -44.6, 77.3, -65.6 })
    jump_to_point({ -41.2, 79.0, -65.5 })
    move_to_point({ -41.4, 79.0, -65.9 })
    --corner
    jump_to_point({ -39.6, 80.9, -63.3 })
    jump_to_point({ -41.5, 82.2, -61.5 })
    jump_to_point({ -41.5, 82.2, -57.0 }, .4)

    jump_to_point({ -41.1, 83.7, -55.4 })
    move_to_point({ -40.0, 83.7, -55.1 })

    jump_to_point({ -38.9, 85.5, -51.9 }, .2)
    jump_to_point({ -39.8, 87.3, -54.3 })
    jump_to_point({ -40.4, 88.4, -54.4 })
    jump_to_point({ -39.9, 89.7, -52.1 })
    jump_to_point({ -42.2, 89.2, -52.8 }, nil, true)
else
    log("Higher than 4th landing")
end


if Player.Entity.Position.Y < 95 then
    --landing 4
    move_to_point({ -42.0, 89.2, -65.0 })
    jump_to_point({ -42.4, 90.9, -65.8 })
    move_to_point({ -43.4, 90.9, -66.5 })
    jump_to_point({ -40.0, 91.0, -68.7 })
    move_to_point({ -39.8, 91.0, -68.9 })
    jump_to_point({ -38.2, 92.8, -66.9 })
    move_to_point({ -36.6, 92.8, -67.1 })
    jump_to_point({ -37.5, 94.6, -65.5 })
    jump_to_point({ -39.5, 96.6, -65.8 }, nil, true)
else
    log("Higher than top")
end


if Config.Get("LampJump") then
    --the lamp
    move_to_point({ -40.3, 96.4, -64.3 })
    Actions.ExecuteGeneralAction(4)
    wait(1)
    jump_to_point({ -04.4, 05.0, -64.0 }, 1)
end
