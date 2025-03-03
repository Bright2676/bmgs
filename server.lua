local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local bmgs_folder = ReplicatedStorage:WaitForChild("BMGS")
local events_folder = bmgs_folder:FindFirstChild("Events")
local viewmodels_folder = bmgs_folder:FindFirstChild("Viewmodels")

local weapon_fired_event = events_folder.WeaponFired
local client_handler_event = events_folder.ClientHandler

local server_handler_functions = {
	on_weapon_fired = function(player, direction, mouse_aim, weapon_damage)
		client_handler_event:FireAllClients(player)
		
		local ray_direction = direction.LookVector.Unit * 100
		local ray_params = RaycastParams.new()
		
		ray_params.FilterDescendantsInstances = {player.Character}
		ray_params.FilterType = Enum.RaycastFilterType.Exclude
		
		local ray_origin = player.Character:FindFirstChildOfClass("Tool").Barrel.Position
		local ray_result = workspace:Raycast(ray_origin, ray_direction, ray_params)
		if ray_result then
			local hit_part = ray_result.Instance
			local character_model = hit_part.Parent
			local part = Instance.new("Part")
			part.Size = Vector3.new(0.2, 0.2, (ray_result.Position - ray_origin).Magnitude)
			part.CFrame = CFrame.lookAt(ray_origin, ray_result.Position) * CFrame.new(0, 0, -part.Size.Z / 2)
			part.Parent = workspace
			part.BrickColor = BrickColor.new("Medium stone grey")
			part.Transparency = 0.5
			part.Anchored = true
			part.CanCollide = false
			Debris:AddItem(part, .033)
			
			if character_model and character_model:FindFirstChildOfClass("Humanoid") then
				if hit_part:IsDescendantOf(character_model) then
					if hit_part.Parent:IsA("Accessory") then
						character_model:FindFirstChild("Humanoid"):TakeDamage(weapon_damage)
						--local humanoid = hit_part.Parent.Parent:FindFirstChildOfClass("Humanoid")
						--humanoid:TakeDamage(weapon_damage)
					elseif hit_part.Parent.Parent:IsA("Accessory") then
						character_model:FindFirstChild("Humanoid"):TakeDamage(weapon_damage)
						--local humanoid = hit_part.Parent.Parent.Parent:FindFirstChildOfClass("Humanoid")
						--humanoid:TakeDamage(weapon_damage)
					else
						character_model:FindFirstChild("Humanoid"):TakeDamage(weapon_damage)
						--local humanoid = character_model:FindFirstChildOfClass("Humanoid")
						--humanoid:TakeDamage(weapon_damage)
					end
					
					if hit_part.Name == "Head" then
						local adjusted_damage = weapon_damage * 1.33
						character_model:FindFirstChild("Humanoid"):TakeDamage(adjusted_damage)
					end
				end
			end
		end
		
	end,
}

weapon_fired_event.OnServerEvent:Connect(function(player, direction, mouse_aim, weapon_damage)
	server_handler_functions.on_weapon_fired(player, direction, mouse_aim, weapon_damage)
end)