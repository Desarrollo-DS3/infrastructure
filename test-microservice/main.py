import pika
import json
import os
from flask import Flask, request, jsonify
import threading

app = Flask(__name__)

rabbit_host = os.getenv('RABBITMQ_HOST')
rabbit_username = os.getenv('RABBITMQ_USERNAME')
rabbit_password = os.getenv('RABBITMQ_PASSWORD')

def send_to_rabbitmq(payload):
    # Conectar a RabbitMQ
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(
            host=rabbit_host,
            port=5672,
            credentials=pika.PlainCredentials(username=rabbit_username, password=rabbit_password)
        )
    )
    channel = connection.channel()

    channel.queue_declare(queue='purchase_discount_stock')

    channel.basic_publish(exchange='',
                          routing_key='purchase_discount_stock',
                          body=json.dumps(payload))

    print(f"Sent to purchase_discount_stock: {json.dumps(payload)}")

    connection.close()

def listen_to_queue(queue_name):
    connection = pika.BlockingConnection(
        pika.ConnectionParameters(
            host=rabbit_host,
            port=5672,
            credentials=pika.PlainCredentials(username=rabbit_username, password=rabbit_password)
        )
    )
    channel = connection.channel()

    channel.queue_declare(queue=queue_name)

    def callback(ch, method, properties, body):
        print(f"Received message from {queue_name}: {body.decode()}")
        ch.basic_ack(delivery_tag=method.delivery_tag)

    channel.basic_consume(queue=queue_name, on_message_callback=callback)

    print(f"Listening for messages on {queue_name}...")
    channel.start_consuming()

@app.route('/product-transaction', methods=['POST'])
def product_transaction():
    try:
        payload = request.get_json()

        if 'userId' not in payload or 'products' not in payload:
            return jsonify({"error": "Invalid payload, 'userId' and 'products' are required"}), 400
        
        send_to_rabbitmq(payload)

        return jsonify({"message": "Product transaction sent to purchase_discount_stock"}), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500

def start_listening():
    threading.Thread(target=listen_to_queue, args=('purchase_register_transaction',), daemon=True).start()
    threading.Thread(target=listen_to_queue, args=('purchase_restore_cart',), daemon=True).start()

if __name__ == '__main__':
    start_listening()
    app.run(debug=True, host='0.0.0.0', port=5000)
