
local parser = require("__phobos__.parser")
local jump_linker = require("__phobos__.jump_linker")
local fold_const = require("__phobos__.optimize.fold_const")
local fold_control_statements = require("__phobos__.optimize.fold_control_statements")
local compiler = require("__phobos__.compiler")
local dump = require("__phobos__.dump")
local error_code_util = require("__phobos__.error_code_util")
local ast_walker = require("__phobos__.ast_walker")
local ll = require("__gui-editor__.linked_list")
local util = require("__gui-editor__.util")
local nodes = depends("__gui-editor__.nodes")
---cSpell:ignore lualib
local factorio_util = require("__core__.lualib.util")

---@type table<ScriptVariables, fun()>
local compiled_value_lut = {}

---cSpell:ignore rcon, loadstring
local fake_env = factorio_util.copy{
  -- _G = _G,
  assert = assert,
  collectgarbage = collectgarbage,
  error = error,
  getmetatable = getmetatable,
  ipairs = ipairs,
  load = load,
  ---@diagnostic disable-next-line: deprecated
  loadstring = loadstring,
  next = next,
  pairs = pairs,
  pcall = pcall,
  print = print,
  rawequal = rawequal,
  rawlen = rawlen,
  rawget = rawget,
  rawset = rawset,
  select = select,
  setmetatable = setmetatable,
  tonumber = tonumber,
  tostring = tostring,
  type = type,
  xpcall = xpcall,
  _VERSION = _VERSION,
  ---@diagnostic disable-next-line: deprecated
  unpack = unpack,
  table = table,
  string = string,
  bit32 = bit32,
  math = math,
  debug = debug,
  serpent = serpent,
  log = log,
  localised_print = localised_print,
  table_size = table_size,
  -- package = package,
  -- require = require,
  -- global = global,
  -- remote = remote,
  -- commands = commands,
  -- settings = settings,
  -- rcon = rcon,
  -- rendering = rendering,
  -- script = script,
  -- defines = defines,
  util = factorio_util,
}
fake_env._G = fake_env

local variable_types = {
  static = 1,
  dynamic = 2,
}

local field_name_lut = {
  [variable_types.static] = "static_variables",
  [variable_types.dynamic] = "dynamic_variables",
}

local function is_builtin_global(name)
  return fake_env[name] ~= nil
end

---@param field_name string
local function create_script_variables(field_name)
  ---@type ScriptVariables
  local variables = {
    field_name = field_name,
    value = "",
    display_value = "",
    compiled_byte_code = nil,
    input_variable_references = {},
    output_variables = {},
  }
  return variables
end

---@param player_data PlayerData
---@param reference ScriptVariableReference
local function add_unresolved_reference(player_data, reference)
  local references = player_data.unresolved_variable_references[reference.variable_name]
  if not references then
    references = ll.new_list(false)
    player_data.unresolved_variable_references[reference.variable_name] = references
  end
  ll.append(references, reference)
end

---@param player_data PlayerData
---@param reference ScriptVariableReference
local function remove_unresolved_reference(player_data, reference)
  local references = player_data.unresolved_variable_references[reference.variable_name]
  ll.remove(references, reference)
  if not references.first then
    player_data.unresolved_variable_references[reference.variable_name] = nil
  end
end

---@param player_data PlayerData
---@param reference ScriptVariableReference
local function add_reference(player_data, reference)
  if reference.variable then
    ll.append(reference.variable.references, reference)
  else
    add_unresolved_reference(player_data, reference)
  end
end

---@param player_data PlayerData
---@param reference ScriptVariableReference
local function remove_reference(player_data, reference)
  if reference.variable then
    ll.remove(reference.variable.references, reference)
  else
    remove_unresolved_reference(player_data, reference)
  end
end

---@param search_node Node? @ search includes this node
---@param variable_type ScriptVariableType
---@param variable_name string
local function find_variable(search_node, variable_type, variable_name)
  local field_name = field_name_lut[variable_type]
  local static_field_name = field_name_lut[variable_types.static]
  while search_node do
    local variables = search_node.node_fields[field_name]--[[@as ScriptVariables]]
    local variable = variables.output_variables[variable_name]
    if variable then
      return variable
    end
    if variable_type == variable_types.dynamic then
      variables = search_node.node_fields[static_field_name]--[[@as ScriptVariables]]
      variable = variables.output_variables[variable_name]
      if variable then
        return variable
      end
    end
    search_node = search_node.parent
  end
end

---@param player_data PlayerData
---@param source_node Node
---@param source_type ScriptVariableType
---@param variable_name string
local function get_reference(player_data, source_node, source_type, variable_name)
  local variable
  if source_type == variable_types.dynamic then
    variable = find_variable(source_node.parent, variable_types.dynamic, variable_name)
  end
  variable = variable or find_variable(source_node.parent, variable_types.static, variable_name)
  ---@type ScriptVariableReference
  local reference = {
    source_type = source_type,
    source_node = source_node,
    variable_name = variable_name,
    variable = variable, -- could be nil, which is fine because it means "unresolved"
  }
  add_reference(player_data, reference)
  return reference
end

---@param player_data PlayerData
---@param reference ScriptVariableReference
---@param referenced_variable ScriptVariable?
local function set_referenced_variable(player_data, reference, referenced_variable)
  remove_reference(player_data, reference)
  reference.variable = referenced_variable
  add_reference(player_data, reference)
end

---@param player_data PlayerData
---@param reference ScriptVariableReference
---@param referenced_variable ScriptVariable?
local function try_set_referenced_variable(player_data, reference, referenced_variable)
  if referenced_variable
    and reference.source_type == variable_types.static
    and referenced_variable.variable_type == variable_types.dynamic
  then
    -- cannot link a static reference to a dynamic variable
    return false
  end
  set_referenced_variable(player_data, reference, referenced_variable)
  return true
end

local function add_validation_error(position, context, get_msg)
  position = position and (" at "..(position.line or 0)..":"..(position.column or 0)) or ""
  context.validation_errors[#context.validation_errors+1] = get_msg(position)
end

local function try_get_index_into_env(index, context)
  if index.ex.node_type == "upval_ref" then
    local def = index.ex.reference_def
    while def.def_type == "upval" do
      def = def.parent_def
    end
    if def.scope.node_type == "env_scope" then
      if index.suffix.node_type ~= "string" then
        add_validation_error(index.suffix_open_token, context, function(position)
          return "Invalid index into _ENV, must use a literal string"..position.."."
        end)
        return
      end
      return index.suffix.value
    end
  end
end

---@param reference ScriptVariableReference
local function get_source_variables(reference)
  return reference.source_node.node_fields[field_name_lut[reference.source_type]]--[[@as ScriptVariables]]
end

---@param player_data PlayerData
---@param variables ScriptVariables
local function set_variables_dirty(player_data, variables)
  player_data.dirty_variables[variables] = true
end

---@param player_data PlayerData
---@param variable ScriptVariable
---@param value any?
local function set_variable_value(player_data, variable, value)
  if variable.value ~= value then
    variable.value = value
    local reference = variable.references.first
    while reference do
      set_variables_dirty(player_data, get_source_variables(reference))
      reference = reference.next
    end
  end
end

local update_dirty_variables

local on_open = {
  ["assignment"] = function(node, context)
    for _, expr in pairs(node.lhs) do
      if expr.node_type == "index" then
        local name = try_get_index_into_env(expr, context)
        context.visited_index_nodes[expr] = true
        if name then
          if is_builtin_global(name) then
            add_validation_error(expr.suffix, context, function(position)
              return "Attempt to assign to builtin global '"..name.."'"..position.."."
            end)
            return
          end
          context.output_variable_names[name] = true
        end
      end
    end
  end,
  ["index"] = function(node, context)
    if context.visited_index_nodes[node] then return end
    local name = try_get_index_into_env(node, context)
    if name and not is_builtin_global(name) then -- only create input_variables for non builtin globals
      context.input_variable_names[name] = true
    end
  end,
}

---@param variables ScriptVariables
local function prepare_fake_env(variables)
  for _, reference in pairs(variables.input_variable_references) do
    if reference.variable then
      fake_env[reference.variable_name] = reference.variable.value
    end
  end
end

---@param variables ScriptVariables @ the variable that just ran and therefore used fake_env
local function cleanup_fake_env(variables)
  for _, reference in pairs(variables.input_variable_references) do
    fake_env[reference.variable_name] = nil
  end
  for _, variable in pairs(variables.output_variables) do
    fake_env[variable.variable_name] = nil
  end
end

local function xpcall_message_handler(msg)
  msg = debug.traceback(msg, 2)
  local index = msg:find("\n%s*__gui%-editor__/")
  if index then
    msg = msg:sub(1, index - 1)
  end
  return "runtime error: "..msg
end

local max_errors_shown = 8
---@param source string
---@param source_name string
local function pre_compile(source, source_name)
  local result = {}

  -- parse
  ---@param errors table
  local function get_message_for_list(errors)
    return error_code_util.get_message_for_list(errors, "syntax errors", max_errors_shown)
  end
  local ast, parser_errors = parser(source, source_name)
  -- variables.ast = ast
  result.ast = ast
  if parser_errors[1] then
    result.error_msg = get_message_for_list(parser_errors)
    result.error_code_instances = parser_errors
    return result
  end
  local jump_linker_errors = jump_linker(ast)
  if jump_linker_errors[1] then
    result.error_msg = get_message_for_list(jump_linker_errors)
    result.error_code_instances = jump_linker_errors
    return result
  end
  result.error_code_instances = nil

  -- analyze
  local context = ast_walker.new_context(on_open, nil)
  result.context = context
  context.validation_errors = {}
  context.visited_index_nodes = {}
  context.input_variable_names = {}
  context.output_variable_names = {}
  ast_walker.walk_scope(ast, context)
  if context.validation_errors then
    result.error_msg = "Invalid script:\n"..table.concat(context.validation_errors, "\n")
    return result
  end
  result.successful_analysis = true

  -- compile
  local compiled = compiler(ast, true)
  local byte_code = dump(compiled)
  local compiled_value, err = load(byte_code, nil, "b", fake_env)
  if not compiled_value then
    error(err) -- Phobos generated broken byte code
  end
  result.byte_code = byte_code
  result.compiled_value = compiled_value

  return result
end

---@param player_data PlayerData
---@param variables ScriptVariables
---@param pre_compile_result table?
local function compile_variables(player_data, variables, pre_compile_result)
  pre_compile_result = pre_compile_result
    or pre_compile(variables.display_value, "=("..variables.field_name..")")

  variables.ast = pre_compile_result.ast
  variables.error_code_instances = pre_compile_result.error_code_instances
  if not pre_compile_result.successful_analysis then
    return nil, pre_compile_result.error_msg
  end

  local context = pre_compile_result.context

  -- prepare variables
  do
    local prev_input_variable_references = variables.input_variable_references
    variables.input_variable_references = {}
    local names = context.input_variable_names

    -- reuse references
    for name in pairs(names) do
      if prev_input_variable_references[name] then
        variables.input_variable_references[name] = prev_input_variable_references[name]
        prev_input_variable_references[name] = nil
        names[name] = nil -- absolute last instruction in the loop
      end
    end

    -- find new references
    local search_node = variables.node.parent
    while search_node and next(names) do
      local output_variables = search_node.static_variables.output_variables
      for name in pairs(names) do
        if output_variables[name] then
          local variable = output_variables[name]
          ---@type ScriptVariableReference
          local reference = {
            source_type = variable_types.static,
            source_node = variables.node,
            variable_name = name,
            variable = variable,
          }
          add_reference(player_data, reference)
          variables.input_variable_references[name] = reference
          names[name] = nil -- absolute last instruction in the loop
        end
      end
      search_node = search_node.parent
    end

    -- remove old references
    for _, reference in pairs(prev_input_variable_references) do
      remove_reference(player_data, reference)
    end

    -- missing references
    for name in pairs(names) do
      ---@type ScriptVariableReference
      local reference = {
        source_type = variable_types.static,
        source_node = variables.node,
        variable_name = name,
        variable = nil,
      }
      add_reference(player_data, reference)
      variables.input_variable_references[name] = reference
    end

    -- load values into `fake_env`
    prepare_fake_env(variables)
  end

  -- run
  local compiled_value = pre_compile_result.compiled_value
  local success, err = xpcall(compiled_value, xpcall_message_handler)
  if not success then
    cleanup_fake_env(variables)
    return nil, err
  end

  -- success, save values
  do
    variables.value = variables.display_value
    variables.compiled_byte_code = pre_compile_result.byte_code
    compiled_value_lut[variables] = compiled_value

    -- update output_variables

    local prev_output_variables = variables.output_variables
    variables.output_variables = {}
    local names = context.output_variable_names
    local search_node = variables.node.parent

    -- TODO: validate output values

    -- reuse
    for name in pairs(names) do
      local variable = prev_output_variables[name]
      if variable then
        set_variable_value(player_data, variable, fake_env[name])
        variables.output_variables[name] = variable
        prev_output_variables[name] = nil
        names[name] = nil -- absolute last instruction in the loop
      end
    end

    -- create new
    for name in pairs(context.output_variable_names) do
      local variable = {
        variable_type = variable_types.static,
        variable_name = name,
        value = fake_env[name],
        defining_node = variables.node,
        references = ll.new_list(false),
      }
      variables.output_variables[name] = variable

      ---@param references ScriptVariableReferenceList
      local function update_references(references)
        if not references then return end
        local reference = references.first
        while reference do
          if nodes.is_child_of(reference.source_node, variables.node)
            and try_set_referenced_variable(player_data, reference, variable)
          then
            set_variables_dirty(player_data, get_source_variables(reference))
          end
          reference = reference.next
        end
      end

      -- searches for both dynamic and static
      local shadowed_variable = find_variable(search_node, variable_types.dynamic, name)
      if shadowed_variable then
        update_references(shadowed_variable.references)
        if shadowed_variable.variable_type == variable_types.dynamic then
          -- if we found a dynamic variable then we might still be shadowing a static variable
          shadowed_variable = find_variable(shadowed_variable.defining_node, variable_types.static, name)
          if shadowed_variable then
            update_references(shadowed_variable.references)
          else -- shadowed a dynamic variable, but there might be unresolved static references
            update_references(player_data.unresolved_variable_references[name])
          end
        end
      else -- didn't find anything, check in unresolved variables
        update_references(player_data.unresolved_variable_references[name])
      end
    end

    -- remove old
    for _, variable in pairs(prev_output_variables) do
      local reference = variable.references.first
      local new_dynamic_variable = find_variable(search_node, variable_types.dynamic, variable.variable_name)
      local new_static_variable
      if new_dynamic_variable then
        if new_dynamic_variable.variable_type == variable_types.static then
          new_static_variable = new_dynamic_variable
        else
          new_static_variable = find_variable(new_dynamic_variable.defining_node, variable_types.static, variable.variable_name)
        end
      end
      while reference do
        if reference.source_type == variable_types.static then
          set_referenced_variable(player_data, reference, new_static_variable)
        else
          set_referenced_variable(player_data, reference, new_dynamic_variable)
        end
        set_variables_dirty(player_data, get_source_variables(reference))
        reference = reference.next
      end
    end
  end

  cleanup_fake_env(variables)
  update_dirty_variables(player_data)
end

---@param player_data PlayerData
---@param variables ScriptVariables
local function evaluate_variable_values(player_data, variables)
  local compiled_value = compiled_value_lut[variables]
  if not compiled_value then
    compile_variables(player_data, variables)
    return
  end

  prepare_fake_env(variables)
  local success, err = xpcall(compiled_value, xpcall_message_handler)
  if not success then
    -- TODO: ensure that the display is updated as well if these variables currently have an editor
    variables.error_msg = err
    cleanup_fake_env(variables)
    return
  end

  -- TODO: validate output value
  for name, variable in pairs(variables.output_variables) do
    set_variable_value(player_data, variable, fake_env[name])
  end
  cleanup_fake_env(variables)
  update_dirty_variables(player_data)
end

---@param player_data PlayerData
function update_dirty_variables(player_data)
  if player_data.currently_updating_dirty_variables then return end
  player_data.currently_updating_dirty_variables = true
  for variables in pairs(player_data.dirty_variables) do
    evaluate_variable_values(player_data, variables)
    player_data.dirty_variables[variables] = nil
  end
  player_data.currently_updating_dirty_variables = nil
end

---@param variables ScriptVariables
local function restore_variables(variables)
  if variables.compiled_byte_code then
    compiled_value_lut[variables] = load(variables.compiled_byte_code, nil, "b", fake_env)
  end
end

---@class __gui-editor__.scripting
local result = {
  create_script_variables = create_script_variables,
  pre_compile = pre_compile,
  compile_variables = compile_variables,
  restore_variables = restore_variables,
  is_builtin_global = is_builtin_global,
}
return result
