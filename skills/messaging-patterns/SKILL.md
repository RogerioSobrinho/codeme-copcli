---
name: messaging-patterns
description: >
  Load when writing @KafkaListener consumers, configuring KafkaTemplate producers, implementing
  the outbox pattern with @TransactionalEventListener, designing dead-letter topics (DLT),
  using Schema Registry with Avro serialization, debugging consumer group lag, implementing
  @RabbitListener with Spring AMQP, or designing domain event publishing with
  Spring Application Events and @TransactionalEventListener(phase = AFTER_COMMIT).
---

# Messaging Patterns for Spring Boot

## Kafka — Producer

### Configuration
```yaml
spring:
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS:localhost:9092}
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all                  # strongest durability guarantee
      retries: 3
      properties:
        enable.idempotence: true # exactly-once semantics at producer level
        max.in.flight.requests.per.connection: 5
```

### KafkaTemplate
```java
@Service
@RequiredArgsConstructor
public class OrderEventPublisher {

    private final KafkaTemplate<String, OrderEvent> kafkaTemplate;

    public void publishOrderPlaced(Order order) {
        OrderPlacedEvent event = new OrderPlacedEvent(
            order.id().toString(),
            order.customerId(),
            order.totalAmount(),
            Instant.now()
        );

        kafkaTemplate.send("orders.placed", order.id().toString(), event)
            .whenComplete((result, ex) -> {
                if (ex != null) {
                    log.error("Failed to publish OrderPlacedEvent orderId={}", order.id(), ex);
                    // Do NOT swallow — let the caller handle or use outbox pattern
                } else {
                    log.info("Published OrderPlacedEvent orderId={} partition={} offset={}",
                        order.id(),
                        result.getRecordMetadata().partition(),
                        result.getRecordMetadata().offset()
                    );
                }
            });
    }
}
```

---

## Kafka — Idempotent Consumer

The most critical consumer pattern. Process-once semantics via idempotency key.

```java
@Component
@RequiredArgsConstructor
public class PaymentEventConsumer {

    private final PaymentUseCase paymentUseCase;
    private final IdempotencyStore idempotencyStore;

    @KafkaListener(
        topics = "orders.placed",
        groupId = "payment-service",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void onOrderPlaced(
        @Payload OrderPlacedEvent event,
        @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
        @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
        @Header(KafkaHeaders.OFFSET) long offset,
        Acknowledgment ack
    ) {
        String idempotencyKey = event.eventId();

        // Check BEFORE any processing
        if (idempotencyStore.alreadyProcessed(idempotencyKey)) {
            log.info("Duplicate event skipped eventId={} topic={} offset={}", idempotencyKey, topic, offset);
            ack.acknowledge();
            return;
        }

        try {
            paymentUseCase.initiatePayment(PaymentCommand.from(event));
            idempotencyStore.markProcessed(idempotencyKey);
            ack.acknowledge();
        } catch (NonRetryableException e) {
            // Permanent failure — acknowledge to stop retrying; DLQ configured via error handler
            log.error("Non-retryable failure processing event eventId={}", idempotencyKey, e);
            ack.acknowledge();
        }
        // For retryable exceptions: do NOT ack — Kafka will redeliver
    }
}
```

### Listener Container Factory with Error Handler
```java
@Configuration
public class KafkaConsumerConfig {

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, Object>
    kafkaListenerContainerFactory(ConsumerFactory<String, Object> consumerFactory,
                                   KafkaTemplate<String, Object> kafkaTemplate) {
        var factory = new ConcurrentKafkaListenerContainerFactory<String, Object>();
        factory.setConsumerFactory(consumerFactory);
        factory.getContainerProperties().setAckMode(ContainerProperties.AckMode.MANUAL_IMMEDIATE);

        // Dead-letter handler — sends to <topic>.DLT after maxAttempts
        var errorHandler = new DefaultErrorHandler(
            new DeadLetterPublishingRecoverer(kafkaTemplate),
            new FixedBackOff(1000L, 3)  // 3 retries with 1s delay
        );
        errorHandler.addNotRetryableExceptions(NonRetryableException.class);
        factory.setCommonErrorHandler(errorHandler);

        return factory;
    }
}
```

---

## Outbox Pattern — Guaranteed Event Publishing

Ensures domain events are only published if the database transaction commits. Eliminates dual-write inconsistency.

### Schema
```sql
CREATE TABLE outbox_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type  VARCHAR(255) NOT NULL,
    payload     JSONB NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed   BOOLEAN NOT NULL DEFAULT FALSE,
    processed_at TIMESTAMPTZ
);

CREATE INDEX idx_outbox_unprocessed ON outbox_events (created_at)
    WHERE processed = FALSE;
```

### Write to Outbox in Same Transaction
```java
@Service
@RequiredArgsConstructor
public class PlaceOrderUseCase {

    private final OrderRepository orderRepository;
    private final OutboxRepository outboxRepository;

    @Transactional
    public Order execute(PlaceOrderCommand command) {
        Order order = Order.create(command);
        orderRepository.save(order);

        // Written in same transaction — atomically with the order
        outboxRepository.save(OutboxEvent.of(
            "OrderPlaced",
            new OrderPlacedEventPayload(order.id(), order.customerId(), order.totalAmount())
        ));

        return order;
    }
}
```

### Outbox Polling Publisher (Spring @Scheduled)
```java
@Component
@RequiredArgsConstructor
public class OutboxPublisher {

    private final OutboxRepository outboxRepository;
    private final KafkaTemplate<String, Object> kafkaTemplate;

    @Scheduled(fixedDelay = 1000)  // poll every 1 second
    @Transactional
    public void publishPending() {
        List<OutboxEvent> pending = outboxRepository.findUnprocessed(Pageable.ofSize(100));

        for (OutboxEvent event : pending) {
            kafkaTemplate.send(topicFor(event.eventType()), event.aggregateId(), event.payload())
                .whenComplete((result, ex) -> {
                    if (ex == null) {
                        outboxRepository.markProcessed(event.id());
                    }
                    // On failure: leave unprocessed — will retry on next poll
                });
        }
    }

    private String topicFor(String eventType) {
        return switch (eventType) {
            case "OrderPlaced" -> "orders.placed";
            case "OrderCancelled" -> "orders.cancelled";
            default -> throw new IllegalArgumentException("Unknown event type: " + eventType);
        };
    }
}
```

---

## Spring Application Events (In-Process Domain Events)

For events that stay within the same service — no Kafka needed.

```java
// Domain event record
public record OrderConfirmedEvent(UUID orderId, UUID customerId, Money total) {}

// Publisher (inside the aggregate or use case)
@Service
@RequiredArgsConstructor
public class ConfirmOrderUseCase {

    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher eventPublisher;

    @Transactional
    public void execute(UUID orderId) {
        Order order = orderRepository.findById(orderId).orElseThrow();
        order.confirm();
        orderRepository.save(order);
        // Published AFTER transaction commits — prevents rollback-after-publish race
        eventPublisher.publishEvent(new OrderConfirmedEvent(order.id(), order.customerId(), order.total()));
    }
}

// Listener — runs AFTER the committing transaction, in a NEW transaction
@Component
@RequiredArgsConstructor
public class NotificationOnOrderConfirmed {

    private final NotificationService notificationService;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void on(OrderConfirmedEvent event) {
        notificationService.sendConfirmation(event.customerId(), event.orderId());
    }
}
```

**Critical:** `@TransactionalEventListener` defaults to `AFTER_COMMIT`. Use `REQUIRES_NEW` on the listener if it needs its own transaction. If the listener throws, it does NOT roll back the original transaction.

---

## Avro + Schema Registry

```xml
<dependency>
    <groupId>io.confluent</groupId>
    <artifactId>kafka-avro-serializer</artifactId>
</dependency>
```

```yaml
spring:
  kafka:
    producer:
      value-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
      properties:
        schema.registry.url: ${SCHEMA_REGISTRY_URL:http://localhost:8081}
        auto.register.schemas: true    # false in production — enforce schema review
    consumer:
      value-deserializer: io.confluent.kafka.serializers.KafkaAvroDeserializer
      properties:
        schema.registry.url: ${SCHEMA_REGISTRY_URL}
        specific.avro.reader: true
```

Schema evolution rules:
- **Backward compatible**: New optional fields with defaults only
- **Never**: Remove required fields, change field types, rename fields without alias

---

## RabbitMQ (Spring AMQP)

```java
@Configuration
public class RabbitConfig {

    public static final String ORDER_QUEUE = "orders.placed";
    public static final String ORDER_EXCHANGE = "orders";
    public static final String DLQ = "orders.placed.dlq";
    public static final String DLX = "orders.dlx";

    @Bean
    Queue orderQueue() {
        return QueueBuilder.durable(ORDER_QUEUE)
            .withArgument("x-dead-letter-exchange", DLX)
            .withArgument("x-dead-letter-routing-key", DLQ)
            .withArgument("x-message-ttl", 300_000)  // 5 min TTL
            .build();
    }

    @Bean
    DirectExchange orderExchange() { return new DirectExchange(ORDER_EXCHANGE); }

    @Bean
    Binding orderBinding(Queue orderQueue, DirectExchange orderExchange) {
        return BindingBuilder.bind(orderQueue).to(orderExchange).with(ORDER_QUEUE);
    }
}

// Consumer
@RabbitListener(queues = RabbitConfig.ORDER_QUEUE)
public void onOrderPlaced(OrderPlacedEvent event, Channel channel,
                          @Header(AmqpHeaders.DELIVERY_TAG) long deliveryTag) throws IOException {
    try {
        paymentUseCase.initiatePayment(PaymentCommand.from(event));
        channel.basicAck(deliveryTag, false);
    } catch (NonRetryableException e) {
        channel.basicReject(deliveryTag, false);  // false = don't requeue → goes to DLQ
    }
    // Retryable exceptions: do not ack — broker redelivers
}
```

---

## Consumer Group Lag Monitoring

Monitor consumer group lag as a key operational metric:

```bash
# Check lag for a consumer group
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --group payment-service

# Output includes LAG column per partition
```

Alert when `LAG > threshold` for more than 5 minutes. High lag = consumers are falling behind producers.

Expose lag as a custom Micrometer metric:
```java
@Scheduled(fixedDelay = 30_000)
public void recordConsumerGroupLag() {
    // Use AdminClient to fetch offsets
    long totalLag = calculateTotalLag("payment-service", "orders.placed");
    meterRegistry.gauge("kafka.consumer.group.lag",
        Tags.of("group", "payment-service", "topic", "orders.placed"),
        totalLag);
}
```

---

## Pitfalls

| Pitfall | Fix |
|---|---|
| Not checking idempotency key before processing | Always check BEFORE any state mutation |
| `ack.acknowledge()` inside catch for retryable errors | Do NOT ack retryable errors — let broker redeliver |
| `@TransactionalEventListener` on same transaction | Use `AFTER_COMMIT` phase; listener cannot roll back the publisher's transaction |
| Kafka producer without `acks=all` | Use `acks=all` + `enable.idempotence=true` for critical events |
| Publishing events before DB commit | Use outbox pattern or `@TransactionalEventListener(AFTER_COMMIT)` |
| High-cardinality topic names | Use `orders.{status}` not `orders.{orderId}` — partition count explodes |
| No DLQ configured | Configure dead-letter topic for every consumer — unhandled failures disappear silently |
