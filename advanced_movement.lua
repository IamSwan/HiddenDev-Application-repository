-- Services
local contextActionService = game:GetService("ContextActionService")  -- Get the ContextActionService for handling player input
local userInputService = game:GetService("UserInputService")          -- Get the UserInputService for detecting user input
local shiftlockModule = require(game.Players.LocalPlayer.Character:WaitForChild("ShiftlockModule"))  -- Load the ShiftlockModule
local tweenService = game:GetService("TweenService")                  -- Get the TweenService for animations
local runService = game:GetService("RunService")                      -- Get the RunService for handling game loops

-- Player's Instances
local player = game.Players.LocalPlayer                                -- Get the local player
local character = player.Character or player.CharacterAdded:Wait()     -- Get the player's character or wait for it to be added
local humanoid: Humanoid = character:WaitForChild("Humanoid")          -- Get the humanoid object of the character
local humanoidRootPart: Part = character:WaitForChild("HumanoidRootPart")  -- Get the root part of the character

-- Modules
local animationModule = require(character:WaitForChild("AnimationModule"))  -- Load the AnimationModule

-- Remotes
local vfxRemote = game.ReplicatedStorage.Remotes.VFXRemote               -- Get the VFXRemote remote
local movesRemote = game.ReplicatedStorage.Remotes.MovesRemote           -- Get the MovesRemote remote

-- InputTable
local inputTable = {
	["fly"] = Enum.KeyCode.V,                      -- Define keybindings for various actions
	["shiftlock"] = Enum.KeyCode.LeftControl,
	["run"] = Enum.KeyCode.LeftShift,
	["fly_up"] = Enum.KeyCode.Space,
	["fly_down"] = Enum.KeyCode.LeftControl,
	["fly_sonic"] = Enum.KeyCode.LeftShift,
	["equip_jetpack"] = Enum.KeyCode.X,
}

-- Constants for character movement and physics
local defaultRunSpeed = 8           -- Default running speed
local runningSpeed = 20             -- Running speed when activated
local slowFlySpeed = 250            -- Speed when flying slowly
local fastFlySpeed = 700            -- Speed when flying rapidly
local gravityVector = Vector3.new(0, workspace.Gravity, 0)  -- Gravity vector
local drag = 1.2                    -- Drag coefficient
local yAxis = 0                     -- Vertical axis for flying

-- Attachments and forces for character physics
local alignOrientation = script:WaitForChild("AlignOrientation")  -- AlignOrientation attachment
alignOrientation.Attachment0 = humanoidRootPart.RootRigAttachment  -- Attach to the character's root attachment
local vectorForce = script:WaitForChild("VectorForce")            -- VectorForce for character physics
vectorForce.Attachment0 = humanoidRootPart.RootRigAttachment      -- Attach to the character's root attachment

local connection = nil  -- Variable to store a connection for handling character physics

local pose = "none"  -- Variable to keep track of the character's pose

-- InputFunctions
local inputFunctions = {
	["fly"] = function(state)
		-- Function to handle flying action
		if character:GetAttribute("jetpack") == "none" then return end  -- Check if the player has a jetpack
		if state ~= Enum.UserInputState.Begin then return end  -- Check if the input is in the "begin" state
		character:SetAttribute("flying", not character:GetAttribute("flying"))  -- Toggle flying attribute
		if (not connection) then
			vectorForce.Enabled = true  -- Enable the VectorForce for character physics
			alignOrientation.Enabled = true  -- Enable the AlignOrientation for character orientation
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)  -- Change the humanoid state to physics
			pose = "none"  -- Set the initial pose to "none"
			connection = runService.Heartbeat:Connect(function(delta)
				-- Create a connection to handle character physics during flying
				if not character:GetAttribute("flying") then 
					vectorForce.Enabled = false  -- Disable the VectorForce
					alignOrientation.Enabled = false  -- Disable the AlignOrientation
					humanoid:ChangeState(Enum.HumanoidStateType.Freefall)  -- Change to freefall state when not flying
					connection:Disconnect()  -- Disconnect the connection
					connection = nil
					return
				end
				vectorForce.Force = gravityVector * humanoidRootPart.AssemblyMass  -- Apply gravitational force
				local moveVector = Vector3.new(humanoid.MoveDirection.X, yAxis, humanoid.MoveDirection.Z)
				if moveVector.Magnitude > 0 and not character:GetAttribute("fly_sonic") then
					-- Handle character movement while flying slowly
					if userInputService:IsKeyDown(Enum.KeyCode.A) then
						if pose ~= "left" then
							pose = "left"
							animationModule:StopAllAnims(.2)
							animationModule:PlayAnimation("jetpackslowLeft", .2)
						end
					elseif userInputService:IsKeyDown(Enum.KeyCode.D) then
						if pose ~= "right" then
							pose = "right"
							animationModule:StopAllAnims(.2)
							animationModule:PlayAnimation("jetpackslowRight", .2)
						end
					elseif userInputService:IsKeyDown(Enum.KeyCode.W) then
						if pose ~= "forward" then
							pose = "forward"
							animationModule:StopAllAnims(.2)
							animationModule:PlayAnimation("jetpackslowFront", .2)
						end
					elseif userInputService:IsKeyDown(Enum.KeyCode.S) then
						if pose ~= "backward" then
							pose = "backward"
							animationModule:StopAllAnims(.2)
							animationModule:PlayAnimation("jetpackslowBack", .2)
						end
					end
					moveVector = moveVector.Unit
					vectorForce.Force += moveVector * slowFlySpeed * humanoidRootPart.AssemblyMass
				elseif moveVector.Magnitude > 0 and character:GetAttribute("fly_sonic") then
					-- Handle character movement while flying rapidly (sonic)
					if pose ~= "fly_sonic" then
						pose = "fly_sonic"
						animationModule:StopAllAnims()
						animationModule:PlayAnimation("jetpackSonic")
					end
					moveVector = workspace.CurrentCamera.CFrame.LookVector
					moveVector = moveVector.Unit
					vectorForce.Force += moveVector * fastFlySpeed * humanoidRootPart.AssemblyMass
				elseif moveVector.Magnitude <= 0 then
					-- Handle character when not moving
					if pose ~= "idle" then
						pose = "idle"
						animationModule:StopAllAnims()
						animationModule:PlayAnimation("jetpackIdle")
					end
				end
				if humanoidRootPart.AssemblyLinearVelocity.Magnitude > 0 then
					-- Apply drag force when character is moving
					local dragVector = -humanoidRootPart.AssemblyLinearVelocity.Unit
					local dragCurve = humanoidRootPart.AssemblyLinearVelocity.Magnitude ^ 1.2
					vectorForce.Force += dragVector * drag * humanoidRootPart.AssemblyMass * dragCurve
					alignOrientation.CFrame = CFrame.lookAt(Vector3.new(0, 0, 0), workspace.CurrentCamera.CFrame.LookVector)
				end
			end)
		else
			-- Disable flying and reset character state when flying ends
			vectorForce.Enabled = false
			alignOrientation.Enabled = false
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			connection:Disconnect()
			connection = nil
		end
	end,
	["shiftlock"] = function(state)
		-- Function to toggle shiftlock mode
		if state == Enum.UserInputState.Begin then
			shiftlockModule:shiftlock(not shiftlockModule:isLocked())  -- Toggle shiftlock state
		end
	end,
	["run"] = function(state)
		-- Function to toggle running mode
		if state == Enum.UserInputState.Begin then
			tweenService:Create(humanoid, TweenInfo.new(.1), {WalkSpeed = runningSpeed}):Play()  -- Create a tween to change walking speed
		elseif state == Enum.UserInputState.End then
			humanoid.WalkSpeed = defaultRunSpeed  -- Reset walking speed
		end
	end,
	["fly_up"] = function(state)
		-- Function to control flying upward
		if state == Enum.UserInputState.Begin then
			yAxis = 1  -- Set vertical axis to move upward
		elseif state == Enum.UserInputState.End then
			yAxis = 0  -- Reset vertical axis when not moving upward
		end
	end,
	["fly_down"] = function(state)
		-- Function to control flying downward
		if state == Enum.UserInputState.Begin then
			yAxis = -1  -- Set vertical axis to move downward
		elseif state == Enum.UserInputState.End then
			yAxis = 0  -- Reset vertical axis when not moving downward
		end
	end,
	["fly_sonic"] = function(state)
		-- Function to toggle sonic flying mode
		if character:GetAttribute("fly_sonic") == nil then
			character:SetAttribute("fly_sonic", false)
		end
		character:SetAttribute("fly_sonic", not character:GetAttribute("fly_sonic"))  -- Toggle sonic flying mode
	end,
	["equip_jetpack"] = function(state)
		-- Function to equip a jetpack
		if state ~= Enum.UserInputState.Begin then return end
		movesRemote:FireServer("equip_jetpack")  -- Fire a remote event to equip a jetpack
	end,
}

shiftlockModule:shiftlock(false)  -- Set default shiftlock state to false

local function input(action, state, _object)
	-- Function to handle player input
	inputFunctions[action](state)
end

-- Bind actions to input functions
contextActionService:BindAction("shiftlock", input, false, inputTable["shiftlock"])
contextActionService:BindAction("fly", input, false, inputTable["fly"])
contextActionService:BindAction("run", input, false, inputTable["run"])
contextActionService:BindAction("equip_jetpack", input, false, inputTable["equip_jetpack"])

local wasShiftlock = false

-- Handle changes to the "flying" attribute of the character
character:GetAttributeChangedSignal("flying"):Connect(function()
	if character:GetAttribute("flying") then
		-- When character starts flying
		contextActionService:UnbindAction("shiftlock")
		contextActionService:UnbindAction("run")
		contextActionService:UnbindAction("equip_jetpack")
		contextActionService:BindAction("fly_up", input, false, inputTable["fly_up"])
		contextActionService:BindAction("fly_down", input, false, inputTable["fly_down"])
		contextActionService:BindAction("fly_sonic", input, false, inputTable["fly_sonic"])
		if not shiftlockModule:isLocked() then
			wasShiftlock = false
			shiftlockModule:shiftlock(true)
		else
			wasShiftlock = true
		end
		character:WaitForChild("Animate").Enabled = false
		character:WaitForChild("AnimateJetpack").Enabled = true
		character:SetAttribute("fly_sonic", false)
		vfxRemote:FireServer(character, "jetpack_fire")
	else
		-- When character stops flying
		contextActionService:BindAction("shiftlock", input, false, inputTable["shiftlock"])
		contextActionService:BindAction("run", input, false, inputTable["run"])
		contextActionService:BindAction("equip_jetpack", input, false, inputTable["equip_jetpack"])
		contextActionService:UnbindAction("fly_up")
		contextActionService:UnbindAction("fly_down")
		contextActionService:UnbindAction("fly_sonic")

		if shiftlockModule:isLocked() ~= wasShiftlock then
			shiftlockModule:shiftlock(wasShiftlock)
		end
		character:WaitForChild("Animate").Enabled = true
		character:WaitForChild("AnimateJetpack").Enabled = false
		character:SetAttribute("fly_sonic", false)
		vfxRemote:FireServer(character, "jetpack_disable")
		pose = "none"
	end
end)
