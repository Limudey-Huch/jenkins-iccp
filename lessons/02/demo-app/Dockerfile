FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install pytest
CMD ["pytest", "--junitxml=results.xml"]
