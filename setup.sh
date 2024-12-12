#!/bin/bash

# Crear el clúster K3D
# Este comando crea un clúster K3D llamado "store-cluster" con un puerto expuesto para el servidor (8000) 
# y otro puerto (50840) para el LoadBalancer. Además, se crea un nodo de carga (agent) y cuatro nodos de agentes.
k3d cluster create store-cluster -p "8000:30100@agent:1" --port 50840:80@loadbalancer --agents 4

# Taint y label de nodos
# Aplica una "taint" al primer nodo para evitar que se programen pods en él a menos que tengan la etiqueta correcta.
kubectl taint nodes k3d-store-cluster-server-0 dedicated=server:NoSchedule
# Etiqueta el segundo nodo de agente como "gateway=true" para asignar pods relacionados con el gateway a este nodo.
kubectl label nodes k3d-store-cluster-agent-0 gateway=true
# Etiqueta el tercer nodo de agente como "stock=true" para asignar pods relacionados con el stock a este nodo.
kubectl label nodes k3d-store-cluster-agent-1 stock=true
# Etiqueta el cuarto nodo de agente como "transaction=true" para asignar pods relacionados con la transacción a este nodo.
kubectl label nodes k3d-store-cluster-agent-2 transaction=true
# Etiqueta el quinto nodo de agente como "auth=true" para asignar pods relacionados con la autenticación a este nodo.
kubectl label nodes k3d-store-cluster-agent-3 auth=true

# Aplicar el operador de RabbitMQ
# El operador de RabbitMQ permite gestionar clústeres de RabbitMQ de manera declarativa en Kubernetes.
kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"

# Revisar si el operador RabbitMQ está corriendo
# Descomentando esta línea podrás revisar los recursos del operador en el namespace "rabbitmq-system".
# kubectl -n rabbitmq-system get all

# Esperar a que la CRD (Custom Resource Definition) esté establecida
# Aquí se espera que la CRD (rabbitmqclusters.rabbitmq.com) se establezca antes de seguir.
kubectl wait --for=condition=Established crd/rabbitmqclusters.rabbitmq.com --timeout=120s

# Aplicar la configuración de RabbitMQ
# El archivo `rabbit-config.yaml` contiene la configuración del clúster de RabbitMQ.
kubectl apply -f ./rabbit/rabbit-config.yaml
# Desplegar la configuración y despliegue de RabbitMQ
kubectl apply -f ./rabbit/rabbit-deployment.yaml
# Aplicar las credenciales de RabbitMQ
kubectl apply -f ./rabbit/rabbit-credentials.yaml

# Esperar unos segundos para que los pods de RabbitMQ se inicialicen
sleep 35

# Esperar a que el pod "rabbit-server-0" esté listo en el namespace "rabbitmq-system"
kubectl wait --for=condition=ready pod/rabbit-server-0 -n rabbitmq-system --timeout=180s

# Desplegar la aplicación Gateway
# Aquí se aplica el archivo de despliegue del gateway, que es responsable de gestionar las solicitudes entrantes.
kubectl apply -f ./gateway/gateway-deployment.yaml
kubectl wait --for=condition=ready pod -l app=gateway --timeout=180s

# Desplegar la aplicación Auth
# Aquí se aplica el archivo de despliegue de auth, que es responsable de gestionar la autenticación y autorización.
kubectl apply -f ./auth/auth-config.yaml
kubectl apply -f ./auth/auth-secrets.yaml
kubectl apply -f ./auth/auth-deployment.yaml
kubectl wait --for=condition=ready pod -l app=auth --timeout=180s

# Desplegar la aplicación Stock
# Aquí se aplica el archivo de despliegue de stock, que es responsable de gestionar el inventario de productos.
kubectl apply -f ./stock/stock-config.yaml
kubectl apply -f ./stock/stock-secrets.yaml
kubectl apply -f ./stock/stock-deployment.yaml
kubectl wait --for=condition=ready pod -l app=stock --timeout=180s

# Desplegar la aplicación Transaction
# Aquí se aplica el archivo de despliegue de transaction, que es responsable de gestionar las transacciones de compra.
kubectl apply -f ./transaction/transaction-config.yaml
kubectl apply -f ./transaction/transaction-secrets.yaml
kubectl apply -f ./transaction/transaction-db-volume.yaml
kubectl apply -f ./transaction/transaction-db-deployment.yaml
kubectl apply -f ./transaction/transaction-deployment.yaml
kubectl wait --for=condition=ready pod -l app=transaction --timeout=180s

# Configurar el monitor de Elastic en la nube
kubectl kustomize https://github.com/elastic/elastic-agent/deploy/kubernetes/elastic-agent-kustomize/default/elastic-agent-standalone\?ref\=v8.16.1 | sed -e 's/JUFQSV9LRVkl/UlY4VHVKTUJrQ19kSncyRmlHckM6MENON2d1c19SZ0M3Q1pJY2Zxc2Mxdw==/g' -e "s/%ES_HOST%/https:\/\/8ad1be6b3216474a83b9f8146d397917.us-central1.gcp.cloud.es.io:443/g" -e "s/%ONBOARDING_ID%/1e1b3b3f-3198-4e96-ae75-f3e6d5aa873d/g" -e "s/\(docker.elastic.co\/beats\/elastic-agent:\).*$/\18.16.1/g" -e "/{CA_TRUSTED}/c\ " | kubectl apply -f-