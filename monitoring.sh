kubectl get elasticsearch
kubectl get kibana
kubectl get filebeat
kubectl get logstash

PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')
echo "Password: $PASSWORD"

kubectl port-forward service/quickstart-kb-http 5601

echo "https://localhost:5601"