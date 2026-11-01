# Plugins do Avatar Studio

Plugins adicionam ferramentas extras ao **Avatar Studio**. Eles ficam na aba **Plugins** do script.

[Read in English](README.md)

## Lyra Tools (plugin oficial)

1. Abra o Avatar Studio e vá na aba **Plugins**.
2. Toque em **Install Lyra Tools**.

Pronto. Ele fica instalado e liga sozinho toda vez que você executa o script.

O que ele tem:

| Ferramenta | O que faz |
| --- | --- |
| Anti-fling | Outros players não conseguem te empurrar nem te girar pra longe. |
| Anti-kick | Bloqueia kicks que o jogo faz do seu lado. Kick vindo do servidor do jogo não tem como bloquear. |
| Anti-AFK | O Roblox não te expulsa por ficar 20 minutos parado. |
| FPS limit | Aumenta o limite de FPS (120, 144, 240 ou ilimitado). O jogo continua com a mesma cara. |
| Background mode | Para de desenhar o jogo enquanto o Roblox está em segundo plano. Esquenta e gasta menos bateria. |
| Low graphics | Mais FPS: tira texturas, sombras e efeitos do mapa. O avatar dos players fica como está. Desligando, tudo volta. |
| FPS and ping | Um contador pequeno no canto da tela. |
| Rejoin / Server hop | Entrar de novo no mesmo servidor, ou ir pra outro. |

Algumas ferramentas dependem do seu executor (FPS limit e anti-kick). Se ele não tiver suporte, a ferramenta avisa.

## Instalar um plugin que alguém compartilhou

1. Pegue o **link raw** do plugin. No GitHub: abra o arquivo `.lua`, toque em **Raw** e copie o endereço. Ele começa com `https://raw.githubusercontent.com/`.
2. Na aba **Plugins**, cole o link na caixa e toque em **Install**.

Os plugins ficam salvos na pasta `workspace` do seu executor, dentro de **Avatar-copier plugins**. Cada um tem um botão pra ligar e desligar, **Update** pra baixar a versão mais nova, e **Remove**.

> **Só instale plugins de quem você confia.** Um plugin roda código com acesso total do seu executor, igual a qualquer script que você executa.

## Fazer o seu próprio plugin

Um plugin é um arquivo Lua. Não precisa saber muito de Lua pra começar.

**1.** Crie uma conta grátis no GitHub e um repositório **público**.

**2.** Adicione um arquivo, por exemplo `meu-plugin.lua`, com isto:

```lua
return {
    Name = "Meu plugin",
    Version = "1.0.0",
    Author = "seu nome",
    Description = "Uma frase sobre o que ele faz.",

    Load = function(api)
        -- Um botão de liga/desliga. Changed roda toda vez que ele muda.
        api.toggle({
            Title = "Dar oi quando eu renascer",
            Description = "Mostra uma mensagem toda vez que seu personagem nasce.",
            Save = "DarOi", -- lembra do botão na próxima vez
            Changed = function(on)
                api.notify(on and "Ligado" or "Desligado")
            end,
        })

        -- Roda pro seu personagem agora e depois de cada vez que ele renasce.
        api.onCharacter(function(character)
            if api.get("DarOi", false) then
                api.notify("Oi, " .. api.Player.DisplayName .. "!")
            end
        end)

        -- Um botão.
        api.button({
            Title = "Olá",
            Description = "Diz olá.",
            Button = "Dizer",
            Pressed = function()
                api.notify("Olá!", "success")
            end,
        })
    end,
}
```

**3.** Abra o arquivo no GitHub, toque em **Raw**, copie o link e instale na aba Plugins.

**4.** Pra compartilhar, mande esse link raw. Quando você mudar o arquivo no GitHub, as pessoas tocam em **Update** pra pegar a versão nova.

Pra um exemplo maior, leia o [`plugins/lyra-tools.lua`](plugins/lyra-tools.lua). Cada parte dele é explicada (em inglês).

## O que o `api` faz

### Controles

Aparecem no card do seu plugin, na ordem em que você cria.

| Código | O que cria |
| --- | --- |
| `api.section({Title = "...", Text = "..."})` | Um título. |
| `api.label({Text = "..."})` | Uma linha de texto. `label.Set("texto novo")` muda ele. |
| `api.button({Title, Description, Button, Pressed})` | Um botão. `Pressed()` roda quando toca. |
| `api.toggle({Title, Description, Default, Save, Changed})` | Um liga/desliga. `Changed(on)` roda quando muda, e uma vez quando o plugin carrega se ficou ligado. |
| `api.number({Title, Description, Min, Max, Step, Default, Save, Changed})` | Um número com botões - e + (dá pra digitar também). `Changed(valor)` roda quando muda. `api.slider` é a mesma coisa. |
| `api.input({Title, Description, Placeholder, Button, Default, Submitted})` | Uma caixa de texto com botão. `Submitted(texto)` roda no botão ou no Enter. |
| `api.dropdown({Title, Description, Options = {"A", "B"}, Default, Save, Changed})` | Uma lista de opções. `Changed(opção)` roda quando escolhe outra. |

Todo controle, menos o título, devolve um objeto com `.Get()` e `.Set(valor)`. No botão, eles leem e mudam o texto do botão.

`Save = "AlgumNome"` faz o controle lembrar o valor na próxima vez.

### Rodar código

Tudo que você começa com isto para sozinho quando o plugin é desligado, atualizado ou removido.

| Código | O que faz |
| --- | --- |
| `api.connect(sinal, function(...) end)` | Conecta num evento do Roblox, tipo `RunService.Heartbeat`. |
| `api.every(segundos, function() end)` | Roda de novo e de novo. `0` é a cada frame. |
| `api.spawn(function() end)` | Roda algo em segundo plano. |
| `api.onCharacter(function(character) end)` | Roda pro seu personagem agora e depois de cada vez que renasce. |
| `api.track(instancia)` | Algo que você criou (uma GUI, uma part). É destruído quando o plugin desliga. |
| `api.onUnload(function() end)` | Roda quando o plugin desliga. Coloque as coisas de volta aqui. |

### Outros

| Código | O que faz |
| --- | --- |
| `api.notify("texto", tipo)` | Uma mensagem na tela. `tipo` é `"info"`, `"success"`, `"warning"` ou `"error"`. |
| `api.get(nome, padrao)` / `api.set(nome, valor)` | Guarda seus próprios valores (true/false, números, textos curtos) pra próxima vez. |
| `api.alive()` | `false` depois que o plugin foi desligado. |
| `api.Player` | Seu player. |
| `api.Version` | A versão do Avatar Studio. |

### Bom saber

- Se o seu plugin tiver um erro, o erro aparece no card dele. O resto do Avatar Studio continua funcionando.
- Um arquivo de plugin pode ter até 500 KB, e você pode ter até 30 plugins.
- O arquivo também pode devolver só a função: `return function(api) ... end`.
