FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install pytest flask
EXPOSE 5000
CMD ["python", "web_app.py"]
