------------------------------------------------------------
-- Copyright (c) 2016 tacigar
-- https://github.com/tacigar/maidroid
------------------------------------------------------------

local util = maidroid.util
local _aux = maidroid.modules._aux

local state = {walk = 0, plant = 1, punch = 2}
local max_punch_time = 20
local max_plant_time = 20
local target_tree_list = { "default:tree" }
local target_sapling_list = { "default:sapling" }

-- punchを始める必要があるか否かを調べる
local function check_punch_flag(forward_pos)
  local forward_upper_pos = util.table_shallow_copy(forward_pos)
  while true do
    local forward_upper_node = minetest.get_node(forward_upper_pos)
    if util.table_find_value(target_tree_list, forward_upper_node.name) then
      return true, forward_upper_pos, forward_upper_node
    elseif forward_upper_node.name ~= "air" then break end
    forward_upper_pos.y = forward_upper_pos.y + 1
  end
  return false, nil, nil
end

-- 苗木を持っているかを調べる
local function has_sapling_item(self)
  local inv = maidroid._aux.get_maidroid_inventory(self)
  local stacks = inv:get_list("main")
  for _, stack in ipairs(stacks) do
    local item_name = stack:get_name()
    if util.table_find_value(target_sapling_list, item_name) then
      return true
    end
  end
  return false
end

-- 木こりモジュールを登録する
maidroid.register_module("maidroid:lumberjack", {
  description = "Maidroid Module : Lumberjack",
  inventory_image = "maidroid_lumberjack_module.png",
  initialize = function(self)
    self.state = state.walk
    self.time_count = 0
    self.object:setacceleration{x = 0, y = -10, z = 0}
    self.object:set_animation(maidroid.animations.walk, 15, 0)
    self.preposition = self.object:getpos()
    _aux.change_dir(self)
  end,
  finalize = function(self)
    self.state = nil
    self.time_count = nil
    self.preposition = nil
    self.object:setvelocity{x = 0, y = 0, z = 0}
  end,
  on_step = function(self, dtime)
    local pos = self.object:getpos()
    local rpos = vector.round(pos)
    local yaw = self.object:getyaw()
    local forward = _aux.get_forward(yaw)
    local rforward = _aux.get_round_forward(forward)
    local forward_pos = vector.add(rpos, rforward)
    local forward_node = minetest.get_node(forward_pos)
    local forward_under_pos = _aux.get_under_pos(forward_pos)
    local forward_under_node = minetest.get_node(forward_under_pos)
    if self.state == state.walk then
      if check_punch_flag(forward_pos) then -- punch tree node
	self.state = state.punch
	self.object:set_animation(maidroid.animations.mine, 15, 0)
	self.object:setvelocity{x = 0, y = 0, z = 0}
      elseif pos.x == self.preposition.x or pos.z == self.preposition.z then
	_aux.change_dir(self)
      elseif forward_node.name == "air"
      and minetest.get_item_group(forward_under_node.name, "soil") > 0
      and has_sapling_item(self) then
	self.state = state.plant
	self.object:set_animation(maidroid.animations.mine, 15, 0)
	self.object:setvelocity{x = 0, y = 0, z = 0}
      end
      -- 苗木を拾い集める
      _aux.pickup_item(self, 1.5, function(itemstring)
	return util.table_find_value(target_sapling_list, itemstring) 
      end)
    elseif self.state == state.punch then
      if self.time_count >= max_punch_time then
	local punch_flag, forward_upper_pos, forward_upper_node
	  = check_punch_flag(forward_pos)
	if punch_flag then
	  minetest.remove_node(forward_upper_pos)
	  local inv = minetest.get_inventory{type = "detached", name = self.invname}
	  local stacks = minetest.get_node_drops(forward_upper_node.name)
	  for _, stack in ipairs(stacks) do
	    local leftover = inv:add_item("main", stack)
	    minetest.add_item(forward_pos, leftover)
	  end
	end
	if (not forward_upper_pos) or (forward_upper_pos and
	  not check_punch_flag(_aux.get_upper_pos(forward_upper_pos))) then
	  self.state = state.walk
	  self.object:set_animation(maidroid.animations.walk, 15, 0)
	  _aux.change_dir(self)
	end
	self.time_count = 0
      else
	self.time_count = self.time_count + 1
      end
    elseif self.state == state.plant then
      if self.time_count > max_plant_time then
	if forward_node.name == "air"
	and minetest.get_item_group(forward_under_node.name, "soil") > 0 then
	  local inv = minetest.get_inventory{type = "detached", name = self.invname}
	  local stacks = inv:get_list("main")
	  for i, stack in ipairs(stacks) do
	    local itemname = stack:get_name()
	    if util.table_find_value(target_sapling_list, itemname) then
	      minetest.add_node(forward_pos, {name = itemname, param2 = 1})
	      stack:take_item(1)
	      inv:set_stack("main", i, stack)
	      break
	    end
	  end
	end
	self.state = state.walk
	self.object:set_animation(maidroid.animations.walk, 15, 0)
	self.time_count = 0
	_aux.change_dir(self)
      else
	self.time_count = self.time_count + 1
      end
    end
    self.preposition = pos
  end
})