# Usa una imagen base de Python
FROM python:3.9-slim

# Establece el directorio de trabajo en el contenedor
WORKDIR /app

# Copia los archivos requeridos al contenedor
COPY . /app

# Instala las dependencias necesarias
RUN pip install pika

# Comando para ejecutar tu script de Python
CMD ["python", "main.py"]
