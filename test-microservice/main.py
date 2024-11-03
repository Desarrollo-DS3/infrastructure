import pika
import random
import os


def callback(ch, method, properties, body):
    print("Received %r" % body)
    
    if random.choice([True, False]):
        print("Process succeeded")
        ch.basic_ack(delivery_tag=method.delivery_tag)
    else:
        print("Process failed")
        rollback_channel.basic_publish(exchange='', routing_key='rollback_queue', body=body)
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=False)

def main():
        # Obtener las variables de entorno
    rabbit_host = os.getenv('RABBITMQ_HOST')
    rabbit_username = os.getenv('RABBITMQ_USERNAME')
    rabbit_password = os.getenv('RABBITMQ_PASSWORD')

    print(f"RabbitMQ Host: {rabbit_host}")
    print(f"RabbitMQ Username: {rabbit_username}")
    print(f"RabbitMQ Password: {rabbit_password}")

    # Conectar a RabbitMQ
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(
            host=rabbit_host, 
            port=5672, 
            credentials=pika.PlainCredentials(username=rabbit_username, password=rabbit_password)
        )
    )
    channel = connection.channel()
    global rollback_channel
    rollback_channel = connection.channel()

    channel.queue_declare(queue='purchase_queue')
    rollback_channel.queue_declare(queue='rollback_queue')

    channel.basic_consume(queue='purchase_queue', on_message_callback=callback)

    print('Waiting for messages. To exit press CTRL+C')
    channel.start_consuming()

if __name__ == "__main__":
    main()
