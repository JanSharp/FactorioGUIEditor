
local editor_util = require("__gui-editor__.editor_util")
local gui = require("__gui-editor__.gui")
local scripting = depends("__gui-editor__.scripting")
local util = require("__gui-editor__.util")



-- this is the formatter from Phobos with a few modifications to insert the [color] rich text tags

-- NOTE: this is not written with incomplete nodes in mind. It might work with most of them, but
-- for now consider that undefined behavior. _for now_.

local colors = {
  white = "#DCDCDC",
  keyword = "#D55FDE",
  string = "#E29660",
  number = "#D8985F",
  comment = "#7F848E",
  loc = "#A7EF00",
  env = "#2EF1FF",
  value_keyword = "#56E4E9",
  global = "#E06932",
  builtin_global = "#2EF1FF",
  invalid = "#FF0000",
}
local bracket_colors = {
  "#FFD700", -- Gold
  "#DA70D6", -- Orchid
  "#87CEFA", -- LightSkyBlue
}
local open_bracket_lut = util.invert{"(", "[", "{"}
local close_bracket_pair_lut = {
  [")"] = "(",
  ["]"] = "[",
  ["}"] = "{",
}
local bracket_lut = util.invert{"(", "[", "{", ")", "]", "}"}
for name, color in pairs(colors) do
  colors[name] = "[color="..color.."]"
end
for name, color in pairs(bracket_colors) do
  bracket_colors[name] = "[color="..color.."]"
end

---@param main AstMain
local function format(main)
  local out = {}
  local bracket_count = 0
  local bracket_stack = {}

  local add_stat
  local add_scope

  local add_exp
  local add_exp_list

  local exprs
  local add_token
  local add_invalid

  local function add(part)
    out[#out+1] = part
  end

  local function add_colored(color, callback)
    add(color)
    callback()
    add("[/color]")
  end

  local function add_node(node)
    if node.node_type == "token" then
      add_token(node)
    elseif node.node_type == "invalid" then
      add_invalid(node)
    elseif exprs[node.node_type] then
      add_exp(node)
    else
      add_stat(node)
    end
  end

  local function add_string(str)
    if str.src_is_ident then
      add(str.value)
    elseif str.src_is_block_str then
      add("[")
      add(str.src_pad)
      add("[")
      if str.src_has_leading_newline then
        add("\n")
      end
      add(str.value)
      add("]")
      add(str.src_pad)
      add("]")
    else -- regular string
      add(str.src_quote)
      add(str.src_value)
      add(str.src_quote)
    end
  end

  local function add_leading(node)
    for _, token in ipairs(node.leading) do
      if token.token_type == "blank" or token.token_type == "comment" then
        add_token(token)
      else
        error("Invalid leading token_type '"..token.token_type.."'.")
      end
    end
  end

  ---@param token_node Token|AstTokenNode|AstInvalidNode
  function add_token(token_node)
    if not token_node then
      return
    end
    if token_node.node_type == "invalid" then
      add_invalid(token_node)
      return
    end
    if token_node.leading then
      add_leading(token_node)
    end
    if token_node.token_type == "blank" then
      add(token_node.value)
    elseif token_node.token_type == "comment" then
      add_colored(colors.comment, function()
        add("--")
        if token_node.src_is_block_str then
          add_string(token_node)
        else
          add(token_node.value)
        end
      end)
    elseif token_node.token_type == "string" then
      add_colored(colors.string, function()
        add_string(token_node)
      end)
    elseif token_node.token_type == "number" then
      add_colored(colors.number, function()
        add(token_node.src_value)
      end)
    elseif token_node.token_type == "ident" then
      add(token_node.value)
    elseif token_node.token_type == "eof" then
      -- nothing
    elseif token_node.token_type == "invalid" then
      add_colored(colors.invalid, function()
        add(token_node.value)
      end)
    else
      if string.find(token_node.token_type, "^[a-z]")
        and token_node.token_type ~= "and"
        and token_node.token_type ~= "or"
        and token_node.token_type ~= "not"
      then
        add_colored(colors.keyword, function()
          add(token_node.token_type)
        end)
      elseif bracket_lut[token_node.token_type] then
        local color
        if open_bracket_lut[token_node.token_type] then
          color = bracket_colors[(bracket_count % 3) + 1]
          bracket_count = bracket_count + 1
          bracket_stack[bracket_count] = token_node.token_type
        elseif bracket_stack[bracket_count] == close_bracket_pair_lut[token_node.token_type] then
          bracket_count = bracket_count - 1
          color = bracket_colors[(bracket_count % 3) + 1]
        else
          color = colors.invalid
        end
        add_colored(color, function()
          add(token_node.token_type)
        end)
      else
        add(token_node.token_type)
      end
    end
  end

  local function add_invalid_without_wrappers(node)
    for _, consumed_node in ipairs(node.consumed_nodes) do
      add_node(consumed_node)
    end
  end

  function add_invalid(node)
    if node.force_single_result then
      for i = #node.src_paren_wrappers, 1, -1 do
        add_token(node.src_paren_wrappers[i].open_paren_token)
      end
      add_invalid_without_wrappers(node)
      for i = 1, #node.src_paren_wrappers do
        add_token(node.src_paren_wrappers[i].close_paren_token)
      end
    else
      add_invalid_without_wrappers(node)
    end
  end

  ---@param node AstCall
  local function call(node)
    add_exp(node.ex)
    if node.is_selfcall then
      add_token(node.colon_token)
      add_exp(node.suffix)
    end
    if node.open_paren_token then
      add_token(node.open_paren_token)
    end
    add_exp_list(node.args, node.args_comma_tokens)
    if node.close_paren_token then
      add_token(node.close_paren_token)
    end
  end

  ---@param node AstFuncBase|AstMain
  local function add_func_base(node, add_name)
    if not node.is_main then
      add_token(node.func_def.function_token)
      if add_name then
        add_name()
      end
      add_token(node.func_def.open_paren_token)
      add_exp_list(node.func_def.params, node.func_def.param_comma_tokens)
      if node.func_def.is_vararg then
        add_token(node.func_def.vararg_token)
      end
      add_token(node.func_def.close_paren_token)
      add_scope(node.func_def)
      add_token(node.func_def.end_token)
    else
      add_scope(node.func_def)
    end
  end

  local function is_env(node)
    if node.node_type == "upval_ref" and node.name == "_ENV" then
      local def = node.reference_def
      while def.def_type == "upval" do
        def = def.parent_def
      end
      if def.scope.node_type == "env_scope" then
        return true
      end
    end
    return false
  end

  exprs = {
    ---@param node AstLocalReference
    local_ref = function(node)
      add_leading(node)
      add_colored(colors.loc, function()
        add(node.name)
      end)
    end,
    ---@param node AstUpvalReference
    upval_ref = function(node)
      add_leading(node)
      if is_env(node) then
        add_colored(colors.env, function()
          add(node.name)
        end)
      else
        add_colored(colors.loc, function()
          add(node.name)
        end)
      end
    end,
    ---@param node AstIndex
    index = function(node)
      local function add_colored_suffix()
        if node.suffix.node_type == "string" and is_env(node.ex) then
          add_colored(
            scripting.is_builtin_global((node.suffix--[[@as AstString]]).value)
              and colors.builtin_global
              or colors.global,
            function()
              add_exp(node.suffix)
            end
          )
        else
          add_exp(node.suffix)
        end
      end
      if node.src_ex_did_not_exist then
        add_colored_suffix()
      else
        add_exp(node.ex)
        ---@diagnostic disable-next-line: undefined-field
        if node.suffix.node_type == "string" and node.suffix.src_is_ident then
          add_token(node.dot_token)
          add_colored_suffix()
        elseif node.suffix.node_type == "invalid" then
          if node.dot_token then add_token(node.dot_token) end
          if node.suffix_open_token then add_token(node.suffix_open_token) end
          add_invalid(node.suffix)
          if node.suffix_close_token then add_token(node.suffix_close_token) end
        else
          add_token(node.suffix_open_token)
          add_exp(node.suffix)
          add_token(node.suffix_close_token)
        end
      end
    end,
    ---@param node AstString
    string = function(node)
      add_leading(node)
      if node.src_is_ident then
        add_string(node)
      else
        add_colored(colors.string, function()
          add_string(node)
        end)
      end
    end,
    ---@param node AstUnOp
    unop = function(node)
      add_token(node.op_token)
      add_exp(node.ex)
    end,
    ---@param node AstBinOp
    binop = function(node)
      add_exp(node.left)
      add_token(node.op_token)
      add_exp(node.right)
    end,
    ---@param node AstConcat
    concat = function(node)
      add_exp_list(node.exp_list, node.op_tokens, node.concat_src_paren_wrappers)
    end,
    ---@param node AstNumber
    number = function(node)
      add_leading(node)
      add_colored(colors.number, function()
        add(node.src_value)
      end)
    end,
    ---@param node AstNil
    ["nil"] = function(node)
      add_leading(node)
      add_colored(colors.value_keyword, function()
        add("nil")
      end)
    end,
    ---@param node AstBoolean
    boolean = function(node)
      add_leading(node)
      add_colored(colors.value_keyword, function()
        add(tostring(node.value))
      end)
    end,
    ---@param node AstVarArg
    vararg = function(node)
      add_leading(node)
      add_colored(colors.value_keyword, function()
        add("...")
      end)
    end,
    ---@param node AstFuncProto
    func_proto = function(node)
      add_func_base(node)
    end,
    ---@param node AstConstructor
    constructor = function(node)
      add_token(node.open_token)
      ---@type AstListField|AstRecordField
      for i, field in ipairs(node.fields) do
        if field.type == "list" then
          ---@cast field AstListField
          add_exp(field.value)
        else
          ---@cast field AstRecordField
          ---@diagnostic disable-next-line: undefined-field
          if field.key.node_type == "string" and field.key.src_is_ident then
            add_exp(field.key)
          else
            add_token(field.key_open_token)
            add_exp(field.key)
            add_token(field.key_close_token)
          end
          add_token(field.eq_token)
          add_exp(field.value)
        end
        if node.comma_tokens[i] then
          add_token(node.comma_tokens[i])
        end
      end
      add_token(node.close_token)
    end,

    call = call,

    invalid = add_invalid_without_wrappers,

    ---@param node AstInlineIIFE
    inline_iife = function(node)
      error("Cannot format 'inline_iife' nodes.")
    end,
  }

  ---@param node AstExpression
  function add_exp(node)
    if node.force_single_result and node.node_type ~= "concat" then
      for i = #node.src_paren_wrappers, 1, -1 do
        add_token(node.src_paren_wrappers[i].open_paren_token)
      end
      exprs[node.node_type](node)
      for i = 1, #node.src_paren_wrappers do
        add_token(node.src_paren_wrappers[i].close_paren_token)
      end
    else
      exprs[node.node_type](node)
    end
  end

  ---@param list AstExpression[]
  function add_exp_list(list, separator_tokens, concat_src_paren_wrappers)
    ---cSpell:ignore cspw
    local cspw = concat_src_paren_wrappers
    for i, node in ipairs(list) do
      if cspw and cspw[i] then
        for j = #cspw[i], 1, -1 do
          add_token(cspw[i][j].open_paren_token)
        end
      end
      add_exp(node)
      if separator_tokens and separator_tokens[i] then
        add_token(separator_tokens[i])
      end
    end
    if cspw then
      for i = #list - 1, 1, -1 do
        for j = 1, #cspw[i] do
          add_token(cspw[i][j].close_paren_token)
        end
      end
    end
  end

  ---@type table<AstStatement|AstTestBlock|AstElseBlock, fun(node: AstStatement|AstTestBlock|AstElseBlock)>
  local stats = {
    ---@param node AstEmpty
    empty = function(node)
      add_token(node.semi_colon_token)
    end,
    ---@param node AstIfStat
    ifstat = function(node)
      for _, test_block in ipairs(node.ifs) do
        ---@diagnostic disable-next-line:param-type-mismatch
        add_stat(test_block)
      end
      if node.elseblock then
        ---@diagnostic disable-next-line:param-type-mismatch
        add_stat(node.elseblock)
      end
      add_token(node.end_token)
    end,
    ---@param node AstTestBlock
    testblock = function(node)
      add_token(node.if_token)
      add_exp(node.condition)
      add_token(node.then_token)
      add_scope(node)
    end,
    ---@param node AstElseBlock
    elseblock = function(node)
      add_token(node.else_token)
      add_scope(node)
    end,
    ---@param node AstWhileStat
    whilestat = function(node)
      add_token(node.while_token)
      add_exp(node.condition)
      add_token(node.do_token)
      add_scope(node)
      add_token(node.end_token)
    end,
    ---@param node AstDoStat
    dostat = function(node)
      add_token(node.do_token)
      add_scope(node)
      add_token(node.end_token)
    end,
    ---@param node AstForNum
    fornum = function(node)
      add_token(node.for_token)
      add_exp(node.var)
      add_token(node.eq_token)
      add_exp(node.start)
      add_token(node.first_comma_token)
      add_exp(node.stop)
      if node.step then
        add_token(node.second_comma_token)
        add_exp(node.step)
      end
      add_token(node.do_token)
      add_scope(node)
      add_token(node.end_token)
    end,
    ---@param node AstForList
    forlist = function(node)
      add_token(node.for_token)
      add_exp_list(node.name_list, node.comma_tokens)
      add_token(node.in_token)
      add_exp_list(node.exp_list, node.exp_list_comma_tokens)
      add_token(node.do_token)
      add_scope(node)
      add_token(node.end_token)
    end,
    ---@param node AstRepeatStat
    repeatstat = function(node)
      add_token(node.repeat_token)
      add_scope(node)
      add_token(node.until_token)
      add_exp(node.condition)
    end,
    ---@param node AstFuncStat
    funcstat = function(node)
      add_func_base(node, function()
        if node.func_def.is_method then
          assert(node.name.node_type == "index")
          ---@diagnostic disable-next-line: undefined-field
          assert(node.name.dot_token.token_type == ":")
        end
        add_exp(node.name)
      end)
    end,
    ---@param node AstLocalFunc
    localfunc = function(node)
      add_token(node.local_token)
      add_func_base(node, function()
        add_exp(node.name)
      end)
    end,
    ---@param node AstLocalStat
    localstat = function(node)
      add_token(node.local_token)
      add_exp_list(node.lhs, node.lhs_comma_tokens)
      if node.rhs then
        add_token(node.eq_token)
        add_exp_list(node.rhs, node.rhs_comma_tokens)
      end
    end,
    ---@param node AstLabel
    label = function(node)
      add_token(node.open_token)
      add_leading(node.name_token) -- value is nil
      add(node.name)
      add_token(node.close_token)
    end,
    ---@param node AstRetStat
    retstat = function(node)
      add_token(node.return_token)
      if node.exp_list then
        add_exp_list(node.exp_list, node.exp_list_comma_tokens)
      end
      if node.semi_colon_token then
        add_token(node.semi_colon_token)
      end
    end,
    ---@param node AstBreakStat
    breakstat = function(node)
      add_token(node.break_token)
    end,
    ---@param node AstGotoStat
    gotostat = function(node)
      add_token(node.goto_token)
      add_leading(node.target_token) -- value is nil
      add(node.target_name)
    end,
    ---@param node AstAssignment
    assignment = function(node)
      add_exp_list(node.lhs, node.lhs_comma_tokens)
      add_token(node.eq_token)
      add_exp_list(node.rhs, node.rhs_comma_tokens)
    end,

    call = call,

    invalid = add_invalid,

    ---@param node AstInlineIIFERetstat
    inline_iife_retstat = function(node)
      error("Cannot format 'inline_iife_retstat' nodes.")
    end,
    ---@param node AstWhileStat
    loopstat = function(node)
      error("Cannot format 'loopstat' nodes.")
    end,
  }

  ---@param node AstStatement|AstTestBlock|AstElseBlock
  function add_stat(node)
    stats[node.node_type](node)
  end

  ---@param node AstScope
  function add_scope(node)
    local stat = node.body.first
    while stat do
      add_stat(stat--[[@as AstStatement]])
      stat = stat.next
    end
  end

  add_colored(colors.white, function()
    if main.shebang_line then
      add_colored(colors.comment, function()
        add(main.shebang_line)
      end)
    end
    add_scope(main)
    add_leading(main.eof_token)
  end)

  -- dirty way of ensuring formatted code doesn't combine identifiers (or keywords or numbers)
  -- one line comments without a blank token afterwards with a newline in its value can still
  -- "break" formatted code in the sense that it changes the general AST structure, or most likely
  -- causes a syntax error when parsed again
  do
    local prev = out[1]
    local i = 2
    local c = #out
    while i <= c do
      local cur = out[i]
      if cur ~= "" then
        -- there is at least 1 case where this adds an extra space where it doesn't need to,
        -- which is for something like `0xk` where 0x is a malformed number and k is an identifier
        -- but yea, I only know of this one case where it's only with invalid nodes anyway...
        -- all in all this logic here shouldn't be needed at all, i just added it for fun
        -- to see if it would work
        if prev:find("[a-z_A-Z0-9]$") and cur:find("^[a-z_A-Z0-9]") then
          table.insert(out, i, " ")
          i = i + 1
          c = c + 1
        end
        prev = cur
      end
      i = i + 1
    end
  end

  return table.concat(out)
end




local default_value = ""

---@param text string
---@return integer line_count
local function count_lines(text)
  local line_count = 1
  for _ in text:gmatch("\n") do
    line_count = line_count + 1
  end
  return line_count
end

---@param line_count integer
---@return integer pixels
local function calculate_text_box_height(line_count)
  return line_count * 20 + 8
end

---@param editor_state EditorState
local function update_string_editor(editor_state)
  local line_count = count_lines(editor_state.display_value or default_value)
  editor_state.wrap_elem.visible = line_count > 1
  editor_state.text_box_elem.style.height = calculate_text_box_height(line_count)
  editor_state.colored_code_elem.style.height = calculate_text_box_height(line_count)
end

---@param editor_state EditorState
local function update_colored_code_elem(editor_state)
  local ast = editor_state.pre_compile_result and editor_state.pre_compile_result.ast
    or editor_state.editor_data.nodes_to_edit[1]
      .node_fields[editor_state.editor_params.name]--[[@as ScriptVariables]].ast
  editor_state.colored_code_elem.text = ast and format(ast) or ""
end

local on_variables_editor_text_changed = gui.register_handler(
  "on_variables_editor_text_changed",
  ---@param event EventData.on_gui_text_changed
  function(player, tags, event)
    editor_util.on_editor_gui_event(player, tags)
    update_string_editor(editor_util.get_editor_state_from_tags(player, tags))
  end
)

---@param editor_state EditorState
local function create(editor_state)
  local params = editor_state.editor_params
  local main_flow = gui.create_elem(params.parent_elem, {
    type = "flow",
    direction = "vertical",
    style_mods = {horizontally_stretchable = true},
  })
  local tab = editor_util.create_table_without_spacing(main_flow, 2)

  editor_util.create_editor_name_label(tab, editor_state)
  editor_state.wrap_elem = gui.create_elem(tab, {
    type = "empty-widget",
    visible = false,
  })
  local tb_parent = gui.create_elem(tab, {
    type = "flow",
    direction = "horizontal",
    style_mods = {
      vertical_align = "center",
    },
  })
  editor_util.create_error_sprite(tb_parent, editor_state)
  if params.optional then
    editor_util.create_optional_switch(tb_parent, editor_state)
  end
  editor_state.text_box_elem = gui.create_elem(tb_parent, {
    type = "text-box",
    tooltip = params.description,
    elem_mods = {
      read_only = params.readonly,
    },
    style_mods = {
      width = 0,
      horizontally_stretchable = true,
      font = "default-mono",
    },
    tags = editor_util.get_tags(editor_state),
    events = {[defines.events.on_gui_text_changed] = on_variables_editor_text_changed},
  })
  editor_util.create_mixed_values_label(editor_state.text_box_elem, editor_state, true)

  editor_state.colored_code_elem = gui.create_elem(main_flow, {
    type = "text-box",
    elem_mods = {
      selectable = false,
    },
    enabled = false,
    style_mods = {
      width = 0,
      horizontally_stretchable = true,
      font = "default-mono",
    },
  })
  update_colored_code_elem(editor_state)
end

---@param editor_state EditorState
local function validate_display_value(editor_state)
  return true
end

---@param editor_state EditorState
local function pre_process_display_value(editor_state)
  editor_state.pre_compile_result = scripting.pre_compile(
    editor_state.display_value,
    "=("..editor_state.editor_params.name..")"
  )
  update_colored_code_elem(editor_state)
end

---@param editor_state EditorState
---@param value string
local function value_to_display_value(editor_state, value)
  return value
end

---@param editor_state EditorState
---@param display_value string
local function display_value_to_value(editor_state, display_value)
  return display_value
end

---@param editor_state EditorState
local function read_display_value_from_gui(editor_state)
  editor_state.display_value = editor_state.text_box_elem.text
end

---@param editor_state EditorState
local function write_display_value_to_gui(editor_state)
  editor_state.text_box_elem.text = editor_state.display_value or default_value
  update_string_editor(editor_state)
end

---@param editor_state EditorState
local function get_mixed_display_value(editor_state)
  return not editor_state.editor_params.optional and default_value or nil
end

---@param editor_state EditorState
---@param left string?
---@param right string?
local function values_equal(editor_state, left, right)
  return left == right
end

editor_util.add_editor{
  editor_type = "variables",
  create = create,
  validate_display_value = validate_display_value,
  pre_process_display_value = pre_process_display_value,
  value_to_display_value = value_to_display_value,
  display_value_to_value = display_value_to_value,
  read_display_value_from_gui = read_display_value_from_gui,
  write_display_value_to_gui = write_display_value_to_gui,
  get_mixed_display_value = get_mixed_display_value,
  values_equal = values_equal,
}
