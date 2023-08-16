# Profile Replication - Documentação

Bem-vindo à documentação do **ProfileReplication**!
Este é um módulo Roblox que oferece uma maneira simples e eficaz de gerenciar perfis de jogador e replicar dados do servidor com os clients.

## Funcionalidades Principais

- Sincronize automaticamente os dados dos jogadores com pastas replicadas no cliente.
- Utiliza ProfileService pra salvar os dados.

---
## Instalação

Siga estas etapas para integrar o **ProfileReplication** ao seu projeto Roblox:

**Diretamente no Roblox Studio:**
1. Pegue o modelo pelo Toolbox: *colocar url aqui*
2. Jogue o moduleScript ProfileService pra dentro de "ServerScriptService"

**Rojo download:**

1. Faça download do repositório
2. Cole a pasta dentro do src files
3. Configure seu o default.project.json pra importar os arquivos
    ```
    "ServerScriptService": {
        "ProfileReplication": {
            "$path": "path/ProfileReplication"
        }
    }
    ```

**Rojo submodulo:**

1. Adicione esse git como submodulo 
3. Configure seu o default.project.json pra importar os arquivos
    ```
    "ServerScriptService": {
        "ProfileReplication": {
            "$path": "path/ProfileReplication"
        }
    }
    ```

---

a. **Verifique as dependências:** O módulo utiliza pacotes como `signal`, `table-util` e `promise`. As dependências já devem aparecer como filho do módulo, dentro da pasta Packages.

## Uso

1. **Inicialize o módulo:** No script do seu jogo, inicialize o módulo `ProfileReplication` com o nome do banco de dados e um modelo de perfil.

2. **Use as funcionalidades:** Use os métodos fornecidos pelo módulo para interagir com os perfis dos jogadores, sincronizar dados e muito mais.

Aqui estão alguns exemplos de como usar o **ProfileReplication** em seu jogo:

```lua
-- Importe o módulo
local ProfileReplication = require(game.ServerScriptService.ProfileReplication)

-- Inicialize o módulo
local databaseName = "PlayerProfiles"
local profileTemplate = { coins = 0, level = 1 }
ProfileReplication:init(databaseName, profileTemplate)
ProfileReplication:start()

-- Interaja com perfis de jogadores
local player = game.Players.LocalPlayer
ProfileReplication:Set(player, "coins", 100)
ProfileReplication:Increment(player, "coins", 50)
```

## Equipe

Conheça os desenvolvedores por trás do **ProfileReplication**:

- Guto - Desenvolvedor
- Queiroz - Desenvolvedor Aux

---

Esperamos que o **ProfileReplication** o ajude em sua experiência Roblox!
