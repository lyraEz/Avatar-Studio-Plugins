# Avatar Studio Plugins

Plugins add extra tools to **Avatar Studio**. You find them in the **Plugins** tab of the script.

[Leia em português](README.pt-BR.md)

## Lyra Tools (official plugin)

1. Open Avatar Studio and go to the **Plugins** tab.
2. Tap **Install Lyra Tools**.

That's it. It stays installed and turns on by itself every time you run the script.

What it has:

| Tool | What it does |
| --- | --- |
| Anti-fling | Other players can't push or spin you away. |
| Anti-kick | Blocks kicks the game does on your side. A kick from the game's server can't be blocked. |
| Anti-AFK | Roblox won't kick you for being idle for 20 minutes. |
| FPS limit | Raises the FPS limit (120, 144, 240 or unlimited). The game looks the same. |
| Background mode | Stops drawing the game while Roblox is in the background. Less heat and battery. |
| Low graphics | More FPS: removes textures, shadows and effects from the map. Players' avatars stay as they are. Turn it off to bring everything back. |
| FPS and ping | A small counter in the corner of the screen. |
| Rejoin / Server hop | Join the same server again, or move to another one. |

Some tools need your executor to support them (FPS limit and anti-kick). If it doesn't, the tool tells you.

## Install a plugin someone shared

1. Get the plugin's **raw link**. On GitHub: open the `.lua` file, tap **Raw**, and copy the address. It starts with `https://raw.githubusercontent.com/`.
2. In the **Plugins** tab, paste the link in the box and tap **Install**.

Plugins are saved in your executor's `workspace` folder, inside **Avatar-copier plugins**. Each one has a switch to turn it on or off, **Update** to download its newest version, and **Remove**.

> **Only install plugins from people you trust.** A plugin runs code with your executor's full access, like any script you execute.

## Make your own plugin

A plugin is one Lua file. You don't need to know much Lua to start.

**1.** Create a free GitHub account and a **public** repository.

**2.** Add a file to it, for example `my-plugin.lua`, with this:

```lua
return {
    Name = "My plugin",
    Version = "1.0.0",
    Author = "your name",
    Description = "One sentence about what it does.",

    Load = function(api)
        -- A switch. Changed runs every time it is switched.
        api.toggle({
            Title = "Say hi when I respawn",
            Description = "Shows a message every time your character spawns.",
            Save = "SayHi", -- remembers the switch for next time
            Changed = function(on)
                api.notify(on and "Turned on" or "Turned off")
            end,
        })

        -- Runs for your character now and after every respawn.
        api.onCharacter(function(character)
            if api.get("SayHi", false) then
                api.notify("Hi, " .. api.Player.DisplayName .. "!")
            end
        end)

        -- A button.
        api.button({
            Title = "Hello",
            Description = "Says hello.",
            Button = "Say it",
            Pressed = function()
                api.notify("Hello!", "success")
            end,
        })
    end,
}
```

**3.** Open the file on GitHub, tap **Raw**, copy the link and install it in the Plugins tab.

**4.** To share it, send that raw link. When you change the file on GitHub, people tap **Update** to get the new version.

For a bigger example, read [`plugins/lyra-tools.lua`](plugins/lyra-tools.lua). Every part of it is explained.

## What `api` can do

### Controls

They show up in your plugin's card, in the order you create them.

| Code | What it makes |
| --- | --- |
| `api.section({Title = "...", Text = "..."})` | A heading. |
| `api.label({Text = "..."})` | A line of text. `label.Set("new text")` changes it. |
| `api.button({Title, Description, Button, Pressed})` | A button. `Pressed()` runs when tapped. |
| `api.toggle({Title, Description, Default, Save, Changed})` | An on/off switch. `Changed(on)` runs when switched, and once when the plugin loads if it was left on. |
| `api.number({Title, Description, Min, Max, Step, Default, Save, Changed})` | A number with - and + buttons (it can also be typed). `Changed(value)` runs when it changes. `api.slider` is the same. |
| `api.input({Title, Description, Placeholder, Button, Default, Submitted})` | A text box with a button. `Submitted(text)` runs on the button or Enter. |
| `api.dropdown({Title, Description, Options = {"A", "B"}, Default, Save, Changed})` | A list of choices. `Changed(choice)` runs when another one is picked. |

Every control except the section returns an object with `.Get()` and `.Set(value)`. On a button, they read and change the button's text.

`Save = "SomeName"` makes the control remember its value for next time.

### Running code

Everything started with these stops by itself when the plugin is turned off, updated or removed.

| Code | What it does |
| --- | --- |
| `api.connect(signal, function(...) end)` | Connects to a Roblox event, like `RunService.Heartbeat`. |
| `api.every(seconds, function() end)` | Runs again and again. `0` means every frame. |
| `api.spawn(function() end)` | Runs something in the background. |
| `api.onCharacter(function(character) end)` | Runs for your character now and after every respawn. |
| `api.track(instance)` | Something you created (a GUI, a part). It is destroyed when the plugin is turned off. |
| `api.onUnload(function() end)` | Runs when the plugin is turned off. Put things back here. |

### Other

| Code | What it does |
| --- | --- |
| `api.notify("text", kind)` | A pop-up message. `kind` is `"info"`, `"success"`, `"warning"` or `"error"`. |
| `api.get(name, default)` / `api.set(name, value)` | Saves your own values (true/false, numbers, short texts) for next time. |
| `api.alive()` | `false` once the plugin was turned off. |
| `api.Player` | Your player. |
| `api.Version` | The version of Avatar Studio. |

### Good to know

- If your plugin has an error, the error shows on its card. The rest of Avatar Studio keeps working.
- A plugin file can be up to 500 KB, and you can have up to 30 plugins.
- `Load` can also be the only thing the file returns: `return function(api) ... end`.
