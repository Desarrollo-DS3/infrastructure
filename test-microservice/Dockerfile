# Usa una imagen base de Python
FROM python:3.9-slim

# Establece el directorio de trabajo en el contenedor
WORKDIR /app

# Copia los archivos requeridos al contenedor
COPY . /app

# Instala las dependencias necesarias
COPY requirements.txt .
RUN pip install -r requirements.txt

EXPOSE 5000

# Comando para ejecutar tu script de Python
CMD ["python", "main.py"]
