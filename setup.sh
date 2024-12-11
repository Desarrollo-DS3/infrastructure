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

# Desplegar la aplicación Auth
# Aquí se aplica el archivo de despliegue de auth, que es responsable de gestionar la autenticación y autorización.
kubectl apply -f ./auth/auth-config.yaml
kubectl apply -f ./auth/auth-secrets.yaml
kubectl apply -f ./auth/auth-deployment.yaml

# Desplegar la aplicación Stock
# Aquí se aplica el archivo de despliegue de stock, que es responsable de gestionar el inventario de productos.
kubectl apply -f ./stock/stock-config.yaml
kubectl apply -f ./stock/stock-secrets.yaml
kubectl apply -f ./stock/stock-deployment.yaml

# Desplegar la aplicación Transaction
# Aquí se aplica el archivo de despliegue de transaction, que es responsable de gestionar las transacciones de compra.
kubectl apply -f ./transaction/transaction-config.yaml
kubectl apply -f ./transaction/transaction-secrets.yaml
kubectl apply -f ./transaction/transaction-db-volume.yaml
kubectl apply -f ./transaction/transaction-db-deployment.yaml
kubectl apply -f ./transaction/transaction-deployment.yaml

# Aplicar los CRDs y el operador Elastic
# Se crean las Custom Resource Definitions (CRDs) necesarias para utilizar ElasticSearch y Kibana en Kubernetes.
kubectl create -f https://download.elastic.co/downloads/eck/2.15.0/crds.yaml
# Aplicar el operador de ElasticSearch y Kibana
kubectl apply -f https://download.elastic.co/downloads/eck/2.15.0/operator.yaml

# Esperar a que la CRD de ElasticSearch esté establecida
kubectl wait --for=condition=Established crd/elasticsearches.elasticsearch.k8s.elastic.co --timeout=120s

# Desplegar ElasticSearch
# Aquí se aplica la configuración de ElasticSearch desde el archivo "elasticsearch.yaml".
kubectl apply -f ./elk/elasticsearch.yaml
# Esperar a que los pods de ElasticSearch estén listos
sleep 5
kubectl wait --for=condition=Ready --timeout=300s pod --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart'

# Desplegar Kibana
# Aquí se aplica la configuración de Kibana desde el archivo "kibana.yaml".
kubectl apply -f ./elk/kibana.yaml
# Esperar a que los pods de Kibana estén listos
sleep 5
kubectl wait --for=condition=Ready --timeout=300s pod --selector='kibana.k8s.elastic.co/name=quickstart'

# Desplegar Filebeat
# Aquí se aplica la configuración de Filebeat, que recolectará logs de los contenedores.
kubectl apply -f ./elk/filebeat.yaml
# Esperar a que los pods de Filebeat estén listos
sleep 5
kubectl wait --for=condition=Ready --timeout=300s pod --selector='beat.k8s.elastic.co/name=quickstart'

# Desplegar Logstash
# Aquí se aplica la configuración de Logstash, que procesará y enviará logs a ElasticSearch.
kubectl apply -f ./elk/logstash.yaml
# Esperar a que los pods de Logstash estén listos
sleep 5
kubectl wait --for=condition=Ready --timeout=300s pod --selector='logstash.k8s.elastic.co/name=quickstart'
