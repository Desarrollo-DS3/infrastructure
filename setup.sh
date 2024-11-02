#!/bin/bash

# Crear el clúster K3D
k3d cluster create store-cluster -p "8081:30100@agent:0" --port 50840:80@loadbalancer --agents 1 

# Taint y label de nodos
kubectl taint nodes k3d-store-cluster-server-0 dedicated=server:NoSchedule
kubectl label nodes k3d-store-cluster-agent-0 stock=true

# Aplicar el operador de RabbitMQ
kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"

# Esperar a que la CRD esté establecida
kubectl wait --for=condition=Established crd/rabbitmqclusters.rabbitmq.com --timeout=120s

# Aplicar la definición de RabbitMQ
kubectl apply -f ./rabbit/rabbit.yaml 

# Esperar 3 segundos
sleep 10

# Esperar a que el pod esté listo
kubectl wait --for=condition=ready pod/rabbit-server-0 -n rabbitmq-system --timeout=120s

# Obtener el secreto
# Obtener el nombre de usuario
USERNAME=$(kubectl -n rabbitmq-system get secret rabbit-default-user -o jsonpath="{.data.username}")

# Obtener la contraseña
PASSWORD=$(kubectl -n rabbitmq-system get secret rabbit-default-user -o jsonpath="{.data.password}")

kubectl create secret generic rabbitmq-credentials \
    --namespace=default \
    --from-literal=username="$USERNAME" \
    --from-literal=password="$PASSWORD"

kubectl -n rabbitmq-system get secret rabbit-default-user -o jsonpath="{.data.username}" | base64 --decode; echo; kubectl -n rabbitmq-system get secret rabbit-default-user -o jsonpath="{.data.password}" | base64 --decode

# Port forward al RabbitMQ Management
kubectl port-forward -n rabbitmq-system rabbit-server-0 8080:15672 &

# Aplicar configuraciones y secretos de stock (descomentado si es necesario)
kubectl apply -f ./stock/stock-config.yaml
kubectl apply -f ./stock/stock-secrets.yaml
kubectl apply -f ./stock/stock-deployment.yaml

# Obtener todos los recursos en el namespace rabbitmq-system
# kubectl get all -l app.kubernetes.io/name=rabbit -n rabbitmq-system
