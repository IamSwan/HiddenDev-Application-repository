-- Services
local contextActionService = game:GetService("ContextActionService")
local userInputService = game:GetService("UserInputService")
local shiftlockModule = require(game.Players.LocalPlayer.Character:WaitForChild("ShiftlockModule"))
local tweenService = game:GetService("TweenService")
local runService = game:GetService("RunService")

-- Player's Instances
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid: Humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart: Part = character:WaitForChild("HumanoidRootPart")

-- Modules
local animationModule = require(character:WaitForChild("AnimationModule"))

-- Remotes
local vfxRemote = game.ReplicatedStorage.Remotes.VFXRemote
local movesRemote = game.ReplicatedStorage.Remotes.MovesRemote

-- InputTable
local inputTable = {
	["fly"] = Enum.KeyCode.V,
	["shiftlock"] = Enum.KeyCode.LeftControl,
	["run"] = Enum.KeyCode.LeftShift,
	["fly_up"] = Enum.KeyCode.Space,
	["fly_down"] = Enum.KeyCode.LeftControl,
	["fly_sonic"] = Enum.KeyCode.LeftShift,
	["equip_jetpack"] = Enum.KeyCode.X,
}

local defaultRunSpeed = 8
local runningSpeed = 20
local slowFlySpeed = 250
local fastFlySpeed = 700
local gravityVector = Vector3.new(0, workspace.Gravity, 0)
local drag = 1.2
local yAxis = 0

local alignOrientation = script:WaitForChild("AlignOrientation")
alignOrientation.Attachment0 = humanoidRootPart.RootRigAttachment
local vectorForce = script:WaitForChild("VectorForce")
vectorForce.Attachment0 = humanoidRootPart.RootRigAttachment

local connection = nil

local pose = "none"

-- InputFunctions
local inputFunctions = {
	["fly"] = function(state)
		if character:GetAttribute("jetpack") == "none" then return end
		if state ~= Enum.UserInputState.Begin then return end
		character:SetAttribute("flying", not character:GetAttribute("flying"))
		if (not connection) then
			vectorForce.Enabled = true
			alignOrientation.Enabled = true
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
			pose = "none"
			connection = runService.Heartbeat:Connect(function(delta)
				if not character:GetAttribute("flying") then 
					vectorForce.Enabled = false
					alignOrientation.Enabled = false
					humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
					connection:Disconnect()
					connection = nil
					return
				end
				vectorForce.Force = gravityVector * humanoidRootPart.AssemblyMass
				local moveVector = Vector3.new(humanoid.MoveDirection.X, yAxis, humanoid.MoveDirection.Z)
				if moveVector.Magnitude > 0 and not character:GetAttribute("fly_sonic") then
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
					if pose ~= "fly_sonic" then
						pose = "fly_sonic"
						animationModule:StopAllAnims()
						animationModule:PlayAnimation("jetpackSonic")
					end
					moveVector = workspace.CurrentCamera.CFrame.LookVector
					moveVector = moveVector.Unit
					vectorForce.Force += moveVector * fastFlySpeed * humanoidRootPart.AssemblyMass
				elseif moveVector.Magnitude <= 0 then
					if pose ~= "idle" then
						pose = "idle"
						animationModule:StopAllAnims()
						animationModule:PlayAnimation("jetpackIdle")
					end
				end
				if humanoidRootPart.AssemblyLinearVelocity.Magnitude > 0 then
					local dragVector = -humanoidRootPart.AssemblyLinearVelocity.Unit
					local dragCurve = humanoidRootPart.AssemblyLinearVelocity.Magnitude ^ 1.2
					vectorForce.Force += dragVector * drag * humanoidRootPart.AssemblyMass * dragCurve
					alignOrientation.CFrame = CFrame.lookAt(Vector3.new(0, 0, 0), workspace.CurrentCamera.CFrame.LookVector)
				end
			end)
		else
			vectorForce.Enabled = false
			alignOrientation.Enabled = false
			humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			connection:Disconnect()
			connection = nil
		end
	end,
	["shiftlock"] = function(state)
		if state == Enum.UserInputState.Begin then
			shiftlockModule:shiftlock(not shiftlockModule:isLocked())
		end
	end,
	["run"] = function(state)
		if state == Enum.UserInputState.Begin then
			tweenService:Create(humanoid, TweenInfo.new(.1), {WalkSpeed = runningSpeed}):Play()
		elseif state == Enum.UserInputState.End then
			humanoid.WalkSpeed = defaultRunSpeed
		end
	end,
	["fly_up"] = function(state)
		if state == Enum.UserInputState.Begin then
			yAxis = 1
		elseif state == Enum.UserInputState.End then
			yAxis = 0
		end
	end,
	["fly_down"] = function(state)
		if state == Enum.UserInputState.Begin then
			yAxis = -1
		elseif state == Enum.UserInputState.End then
			yAxis = 0
		end
	end,
	["fly_sonic"] = function(state)
		
		if character:GetAttribute("fly_sonic") == nil then
			character:SetAttribute("fly_sonic", false)
		end
		
		character:SetAttribute("fly_sonic", not character:GetAttribute("fly_sonic"))
	end,
	["equip_jetpack"] = function(state)
		if state ~= Enum.UserInputState.Begin then return end
		movesRemote:FireServer("equip_jetpack")
	end,
}

shiftlockModule:shiftlock(false) -- set default shiftlock

local function input(action, state, _object)
	inputFunctions[action](state)
end

-- Bind actions
contextActionService:BindAction("shiftlock", input, false, inputTable["shiftlock"])
contextActionService:BindAction("fly", input, false, inputTable["fly"])
contextActionService:BindAction("run", input, false, inputTable["run"])
contextActionService:BindAction("equip_jetpack", input, false, inputTable["equip_jetpack"])

local wasShiftlock = false

character:GetAttributeChangedSignal("flying"):Connect(function()
	if character:GetAttribute("flying") then
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
