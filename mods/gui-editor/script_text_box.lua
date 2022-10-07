
local gui = require("__gui-editor__.gui")
local scripting = depends("__gui-editor__.scripting")
local util = require("__gui-editor__.util")
local error_code_util = require("__phobos__.error_code_util")

-- this is the formatter from Phobos with a few modifications to insert [color] rich text tags

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
local function format_colored(main)
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



---@param text string
---@return integer line_count
---@return integer longest_line
---@return integer last_line_length
local function count_lines(text)
  local line_count = 1
  local longest_line
  local last_line_length
  do
    local line_start, line_end = text:find("[^\n]*")
    last_line_length = line_end - line_start + 1
    longest_line = last_line_length
  end
  for line_start, line_end in text:gmatch("\n()[^\n]*()") do
    line_count = line_count + 1
    last_line_length = line_end - line_start
    if last_line_length > longest_line then
      longest_line = last_line_length
    end
  end
  return line_count, longest_line, last_line_length
end

-- font: default-mono, font size: 14
local char_width = 8
local char_height = 20
local tb_padding = 4
local scroll_bar_size = 12

---@param stb_state ScriptTextBoxState
---@param line_count integer
---@return integer pixels
local function calculate_text_box_height(stb_state, line_count)
  local minimal_height = stb_state.minimal_size.height - scroll_bar_size
  return math.max(line_count * char_height + tb_padding * 2, minimal_height)
end

---@param stb_state ScriptTextBoxState
---@param line_count integer
---@param longest_line integer
---@return integer line_numbers_lb_width
---@return integer text_box_width
local function calculate_widths(stb_state, line_count, longest_line)
  local line_numbers_lb_width = (#tostring(line_count)) * char_width
  -- 4 -- left margin for line numbers
  -- 4 -- left margin for the separator line
  -- 4 -- line separator width
  local min_width = stb_state.minimal_size.width - 4 - line_numbers_lb_width - 4 - 4 - scroll_bar_size
  -- 4 -- one extra character to prevent a flash of the text box's scroll bars appearing, because
  --      the character didn't fit with the current size (before the on text changed even fires)
  --      and then 3 more to make it less cramped
  -- 1 - the flash mentioned previously still happened, so 1 extra pixel and it went away
  return line_numbers_lb_width, math.max((longest_line + 4) * char_width + tb_padding * 2 + 1, min_width)
end

---@param stb_state ScriptTextBoxState
local function update_sizes(stb_state)
  local line_count, longest_line, last_line_length = count_lines(stb_state.text)
  stb_state.line_count = line_count
  stb_state.last_line_length = last_line_length
  local height = calculate_text_box_height(stb_state, line_count)
  local line_numbers_lb_width, width = calculate_widths(stb_state, line_count, longest_line)
  stb_state.flow.style.height = height
  stb_state.tb_width = width
  stb_state.main_tb.style.width = width
  stb_state.colored_tb.style.width = width
  stb_state.colored_tb.style.left_margin = -width
  stb_state.line_numbers_lb.style.width = line_numbers_lb_width
  local line_numbers = {}
  local pattern = "%"..#tostring(line_count).."d"
  for i = 1, line_count do
    line_numbers[i] = string.format(pattern, i)
  end
  stb_state.line_numbers_lb.caption = table.concat(line_numbers, "\n")
end

---updates the text for `main_tb`
---@param stb_state ScriptTextBoxState
---@param text string
local function set_text(stb_state, text)
  stb_state.text = text
  stb_state.main_tb.text = text
  update_sizes(stb_state)
end

---updates the text for `colored_tb`
---@param stb_state ScriptTextBoxState
---@param ast AstMain
---@param error_code_instances ErrorCodeInstance[]
local function set_ast(stb_state, ast, error_code_instances)
  stb_state.colored_tb.text = ast and format_colored(ast) or ""

  -- TODO: combine errors at the same location into one sprite with a combined tooltip

  local last_i = 0
  if error_code_instances then
    for i, error_code_instance in pairs(error_code_instances) do
      last_i = i
      local sprite = stb_state.error_sprites[i]
      if not sprite then
        sprite = stb_state.flow.add{
          type = "sprite",
          sprite = "gui-editor-script-error",
        }
        stb_state.error_sprites[i] = sprite
      end
      local style = sprite.style

      -- NOTE: I'd like to remove the ' at line:column' part of the message, but unfortunately [...]
      -- it is apart of the location_str which contains more text than just the 'at' part. Like
      -- ' near foo at 1:1' for example. So we can't just remove the location_str
      -- and I don't want to add a pattern based string operation here right now
      sprite.tooltip = error_code_util.get_message(error_code_instance)

      local sprite_width = 8
      local sprite_height = 6
      local y = tb_padding - sprite_height
        + (error_code_instance.start_position.line or stb_state.line_count) * char_height
      style.top_margin = y
      local x = -stb_state.tb_width + tb_padding
        + (error_code_instance.start_position.column or (stb_state.last_line_length + 1)) * char_width
        - sprite_width
      style.left_margin = x
      style.bottom_margin = -y - sprite_height
      style.right_margin = -x - sprite_width
    end
  end

  for i = last_i + 1, #stb_state.error_sprites do
    stb_state.error_sprites[i].destroy()
    stb_state.error_sprites[i] = nil
  end
end

local on_script_text_box_text_changed = gui.register_handler(
  "on_script_text_box_text_changed",
  ---@param event EventData.on_gui_text_changed
  function(player, tags, event)
    local stb_state = player.stb_states_by_id[tags.stb_id]
    stb_state.text = stb_state.main_tb.text
    update_sizes(stb_state)
  end
)

---@class CreateScriptTextBoxParams
---@field starting_text string?
---@field tooltip LocalisedString?
---@field tags any?
---@field on_text_changed GUIEventHandler
---@field read_only boolean?
---@field maximal_size Size
---@field minimal_size Size

---@param player PlayerData
---@param parent_elem LuaGuiElement
---@param params CreateScriptTextBoxParams
local function create(player, parent_elem, params)
  local starting_text = params.starting_text or ""
  local tags = params.tags or {}
  local stb_id = player.next_stb_id
  player.next_stb_id = stb_id + 1
  tags.stb_id = stb_id

  -- concept:
  -- frame (maximal size)
  --   scroll-pane (inherits size from content)
  --     flow (horizontal, calculated height, calculated min height)
  --       label
  --       line
  --       text-box (calculated width, calculated min width)
  --       text-box (calculated width, calculated min width)

  local frame, inner = gui.create_elem(parent_elem, {
    type = "frame",
    style = "deep_frame_in_shallow_frame",
    style_mods = {
      maximal_width = params.maximal_size.width,
      maximal_height = params.maximal_size.height,
      horizontally_stretchable = false,
      vertically_stretchable = false,
      horizontally_squashable = false,
      vertically_squashable = false,
    },
    children = {
      {
        type = "scroll-pane",
        style = "naked_scroll_pane",
        vertical_scroll_policy = "auto-and-reserve-space",
        horizontal_scroll_policy = "auto-and-reserve-space",
        children = {
          {
            type= "flow",
            name = "flow",
            direction = "horizontal",
            style_mods = {
              horizontal_spacing = 0,
            },
            children = {
              {
                type = "label",
                name = "line_numbers_lb",
                caption = "1",
                style_mods = {
                  font = "default-mono",
                  left_margin = 4,
                  top_margin = 4,
                  single_line = false,
                },
              },
              {
                type = "line",
                direction = "vertical",
                style_mods = {
                  vertically_stretchable = true,
                  left_margin = 4,
                  right_margin = 0,
                },
              },
              {
                type = "text-box",
                name = "main_tb",
                text = starting_text,
                tooltip = params.tooltip,
                elem_mods = {
                  read_only = params.read_only,
                },
                style = "gui_editor_invisible_textbox",
                style_mods = {
                  padding = 4,
                  maximal_width = 0,
                  vertically_stretchable = true,
                  font = "default-mono",
                  ---cSpell:ignore FiraCode
                  -- NOTE: the cursor also seems to be using the font_color, so it has to be non-invisible [...]
                  -- there might be a way to abuse rich text, but the text boxes should have rich text disabled.
                  -- so the other option is to keep the font_color white, but make it a "light" version of the
                  -- font, or make the colored text box use a "bold" version of the font. But factorio doesn't
                  -- ship with either of those versions for mono spaced fonts, so the gui editor would have to
                  -- come with its own font. I'd probably just use FiraCode, because I'm familiar with it.
                  font_color = {1, 1, 1, 1},
                },
                tags = tags,
                events = {
                  [defines.events.on_gui_text_changed] = {
                    on_script_text_box_text_changed,
                    params.on_text_changed,
                  },
                },
              },
              {
                type = "text-box",
                name = "colored_tb",
                ignored_by_interaction = true,
                style = "gui_editor_invisible_textbox",
                style_mods = {
                  padding = 4,
                  maximal_width = 0,
                  vertically_stretchable = true,
                  font = "default-mono",
                },
              },
            },
          },
        },
      },
    },
  })
  ---@type ScriptTextBoxState
  local stb_state = {
    stb_id = stb_id,
    frame = frame,
    text = starting_text,
    flow = inner.flow,
    main_tb = inner.main_tb,
    colored_tb = inner.colored_tb,
    line_numbers_lb = inner.line_numbers_lb,
    error_sprites = {},
    maximal_size = params.maximal_size,
    minimal_size = params.minimal_size,
  }
  player.stb_states_by_id[stb_id] = stb_state
  update_sizes(stb_state)
  return stb_state
end

---@param player PlayerData
local function init_player(player)
  player.stb_states_by_id = {}
  player.next_stb_id = 1
end

---@class __gui-editor__.script_text_box
return {
  set_text = set_text,
  set_ast = set_ast,
  create = create,
  init_player = init_player,
}
