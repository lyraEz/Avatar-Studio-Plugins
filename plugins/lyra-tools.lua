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
      * Fake buyer      a copy of the purchase window with visual Robux and Roblox Plus, only on your screen
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
    Version = "1.1.0",
    Author = "lyraEz",
    Description = "Anti-fling, anti-kick, anti-AFK, FPS boost, an FPS and ping counter, a visual fake buyer, rejoin and server hop.",

    Load = function(api)
        local player = api.Player

        ------------------------------------------------------------------------------------------------------------
        -- ANTI-FLING
        -- Flingers spin their character very fast and touch you. Two things stop it:
        --   1. Other players' bodies don't collide with you (on your screen only, they can't push you).
        --   2. If you still get thrown (very fast sideways or spinning), you are stopped and put back where you were.
        --      Running fast on purpose is not a throw: a speed setting, a game's speed upgrades or a dash go the way you
        --      steer. Only a speed well over your walk speed in another direction, or a fast spin, counts as a fling.
        --      (1.0.1 and older stopped every run over 250 studs a second, so at a high walk speed you were pulled back
        --      over and over and could not move.)
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
            local flat = Vector3.new(velocity.X, 0, velocity.Z) -- falling fast is not a fling
            local sideways = flat.Magnitude
            local spin = root.AssemblyAngularVelocity.Magnitude
            local walk = humanoid.WalkSpeed
            -- Going the way you steer is your own run, however fast.
            local steer = humanoid.MoveDirection
            local ownRun = steer.Magnitude > 0.1 and sideways > 1 and flat.Unit:Dot(steer.Unit) > 0.7
            if spin > 50 or (sideways > math.max(250, walk * 2) and not ownRun) then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                if fling.Safe then root.CFrame = fling.Safe end
            elseif spin < 15 and (ownRun or sideways < math.max(100, walk * 1.2)) then
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
        local caps = {
            ["Don't change"] = false,
            ["60"] = {Setter = 60, Flag = 60},
            ["120"] = {Setter = 120, Flag = 120},
            ["144"] = {Setter = 144, Flag = 144},
            ["240"] = {Setter = 240, Flag = 240},
            ["Unlimited"] = {Setter = 0, Flag = 10000},
        }

        -- Some executors expose their functions only through the global environment given to scripts.
        local environments = {}
        if type(getgenv) == "function" then
            local ok, environment = pcall(getgenv)
            if ok and type(environment) == "table" then environments[#environments + 1] = environment end
        end
        if type(getfenv) == "function" then
            local ok, environment = pcall(getfenv, 0)
            if ok and type(environment) == "table" then environments[#environments + 1] = environment end
        end
        local function executorValue(name)
            for _, environment in ipairs(environments) do
                local value = environment[name]
                if value ~= nil then return value end
            end
            return nil
        end
        local function executorFunction(name, direct)
            if type(direct) == "function" then return direct end
            local value = executorValue(name)
            return type(value) == "function" and value or nil
        end

        local setFpsCap = executorFunction("setfpscap", setfpscap) or executorFunction("set_fps_cap", set_fps_cap)
        local getFpsCap = executorFunction("getfpscap", getfpscap) or executorFunction("get_fps_cap", get_fps_cap)
        local synApi = executorValue("syn")
        if type(synApi) == "table" then
            setFpsCap = setFpsCap or (type(synApi.set_fps_cap) == "function" and synApi.set_fps_cap or nil)
            getFpsCap = getFpsCap or (type(synApi.get_fps_cap) == "function" and synApi.get_fps_cap or nil)
        end
        local setFFlag = executorFunction("setfflag", setfflag)
        local getFFlag = executorFunction("getfflag", getfflag)
        local targetFlag = "DFIntTaskSchedulerTargetFps"
        local limitFlag = "FFlagTaskSchedulerLimitTargetFpsTo2402"

        local function readCap()
            if not getFpsCap then return nil end
            local ok, value = pcall(getFpsCap)
            if ok and type(value) == "number" and value == value and value >= 0 then return value end
            return nil
        end
        local function readFlag(name)
            if not getFFlag then return nil end
            local ok, value = pcall(getFFlag, name)
            if ok and value ~= nil then return tostring(value) end
            return nil
        end
        local function writeFlag(name, value)
            if not setFFlag then return false end
            local ok, result = pcall(setFFlag, name, tostring(value))
            return ok and result ~= false
        end

        local originalTargetFlag = readFlag(targetFlag)
        local originalLimitFlag = readFlag(limitFlag)
        local originalCap = readCap()
        if originalCap == math.huge then
            originalCap = 0
        elseif originalCap == nil then
            local flagCap = tonumber(originalTargetFlag)
            originalCap = flagCap and flagCap == flagCap and flagCap < math.huge and flagCap >= 0 and flagCap or 60
        end
        local originalFlagCap = originalCap > 0 and originalCap < math.huge and originalCap or 10000
        local fpsCap = {Target = nil, SetterTouched = false, TargetFlagTouched = false, LimitFlagTouched = false}

        local function restoreLimitFlag()
            if not fpsCap.LimitFlagTouched then return true end
            if originalLimitFlag ~= nil and writeFlag(limitFlag, originalLimitFlag) then
                fpsCap.LimitFlagTouched = false
                return true
            end
            return false
        end
        local function callSetter(value)
            if not setFpsCap then return false end
            local ok, result = pcall(setFpsCap, value)
            return ok and result ~= false
        end
        local function applyCap(target, showWarning)
            if target.Flag <= 240 then restoreLimitFlag() end

            local setterApplied = callSetter(target.Setter)
            fpsCap.SetterTouched = fpsCap.SetterTouched or setterApplied

            -- Apply the scheduler target too when available. It covers executors whose setfpscap is a no-op.
            local flagApplied = false
            local changedLimitNow = false
            if setFFlag then
                if target.Flag > 240 and originalLimitFlag ~= nil then
                    local limitApplied = writeFlag(limitFlag, "False")
                    changedLimitNow = limitApplied and not fpsCap.LimitFlagTouched
                    fpsCap.LimitFlagTouched = fpsCap.LimitFlagTouched or limitApplied
                end
                flagApplied = writeFlag(targetFlag, math.floor(target.Flag))
                fpsCap.TargetFlagTouched = fpsCap.TargetFlagTouched or flagApplied
                if changedLimitNow and not flagApplied then restoreLimitFlag() end
            end

            if setterApplied or flagApplied then
                fpsCap.Target = target
                return true
            end
            fpsCap.Target = nil
            if showWarning then
                local message = not setFpsCap and not setFFlag
                    and "Your executor can't change the FPS limit."
                    or "Your executor couldn't apply the FPS limit."
                api.notify(message, "warning")
            end
            return false
        end
        local function restoreCap(showWarning)
            local failed = false
            if fpsCap.TargetFlagTouched then
                if writeFlag(targetFlag, originalTargetFlag or math.floor(originalFlagCap)) then
                    fpsCap.TargetFlagTouched = false
                else
                    failed = true
                end
            end
            if not restoreLimitFlag() then failed = true end
            if fpsCap.SetterTouched then
                if callSetter(originalCap) then
                    fpsCap.SetterTouched = false
                else
                    failed = true
                end
            end
            fpsCap.Target = nil
            if failed and showWarning then
                api.notify("Your executor couldn't restore the previous FPS limit.", "warning")
            end
            return not failed
        end
        local function setCap(choice)
            local cap = caps[choice]
            if type(cap) == "table" then
                applyCap(cap, true)
            elseif choice == "Don't change" then
                restoreCap(true)
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
        api.connect(UserInputService.WindowFocused, function()
            if fpsCap.Target ~= nil then applyCap(fpsCap.Target, false) end
        end)
        api.onUnload(function() restoreCap(false) end)

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
        -- The executor's hidden container when it has one, so the game can't see or remove what the plugin draws.
        local function guiParent()
            local parent = type(gethui) == "function" and select(2, pcall(gethui)) or nil
            if typeof(parent) ~= "Instance" then parent = player:FindFirstChildOfClass("PlayerGui") end
            return parent
        end

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
            gui.Parent = guiParent()
            counter.Gui = api.track(gui)
            counter.Label = label
        end
        local frames = 0
        local lastSample = os.clock()
        api.connect(RunService.RenderStepped, function() frames = frames + 1 end)
        api.every(0.5, function()
            local now = os.clock()
            local elapsed = now - lastSample
            local fps = elapsed > 0 and math.floor(frames / elapsed + 0.5) or 0
            frames = 0
            lastSample = now
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
        -- FAKE BUYER (only on your screen)
        -- When the game asks to sell you something (a game pass, a product, an item or a bundle), Roblox's purchase
        -- window does not open: a copy drawn by the plugin shows up instead, with the Robux you typed and, if you
        -- want, the Roblox Plus price. "Buy" only plays the purchase on your screen and takes the price from your
        -- visual Robux. Nothing is bought, the game is never told about it and your real Robux are not touched.
        -- The item's name, price and picture are read with GetProductInfo, the same read-only lookup games use.
        ------------------------------------------------------------------------------------------------------------
        api.section({Title = "Fake buyer", Text = "Only on your screen: nothing is bought and the game is never told."})
        local MarketplaceService = game:GetService("MarketplaceService")
        local ROBUX = utf8.char(0xE002) -- the Robux icon inside Roblox texts
        local colors = {
            Panel = Color3.fromRGB(25, 27, 31),
            Text = Color3.fromRGB(240, 242, 245),
            Soft = Color3.fromRGB(160, 163, 170),
            Line = Color3.fromRGB(62, 65, 72),
            Blue = Color3.fromRGB(51, 95, 255),
            Grey = Color3.fromRGB(58, 61, 68),
        }
        local promptKinds = {
            PromptGamePassPurchase = "GamePass",
            PromptProductPurchase = "Product",
            PromptPurchase = "Asset",
            PromptBundlePurchase = "Bundle",
        }
        local infoTypes = {
            GamePass = Enum.InfoType.GamePass,
            Product = Enum.InfoType.Product,
            Asset = Enum.InfoType.Asset,
            Bundle = Enum.InfoType.Bundle,
        }
        local thumbnailTypes = {GamePass = "GamePass", Asset = "Asset", Bundle = "BundleThumbnail"}
        local fake = {On = false, Hooked = false, Pending = nil}
        local prompt = {}
        local balanceControl, plusSwitch, fakeSwitch

        local function withCommas(value)
            local sign, digits = tostring(math.floor(value)):match("^(-?)(%d+)$")
            if not digits then return tostring(value) end
            digits = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
            return sign .. digits
        end
        -- Item names go inside rich text, where < > & " ' have a meaning of their own.
        local function escaped(value)
            return (value:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&apos;"))
        end
        local function balance()
            return math.max(0, math.floor(tonumber(balanceControl and balanceControl.Get()) or 0))
        end
        local function plusOn()
            return plusSwitch ~= nil and plusSwitch.Get() == true
        end
        local function plusPrice(price)
            return math.floor(price * 0.8 + 0.5) -- Plus takes 20% off, like 75 -> 60
        end

        local function make(class, properties, parent)
            local item = Instance.new(class)
            for property, value in pairs(properties) do item[property] = value end
            item.Parent = parent
            return item
        end
        local function round(item, radius)
            make("UICorner", {CornerRadius = UDim.new(0, radius)}, item)
        end
        local function text(parent, properties)
            local label = make("TextLabel", {
                BackgroundTransparency = 1, BorderSizePixel = 0, Font = Enum.Font.BuilderSans, TextSize = 15,
                TextColor3 = colors.Text, TextXAlignment = Enum.TextXAlignment.Left, RichText = true,
            }, parent)
            for property, value in pairs(properties) do label[property] = value end
            return label
        end
        local function blueButton(parent, caption, order)
            local button = make("TextButton", {
                LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = colors.Blue, BorderSizePixel = 0,
                AutoButtonColor = true, Font = Enum.Font.BuilderSansBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
                Text = caption,
            }, parent)
            round(button, 8)
            return button
        end

        local function closePrompt()
            if prompt.Gui then prompt.Gui:Destroy() end
            prompt = {}
        end
        -- The dark backdrop and the empty window every step of the purchase is drawn in.
        local function newWindow(item, step)
            closePrompt()
            local gui = make("ScreenGui", {
                Name = "LyraToolsPurchase", ResetOnSpawn = false, DisplayOrder = 1001, IgnoreGuiInset = true,
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            })
            -- Covers the screen so taps don't reach the game behind the window, like Roblox's own one.
            make("TextButton", {
                Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45,
                BorderSizePixel = 0, AutoButtonColor = false, Text = "",
            }, gui)
            local window = make("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 0),
                AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = colors.Panel, BorderSizePixel = 0,
            }, gui)
            round(window, 12)
            make("UIPadding", {
                PaddingTop = UDim.new(0, 16), PaddingBottom = UDim.new(0, 16),
                PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16),
            }, window)
            make("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 14)}, window)
            -- Small phones get a smaller window instead of one cut at the edges.
            local camera = workspace.CurrentCamera
            local width = camera and camera.ViewportSize.X or 1000
            make("UIScale", {Scale = math.clamp((width - 24) / 380, 0.6, 1)}, window)
            gui.Parent = guiParent()
            prompt = {Gui = api.track(gui), Window = window, Item = item, Step = step}
            return window
        end
        local function header(window, title)
            local bar = make("Frame", {LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1}, window)
            text(bar, {Size = UDim2.new(1, -200, 1, 0), Font = Enum.Font.BuilderSansBold, TextSize = 18, Text = title})
            text(bar, {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -36, 0.5, 0), Size = UDim2.new(0, 160, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.BuilderSansBold, TextSize = 14,
                Text = ROBUX .. " " .. withCommas(balance()),
            })
            local close = make("TextButton", {
                AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(28, 28),
                BackgroundTransparency = 1, Font = Enum.Font.BuilderSansBold, TextSize = 18, TextColor3 = colors.Text,
                Text = "X",
            }, bar)
            close.MouseButton1Click:Connect(closePrompt)
        end

        local showPrompt
        local function showDone(item)
            local window = newWindow(item, "done")
            header(window, "Purchase completed")
            text(window, {
                LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextWrapped = true,
                TextColor3 = colors.Soft, Text = "You have successfully bought <b>" .. escaped(item.Name) .. "</b>.",
            })
            blueButton(window, "OK", 3).MouseButton1Click:Connect(closePrompt)
        end
        showPrompt = function(item)
            local window = newWindow(item, "buy")
            header(window, "Buy item")
            local plus = plusOn()
            local cost = plus and plusPrice(item.Price) or item.Price

            local row = make("Frame", {LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 64), BackgroundTransparency = 1}, window)
            local picture = make("ImageLabel", {
                Size = UDim2.fromOffset(64, 64), BackgroundColor3 = colors.Grey, BorderSizePixel = 0,
                Image = item.Image, ScaleType = Enum.ScaleType.Fit,
            }, row)
            round(picture, 8)
            text(row, {
                Position = UDim2.fromOffset(78, 6), Size = UDim2.new(1, -78, 0, 22), Font = Enum.Font.BuilderSansBold,
                TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd, RichText = false, Text = item.Name,
            })
            local price = ROBUX .. " " .. withCommas(cost)
            if plus and cost ~= item.Price then
                price = price .. '  <font color="#A0A3AA"><s>' .. ROBUX .. " " .. withCommas(item.Price) .. "</s></font>"
            end
            text(row, {
                Position = UDim2.fromOffset(78, 34), Size = UDim2.new(1, -78, 0, 22), Font = Enum.Font.BuilderSansBold,
                Text = price,
            })

            if plus and cost ~= item.Price then
                local saving = make("Frame", {
                    LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1,
                }, window)
                round(saving, 8)
                make("UIStroke", {Color = colors.Line, Thickness = 1}, saving)
                -- The Plus icon: a ring with a plus inside.
                local badge = make("Frame", {
                    AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(18, 18),
                    BackgroundTransparency = 1,
                }, saving)
                round(badge, 9)
                make("UIStroke", {Color = colors.Text, Thickness = 1.5}, badge)
                text(badge, {
                    Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
                    Font = Enum.Font.BuilderSansBold, TextSize = 15, Text = "+",
                })
                text(saving, {
                    Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -52, 1, 0), TextSize = 14,
                    Text = "Saving <b>" .. ROBUX .. " " .. withCommas(item.Price - cost) .. "</b> with Plus",
                })
            end

            local enough = balance() >= cost
            local buy = blueButton(window, enough and "Buy" or "Not enough Robux", 4)
            if not enough then
                buy.BackgroundColor3 = colors.Grey
                buy.AutoButtonColor = false
                return
            end
            local current = prompt
            buy.MouseButton1Click:Connect(function()
                if prompt ~= current or current.Buying then return end
                current.Buying = true
                buy.Text = "Buying…"
                buy.BackgroundColor3 = colors.Grey
                buy.AutoButtonColor = false
                api.spawn(function()
                    task.wait(1.2) -- a real purchase takes a moment too
                    if prompt ~= current or not api.alive() then return end
                    balanceControl.Set(math.max(0, balance() - cost))
                    showDone(item)
                end)
            end)
        end

        -- Reads what the game is selling. A failed lookup still opens the window, with what is known.
        local function itemFromGame(kind, id)
            local item = {Name = "Item", Price = 0, Image = ""}
            local ok, info = pcall(function() return MarketplaceService:GetProductInfo(id, infoTypes[kind]) end)
            if ok and type(info) == "table" then
                item.Name = type(info.Name) == "string" and info.Name or item.Name
                item.Price = math.max(0, math.floor(tonumber(info.PriceInRobux) or 0))
                local icon = tonumber(info.IconImageAssetId)
                if icon and icon > 0 then item.Image = "rbxassetid://" .. icon end
            end
            if item.Image == "" and thumbnailTypes[kind] then
                item.Image = string.format("rbxthumb://type=%s&id=%d&w=150&h=150", thumbnailTypes[kind], id)
            end
            return item
        end
        -- The hook only leaves a note; the window is opened from the plugin's own thread, every frame at most.
        api.every(0, function()
            local pending = fake.Pending
            if not pending or not fake.On then return end
            fake.Pending = nil
            api.spawn(function()
                local item = itemFromGame(pending.Kind, pending.Id)
                if fake.On and api.alive() then showPrompt(item) end
            end)
        end)

        -- The game's purchase requests are caught here, so Roblox's real window never opens while this is on.
        local function hookPrompts()
            if fake.Hooked then return true end
            if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then return false end
            local wrap = type(newcclosure) == "function" and newcclosure or function(fn) return fn end
            local original
            original = hookmetamethod(game, "__namecall", wrap(function(self, ...)
                if fake.On and self == MarketplaceService and api.alive() then
                    local kind = promptKinds[getnamecallmethod()]
                    if kind and not (type(checkcaller) == "function" and checkcaller()) then
                        local id = tonumber((select(2, ...)))
                        if id and id > 0 and id == math.floor(id) then fake.Pending = {Kind = kind, Id = id} end
                        return nil
                    end
                end
                return original(self, ...)
            end))
            fake.Hooked = true
            return true
        end

        fakeSwitch = api.toggle({
            Title = "Robux visual",
            Description = "When the game offers a purchase, a copy of Roblox's window opens with your visual Robux. Buy plays the purchase on your screen only. Real purchases don't open while this is on.",
            Save = "FakeBuyer",
            Changed = function(on)
                if on and not hookPrompts() then
                    api.notify("Your executor can't do this (it has no hookmetamethod).", "warning")
                    if fakeSwitch then fakeSwitch.Set(false, true) end
                    fake.On = false
                    return
                end
                fake.On = on
                fake.Pending = nil
                if not on then closePrompt() end
            end,
        })
        local function redraw()
            if prompt.Step == "buy" and prompt.Item then showPrompt(prompt.Item) end
        end
        balanceControl = api.number({
            Title = "Robux",
            Description = "How many Robux the purchase window shows. Each visual purchase takes its price from here.",
            Min = 0,
            Max = 999999999,
            Step = 100,
            Default = 15041,
            Save = "FakeRobux",
            Changed = redraw,
        })
        plusSwitch = api.toggle({
            Title = "Roblox Plus",
            Description = "Shows the Plus icon and the Plus price (20% off) in the purchase window.",
            Save = "FakePlus",
            Changed = redraw,
        })
        api.button({
            Title = "Try it",
            Description = "Opens the purchase window with an example item.",
            Button = "Open",
            Pressed = function()
                showPrompt({Name = "Theme Prop", Price = 75, Image = ""})
            end,
        })
        api.onUnload(closePrompt)

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
