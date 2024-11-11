instance=rabbit
username=$(kubectl -n rabbitmq-system get secret ${instance}-default-user -o jsonpath="{.data.username}" | base64 --decode)
password=$(kubectl -n rabbitmq-system get secret ${instance}-default-user -o jsonpath="{.data.password}" | base64 --decode)
service=${instance}
kubectl run perf-test --image=pivotalrabbitmq/perf-test -- --uri "amqp://${username}:${password}@rabbit.rabbitmq-system.svc.cluster.local"
kubectl wait --for=condition=Ready pod/perf-test --timeout=60s
kubectl logs -f perf-test