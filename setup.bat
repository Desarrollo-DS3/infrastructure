k3d cluster create store-cluster -p "8080:30100@agent:0" --port 50840:80@loadbalancer --agents 1 
kubectl taint nodes k3d-store-cluster-server-0 dedicated=server:NoSchedule

kubectl label nodes k3d-store-cluster-agent-0 stock=true

kubectl apply -f "https://github.com/rabbitmq/cluster-operator/releases/latest/download/cluster-operator.yml"

kubectl wait --for=condition=Established crd/rabbitmqclusters.rabbitmq.com --timeout=120s

kubectl apply -f ./rabbit/definition.yaml 

timeout /t 3

kubectl wait --for=condition=ready pod/definition-server-0 -n rabbitmq-system --timeout=120s

kubectl get secret definition-default-user -n rabbitmq-system -o yaml

kubectl port-forward -n rabbitmq-system definition-server-0 8080:15672

@REM kubectl apply -f ./stock/stock-config.yaml
@REM kubectl apply -f ./stock/stock-secrets.yaml
@REM kubectl apply -f ./stock/stock-deployment.yaml

@REM kubectl get all -l app.kubernetes.io/name=definition -n rabbitmq-system