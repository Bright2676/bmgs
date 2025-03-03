--[[

	Bright's Modular Gun System (BMGS)
	Version 2.0
	
	InDev - expect bugs

]]--

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local debug_mode = true
local tool = nil
local equipped = false
local reloading = false
local firing = false
local client_cooldown = false
local viewmodel = nil
local aiming = false

local sounds_folder = nil
local config_folder = nil

local equip_sound = nil
local reload_sound = nil
local fire_sound = nil

local cooldown = nil
local ammo_value = nil
local maxammo_value = nil
local automatic_value = nil
local recoil_value = nil

local recoil_amount = 0.5
local recoil_speed = 0.1
local max_recoil = 1
local current_recoil = 0

local aim_cframe = CFrame.new()

local viewmodel_folder = ReplicatedStorage.BMGS.Viewmodels
local events_folder = ReplicatedStorage.BMGS.Events

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local player_character: Model = player.Character or player.CharacterAdded:Wait()
local player_humanoid = player_character:WaitForChild("Humanoid")

local gun_ui = player.PlayerGui.gun_ui
local gun_ui_frame = gun_ui.main

local gun_ui_name = gun_ui_frame.WeaponName
local gun_ui_ammo = gun_ui_frame.Ammo
local gun_ui_maxammo = gun_ui_frame.MaxAmmo

gun_functions = {
	ads = function()
		if not equipped then return end
		if not aiming then
			aiming = true
			
			if aiming and viewmodel ~= nil then
				local offset = viewmodel:FindFirstChild("AimPart").CFrame:ToObjectSpace(viewmodel.PrimaryPart.CFrame)
				aim_cframe = aim_cframe:Lerp(offset, .1)
			else
				local offset = CFrame.new()
				aim_cframe = aim_cframe:Lerp(offset, .1)
			end
		end
	end,
	
	recoil = function()
		local randY = math.random(-1, 1) * 0.00015
		local randZ = math.random(-1, 1) * 0.00035

		local oldCFrame = workspace.CurrentCamera.CFrame
		local tweenProperties = {
			CFrame = workspace.CurrentCamera.CFrame * CFrame.Angles(0.01, math.rad(randY), math.rad(randZ)) -- Smaller angles
		}
		local recoilTween = game:GetService("TweenService"):Create(
			workspace.CurrentCamera,
			TweenInfo.new(0.03, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0),
			tweenProperties
		)

		local current_fov = workspace.CurrentCamera.FieldOfView
		local distance = (workspace.CurrentCamera.CFrame.Position - workspace.CurrentCamera.Focus.Position).Magnitude
		local is_first_person = distance <= 0.75

		if is_first_person then
			recoilTween:Play()
		end
	end,

	reload_gun = function()
		if equipped and ammo_value.Value >= 0 then
			reloading = true
			reload_sound:Play()
			task.wait(reload_sound.TimeLength)
			ammo_value.Value = maxammo_value.Value
			print(tostring(ammo_value.Value.." / "..maxammo_value.Value))
			gun_ui_ammo.Text = tostring(ammo_value.Value)
			gun_ui_maxammo.Text = tostring(maxammo_value.Value)
		elseif equipped == not equipped then
			print("[BMGS]: Gun is unequipped")
		elseif ammo_value.Value >= 1 then
			print("[BMGS]: Gun ammo is above required value")
		else
			print("[BMGS]: Unknown statement")
		end
	end,

	fire_gun_client = function()
		if client_cooldown or not equipped then return end
		if ammo_value.Value <= 0 and not reloading then
			gun_functions.reload_gun()
		else
			gun_functions.recoil()
			
			if viewmodel then
				local root_fire_anim = viewmodel:WaitForChild("Animations"):FindFirstChild("Fire")
				local fire_anim_track = viewmodel:WaitForChild("AnimationController"):FindFirstChild("Animator"):LoadAnimation(root_fire_anim)
				fire_anim_track:Play()
			end
			
			fire_sound:Play()
			client_cooldown = true
			local mouse_pos = mouse.Hit
			ReplicatedStorage.BMGS.Events.WeaponFired:FireServer(mouse_pos, mouse.Hit.p, damage_value.Value)
			gun_ui_ammo.Text = tostring(ammo_value.Value)
			gun_ui_maxammo.Text = tostring(maxammo_value.Value)

			if mouse.Target and mouse.Target.Parent then
				local highlight = Instance.new("Highlight")
				if mouse.Target.Name == "Baseplate" or mouse.Target.Parent.Name == "Baseplate" then
					print("baseplate and i am NOT adding a hitmarker for that")
				else
					highlight.Parent = mouse.Target
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				end
				local tween = game:GetService("TweenService"):Create(highlight, TweenInfo.new(1), {OutlineTransparency = 1, FillTransparency = 1})
				tween:Play()
				tween.Completed:Connect(function()
					game:GetService("Debris"):AddItem(highlight, 0.1)
				end)
			elseif mouse.Target == nil then
				warn("[BMGS]: Mouse is not pointing at any object")
			elseif mouse.Target.Parent == nil then
				warn("[BMGS]: Mouse target does not have a valid parent")
			else
				print("[BMGS]: Unknown statement")
			end

			ammo_value.Value = ammo_value.Value - 1
			task.wait(cooldown_value.Value)
			client_cooldown = false
			if ammo_value.Value <= 0 then gun_functions.reload_gun() end
		end
	end,

}

input_functions = {
	on_equipped = function()
		if player_character:FindFirstChildOfClass("Tool") then
			local possible_tool = player_character:FindFirstChildOfClass("Tool")
			if possible_tool:WaitForChild("Handle"):FindFirstChild("Config") then
				sounds_folder = possible_tool:WaitForChild("Handle"):FindFirstChild("Sounds")
				config_folder = possible_tool:WaitForChild("Handle"):FindFirstChild("Config")

				fire_sound = sounds_folder:FindFirstChild("Fire")
				reload_sound = sounds_folder:FindFirstChild("Reload")
				equip_sound = sounds_folder:FindFirstChild("Equip")

				automatic_value = possible_tool:WaitForChild("Handle"):FindFirstChild("Config"):FindFirstChild("Automatic")
				cooldown_value = possible_tool:WaitForChild("Handle"):FindFirstChild("Config"):FindFirstChild("Cooldown")
				damage_value = possible_tool:WaitForChild("Handle"):FindFirstChild("Config"):FindFirstChild("Damage")
				ammo_value = possible_tool:WaitForChild("Handle"):FindFirstChild("Config"):FindFirstChild("Ammo")
				maxammo_value = possible_tool:WaitForChild("Handle"):FindFirstChild("Config"):FindFirstChild("MaxAmmo")
				recoil_value = possible_tool:WaitForChild("Handle"):FindFirstChild("Config"):FindFirstChild("Recoil")

				tool = possible_tool

				if tool.Name == "Minigun" then
					sounds_folder:FindFirstChild("RevUp"):Play()
					task.wait(0.99)
					sounds_folder:FindFirstChild("Loop").Playing = true
				end

				viewmodel = nil
				equipped = true

				print(tool.Name)

				character_functions.viewmodel_loop()

				mouse.Icon = "rbxassetid://9947945465"
				gun_ui_frame.Visible = true
				gun_ui_name.Text = tool.Name
				gun_ui_ammo.Text = tostring(ammo_value.Value)
				gun_ui_maxammo.Text = tostring(maxammo_value.Value)
			else
				mouse.Icon = "rbxassetid://0"
				equipped = false
				print("[BMGS]: Tool found did not have valid weapon config")
			end
		else
			print("[BMGS]: Function called w/o valid tool equipped")
		end
		reloading = not reloading
		equip_sound:Play()
	end,

	on_unequipped = function()
		mouse.Icon = "rbxassetid://0"
		gun_ui_name.Text = "N/A"
		gun_ui_ammo.Text = "0"
		gun_ui_maxammo.Text = "0"
		gun_ui_frame.Visible = false

		if tool.Name == "Minigun" then
			sounds_folder:FindFirstChild("Loop").Playing = false
			sounds_folder:FindFirstChild("RevUp"):Stop()
			sounds_folder:FindFirstChild("RevDown"):Play()
		end

		if viewmodel then
			viewmodel:Destroy()
		end

		viewmodel = nil
		equipped = not equipped
		tool = nil
		reloading = not reloading
		equip_sound:Play()
		sounds_folder = nil
		config_folder = nil
		cooldown_value = nil
		ammo_value = nil
		maxammo_value = nil
	end,
}

character_functions = {
	on_child_added = function(child_add)
		if child_add:IsA("Tool") then
			input_functions.on_equipped()
		end
	end,

	on_child_removed = function(child_remove)
		if child_remove:IsA("Tool") and child_remove:WaitForChild("Handle"):FindFirstChild("Config") then
			input_functions.on_unequipped()
		else
			print("[BMGS]: Tool unequipped, did not have valid weapon config")
		end
	end,

	viewmodel_loop = function()
		local current_fov = workspace.CurrentCamera.FieldOfView
		local distance = (workspace.CurrentCamera.CFrame.Position - workspace.CurrentCamera.Focus.Position).Magnitude
		local is_first_person = distance <= 0.75

		if is_first_person then
			if tool then
				for _, part in pairs(tool:GetChildren()) do
					if part:IsA("MeshPart") or part:IsA("Part") then
						part.Transparency = 1
					end
				end
			end

			if not viewmodel then
				if not equipped then return end
				if viewmodel_folder:FindFirstChild(tool.Name) then
					for _, v in pairs(tool:GetChildren()) do
						if v:IsA("MeshPart") or v:IsA("Part") then
							v.Transparency = 1
						end
					end

					viewmodel = viewmodel_folder:FindFirstChild(tool.Name):Clone()
					viewmodel.Parent = workspace.CurrentCamera

					viewmodel:FindFirstChild("LeftArm").BrickColor = player_character["LeftLowerArm"].BrickColor
					viewmodel:FindFirstChild("RightArm").BrickColor = player_character["RightLowerArm"].BrickColor
				else
					warn("[BMGS]: No viewmodel found for " .. tool.Name)
				end
			end

			if viewmodel then
				for index, child in pairs(workspace.CurrentCamera:GetChildren()) do
					if child:IsA("Model") then
						child:SetPrimaryPartCFrame(workspace.CurrentCamera.CFrame, aim_cframe)
					end
				end
			end
		else
			if tool then
				for _, part in pairs(tool:GetChildren()) do
					if part:IsA("MeshPart") or part:IsA("Part") then
						part.Transparency = 0
					end
				end
			end

			if viewmodel and viewmodel.Parent then
				for _, v in pairs(tool:GetChildren()) do
					if v:IsA("MeshPart") or v:IsA("Part") then
						v.Transparency = 0
					end
				end
				viewmodel:Destroy()
				viewmodel = nil
			end
		end
	end

}

player_character.ChildAdded:Connect(function(child_add)
	if debug_mode then print(tostring(child_add)) end
	character_functions.on_child_added(child_add)
end)

player_character.ChildRemoved:Connect(function(child_remove)
	if debug_mode then print(tostring(child_remove)) end
	character_functions.on_child_removed(child_remove)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.R then
		gun_functions.reload_gun()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aiming = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = true
		local is_automatic = automatic_value and automatic_value.Value
		if is_automatic then
			task.spawn(function()
				while firing and equipped and ammo_value.Value > 0 do
					gun_functions.fire_gun_client()
					task.wait(cooldown_value.Value)
				end
			end)
		else
			gun_functions.fire_gun_client()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		firing = not firing
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		aiming = not aiming
	end
end)

RunService.RenderStepped:Connect(function()
	character_functions.viewmodel_loop()
end)