-- Returns issuing player and target force, or the player and nil on failure
local console_diplo = function(command)
  local player = game.players[command.player_index]

  -- Abort if command came from the default force
  if player.force.name == "player" then
    player.print("Join or create a force if you want to engage in diplomacy.")
    return player
  end

  -- Abort if command has no parameter
  if command.parameter == nil then
    player.print("Command needs a target parameter")
    return player
  end

  -- Abort if the target is a default force name
  if command.parameter == "player" or
     command.parameter == "enemy" or
     command.parameter == "neutral" then
    player.print("Command target cannot be player, enemy, or neutral")
    return player
  end

  local target = game.forces[command.parameter]
  if target == nil then
    -- Parameter is not a valid force name
    player.print("No force named "..command.parameter)
  end

  return player, target
end
local console_friend = function(command)
  local player, target = console_diplo(command)
  if target == nil then return end
  -- Abort if they're already friends
  if player.force.get_friend(target) then
    player.print("Already friends with "..target.name)
    return
  end

  -- Check for existing friend proposal
  local target_prop_table = global.friend_props[target.index]
  if target_prop_table[player.force.index] then
    -- Set them as friends
    player.force.set_friend(target, true)
    target.set_friend(player.force, true)
    -- Delete proposal
    target_prop_table[player.force.index] = nil

    -- Notify both players of the accepted proposal
    player.print("Accepted friendship proposal from "..target.name)
    for i, p in pairs(target.players) do
      if p.connected then
        p.print(player.force.name.." accepted your friendship proposal")
      end
    end

    -- Warn if new friend is marked for attack
    if not player.force.get_cease_fire(target) then
      player.print("Warning: "..target.name..
        " is marked for attack. Use /ceasefire to unmark.")
    end
  else
    -- No proposal exists, so create one
    global.friend_props[player.force.index][target.index] = true
    player.print("Proposed friendship with "..target.name)
    -- Notify other team
    for i, p in pairs(target.players) do
      if p.connected then
        p.print(player.force.name.." proposed friendship with you")
      end
    end
  end
end
local console_unfriend = function(command)
  local player, target = console_diplo(command)
  if target == nil then return end

  -- Check for existing friendship
  local proposals = global.friend_props[player.force.index]
  if player.force.get_friend(target) then
    -- Set them as not friends
    player.force.set_friend(target, false)
    target.set_friend(player.force, false)
    player.print("Broke friendship with "..target.name)
  elseif proposals[target.index] then
    -- Take back offer
    proposals[target.index] = nil
    player.print("Retracted proposal of friendship with "..target.name)
  else
    player.print("Not friends with "..target.name)
  end
end
local console_attack = function(command)
  local player, target = console_diplo(command)
  if target == nil then return end

  player.force.set_cease_fire(target, false)
  console_unfriend(command)
  player.print("Attacking "..command.parameter)
end
local console_ceasefire = function(command)
  local player, target = console_diplo(command)
  if target == nil then return end

  player.force.set_cease_fire(target, true)
  player.print("Ceasing fire on "..command.parameter)
end
local console_suicide = function(command)
  local player = game.players[command.player_index]
  if player.character then
    player.character.die(player.force)
  end
end
local console_splinter = function(command)
  local player = game.players[command.player_index]

  -- Abort if command has no parameter
  if command.parameter == nil then
    player.print("Failed to create team: No name specified")
    return
  end
  --Abort if we ran out of space
  if #game.forces == 64 then
    player.print("Failed to create team: Too many teams")
    return
  end
  --Abort if force name is taken
  if game.forces[command.parameter] then
    player.print("Failed to create team: Name taken")
    return
  end

  player.force = game.create_force(command.parameter)
  player.print("Created team: "..command.parameter)
end
local console_invite = function(command)
  local player = game.players[command.player_index]

  -- Abort if invite comes from default team
  if player.force.index == 1 then return end
  -- Abort if command has no parameter
  if command.parameter == nil then
    player.print("Failed to invite: No player specified")
    return
  end
  -- Abort if target doesn't exist
  local target = game.players[command.parameter]
  if target == nil then
    player.print("Failed to invite: "..command.parameter..
      " isn't a player name")
    return
  end
  -- Abort if target already joined
  if target.force == player.force then
    player.print("Failed to invite: "..target.name.." already joined")
    return
  end

  global.invites[player.force.index][target.index] = true
  player.print("Invited "..target.name)
  if target.connected then
    target.print("You have been invited to join "..player.force.name)
  end
end
local console_join = function(command)
  local player = game.players[command.player_index]

  -- Abort if command has no parameter
  if command.parameter == nil then
    player.print("Failed to join: No team specified")
    return
  end
  -- Abort if target doesn't exist
  local target = game.forces[command.parameter]
  if target == nil then
    player.print("Failed to join: "..command.parameter.." isn't a team name")
    return
  end
  -- Abort if already joined
  if target == player.force then
    player.print("Failed to join: Already joined")
    return
  end

  -- Join if invited
  local invites = global.invites[target.index]
  if invites[player.index] then
    player.force = target
    invites[player.index] = nil
    player.print("Joined "..target.name)
  else
    player.print("Failed to join "..target.name..": Not invited")
  end
end
local register_commands = function()
  -- Various commands for setting stance and friendly status
  commands.add_command("friend",    "", console_friend)
  commands.add_command("unfriend",  "", console_unfriend)
  commands.add_command("attack",    "", console_attack)
  commands.add_command("ceasefire", "", console_ceasefire)
  -- Instant character death
  commands.add_command("suicide",   "", console_suicide)
  -- Attempt to create a new team
  commands.add_command("splinter",  "", console_splinter)
  -- Invite a player to the team
  commands.add_command("invite",  "", console_invite)
  -- Accept an existing invite
  commands.add_command("join",  "", console_join)
end


-- Unused, but kept for compatibility with other mods
local created_items = function()
  return {}
end
local respawn_items = function()
  return {}
end
script.on_init(function()
  -- Set the starting items
  global.created_items = created_items()
  global.respawn_items = respawn_items()

  -- Register commands for the first time
  register_commands()
  -- Initialize friend proposal system
  global.friend_props = {}
  global.invites = {}
end)
script.on_load(function()
  -- Register commands again
  register_commands()
end)
script.on_configuration_changed(function(event)
  -- Start items maybe changed
  global.created_items = global.created_items or created_items()
  global.respawn_items = global.respawn_items or respawn_items()
end)
-- Interface for other mods to change settings
-- Pretend to be the freeplay scenario for compatibility with other mods
remote.add_interface("freeplay",
{
  get_created_items = function()
    return global.created_items
  end,
  set_created_items = function(map)
    global.created_items = map
  end,
  get_respawn_items = function()
    return global.respawn_items
  end,
  set_respawn_items = function(map)
    global.respawn_items = map
  end,
  set_chart_distance = function(value)
    global.chart_distance = tonumber(value)
  end
})


-- Destroy teams without alive characters
local kill = function(force)
  -- Attempt not destruction of the default force
  if force.index == 1 then return end

  local name = force.name
  -- Prevent default force from inheriting map or tech
  force.reset()
  game.merge_forces(force, "player")
  -- Tell everyone of the destroyed force
  for i, player in pairs(game.players) do
    if player.connected then player.print(name..
      " has run out of characters, and is thus destroyed!") end
  end
end
script.on_event(defines.events.on_entity_died, function(event)
  local force = event.entity.force
  -- Dead characters still exist, but with zero health.
  -- Check if this is the final character
  if force.get_entity_count("character") == 1 then kill(force) end
end,
  {{filter = "type", type = "character"}}
)
script.on_event(defines.events.on_player_changed_force, function(event)
  local force = event.force
  if force.get_entity_count("character") == 0 then kill(force) end
end)


-- Handle new/removed forces
script.on_event(defines.events.on_forces_merging, function(event)
  -- Clear proposals from removed force
  global.friend_props[event.source.index] = nil
  global.invites[event.source.index] = nil

  -- Delete proposals targeting removed force
  for i, proposals in pairs(global.friend_props) do
    proposals[event.source.index] = nil
  end
end)
script.on_event(defines.events.on_force_created, function(event)
  -- Initialize friend proposals
  global.friend_props[event.force.index] = {}
  global.invites[event.force.index] = {}
  -- Always share charting with friends
  event.force.share_chart = true
end)


-- Handle new/removed players
script.on_event(defines.events.on_pre_player_removed, function(event)
  -- Delete invites targeting removed player
  for i, proposals in pairs(global.invites) do
    proposals[event.player_index] = nil
  end
end)
script.on_event(defines.events.on_player_created, function(event)
  -- Give new player items
  local player = game.players[event.player_index]
  for i, v in pairs(global.created_items) do
    player.insert{name = i, count = v}
  end
end)
script.on_event(defines.events.on_player_died, function(event)
  local player = game.players[event.player_index]
  -- Because of Persistent Character, when a player dies, it's because they ran
  -- out of available characters to switch to instead of dying.
  -- Kicking player to the default force should ensure that their respawn
  -- doesn't (immediately) contribute to the character count of their force.
  player.force = game.forces.player
end)
script.on_event(defines.events.on_player_respawned, function(event)
  local player = game.players[event.player_index]

  -- Give respawned player items
  for i, v in pairs(global.respawn_items) do
    player.insert{name = i, count = v}
  end
  -- Free initial charting, disabled by default
  if global.chart_distance and global.chart_distance > 0 then
    local r_vec = {x = global.chart_distance, y = global.chart_distance}
    player.force.chart(
      player.surface,
      {player.position - r_vec, player.position + r_vec}
    )
  end
end)
