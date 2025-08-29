#!/usr/bin/env bash
# setup.sh — instala dependências, cria venv e inicia a API com waitress em background
# Uso:
#   chmod +x setup.sh
#   ./setup.sh
#
# Variáveis opcionais:
#   PORT=8000 HOST=0.0.0.0 VENVDIR=.venv LOG_DIR=./logs REQ_FILE=./requirements.txt SOURCE_DOTENV=1 ./setup.sh

set -Eeuo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8000}"
HOST="${HOST:-0.0.0.0}"
VENVDIR="${VENVDIR:-$APP_DIR/.venv}"
LOG_DIR="${LOG_DIR:-$APP_DIR/logs}"
REQ_FILE="${REQ_FILE:-$APP_DIR/requirements.txt}"
APP_MODULE="${APP_MODULE:-main:app}"  # ajuste se seu app estiver em outro módulo
NOHUP_CMD="nohup waitress-serve --listen=${HOST}:${PORT} ${APP_MODULE} &"

echo "==> Diretorio da app: $APP_DIR"
echo "==> Porta/Host: ${HOST}:${PORT}"
echo "==> Venv: $VENVDIR"
echo "==> Logs: $LOG_DIR"
echo "==> Reqs: $REQ_FILE"
echo "==> App:  $APP_MODULE"

# 1) Instalar Python + ferramentas (se possível)
install_system_deps() {
  if command -v python3 >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
    echo "==> Python3 e pip já presentes. Pulando instalação do sistema."
    return 0
  fi

  if command -v apt-get >/dev/null 2>&1; then
    echo "==> Instalando via apt-get..."
    sudo apt-get update -y
    sudo apt-get install -y python3 python3-venv python3-pip
  elif command -v yum >/dev/null 2>&1; then
    echo "==> Instalando via yum..."
    sudo yum install -y python3 python3-pip
    # Em algumas distros, o venv já vem junto. Caso falhe, tente: sudo yum install -y python3-virtualenv
  elif command -v apk >/dev/null 2>&1; then
    echo "==> Instalando via apk..."
    sudo apk add --no-cache python3 py3-pip py3-virtualenv
  else
    echo "!! Não foi possível detectar um gerenciador de pacotes compatível."
    echo "   Certifique-se de ter python3, pip e venv instalados."
  fi
}
install_system_deps

# 2) Criar venv
if [ ! -d "$VENVDIR" ]; then
  echo "==> Criando ambiente virtual em $VENVDIR"
  python3 -m venv "$VENVDIR"
fi
# shellcheck disable=SC1090
source "$VENVDIR/bin/activate"
python -m pip install --upgrade pip setuptools wheel

# 3) Instalar dependências Python
if [ -f "$REQ_FILE" ]; then
  echo "==> Instalando requirements de $REQ_FILE"
  pip install --no-cache-dir -r "$REQ_FILE"
else
  echo "==> requirements.txt não encontrado. Instalando mínimo necessário..."
  pip install --no-cache-dir flask flask-cors python-dotenv waitress
fi

# 4) (Opcional) Carregar .env no processo atual ANTES de subir (para variáveis usadas pelo waitress/app)
if [ "${SOURCE_DOTENV:-0}" = "1" ] && [ -f "$APP_DIR/.env" ]; then
  echo "==> Carregando variáveis de $APP_DIR/.env para a sessão atual"
  # Exporta apenas linhas no formato KEY=VALUE sem espaços ao redor
  set -a
  # shellcheck disable=SC2046
  source <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=.+' "$APP_DIR/.env" | sed 's/\r$//')
  set +a
fi

# 5) Preparar logs
mkdir -p "$LOG_DIR"
OUT_LOG="$LOG_DIR/app.out"
PID_FILE="$LOG_DIR/app.pid"

# 6) Encerrar instâncias anteriores (se existirem)
echo "==> Encerrando instâncias anteriores (se houver)..."
if command -v pkill >/dev/null 2>&1; then
  pkill -f "waitress-serve --listen=${HOST}:${PORT} ${APP_MODULE}" || true
  pkill -f "waitress-serve.*${APP_MODULE}" || true
fi
if [ -f "$PID_FILE" ]; then
  OLD_PID="$(cat "$PID_FILE" || true)"
  if [ -n "${OLD_PID:-}" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "==> Matando PID antigo $OLD_PID"
    kill "$OLD_PID" || true
  fi
fi

# 7) Iniciar a aplicação
echo "==> Iniciando aplicação com:"
echo "    $NOHUP_CMD"
# Redireciona stdout/stderr para arquivo de log
bash -lc "$NOHUP_CMD" >>"$OUT_LOG" 2>&1
NEW_PID=$!
echo "$NEW_PID" > "$PID_FILE"
echo "==> App iniciado. PID: $NEW_PID"
echo "==> Logs: $OUT_LOG"

# 8) Checagem rápida de saúde
echo "==> Aguardando inicialização..."
sleep 1
HEALTH_URL="http://${HOST}:${PORT}/health"
# Para hosts 0.0.0.0, cheque via localhost
if [ "$HOST" = "0.0.0.0" ]; then
  HEALTH_URL="http://127.0.0.1:${PORT}/health"
fi

echo "==> Health check: $HEALTH_URL"
if command -v curl >/dev/null 2>&1; then
  curl -fsS "$HEALTH_URL" || echo "Health ainda não respondeu. Veja os logs."
fi

echo "==> Pronto! Para acompanhar logs em tempo real:"
echo "    tail -f $OUT_LOG"
echo "==> Para parar:"
echo "    kill \$(cat $PID_FILE)"
