# mcp2xiaozhi bridge + health endpoint for Render
# https://github.com/StanleyChanH/MCP2Xiaozhi
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# 1. Ставим MCP SDK v1, совместимый pydantic и Flask для health-check
RUN pip install --no-cache-dir "mcp==1.28.1" "pydantic==2.11.4" "flask==3.1.0"

# 2. Ставим сам мост БЕЗ зависимостей, чтобы он не перетащил mcp 2.x
RUN pip install --no-cache-dir --no-deps mcp2xiaozhi

# 3. Вручную ставим остальные зависимости моста
RUN pip install --no-cache-dir websockets httpx anyio python-dotenv

WORKDIR /app
COPY mcp_config.json /app/mcp_config.json

# 4. Создаём Flask-сервер для health-check
#    Отвечает и на GET, и на HEAD — чтобы UptimeRobot работал на бесплатном тарифе
RUN cat > /app/health.py << 'PYEOF'
from flask import Flask
import os

app = Flask(__name__)

@app.route('/health', methods=['GET', 'HEAD'])
def health():
    return {'status': 'ok'}

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 10000))
    app.run(host='0.0.0.0', port=port)
PYEOF

# 5. Скрипт запуска: health в фоне + мост в foreground
RUN cat > /app/start.sh << 'SHEOF'
#!/bin/bash
python /app/health.py &
mcp2xiaozhi run --all
SHEOF

RUN chmod +x /app/start.sh

CMD ["/app/start.sh"]
