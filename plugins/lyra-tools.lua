--[[
    Lyra Tools - the official Avatar Studio plugin.

    What it adds (all in the Plugins tab of Avatar Studio):
      * Anti-fling      other players can't push or spin you away
      * Anti-kick       blocks kicks the game does on your side
      * Anti-AFK        Roblox won't kick you after 20 minutes without moving
      * FPS limit       raise (or lower) the FPS cap, the game looks the same
      * Background mode stops drawing the game while Roblox is in the background
      * Low graphics    removes textures, shadows and effects for more FPS (players' avatars stay as they are)
      * FPS and ping    a small counter in the corner of the screen
      * Rejoin / Server hop

    This file is also an example of how a plugin is made. A plugin is a Lua file that returns a table with its
    name and a Load function. Avatar Studio calls Load(api) and gives it the "api": the toolbox to add switches,
    buttons and other controls, and to run code that is stopped by itself when the plugin is turned off.
    Read the README of this repository for the full list of what the api can do.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

return {
    Name = "Lyra Tools",
    Version = "1.0.0",
    Author = "lyraEz",
    Description = "Anti-fling, anti-kick, anti-AFK, FPS boost, an FPS and ping counter, rejoin and server hop.",

    Load = function(api)
        local player = api.Player

        ------------------------------------------------------------------------------------------------------------
        -- ANTI-FLING
        -- Flingers spin their character very fast and touch you. Two things stop it:
        --   1. Other players' bodies don't collide with you (on your screen only, they can't push you).
        --   2. If you still get thrown (very fast sideways or spinning), you are stopped and put back where you were.
        ------------------------------------------------------------------------------------------------------------
        api.section({Title = "Protection"})
        local fling = {On = false, Parts = {}, Changed = setmetatable({}, {__mode = "k"}), Safe = nil}

        -- The list of other players' body parts is refreshed every second (players come and go, respawn...).
        api.every(1, function()
            if not fling.On then return end
            local parts = {}
            for _, other in ipairs(Players:GetPlayers()) do
                if other ~= player and other.Character then
                    for _, part in ipairs(other.Character:GetDescendants()) do
                        if part:IsA("BasePart") then table.insert(parts, part) end
                    end
                end
            end
            fling.Parts = parts
        end)
        -- Stepped runs right before physics, every frame: their parts stop colliding just in time.
        api.connect(RunService.Stepped, function()
            if not fling.On then return end
            for _, part in ipairs(fling.Parts) do
                if part.CanCollide then
                    fling.Changed[part] = true
                    part.CanCollide = false
                end
            end
        end)
        -- Heartbeat runs right after physics: a throw is caught and undone here.
        api.connect(RunService.Heartbeat, function()
            if not fling.On then return end
            local character = player.Character
            local root = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            if not root or not humanoid or humanoid.SeatPart then fling.Safe = nil; return end
            local velocity = root.AssemblyLinearVelocity
            local sideways = Vector3.new(velocity.X, 0, velocity.Z).Magnitude -- falling fast is not a fling
            local spin = root.AssemblyAngularVelocity.Magnitude
            if sideways > 250 or spin > 50 then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                if fling.Safe then root.CFrame = fling.Safe end
            elseif sideways < 100 and spin < 15 then
                fling.Safe = root.CFrame
            end
        end)
        local function restoreCollisions()
            for part in pairs(fling.Changed) do
                if part.Parent then pcall(function() part.CanCollide = true end) end
            end
            fling.Changed = setmetatable({}, {__mode = "k"})
            fling.Parts = {}
        end
        api.toggle({
            Title = "Anti-fling",
            Description = "Other players can't push or spin you away (useful in Natural Disaster Survival and similar games).",
            Save = "AntiFling", -- remembers the switch for next time
            Changed = function(on)
                fling.On = on
                fling.Safe = nil
                if not on then restoreCollisions() end
            end,
        })
        api.onUnload(restoreCollisions)

        ------------------------------------------------------------------------------------------------------------
        -- ANTI-KICK
        -- A game can kick you from its own scripts on your device (player:Kick()). That call is caught and ignored.
        -- A kick decided by the game's server can't be blocked by anything on your side.
        ------------------------------------------------------------------------------------------------------------
        local kick = {On = false, Hooked = false}
        local function hookKick()
            if kick.Hooked then return true end
            if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return false end
            local wrap = type(newcclosure) == "function" and newcclosure or function(fn) return fn end
            local original
            original = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                if kick.On and self == player and api.alive() then
                    local method = getnamecallmethod()
                    if (method == "Kick" or method == "kick") and not (type(checkcaller) == "function" and checkcaller()) then
                        api.notify("The game tried to kick you. It was blocked.", "warning")
                        return nil
                    end
                end
                return original(self, ...)
            end))
            kick.Hooked = true
            return true
        end
        local kickSwitch
        kickSwitch = api.toggle({
            Title = "Anti-kick",
            Description = "Blocks kicks the game does on your side. A kick from the game's server can't be blocked.",
            Save = "AntiKick",
            Changed = function(on)
                if on and not hookKick() then
                    api.notify("Your executor can't do this (it has no hookmetamethod).", "warning")
                    kickSwitch.Set(false, true)
                    kick.On = false
                    return
                end
                kick.On = on
            end,
        })

        ------------------------------------------------------------------------------------------------------------
        -- ANTI-AFK
        -- Roblox kicks you after 20 minutes without input. When Roblox says you went idle, a click is simulated.
        ------------------------------------------------------------------------------------------------------------
        local afk = {On = false}
        api.connect(player.Idled, function()
            if not afk.On then return end
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        api.toggle({
            Title = "Anti-AFK",
            Description = "Roblox won't kick you for being idle for 20 minutes.",
            Save = "AntiAFK",
            Changed = function(on) afk.On = on end,
        })

        ------------------------------------------------------------------------------------------------------------
        -- FPS BOOST WITHOUT CHANGING HOW THE GAME LOOKS
        ------------------------------------------------------------------------------------------------------------
        api.section({Title = "Performance", Text = "The first two options change nothing you see. Low graphics does."})
        local caps = {["Don't change"] = false, ["60"] = 60, ["120"] = 120, ["144"] = 144, ["240"] = 240, ["Unlimited"] = 1000}
        local originalCap = type(getfpscap) == "function" and select(2, pcall(getfpscap)) or nil
        local cappedByUs = false
        local function setCap(choice)
            if type(setfpscap) ~= "function" then
                if choice ~= "Don't change" then api.notify("Your executor can't change the FPS limit.", "warning") end
                return
            end
            local cap = caps[choice]
            if cap then
                setfpscap(cap); cappedByUs = true
            elseif cappedByUs then
                setfpscap(type(originalCap) == "number" and originalCap or 60); cappedByUs = false
            end
        end
        local capChoice = api.dropdown({
            Title = "FPS limit",
            Description = "Roblox normally stops at 60 FPS. A higher limit gives smoother play on devices that can run it.",
            Options = {"Don't change", "60", "120", "144", "240", "Unlimited"},
            Default = "Don't change",
            Save = "FpsCap",
            Changed = setCap,
        })
        if capChoice.Get() ~= "Don't change" then setCap(capChoice.Get()) end -- a saved limit comes back at start
        api.onUnload(function() if cappedByUs then setCap("Don't change") end end)

        local background = {On = false}
        api.connect(UserInputService.WindowFocusReleased, function()
            if background.On then pcall(function() RunService:Set3dRenderingEnabled(false) end) end
        end)
        api.connect(UserInputService.WindowFocused, function()
            pcall(function() RunService:Set3dRenderingEnabled(true) end)
        end)
        api.toggle({
            Title = "Background mode",
            Description = "While Roblox is in the background (another window or app), the game is not drawn: less heat and battery.",
            Save = "BackgroundMode",
            Changed = function(on)
                background.On = on
                if not on then pcall(function() RunService:Set3dRenderingEnabled(true) end) end
            end,
        })
        api.onUnload(function() pcall(function() RunService:Set3dRenderingEnabled(true) end) end)

        ------------------------------------------------------------------------------------------------------------
        -- LOW GRAPHICS (changes how the game looks)
        -- Textures, shadows, reflections and effects are removed from the map. Everything is remembered and comes
        -- back when the switch is turned off. Players' and NPCs' avatars (anything with a Humanoid) and the avatars
        -- Avatar Studio draws are never touched. A big map is done a little every frame so nothing freezes.
        ------------------------------------------------------------------------------------------------------------
        local low = {On = false, Saved = {}, Serial = 0, Avatars = setmetatable({}, {__mode = "k"})}
        local effects = {ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true}
        local postEffects = {BloomEffect = true, BlurEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true}

        local function change(item, property, value)
            local saved = low.Saved[item]
            if not saved then saved = {}; low.Saved[item] = saved end
            local ok, current = pcall(function() return item[property] end)
            if not ok or current == value then return end
            if saved[property] == nil then saved[property] = current end
            pcall(function() item[property] = value end)
        end
        local function onAvatar(item)
            local camera = workspace.CurrentCamera
            if camera and item:IsDescendantOf(camera) then return true end
            local model = item:FindFirstAncestorOfClass("Model")
            while model do
                local known = low.Avatars[model]
                if known == nil then
                    known = model:FindFirstChildOfClass("Humanoid") ~= nil
                    low.Avatars[model] = known
                end
                if known then return true end
                model = model:FindFirstAncestorOfClass("Model")
            end
            return false
        end
        local function simplify(item)
            if item:IsA("BasePart") then
                if item:IsA("Terrain") or onAvatar(item) then return end
                change(item, "Material", Enum.Material.SmoothPlastic)
                change(item, "Reflectance", 0)
                change(item, "CastShadow", false)
                if item:IsA("MeshPart") then change(item, "TextureID", "") end
            elseif item:IsA("Decal") then -- Decal and Texture
                if not onAvatar(item) then change(item, "Transparency", 1) end
            elseif item:IsA("SurfaceAppearance") then
                if not onAvatar(item) then change(item, "Parent", nil) end
            elseif effects[item.ClassName] then
                if not onAvatar(item) then change(item, "Enabled", false) end
            end
        end
        local function lowOn()
            low.Serial = low.Serial + 1
            local serial = low.Serial
            change(Lighting, "GlobalShadows", false)
            for _, effect in ipairs(Lighting:GetChildren()) do
                -- Avatar Studio's own window blur is left alone.
                if postEffects[effect.ClassName] and effect.Name ~= "CopierLiquidBlur" then change(effect, "Enabled", false) end
            end
            local terrain = workspace:FindFirstChildOfClass("Terrain")
            if terrain then
                change(terrain, "Decoration", false)
                change(terrain, "WaterWaveSize", 0)
                change(terrain, "WaterWaveSpeed", 0)
                change(terrain, "WaterReflectance", 0)
            end
            pcall(function()
                local rendering = settings().Rendering
                change(rendering, "QualityLevel", Enum.QualityLevel.Level01)
            end)
            api.spawn(function()
                for index, item in ipairs(workspace:GetDescendants()) do
                    if low.Serial ~= serial then return end
                    simplify(item)
                    if index % 1500 == 0 then task.wait() end
                end
            end)
        end
        -- now: put everything back at once (the plugin is being turned off), else a little every frame.
        local function lowOff(now)
            low.Serial = low.Serial + 1
            local saved = low.Saved
            low.Saved = {}
            local count = 0
            for item, properties in pairs(saved) do
                for property, value in pairs(properties) do pcall(function() item[property] = value end) end
                count = count + 1
                if not now and count % 1500 == 0 then task.wait() end
            end
        end
        -- Parts that load later (a map streaming in) get the same treatment.
        api.connect(workspace.DescendantAdded, function(item)
            if low.On then task.defer(function() if low.On then simplify(item) end end) end
        end)
        api.toggle({
            Title = "Low graphics",
            Description = "More FPS: removes textures, shadows, reflections and effects from the map. Players' avatars stay as they are. Turn it off to bring everything back.",
            Save = "LowGraphics",
            Changed = function(on)
                low.On = on
                if on then lowOn() else lowOff() end
            end,
        })
        api.onUnload(function() if low.On then low.On = false; lowOff(true) end end)

        ------------------------------------------------------------------------------------------------------------
        -- FPS AND PING COUNTER
        ------------------------------------------------------------------------------------------------------------
        local counter = {}
        local function showCounter(on)
            if counter.Gui then counter.Gui:Destroy(); counter.Gui = nil end
            if not on then return end
            local gui = Instance.new("ScreenGui")
            gui.Name = "LyraToolsCounter"; gui.ResetOnSpawn = false; gui.DisplayOrder = 1000; gui.IgnoreGuiInset = true
            local label = Instance.new("TextLabel")
            label.AnchorPoint = Vector2.new(0, 1); label.Position = UDim2.new(0, 10, 1, -10); label.Size = UDim2.fromOffset(150, 26)
            label.BackgroundColor3 = Color3.fromRGB(20, 18, 28); label.BackgroundTransparency = 0.3; label.BorderSizePixel = 0
            label.TextColor3 = Color3.fromRGB(235, 230, 255); label.Font = Enum.Font.GothamBold; label.TextSize = 13; label.Text = "FPS --  ·  -- ms"
            Instance.new("UICorner", label).CornerRadius = UDim.new(0, 8)
            label.Parent = gui
            -- The executor's hidden container when it has one, so the game can't see or remove it.
            local parent = type(gethui) == "function" and select(2, pcall(gethui)) or nil
            if typeof(parent) ~= "Instance" then parent = player:FindFirstChildOfClass("PlayerGui") end
            gui.Parent = parent
            counter.Gui = api.track(gui)
            counter.Label = label
        end
        local frames = 0
        api.connect(RunService.RenderStepped, function() frames = frames + 1 end)
        api.every(0.5, function()
            local fps = frames * 2
            frames = 0
            if counter.Label and counter.Label.Parent then
                local ok, ping = pcall(function() return player:GetNetworkPing() end)
                counter.Label.Text = string.format("FPS %d  ·  %s ms", fps, ok and tostring(math.floor(ping * 1000 + 0.5)) or "--")
            end
        end)
        api.toggle({
            Title = "FPS and ping",
            Description = "A small counter in the bottom-left corner of the screen.",
            Save = "Counter",
            Changed = showCounter,
        })

        ------------------------------------------------------------------------------------------------------------
        -- SERVER
        ------------------------------------------------------------------------------------------------------------
        api.section({Title = "Server"})
        api.button({
            Title = "Rejoin",
            Description = "Leaves and joins this same server again.",
            Button = "Rejoin",
            Pressed = function()
                api.notify("Rejoining…")
                if #Players:GetPlayers() <= 1 then
                    TeleportService:Teleport(game.PlaceId, player)
                else
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
                end
            end,
        })
        api.button({
            Title = "Server hop",
            Description = "Moves you to another server of this game that has free space.",
            Button = "Hop",
            Pressed = function()
                api.notify("Looking for another server…")
                local cursor = ""
                for _ = 1, 5 do
                    local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Desc&limit=100"
                    if cursor ~= "" then url = url .. "&cursor=" .. cursor end
                    local ok, body = pcall(function() return game:HttpGet(url) end)
                    if not ok then break end
                    local decoded, data = pcall(function() return HttpService:JSONDecode(body) end)
                    if not decoded or type(data) ~= "table" then break end
                    for _, server in ipairs(data.data or {}) do
                        if server.id ~= game.JobId and (server.playing or 0) < (server.maxPlayers or 0) then
                            api.notify("Joining another server…")
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                            return
                        end
                    end
                    cursor = data.nextPageCursor or ""
                    if cursor == "" then break end
                end
                api.notify("No other server with free space was found.", "warning")
            end,
        })
    end,
}
