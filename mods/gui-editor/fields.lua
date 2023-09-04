local a={}a[1]={"textfield",}a[2]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="allow_decimal",["subclasses"]=a[1],["order"]=0x1.bp+5,["description"]="Whether this textfield (when in numeric mode) allows decimal numbers.",["read"]=true,}a[3]={"textfield",}a[4]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="allow_negative",["subclasses"]=a[3],["order"]=0x1.b8p+5,["description"]="Whether this textfield (when in numeric mode) allows negative numbers.",["read"]=true,}a[5]={"This can't be set to false if the current switch_state is 'none'.",}a[6]={"switch",}a[7]={["type"]="boolean",["notes"]=a[5],["order"]=0x1.0cp+6,["optional"]=false,["name"]="allow_none_state",["subclasses"]=a[6],["read"]=true,["description"]="Whether the `\"none\"` state is allowed for this switch.",["write"]=true,}a[8]={["type"]="GuiAnchor",["optional"]=true,["name"]="anchor",["write"]=true,["order"]=0x1.f8p+5,["description"]="The anchor for this relative widget, if any. Setting `nil` clears the anchor.",["read"]=true,}a[9]={"frame",}a[10]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="auto_center",["subclasses"]=a[9],["order"]=0x1.bp+4,["description"]="Whether this frame auto-centers on window resize when stored in [LuaGui::screen](runtime:LuaGui::screen).",["read"]=true,}a[11]={"button","sprite-button",}a[12]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="auto_toggle",["subclasses"]=a[11],["order"]=0x1.dp+4,["description"]="Whether this button will automatically toggle when clicked.",["read"]=true,}a[13]={"tab",}a[14]={["type"]="LocalisedString",["write"]=true,["optional"]=false,["name"]="badge_text",["subclasses"]=a[13],["order"]=0x1.cp+4,["description"]="The text to display after the normal tab text (designed to work with numbers)",["read"]=true,}a[15]={"Whilst this attribute may be used on all elements without producing an error, it doesn't make sense for tables and flows as they won't display it.",}a[16]={["type"]="LocalisedString",["notes"]=a[15],["optional"]=false,["name"]="caption",["write"]=true,["order"]=0x1p+2,["description"]="The text displayed on this element. For frames, this is the \"heading\". For other elements, like buttons or labels, this is the content.",["read"]=true,}a[17]={["complex_type"]="array",["value"]="LuaGuiElement",}a[18]={["type"]=a[17],["optional"]=false,["name"]="children",["write"]=false,["order"]=0x1.5p+4,["description"]="The child-elements of this GUI element.",["read"]=true,}a[19]={["complex_type"]="array",["value"]="string",}a[20]={["type"]=a[19],["optional"]=false,["name"]="children_names",["write"]=false,["order"]=0x1.4p+3,["description"]="Names of all the children of this element. These are the identifiers that can be used to access the child as an attribute of this element.",["read"]=true,}a[21]={"textfield","text-box",}a[22]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="clear_and_focus_on_right_click",["subclasses"]=a[21],["order"]=0x1.dp+5,["description"]="Makes it so right-clicking on this textfield clears and focuses it.",["read"]=true,}a[23]={"sprite-button",}a[24]={["type"]="SpritePath",["write"]=true,["optional"]=false,["name"]="clicked_sprite",["subclasses"]=a[23],["order"]=0x1p+4,["description"]="The sprite to display on this sprite-button when it is clicked.",["read"]=true,}a[25]={"table",}a[26]={["type"]="uint",["write"]=false,["optional"]=false,["name"]="column_count",["subclasses"]=a[25],["order"]=0x1.88p+5,["description"]="The number of columns in this table.",["read"]=true,}a[27]={"frame","flow","line",}a[28]={["type"]="string",["write"]=false,["optional"]=false,["name"]="direction",["subclasses"]=a[27],["order"]=0x1.8p+2,["description"]="Direction of this element's layout. May be either `\"horizontal\"` or `\"vertical\"`.",["read"]=true,}a[29]={"Only top-level elements in [LuaGui::screen](runtime:LuaGui::screen) can be `drag_target`s.",}a[30]={"This creates a frame that contains a dragging handle which can move the frame. \
```\
local frame = player.gui.screen.add{type=\"frame\", direction=\"vertical\"}\
local dragger = frame.add{type=\"empty-widget\", style=\"draggable_space\"}\
dragger.style.size = {128, 24}\
dragger.drag_target = frame\
```",}a[31]={"flow","frame","label","table","empty-widget",}a[32]={["type"]="LuaGuiElement",["notes"]=a[29],["order"]=0x1.d8p+5,["write"]=true,["optional"]=true,["examples"]=a[30],["subclasses"]=a[31],["read"]=true,["description"]="The `frame` that is being moved when dragging this GUI element, if any. This element needs to be a child of the `drag_target` at some level.",["name"]="drag_target",}a[33]={"table",}a[34]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="draw_horizontal_line_after_headers",["subclasses"]=a[33],["order"]=0x1.8p+5,["description"]="Whether this table should draw a horizontal grid line below the first table row.",["read"]=true,}a[35]={"table",}a[36]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="draw_horizontal_lines",["subclasses"]=a[35],["order"]=0x1.78p+5,["description"]="Whether this table should draw horizontal grid lines.",["read"]=true,}a[37]={"table",}a[38]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="draw_vertical_lines",["subclasses"]=a[37],["order"]=0x1.7p+5,["description"]="Whether this table should draw vertical grid lines.",["read"]=true,}a[39]={"Writing to this field does not change or clear the currently selected element.",}a[40]={"This will configure a choose-elem-button of type `\"entity\"` to only show items of type `\"furnace\"`. \
```\
button.elem_filters = {{filter = \"type\", type = \"furnace\"}}\
```","Then, there are some types of filters that work on a specific kind of attribute. The following will configure a choose-elem-button of type `\"entity\"` to only show entities that have their `\"hidden\"` [flags](runtime:EntityPrototypeFlags) set. \
```\
button.elem_filters = {{filter = \"hidden\"}}\
```","Lastly, these filters can be combined at will, taking care to specify how they should be combined (either `\"and\"` or `\"or\"`. The following will filter for any `\"entities\"` that are `\"furnaces\"` and that are not `\"hidden\"`. \
```\
button.elem_filters = {{filter = \"type\", type = \"furnace\"}, {filter = \"hidden\", invert = true, mode = \"and\"}}\
```",}a[41]={"choose-elem-button",}a[42]={["type"]="PrototypeFilter",["notes"]=a[39],["order"]=0x1.38p+5,["write"]=true,["optional"]=true,["examples"]=a[40],["subclasses"]=a[41],["read"]=true,["description"]="The elem filters of this choose-elem-button, if any. The compatible type of filter is determined by `elem_type`.",["name"]="elem_filters",}a[43]={"choose-elem-button",}a[44]={["type"]="string",["write"]=false,["optional"]=false,["name"]="elem_type",["subclasses"]=a[43],["order"]=0x1.28p+5,["description"]="The elem type of this choose-elem-button.",["read"]=true,}a[45]={"string","SignalID",}a[46]={["complex_type"]="union",["options"]=a[45],["full_format"]=false,}a[47]={"The `\"signal\"` type operates with [SignalID](runtime:SignalID), while all other types use strings.",}a[48]={"choose-elem-button",}a[49]={["type"]=a[46],["notes"]=a[47],["order"]=0x1.3p+5,["optional"]=true,["name"]="elem_value",["subclasses"]=a[48],["read"]=true,["description"]="The elem value of this choose-elem-button, if any.",["write"]=true,}a[50]={["type"]="boolean",["optional"]=false,["name"]="enabled",["write"]=true,["order"]=0x1.58p+5,["description"]="Whether this GUI element is enabled. Disabled GUI elements don't trigger events when clicked.",["read"]=true,}a[51]={"entity-preview","camera","minimap",}a[52]={["type"]="LuaEntity",["write"]=true,["optional"]=true,["name"]="entity",["subclasses"]=a[51],["order"]=0x1.fp+5,["description"]="The entity associated with this entity-preview, camera, minimap, if any.",["read"]=true,}a[53]={"minimap",}a[54]={["type"]="string",["write"]=true,["optional"]=true,["name"]="force",["subclasses"]=a[53],["order"]=0x1.2p+5,["description"]="The force this minimap is using, if any.",["read"]=true,}a[55]={["type"]="defines.game_controller_interaction",["optional"]=false,["name"]="game_controller_interaction",["write"]=true,["order"]=0x1.fp+4,["description"]="How this element should interact with game controllers.",["read"]=true,}a[56]={["type"]="LuaGui",["optional"]=false,["name"]="gui",["write"]=false,["order"]=0x1p+0,["description"]="The GUI this element is a child of.",["read"]=true,}a[57]={"scroll-pane",}a[58]={["type"]="string",["write"]=true,["optional"]=false,["name"]="horizontal_scroll_policy",["subclasses"]=a[57],["order"]=0x1.2p+4,["description"]="Policy of the horizontal scroll bar. Possible values are `\"auto\"`, `\"never\"`, `\"always\"`, `\"auto-and-reserve-space\"`, `\"dont-show-but-allow-scrolling\"`.",["read"]=true,}a[59]={"sprite-button",}a[60]={["type"]="SpritePath",["write"]=true,["optional"]=false,["name"]="hovered_sprite",["subclasses"]=a[59],["order"]=0x1.ep+3,["description"]="The sprite to display on this sprite-button when it is hovered.",["read"]=true,}a[61]={["type"]="boolean",["optional"]=false,["name"]="ignored_by_interaction",["write"]=true,["order"]=0x1.6p+5,["description"]="Whether this GUI element is ignored by interaction. This makes clicks on this element 'go through' to the GUI element or even the game surface below it.",["read"]=true,}a[62]={["type"]="uint",["optional"]=false,["name"]="index",["write"]=false,["order"]=0x0p+0,["description"]="The index of this GUI element (unique amongst the GUI elements of a LuaPlayer).",["read"]=true,}a[63]={"textfield",}a[64]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="is_password",["subclasses"]=a[63],["order"]=0x1.cp+5,["description"]="Whether this textfield displays as a password field, which renders all characters as `*`.",["read"]=true,}a[65]={["complex_type"]="array",["value"]="LocalisedString",}a[66]={"drop-down","list-box",}a[67]={["type"]=a[65],["write"]=true,["optional"]=false,["name"]="items",["subclasses"]=a[66],["order"]=0x1.6p+4,["description"]="The items in this dropdown or listbox.",["read"]=true,}a[68]={"switch",}a[69]={["type"]="LocalisedString",["write"]=true,["optional"]=false,["name"]="left_label_caption",["subclasses"]=a[68],["order"]=0x1.1p+6,["description"]="The text shown for the left switch label.",["read"]=true,}a[70]={"switch",}a[71]={["type"]="LocalisedString",["write"]=true,["optional"]=false,["name"]="left_label_tooltip",["subclasses"]=a[70],["order"]=0x1.14p+6,["description"]="The tooltip shown on the left switch label.",["read"]=true,}a[72]={["type"]="GuiLocation",["optional"]=true,["name"]="location",["write"]=true,["order"]=0x1.ap+4,["description"]="The location of this widget when stored in [LuaGui::screen](runtime:LuaGui::screen). `nil` if not set or not in [LuaGui::screen](runtime:LuaGui::screen).",["read"]=true,}a[73]={"choose-elem-button",}a[74]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="locked",["subclasses"]=a[73],["order"]=0x1.68p+5,["description"]="Whether this choose-elem-button can be changed by the player.",["read"]=true,}a[75]={"textfield",}a[76]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="lose_focus_on_confirm",["subclasses"]=a[75],["order"]=0x1.c8p+5,["description"]="Whether this textfield loses focus after [defines.events.on_gui_confirmed](runtime:defines.events.on_gui_confirmed) is fired.",["read"]=true,}a[77]={"minimap",}a[78]={["type"]="uint",["write"]=true,["optional"]=false,["name"]="minimap_player_index",["subclasses"]=a[77],["order"]=0x1.18p+5,["description"]="The player index this minimap is using.",["read"]=true,}a[79]={"button","sprite-button",}a[80]={["type"]="MouseButtonFlags",["write"]=true,["optional"]=false,["name"]="mouse_button_filter",["subclasses"]=a[79],["order"]=0x1.ap+5,["description"]="The mouse button filters for this button or sprite-button.",["read"]=true,}a[81]={"```\
game.player.gui.top.greeting.name == \"greeting\"\
```",}a[82]={["type"]="string",["write"]=true,["optional"]=false,["name"]="name",["read"]=true,["order"]=0x1.8p+1,["description"]="The name of this element. `\"\"` if no name was set.",["examples"]=a[81],}a[83]={"sprite-button",}a[84]={["type"]="double",["write"]=true,["optional"]=false,["name"]="number",["subclasses"]=a[83],["order"]=0x1.8p+4,["description"]="The number to be shown in the bottom right corner of this sprite-button. Set this to `nil` to show nothing.",["read"]=true,}a[85]={"textfield",}a[86]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="numeric",["subclasses"]=a[85],["order"]=0x1.a8p+5,["description"]="Whether this textfield is limited to only numberic characters.",["read"]=true,}a[87]={["type"]="string",["optional"]=false,["name"]="object_name",["write"]=false,["order"]=0x1.24p+6,["description"]="The class name of this object. Available even when `valid` is false. For LuaStruct objects it may also be suffixed with a dotted path to a member of the struct.",["read"]=true,}a[88]={["type"]="LuaGuiElement",["optional"]=true,["name"]="parent",["write"]=false,["order"]=0x1p+1,["description"]="The direct parent of this element. `nil` if this is a top-level element.",["read"]=true,}a[89]={["type"]="uint",["optional"]=false,["name"]="player_index",["write"]=false,["order"]=0x1.8p+3,["description"]="Index into [LuaGameScript::players](runtime:LuaGameScript::players) specifying the player who owns this element.",["read"]=true,}a[90]={"camera","minimap",}a[91]={["type"]="MapPosition",["write"]=true,["optional"]=false,["name"]="position",["subclasses"]=a[90],["order"]=0x1p+5,["description"]="The position this camera or minimap is focused on, if any.",["read"]=true,}a[92]={["type"]="boolean",["optional"]=false,["name"]="raise_hover_events",["write"]=true,["order"]=0x1.04p+6,["description"]="Whether this element will raise [on_gui_hover](runtime:on_gui_hover) and [on_gui_leave](runtime:on_gui_leave).",["read"]=true,}a[93]={"text-box",}a[94]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="read_only",["subclasses"]=a[93],["order"]=0x1.5p+5,["description"]="Whether this text-box is read-only. Defaults to `false`.",["read"]=true,}a[95]={"sprite",}a[96]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="resize_to_sprite",["subclasses"]=a[95],["order"]=0x1.cp+3,["description"]="Whether the sprite widget should resize according to the sprite in it. Defaults to `true`.",["read"]=true,}a[97]={"switch",}a[98]={["type"]="LocalisedString",["write"]=true,["optional"]=false,["name"]="right_label_caption",["subclasses"]=a[97],["order"]=0x1.18p+6,["description"]="The text shown for the right switch label.",["read"]=true,}a[99]={"switch",}a[100]={["type"]="LocalisedString",["write"]=true,["optional"]=false,["name"]="right_label_tooltip",["subclasses"]=a[99],["order"]=0x1.1cp+6,["description"]="The tooltip shown on the right switch label.",["read"]=true,}a[101]={"text-box",}a[102]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="selectable",["subclasses"]=a[101],["order"]=0x1.4p+5,["description"]="Whether the contents of this text-box are selectable. Defaults to `true`.",["read"]=true,}a[103]={"drop-down","list-box",}a[104]={["type"]="uint",["write"]=true,["optional"]=false,["name"]="selected_index",["subclasses"]=a[103],["order"]=0x1.7p+4,["description"]="The selected index for this dropdown or listbox. Returns `0` if none is selected.",["read"]=true,}a[105]={"tabbed-pane",}a[106]={["type"]="uint",["write"]=true,["optional"]=true,["name"]="selected_tab_index",["subclasses"]=a[105],["order"]=0x1.ep+5,["description"]="The selected tab index for this tabbed pane, if any.",["read"]=true,}a[107]={"sprite-button",}a[108]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="show_percent_for_small_numbers",["subclasses"]=a[107],["order"]=0x1.9p+4,["description"]="Related to the number to be shown in the bottom right corner of this sprite-button. When set to `true`, numbers that are non-zero and smaller than one are shown as a percentage rather than the value. For example, `0.5` will be shown as `50%` instead.",["read"]=true,}a[109]={"slider",}a[110]={["type"]="double",["write"]=true,["optional"]=false,["name"]="slider_value",["subclasses"]=a[109],["order"]=0x1.98p+5,["description"]="The value of this slider element.",["read"]=true,}a[111]={"sprite-button","sprite",}a[112]={["type"]="SpritePath",["write"]=true,["optional"]=false,["name"]="sprite",["subclasses"]=a[111],["order"]=0x1.ap+3,["description"]="The sprite to display on this sprite-button or sprite in the default state.",["read"]=true,}a[113]={"checkbox","radiobutton",}a[114]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="state",["subclasses"]=a[113],["order"]=0x1.6p+3,["description"]="Is this checkbox or radiobutton checked?",["read"]=true,}a[115]={"LuaStyle","string",}a[116]={["complex_type"]="union",["options"]=a[115],["full_format"]=false,}a[117]={["type"]=a[116],["optional"]=false,["name"]="style",["write"]=true,["order"]=0x1.cp+2,["description"]="The style of this element. When read, this evaluates to a [LuaStyle](runtime:LuaStyle). For writing, it only accepts a string that specifies the textual identifier (prototype name) of the desired style.",["read"]=true,}a[118]={"camera","minimap",}a[119]={["type"]="uint",["write"]=true,["optional"]=false,["name"]="surface_index",["subclasses"]=a[118],["order"]=0x1.08p+5,["description"]="The surface index this camera or minimap is using.",["read"]=true,}a[120]={"If [LuaGuiElement::allow_none_state](runtime:LuaGuiElement::allow_none_state) is false this can't be set to `\"none\"`.",}a[121]={"switch",}a[122]={["type"]="string",["notes"]=a[120],["order"]=0x1.08p+6,["optional"]=false,["name"]="switch_state",["subclasses"]=a[121],["read"]=true,["description"]="The switch state (left, none, right) for this switch.",["write"]=true,}a[123]={["complex_type"]="array",["value"]="TabAndContent",}a[124]={"tabbed-pane",}a[125]={["type"]=a[123],["write"]=false,["optional"]=false,["name"]="tabs",["subclasses"]=a[124],["order"]=0x1.e8p+5,["description"]="The tabs and contents being shown in this tabbed-pane.",["read"]=true,}a[126]={["type"]="Tags",["optional"]=false,["name"]="tags",["write"]=true,["order"]=0x1p+6,["description"]="The tags associated with this LuaGuiElement.",["read"]=true,}a[127]={"textfield","text-box",}a[128]={["type"]="string",["write"]=true,["optional"]=false,["name"]="text",["subclasses"]=a[127],["order"]=0x1.2p+3,["description"]="The text contained in this textfield or text-box.",["read"]=true,}a[129]={"button","sprite-button",}a[130]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="toggled",["subclasses"]=a[129],["order"]=0x1.ep+4,["description"]="Whether this button is currently toggled. When a button is toggled, it will use the `selected_graphical_set` and `selected_font_color` defined in its style.",["read"]=true,}a[131]={["type"]="LocalisedString",["optional"]=false,["name"]="tooltip",["write"]=true,["order"]=0x1.1p+4,["description"]="The text to display when hovering over this element. Writing `\"\"` will disable the tooltip, while writing `nil` will set it to `\"nil\"`.",["read"]=true,}a[132]={["type"]="string",["optional"]=false,["name"]="type",["write"]=false,["order"]=0x1.4p+4,["description"]="The type of this GUI element.",["read"]=true,}a[133]={["type"]="boolean",["optional"]=false,["name"]="valid",["write"]=false,["order"]=0x1.2p+6,["description"]="Is this object valid? This Lua object holds a reference to an object within the game engine. It is possible that the game-engine object is removed whilst a mod still holds the corresponding Lua object. If that happens, the object becomes invalid, i.e. this attribute will be `false`. Mods are advised to check for object validity if any change to the game state might have occurred between the creation of the Lua object and its access.",["read"]=true,}a[134]={"progressbar",}a[135]={["type"]="double",["write"]=true,["optional"]=false,["name"]="value",["subclasses"]=a[134],["order"]=0x1.4p+2,["description"]="How much this progress bar is filled. It is a value in the range [0, 1].",["read"]=true,}a[136]={"table",}a[137]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="vertical_centering",["subclasses"]=a[136],["order"]=0x1.9p+5,["description"]="Whether the content of this table should be vertically centered. Overrides [LuaStyle::column_alignments](runtime:LuaStyle::column_alignments). Defaults to `true`.",["read"]=true,}a[138]={"scroll-pane",}a[139]={["type"]="string",["write"]=true,["optional"]=false,["name"]="vertical_scroll_policy",["subclasses"]=a[138],["order"]=0x1.3p+4,["description"]="Policy of the vertical scroll bar. Possible values are `\"auto\"`, `\"never\"`, `\"always\"`, `\"auto-and-reserve-space\"`, `\"dont-show-but-allow-scrolling\"`.",["read"]=true,}a[140]={["type"]="boolean",["optional"]=false,["name"]="visible",["write"]=true,["order"]=0x1p+3,["description"]="Sets whether this GUI element is visible or completely hidden, taking no space in the layout.",["read"]=true,}a[141]={"text-box",}a[142]={["type"]="boolean",["write"]=true,["optional"]=false,["name"]="word_wrap",["subclasses"]=a[141],["order"]=0x1.48p+5,["description"]="Whether this text-box will word-wrap automatically. Defaults to `false`.",["read"]=true,}a[143]={"camera","minimap",}a[144]={["type"]="double",["write"]=true,["optional"]=false,["name"]="zoom",["subclasses"]=a[143],["order"]=0x1.1p+5,["description"]="The zoom this camera or minimap is using. This value must be positive.",["read"]=true,}a[145]={a[2],a[4],a[7],a[8],a[10],a[12],a[14],a[16],a[18],a[20],a[22],a[24],a[26],a[28],a[32],a[34],a[36],a[38],a[42],a[44],a[49],a[50],a[52],a[54],a[55],a[56],a[58],a[60],a[61],a[62],a[64],a[67],a[69],a[71],a[72],a[74],a[76],a[78],a[80],a[82],a[84],a[86],a[87],a[88],a[89],a[91],a[92],a[94],a[96],a[98],a[100],a[102],a[104],a[106],a[108],a[110],a[112],a[114],a[117],a[119],a[122],a[125],a[126],a[128],a[130],a[131],a[132],a[133],a[135],a[137],a[139],a[140],a[142],a[144],}return a[145]