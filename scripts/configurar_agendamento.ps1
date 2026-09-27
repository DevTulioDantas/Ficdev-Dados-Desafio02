# =====================================================================
# Cria (ou atualiza) a tarefa agendada da carga completa (RF22)
# no Agendador de Tarefas do Windows.
#
# -Horario : horário diário da execução (padrão 06:00)
# -Remover : apaga a tarefa agendada
#
# Pode ser executado mais de uma vez: se a tarefa já existir, ela é
# substituída pela configuração atual (idempotente).
# Requisitos no horário agendado: computador ligado, usuário conectado
# e Docker Desktop aberto (o PostgreSQL roda em container).
# =====================================================================
param(
    [string]$Horario = "06:00",
    [switch]$Remover
)

$NomeTarefa = "FIC_DEV carga_completa"
$Descricao  = "Desafio 2 - RF22: carga Bronze + Silver via hop-run"

# Caminho do .bat calculado a partir da pasta deste script,
# funciona em qualquer computador da equipe, sem caminho fixo.
$ScriptCarga = Join-Path $PSScriptRoot "executar_carga_completa.bat"

# --- Remoção -----------------------------------------------------------
if ($Remover) {
    if (Get-ScheduledTask -TaskName $NomeTarefa -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $NomeTarefa -Confirm:$false
        Write-Host "Tarefa '$NomeTarefa' removida." -ForegroundColor Yellow
    } else {
        Write-Host "Tarefa '$NomeTarefa' não existe. Nada a remover."
    }
    exit 0
}

# --- Validações --------------------------------------------------------
if (-not (Test-Path $ScriptCarga)) {
    Write-Host "Script não encontrado: $ScriptCarga" -ForegroundColor Red
    exit 1
}

try {
    $hora = [datetime]::ParseExact($Horario, "HH:mm", $null)
} catch {
    Write-Host "Horário inválido: '$Horario'. Use o formato HH:mm, ex.: 06:00" -ForegroundColor Red
    exit 1
}

# --- Criação / atualização --------------------------------------------
$acao    = New-ScheduledTaskAction -Execute "`"$ScriptCarga`""
$gatilho = New-ScheduledTaskTrigger -Daily -At $hora

# StartWhenAvailable: se o PC estava desligado às 06:00, roda assim que ligar.
# ExecutionTimeLimit: encerra a execução se passar de 1 hora (evita tarefa travada).
$config  = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)

Register-ScheduledTask -TaskName $NomeTarefa `
                       -Action $acao `
                       -Trigger $gatilho `
                       -Settings $config `
                       -Description $Descricao `
                       -Force | Out-Null

# --- Conferência -------------------------------------------------------
$info = Get-ScheduledTaskInfo -TaskName $NomeTarefa
Write-Host ""
Write-Host "Tarefa agendada com sucesso." -ForegroundColor Green
Write-Host ("Nome ............: {0}" -f $NomeTarefa)
Write-Host ("Executa .........: {0}" -f $ScriptCarga)
Write-Host ("Horário .........: todo dia às {0}" -f $hora.ToString("HH:mm"))
Write-Host ("Próxima execução : {0}" -f $info.NextRunTime)
Write-Host ""
Write-Host "Para testar agora:"
Write-Host "  powershell -ExecutionPolicy Bypass -File .\scripts\verificar_agendamento.ps1 -Executar"
