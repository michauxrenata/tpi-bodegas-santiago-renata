FROM python:3.12-slim
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . /srv/api
WORKDIR /srv/api
ENV PYTHONPATH=/srv PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN useradd --create-home apiuser
USER apiuser
CMD ["uvicorn", "api.app.main:app", "--host", "0.0.0.0", "--port", "8000"]
