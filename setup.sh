#!/bin/bash

# Crear el clúster K3D
k3d cluster create store-cluster -p "8000:30100@agent:0" --port 50840:80@loadbalancer --agents 5

# Taint y label de nodos
kubectl taint nodes k3d-store-cluster-server-0 dedicated=server:NoSchedule
kubectl label nodes k3d-store-cluster-agent-0 gateway=true
kubectl label nodes k3d-store-cluster-agent-1 auth=true
kubectl label nodes k3d-store-cluster-agent-2 stock=true
kubectl label nodes k3d-store-cluster-agent-3 transaction=true

# Aplicar el operador de RabbitMQ
kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"
# Revisar si el operador está corriendo
# kubectl -n rabbitmq-system get all

# Esperar a que la CRD esté establecida
kubectl wait --for=condition=Established crd/rabbitmqclusters.rabbitmq.com --timeout=120s

kubectl apply -f ./rabbit/rabbit-config.yaml
kubectl apply -f ./rabbit/rabbit-deployment.yaml
kubectl apply -f ./rabbit/rabbit-credentials.yaml
# Revisar si el cluster está corriendo
# kubectl -n rabbitmq-system get all

# Esperar 3 segundos
sleep 35
# Esperar a que el pod esté listo
kubectl wait --for=condition=ready pod/rabbit-server-0 -n rabbitmq-system --timeout=180s

# Obtener los secretos
kubectl get secret rabbitmq-credentials -n default -o jsonpath="{.data.username}" | base64 --decode;
echo;
kubectl get secret rabbitmq-credentials -n default -o jsonpath="{.data.password}" | base64 --decode;
echo;

kubectl port-forward -n rabbitmq-system rabbit-server-0 8080:15672 &

kubectl apply -f ./gateway/gateway-deployment.yaml

kubectl apply -f ./auth/auth-config.yaml
kubectl apply -f ./auth/auth-secrets.yaml
kubectl apply -f ./auth/auth-deployment.yaml

kubectl apply -f ./stock/stock-config.yaml
kubectl apply -f ./stock/stock-secrets.yaml
kubectl apply -f ./stock/stock-deployment.yaml

kubectl apply -f ./transaction/transaction-config.yaml
kubectl apply -f ./transaction/transaction-secrets.yaml
kubectl apply -f ./transaction/transaction-db-volume.yaml
kubectl apply -f ./transaction/transaction-db-deployment.yaml
kubectl apply -f ./transaction/transaction-deployment.yaml

# Obtener todos los recursos en el namespace rabbitmq-system
# kubectl get all -l app.kubernetes.io/name=rabbit -n rabbitmq-system
