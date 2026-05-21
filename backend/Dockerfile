FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    ffmpeg \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade pip setuptools==68.2.2 wheel

# Pin numpy to 1.x FIRST before anything else
RUN pip install --no-cache-dir "numpy<2.0"

# Install torch - upgraded to 2.4 for transformers compatibility
RUN pip install --no-cache-dir \
    torch==2.4.0 \
    torchaudio==2.4.0 \
    --index-url https://download.pytorch.org/whl/cpu

# Install whisperx
RUN pip install --no-cache-dir whisperx==3.1.1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Force numpy back to 1.x in case anything upgraded it
RUN pip install --no-cache-dir "numpy<2.0"

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]