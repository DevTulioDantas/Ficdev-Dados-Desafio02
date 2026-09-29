#!/usr/bin/env bash
# =====================================================================
# Executa o workflow carga_completa (RF22) - Linux e macOS
# Equivalente ao executar_carga_completa.bat do Windows.
# Log de cada execucao: logs/carga_completa_AAAAMMDD_HHMMSS.log
# Codigo de saida: 0 = sucesso, diferente de 0 = falha
#
# HOP_HOME = pasta de instalacao do Apache Hop (padrao: ~/hop)
# =====================================================================
set -u

PROJ="$(cd "$(dirname "$0")/.." && pwd)"
HOP_HOME="${HOP_HOME:-$HOME/hop}"
mkdir -p "$PROJ/logs"
LOG="$PROJ/logs/carga_completa_$(date +%Y%m%d_%H%M%S).log"

cd "$PROJ"
"$HOP_HOME/hop-run.sh" -j desafio_dados_2 -e dev \
  -f "$PROJ/hop/workflows/carga_completa.hwf" -r local -l Basic > "$LOG" 2>&1
RESULTADO=$?

echo "Codigo de saida: $RESULTADO" >> "$LOG"
exit $RESULTADO
