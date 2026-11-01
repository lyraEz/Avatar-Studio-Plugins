Movement & Vision Tools - plugin for Avatar Studio.

    What it adds (all in the Plugins tab of Avatar Studio):
      * Noclip          walk through walls and objects
      * Fly             fly freely, with a speed slider (mobile: on-screen buttons)
      * VFly            vertical fly, straight up and down (mobile: on-screen buttons)
      * ESP             see other players through walls (with team check option)
      * Highlight       draw a highlight around any player you pick
      * Invisible       your character becomes invisible to others (FE)

    Install: paste this file's raw GitHub link in the Plugins tab of Avatar Studio.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

return {
    Name = "Movement & Vision",
    Version = "1.0.0",
    Author = "you",
    Description = "Noclip, fly, vfly, ESP, highlight and invisibility (FE).",

    Load = function(api)
        local player = api.Player
        local camera = workspace.CurrentCamera

        
        
        
        
        
        api.section({Title = "Movement"})
        local noclip = {On = false}
        local function setNoclip(on)
            noclip.On = on
            local character = player.Character
            if character then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = not on end
                end
            end
        end
        api.connect(RunService.Stepped, function()
            if not noclip.On then return end
            local character = player.Character
            if not character then return end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end)
        api.onCharacter(function(character)
            if noclip.On then
                for _, part in ipairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
        api.toggle({
            Title = "Noclip",
            Description = "Walk through walls and objects. You fall through floors, use Fly with it.",
            Save = "Noclip",
            Changed = setNoclip,
        })
        api.onUnload(function() if noclip.On then setNoclip(false) end end)

        
        
        
        
        
        
        
        local fly = {Mode = "Off", Speed = 50, Root = nil, Humanoid = nil, Body = nil, Pad = nil}

        local function hidePad()
            if fly.Pad then fly.Pad:Destroy(); fly.Pad = nil end
        end

        local function showPad(mode)
            hidePad()
            if not UserInputService.TouchEnabled then return end 
            local gui = Instance.new("ScreenGui")
            gui.Name = "MovementPad"; gui.ResetOnSpawn = false; gui.DisplayOrder = 999; gui.IgnoreGuiInset = true
            local parent = type(gethui) == "function" and select(2, pcall(gethui)) or nil
            if typeof(parent) ~= "Instance" then parent = player:FindFirstChildOfClass("PlayerGui") end
            gui.Parent = parent
            fly.Pad = gui

            local function makeButton(text, pos, size, color)
                local b = Instance.new("TextButton")
                b.Size = size; b.Position = pos; b.BackgroundColor3 = color; b.BackgroundTransparency = 0.35
                b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Font = Enum.Font.GothamBold; b.TextSize = 20; b.Text = text
                b.BorderSizePixel = 0; b.AutoButtonColor = true
                Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
                b.Parent = gui
                return b
            end

            local holding = {}
            local function hold(button, key)
                button.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then holding[key] = true end
                end)
                button.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch then holding[key] = false end
                end)
            end

            local padColor = Color3.fromRGB(30, 30, 40)
            if mode == "Fly" then
                hold(makeButton("▲", UDim2.new(1, -170, 1, -230), UDim2.fromOffset(60, 60), padColor), "Space")
                hold(makeButton("▼", UDim2.new(1, -170, 1, -160), UDim2.fromOffset(60, 60), padColor), "LeftShift")
                hold(makeButton("◀", UDim2.new(1, -240, 1, -195), UDim2.fromOffset(60, 60), padColor), "A")
                hold(makeButton("▶", UDim2.new(1, -100, 1, -195), UDim2.fromOffset(60, 60), padColor), "D")
                hold(makeButton("▲", UDim2.new(1, -170, 1, -265), UDim2.fromOffset(60, 40), padColor), "W")
                hold(makeButton("▼", UDim2.new(1, -170, 1, -125), UDim2.fromOffset(60, 40), padColor), "S")
            else 
                hold(makeButton("▲ UP", UDim2.new(1, -180, 1, -230), UDim2.fromOffset(80, 60), padColor), "Space")
                hold(makeButton("▼ DOWN", UDim2.new(1, -180, 1, -160), UDim2.fromOffset(80, 60), padColor), "LeftShift")
            end

            fly.Holding = holding
        end

        local keys = {W = false, A = false, S = false, D = false, Space = false, LeftShift = false}
        api.connect(UserInputService.InputBegan, function(input, processed)
            if processed then return end
            local key = input.KeyCode.Name
            if keys[key] ~= nil then keys[key] = true end
        end)
        api.connect(UserInputService.InputEnded, function(input)
            local key = input.KeyCode.Name
            if keys[key] ~= nil then keys[key] = false end
        end)

        local function isDown(key)
            if fly.Holding and fly.Holding[key] then return true end
            return keys[key]
        end

        local function stopFly()
            fly.Mode = "Off"
            if fly.Body then fly.Body:Destroy(); fly.Body = nil end
            if fly.Humanoid then
                pcall(function() fly.Humanoid.PlatformStand = false end)
                pcall(function() fly.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            end
            hidePad()
        end

        api.connect(RunService.Heartbeat, function()
            if fly.Mode == "Off" then return end
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not root or not humanoid then stopFly(); return end
            fly.Root = root; fly.Humanoid = humanoid

            if not fly.Body or fly.Body.Parent ~= root then
                local old = root:FindFirstChild("MovementFlyBody")
                if old then old:Destroy() end
                local body = Instance.new("BodyVelocity")
                body.Name = "MovementFlyBody"; body.MaxForce = Vector3.new(9e9, 9e9, 9e9); body.Velocity = Vector3.zero
                body.Parent = root; fly.Body = body
                humanoid.PlatformStand = true
            end

            local direction = Vector3.zero
            if fly.Mode == "Fly" then
                local look = camera.CFrame.LookVector
                local right = camera.CFrame.RightVector
                if isDown("W") then direction = direction + look end
                if isDown("S") then direction = direction - look end
                if isDown("D") then direction = direction + right end
                if isDown("A") then direction = direction - right end
                if isDown("Space") then direction = direction + Vector3.new(0, 1, 0) end
                if isDown("LeftShift") then direction = direction - Vector3.new(0, 1, 0) end
            else 
                if isDown("Space") then direction = direction + Vector3.new(0, 1, 0) end
                if isDown("LeftShift") then direction = direction - Vector3.new(0, 1, 0) end
            end
            if direction.Magnitude > 0 then direction = direction.Unit end
            fly.Body.Velocity = direction * fly.Speed
        end)

        api.dropdown({
            Title = "Fly mode",
            Description = "Fly moves where you look. VFly goes straight up and down. Space = up, LeftShift = down (on mobile use the on-screen buttons).",
            Options = {"Off", "Fly", "VFly"},
            Default = "Off",
            Save = "FlyMode",
            Changed = function(choice)
                stopFly()
                if choice ~= "Off" then
                    fly.Mode = choice
                    showPad(choice)
                    api.notify(choice .. " is on. Space = up, LeftShift = down.", "success")
                end
            end,
        })
        api.number({
            Title = "Fly speed",
            Description = "How fast you move while flying.",
            Min = 10, Max = 500, Step = 10, Default = 50,
            Save = "FlySpeed",
            Changed = function(value) fly.Speed = value end,
        })
        api.onCharacter(function() if fly.Mode ~= "Off" then stopFly() end end)
        api.onUnload(stopFly)

        
        
        
        
        
        api.section({Title = "Vision"})
        local esp = {On = false, TeamCheck = false, Tags = setmetatable({}, {__mode = "k"})}

        local function removeTag(other)
            local tag = esp.Tags[other]
            if tag then pcall(function() tag:Destroy() end); esp.Tags[other] = nil end
        end
        local function clearEsp()
            for other in pairs(esp.Tags) do removeTag(other) end
        end

        local function addTag(other)
            if other == player then return end
            if esp.TeamCheck and other.Team and player.Team and other.Team == player.Team then return end
            local character = other.Character
            if not character then return end
            local head = character:FindFirstChild("Head")
            if not head then return end
            removeTag(other)
            local gui = Instance.new("BillboardGui")
            gui.Name = "MovementEsp"; gui.Adornee = head; gui.AlwaysOnTop = true
            gui.Size = UDim2.fromOffset(120, 40); gui.StudsOffset = Vector3.new(0, 2.5, 0); gui.MaxDistance = 500
            local label = Instance.new("TextLabel")
            label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
            label.TextColor3 = Color3.fromRGB(255, 80, 80); label.Font = Enum.Font.GothamBold; label.TextSize = 14
            label.TextStrokeTransparency = 0.4
            label.Text = other.DisplayName .. "\n[" .. other.Name .. "]"
            label.Parent = gui
            local parent = type(gethui) == "function" and select(2, pcall(gethui)) or nil
            if typeof(parent) ~= "Instance" then parent = player:FindFirstChildOfClass("PlayerGui") end
            gui.Parent = parent
            esp.Tags[other] = gui
        end

        local function refreshEsp()
            if not esp.On then return end
            for _, other in ipairs(Players:GetPlayers()) do addTag(other) end
        end
        api.every(2, refreshEsp)
        api.connect(Players.PlayerAdded, function(other)
            if esp.On then task.wait(1); addTag(other) end
        end)
        api.connect(Players.PlayerRemoving, removeTag)

        api.toggle({
            Title = "ESP",
            Description = "See other players' names and boxes through walls.",
            Save = "Esp",
            Changed = function(on)
                esp.On = on
                if on then refreshEsp() else clearEsp() end
            end,
        })
        api.toggle({
            Title = "ESP team check",
            Description = "Don't show ESP for players on your team.",
            Save = "EspTeamCheck",
            Changed = function(on)
                esp.TeamCheck = on
                clearEsp()
                if esp.On then refreshEsp() end
            end,
        })
        api.onUnload(clearEsp)

        
        
        
        
        local highlight = {Target = nil, Object = nil}
        local function clearHighlight()
            if highlight.Object then pcall(function() highlight.Object:Destroy() end); highlight.Object = nil end
            highlight.Target = nil
        end
        local function applyHighlight()
            clearHighlight()
            local name = api.get("HighlightTarget", "")
            if name == "" then return end
            local other = Players:FindFirstChild(name)
            if not other or not other.Character then
                api.notify("Player not found or has no character: " .. name, "warning")
                return
            end
            highlight.Target = other
            local object = Instance.new("Highlight")
            object.Name = "MovementHighlight"; object.Adornee = other.Character
            object.FillColor = Color3.fromRGB(80, 170, 255); object.FillTransparency = 0.6
            object.OutlineColor = Color3.fromRGB(255, 255, 255); object.OutlineTransparency = 0
            object.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            local parent = type(gethui) == "function" and select(2, pcall(gethui)) or nil
            if typeof(parent) ~= "Instance" then parent = player:FindFirstChildOfClass("PlayerGui") end
            object.Parent = parent
            highlight.Object = object
            api.notify("Highlighting " .. other.DisplayName, "success")
        end
        api.connect(Players.PlayerRemoving, function(other)
            if highlight.Target == other then clearHighlight() end
        end)
        api.input({
            Title = "Highlight player",
            Description = "Type a player's username and they get a highlight around them, visible through walls.",
            Placeholder = "username",
            Button = "Highlight",
            Default = api.get("HighlightTarget", ""),
            Submitted = function(text)
                api.set("HighlightTarget", text)
                applyHighlight()
            end,
        })
        api.button({
            Title = "Clear highlight",
            Description = "Removes the highlight.",
            Button = "Clear",
            Pressed = function()
                api.set("HighlightTarget", "")
                clearHighlight()
                api.notify("Highlight removed.")
            end,
        })
        api.onUnload(clearHighlight)
        
        if api.get("HighlightTarget", "") ~= "" then applyHighlight() end

        
        
        
        
        
        
        api.section({Title = "Character"})
        local invisible = {On = false}
        local function setInvisible(on)
            invisible.On = on
            local character = player.Character
            if not character then return end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = on and 1 or 0
                    part.CanCollide = not on
                elseif part:IsA("Decal") then
                    part.LocalTransparencyModifier = on and 1 or 0
                end
            end
        end
        api.connect(RunService.Stepped, function()
            if not invisible.On then return end
            local character = player.Character
            if not character then return end
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.LocalTransparencyModifier < 1 then
                    part.LocalTransparencyModifier = 1
                    part.CanCollide = false
                elseif part:IsA("Decal") and part.LocalTransparencyModifier < 1 then
                    part.LocalTransparencyModifier = 1
                end
            end
        end)
        api.onCharacter(function(character)
            if invisible.On then
                task.wait(0.5) 
                if invisible.On then setInvisible(true) end
            end
        end)
        api.toggle({
            Title = "Invisible (FE)",
            Description = "Other players can't see or touch you. Your own screen shows you normally.",
            Save = "Invisible",
            Changed = setInvisible,
        })
        api.onUnload(function() if invisible.On then setInvisible(false) end end)
    end,
}
