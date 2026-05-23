# Navegador skill

Uma IA que controle o navegador como se fosse um usuário humano é algo que muita gente quer no Brasil.

Muitas pessoas entusiastas de agentes de IA não sabem programar e têm muita dificuldade em configurar uma IA para usar o navegador.

## Totalmente opinionado

- Só funciona no Windows 11
- O navegador e dados de usuário vão ficar no Windows e não no Wsl2
- Vai sempre usar o mesmo navegador Google Chrome para tudo, com o mesmo `user_data_dir`
- O navegador vai usar o Chrome com `user_data_dir` apontando para `%USERPROFILE%\Navegador`
- Será criada uma função chamada `navegador` para permitir que seus agentes de IA usem o navegador opinionado (adicionado ao seu `$PROFILE` do PowerShell)
- Não é necessário ter Wsl2, mas se tiver, será instalada a função `navegador` no `.bashrc` (se for Ubuntu 24+, caso contrário o Wsl2 será ignorado). A função no `.bashrc` vai apenas repassar os parâmetros para a função `navegador` do PowerShell
- Se a pessoa tiver ambos Claude Code e Codex instalados, a skill será instalada em ambos
- A skill será criada com escopo global e não de projeto, permitindo que qualquer projeto a use
- `agent-browser` será instalado no Windows via `npm install -g`, ficando disponível globalmente para uso no terminal

## Requerimentos

Você precisa ter o Codex ou Claude Code instalado no seu computador (pode ser na IDE ou Desktop) e precisa ter um plano pago ativo (aprox. R$ 100,00/mês).

Eu recomendo o Codex, pois ele também permite você usar o celular para controlar o navegador do computador.

## Como instalar

Criei um prompt que você pode copiar e colar no seu Codex ou Claude Code para instalar.

`````markdown
Siga o passo a passo para configurar a skill navegador neste computador.

## Guardrails

- Se o PowerShell não estiver disponível para uso, pare imediatamente e avise o usuário que este prompt apenas pode ser rodado em um Claude Code ou OpenAI Codex com acesso ao terminal.
- Se não for possível instalar algum software necessário, pare imediatamente e avise o usuário.
- Se qualquer coisa der errado, por favor remova todo e qualquer vestígio que este prompt possa ter deixado no computador: desinstale todo e qualquer software, remova arquivos que foram adicionados e reverta alterações manuais feitas em arquivos para a versão original.
- Não esconda erros. Se este prompt não puder ser executado até o final, mas for algo que o humano pode resolver, peça ao humano para resolver; caso o humano se recuse, prossiga com o modo de limpeza pois algo deu errado.
- Ao final, dê um relatório conciso para o usuário do que foi instalado e desinstalado, arquivos criados e alterados e um status informando se tudo deu certo.
- Se você não conseguir executar comandos no PowerShell do Windows, não prossiga com a instalação. Avise o usuário que esta skill precisa ser instalada no Windows diretamente e não deve rodar dentro de um Wsl.
- Você tem permissão de usar o PowerShell para instalar os softwares aqui descritos.

## Reinicialização do ambiente

É possível que, após instalar algo ou colocar variáveis de ambiente no Windows, a sua sessão de terminal não esteja atualizada. Você pode tentar atualizar sua sessão carregando diretamente o arquivo `$PROFILE` do Windows 11 ou pedindo para o humano reinicializar pra você: diga o motivo da reinicialização e peça ao usuário para voltar nessa conversa e digitar "continuar" para que você possa continuar o seu trabalho. Se ainda assim o comando não estiver disponível, confira se está no local correto e então pare imediatamente e diga que a reinicialização não funcionou.

Em qualquer dos casos, ao pedir para reiniciar, informe que o usuário pode te pedir para abortar e desinstalar tudo a qualquer momento, é só pedir.

## 1. Verificações de requerimentos

Verifique se Node/NPM está instalado e acessível pelo PowerShell — o comando `npm --version` precisa funcionar para continuar.

Caso o `npm` não esteja acessível, tente o comando `npm.exe --version`. Se funcionar, precisamos fazer o que for necessário para que o `npm` funcione sem o sufixo `.exe`.

## 2. Instale o agent-browser usando npm do Windows 11

```powershell
npm install -g agent-browser
agent-browser install  # Download Chrome from Chrome for Testing (first time only)
```

## 3. Adicione a função navegador ao PowerShell

Adicione uma função chamada `navegador` no arquivo `$PROFILE` do PowerShell para sempre reutilizar o mesmo perfil do Chrome em `%USERPROFILE%\Navegador`.

### 3.1 Garanta que o `$PROFILE` existe e pode rodar scripts

Em máquinas novas o arquivo `$PROFILE` pode não existir e a `ExecutionPolicy` do `CurrentUser` pode estar bloqueando a execução do perfil. Rode:

```powershell
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
}
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -in @('Restricted', 'Undefined', 'AllSigned')) {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}
```

### 3.2 Insira (ou substitua) o bloco da função no `$PROFILE`

O bloco é delimitado pelos marcadores `# >>> navegador >>>` e `# <<< navegador <<<`. Se o bloco já existir, substitua; caso contrário, anexe no final. Isso garante idempotência e permite remoção limpa em caso de rollback.

```powershell
$beginMarker = '# >>> navegador >>>'
$endMarker   = '# <<< navegador <<<'
$bloco = @"
$beginMarker
function navegador {
    param(
        [Parameter(ValueFromRemainingArguments = `$true)]
        [string[]] `$Argumentos
    )

    agent-browser --profile "`$env:USERPROFILE\Navegador" --headed @Argumentos
}
$endMarker
"@

$profileContent = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { '' }
if ($profileContent -match "(?ms)$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))") {
    $novoConteudo = [regex]::Replace(
        $profileContent,
        "(?ms)$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))",
        [System.Text.RegularExpressions.Regex]::Escape($bloco) -replace '\\(.)', '$1'
    )
    Set-Content -Path $PROFILE -Value $novoConteudo -Encoding UTF8
} else {
    Add-Content -Path $PROFILE -Value "`r`n$bloco`r`n" -Encoding UTF8
}
```

### 3.3 Carregue a função na sessão atual

Sem isso, o step 4 vai falhar porque o `$PROFILE` ainda não foi lido na sessão em uso.

```powershell
. $PROFILE
if (-not (Get-Command navegador -ErrorAction SilentlyContinue)) {
    throw "A funcao navegador nao ficou disponivel apos carregar o `$PROFILE. Verifique a ExecutionPolicy e se ha outra funcao/alias com o mesmo nome."
}
```

Depois disso, sempre que você executar um comando como:

```powershell
navegador open myapp.com
```

o PowerShell vai interpretar como:

```powershell
agent-browser --profile "%USERPROFILE%\Navegador" --headed open myapp.com
```

## 4. Teste se o navegador está funcionando

> TODO: melhorar esses comandos, não dá pra IA saber se vai estar funcionando mesmo rodando isso.

- `navegador open revolucaodainteligencia.com.br` — deve abrir o navegador para o usuário
- `navegador wait 5000` — deve esperar 5 segundos para a página carregar
- `navegador close` — deve fechar o navegador

Caso os comandos não estejam funcionando, siga os procedimentos de guardrails.

## 5. Cadastre a skill globalmente

Não use git, GitHub CLI nem peça conta do GitHub para o usuário.

O próprio Codex deve baixar o arquivo `SKILL.md` com uma request GET para a URL raw do GitHub. Baixe diretamente este arquivo:

```
https://raw.githubusercontent.com/giovannefeitosa/navegador/main/skills/navegador/SKILL.md
```

### 5.1 Verifique se Codex ou Claude Code estão instalados

No PowerShell, rode:

```powershell
$codexSkills = Join-Path $env:USERPROFILE ".codex\skills"
$claudeSkills = Join-Path $env:USERPROFILE ".claude\skills"
$hasCodex = Test-Path $codexSkills
$hasClaude = Test-Path $claudeSkills
[pscustomobject]@{
    CodexSkillsPath  = $codexSkills
    CodexInstalado   = $hasCodex
    ClaudeSkillsPath = $claudeSkills
    ClaudeInstalado  = $hasClaude
}
```

Se `CodexInstalado` e `ClaudeInstalado` forem ambos `False`, pare imediatamente e explique que o computador precisa ter Codex ou Claude Code instalados antes de cadastrar a skill globalmente.

### 5.2 Baixe o conteúdo da skill com GET

Rode este bloco no PowerShell:

```powershell
$skillUrl = "https://raw.githubusercontent.com/giovannefeitosa/navegador/main/skills/navegador/SKILL.md"
try {
    $response = Invoke-WebRequest -Uri $skillUrl -UseBasicParsing
}
catch {
    throw "Nao foi possivel baixar o arquivo da skill em $skillUrl. Verifique sua internet e se o repositorio ja esta publicado."
}
if ($response.StatusCode -ne 200) {
    throw "Download da skill falhou com status HTTP $($response.StatusCode)."
}
$skillContent = $response.Content
if ([string]::IsNullOrWhiteSpace($skillContent)) {
    throw "O arquivo SKILL.md veio vazio."
}
if ($skillContent -notmatch "(?m)^name:" -or $skillContent -notmatch "(?m)^description:") {
    throw "O arquivo baixado nao parece ser uma skill valida."
}
```

Se o arquivo não tiver sido baixado, pare imediatamente e explique que a skill não pôde ser baixada.

### 5.3 Grave a skill globalmente

Como esta skill possui apenas um arquivo, crie a pasta `navegador` dentro das pastas globais existentes e salve nela o arquivo `SKILL.md`.

Rode este bloco no PowerShell:

```powershell
$codexSkills = Join-Path $env:USERPROFILE ".codex\skills"
$claudeSkills = Join-Path $env:USERPROFILE ".claude\skills"
$hasCodex = Test-Path $codexSkills
$hasClaude = Test-Path $claudeSkills
if ($hasCodex) {
    $codexSkillDir = Join-Path $codexSkills "navegador"
    New-Item -ItemType Directory -Path $codexSkillDir -Force | Out-Null
    Set-Content -Path (Join-Path $codexSkillDir "SKILL.md") -Value $skillContent -Encoding UTF8
}
if ($hasClaude) {
    $claudeSkillDir = Join-Path $claudeSkills "navegador"
    New-Item -ItemType Directory -Path $claudeSkillDir -Force | Out-Null
    Set-Content -Path (Join-Path $claudeSkillDir "SKILL.md") -Value $skillContent -Encoding UTF8
}
```

### 5.4 Verifique se ficou global

Rode:

```powershell
Get-Content "$env:USERPROFILE\.codex\skills\navegador\SKILL.md" -ErrorAction SilentlyContinue | Select-Object -First 5
Get-Content "$env:USERPROFILE\.claude\skills\navegador\SKILL.md" -ErrorAction SilentlyContinue | Select-Object -First 5
```

Se apenas um dos programas estiver instalado, é normal que o outro comando não retorne nada.

Se o download da URL raw falhar, pare imediatamente e avise o usuário que o repositório ainda não está publicado ou a internet não está disponível.

## 6. Integração com WSL2 (opcional)

Se o computador tiver WSL2 com Ubuntu 24+, instale uma função `navegador` no `.bashrc` que apenas repassa todos os argumentos para a função `navegador` do PowerShell. Se não houver WSL2, ou se a distro padrão não for Ubuntu 24+, **ignore silenciosamente este passo e registre o motivo no relatório final**. Nunca interrompa a instalação por causa do WSL.

### 6.1 Detecte se há WSL2 instalado

```powershell
$wslDisponivel = $false
$wslMotivoIgnorado = $null
try {
    $wslStatus = wsl --status 2>$null
    if ($LASTEXITCODE -eq 0 -and $wslStatus) {
        $wslDisponivel = $true
    } else {
        $wslMotivoIgnorado = "WSL2 nao detectado neste computador."
    }
}
catch {
    $wslMotivoIgnorado = "WSL2 nao detectado neste computador."
}
```

### 6.2 Confirme que a distro padrão é Ubuntu 24+

Se `$wslDisponivel` for `$true`, rode dentro da distro padrão:

```powershell
if ($wslDisponivel) {
    $ubuntuVersao = (wsl -- bash -lc "lsb_release -rs 2>/dev/null" 2>$null) -as [string]
    $ubuntuVersao = ($ubuntuVersao -replace '\s', '')
    $ehUbuntu24 = $false
    if ($ubuntuVersao -match '^\d+(\.\d+)?$') {
        $major = [int]([double]$ubuntuVersao)
        if ($major -ge 24) { $ehUbuntu24 = $true }
    }
    if (-not $ehUbuntu24) {
        $wslMotivoIgnorado = "WSL2 detectado mas a distro padrao nao e Ubuntu 24+ (lsb_release retornou '$ubuntuVersao'). Integracao com .bashrc ignorada."
        $wslDisponivel = $false
    }
}
```

### 6.3 Escreva o bloco no `~/.bashrc` da distro

Use os mesmos marcadores `# >>> navegador >>>` / `# <<< navegador <<<` para garantir idempotência. A função em bash apenas repassa os argumentos para a função do PowerShell via `powershell.exe -NoProfile -Command "navegador @Args"`.

```powershell
if ($wslDisponivel) {
    $bashScript = @'
BEGIN_MARK="# >>> navegador >>>"
END_MARK="# <<< navegador <<<"
BASHRC="$HOME/.bashrc"
touch "$BASHRC"

BLOCO=$(cat <<'EOF'
# >>> navegador >>>
navegador() {
    powershell.exe -NoProfile -Command "navegador @Args" -- "$@"
}
# <<< navegador <<<
EOF
)

if grep -q "$BEGIN_MARK" "$BASHRC"; then
    awk -v b="$BEGIN_MARK" -v e="$END_MARK" '
        $0==b {skip=1}
        !skip {print}
        $0==e {skip=0; next}
    ' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
fi

printf "\n%s\n" "$BLOCO" >> "$BASHRC"
'@
    $bashScript | wsl -- bash -l
    if ($LASTEXITCODE -ne 0) {
        $wslMotivoIgnorado = "Falha ao escrever no .bashrc da distro WSL2. Integracao parcial."
        $wslDisponivel = $false
    }
}
```

Se a escrita no `.bashrc` falhar, registre o motivo no relatório final mas **não pare** a instalação — a skill no Windows continua funcionando.

## 7. Reiniciar o cliente de IA

Peça para o usuário fechar completamente o Claude Code e/ou o Codex (todas as janelas e o processo de background) e reabri-lo. Isso é necessário para que o cliente de IA carregue a skill recém-instalada do diretório global de skills.

Diga ao usuário que, após reiniciar, ele pode testar pedindo algo como **"use a skill navegador para abrir google.com"**. A IA reiniciada deve reconhecer a skill e usar a função `navegador` automaticamente.

Informe também que, caso queira desfazer toda a instalação no futuro, basta pedir "rode o rollback da skill navegador" — o procedimento está no apêndice deste prompt.

## 8. Relatório final

Após concluir todos os passos, mostre ao usuário um relatório no formato abaixo. Preencha cada campo com o que de fato aconteceu nesta máquina — não invente versões nem status.

```
=== Relatório de instalação — skill navegador ===

Softwares instalados:
- Node.js: <versão obtida em `node --version`>
- npm: <versão obtida em `npm --version`>
- agent-browser: <versão obtida em `agent-browser --version` ou `npm list -g agent-browser`>
- Chrome for Testing: <instalado via `agent-browser install` — sim/não, já existia/baixado agora>

Arquivos criados:
- <caminho do $PROFILE, se foi criado neste passo>
- <%USERPROFILE%\.codex\skills\navegador\SKILL.md, se aplicável>
- <%USERPROFILE%\.claude\skills\navegador\SKILL.md, se aplicável>

Arquivos modificados:
- $PROFILE: bloco `# >>> navegador >>>` ... `# <<< navegador <<<` inserido/atualizado
- ~/.bashrc da distro WSL2: <inserido/atualizado | não aplicável>
- ExecutionPolicy do CurrentUser: <alterada de X para RemoteSigned | inalterada>

Clientes em que a skill foi registrada:
- Codex: <sim/não>
- Claude Code: <sim/não>

Status do WSL2:
- <integrado com Ubuntu XX.XX | ignorado: <motivo> | não detectado>

Status geral: <✅ sucesso | ⚠️ sucesso parcial: <motivo> | ❌ falha: <motivo>>
```

Termine o relatório lembrando o usuário de reiniciar o cliente de IA (passo 7) caso ainda não tenha feito.

## Apêndice — Procedimento de rollback

Este é o procedimento que os guardrails referenciam. Use exatamente este bloco para desfazer a instalação. É idempotente: pode ser executado quantas vezes for necessário sem produzir erro mesmo se algum item já tiver sido removido.

```powershell
$beginMarker = '# >>> navegador >>>'
$endMarker   = '# <<< navegador <<<'

# 1. Remove o bloco do $PROFILE
if (Test-Path $PROFILE) {
    $conteudo = Get-Content $PROFILE -Raw
    if ($conteudo -match "(?ms)$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))") {
        $novo = [regex]::Replace(
            $conteudo,
            "(?ms)\r?\n?$([regex]::Escape($beginMarker)).*?$([regex]::Escape($endMarker))\r?\n?",
            ''
        )
        Set-Content -Path $PROFILE -Value $novo -Encoding UTF8
    }
}

# 2. Remove o bloco do ~/.bashrc da distro WSL2 (se houver)
try {
    $wslStatus = wsl --status 2>$null
    if ($LASTEXITCODE -eq 0 -and $wslStatus) {
        $script = @'
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ] && grep -q "# >>> navegador >>>" "$BASHRC"; then
    awk '
        $0=="# >>> navegador >>>" {skip=1}
        !skip {print}
        $0=="# <<< navegador <<<" {skip=0; next}
    ' "$BASHRC" > "$BASHRC.tmp" && mv "$BASHRC.tmp" "$BASHRC"
fi
'@
        $script | wsl -- bash -l 2>$null | Out-Null
    }
}
catch { }

# 3. Desinstala o agent-browser globalmente
npm uninstall -g agent-browser 2>$null | Out-Null

# 4. Apaga o diretório de perfil do Chrome
$perfil = Join-Path $env:USERPROFILE "Navegador"
if (Test-Path $perfil) {
    Remove-Item -Path $perfil -Recurse -Force -ErrorAction SilentlyContinue
}

# 5. Apaga as skills globais
$codexSkill  = Join-Path $env:USERPROFILE ".codex\skills\navegador"
$claudeSkill = Join-Path $env:USERPROFILE ".claude\skills\navegador"
foreach ($p in @($codexSkill, $claudeSkill)) {
    if (Test-Path $p) {
        Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "Rollback concluido. Caso o cliente de IA esteja aberto, reinicie-o para que a skill desapareca da lista."
```

Após rodar o rollback, peça ao usuário para reiniciar o Claude Code e/ou Codex para que a skill desapareça da lista de skills carregadas.
`````
