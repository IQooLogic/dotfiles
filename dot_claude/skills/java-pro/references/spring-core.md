# Spring Core Patterns

## Dependency Injection

### Constructor Injection (Required)

```java
@Service
public class EventProcessor {
    private final EventRepository repository;
    private final NotificationService notifications;
    private final Clock clock;

    // Single constructor — @Autowired optional since Spring 4.3
    public EventProcessor(EventRepository repository,
                          NotificationService notifications,
                          Clock clock) {
        this.repository = repository;
        this.notifications = notifications;
        this.clock = clock;
    }
}
```

### Rules
- **Constructor injection only.** Never `@Autowired` on fields.
- Declare dependencies `final` — immutable after construction.
- Inject `Clock` for time-dependent logic (testable).
- Inject interfaces, not implementations.
- If a class has >5 constructor parameters, it likely has too many responsibilities.

## Bean Lifecycle

```
Constructor → @PostConstruct → Ready → @PreDestroy → Destroyed
```

```java
@Component
public class CacheWarmer {
    private final DataService dataService;

    public CacheWarmer(DataService dataService) {
        this.dataService = dataService;
    }

    @PostConstruct
    void warmCache() {
        // Safe to call — all dependencies injected
        dataService.loadFrequentData();
    }

    @PreDestroy
    void cleanup() {
        // Graceful shutdown
    }
}
```

### Rules
- `@PostConstruct` for initialization that needs injected dependencies
- `@PreDestroy` for cleanup (close connections, flush buffers)
- Never do heavy I/O in constructors
- For async initialization, use `ApplicationRunner` or `SmartLifecycle`

## Transaction Management

```java
@Service
public class OrderService {
    private final OrderRepository orderRepo;
    private final PaymentService paymentService;

    @Transactional
    public Order placeOrder(CreateOrderRequest request) {
        var order = Order.create(request);
        orderRepo.save(order);
        paymentService.charge(order); // also transactional
        return order;
    }

    @Transactional(readOnly = true)
    public Page<Order> findOrders(Pageable pageable) {
        return orderRepo.findAll(pageable);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void logAuditEvent(AuditEvent event) {
        // Independent transaction — commits even if outer rolls back
    }
}
```

### Transaction Rules
- `@Transactional` on service methods, never controllers or repositories
- `readOnly = true` for queries — enables optimizations
- Never call `@Transactional` methods from within the same class (proxy bypass)
- Keep transactions short — no HTTP calls, no file I/O inside
- `REQUIRES_NEW` only for audit/logging that must survive outer rollback
- Rollback rules: `@Transactional(rollbackFor = Exception.class)` if needed

## AOP (Aspect-Oriented Programming)

```java
@Aspect
@Component
public class PerformanceAspect {
    private static final Logger log = LoggerFactory.getLogger(PerformanceAspect.class);

    @Around("@annotation(Timed)")
    public Object measureTime(ProceedingJoinPoint joinPoint) throws Throwable {
        var start = System.nanoTime();
        try {
            return joinPoint.proceed();
        } finally {
            var duration = Duration.ofNanos(System.nanoTime() - start);
            log.info("Method {} took {}", joinPoint.getSignature().getName(), duration);
        }
    }
}

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Timed {}
```

### AOP Rules
- Use sparingly — only for cross-cutting concerns (logging, metrics, security)
- Never use AOP for business logic
- Prefer `@Around` — most flexible. `@Before`/`@After` for simple cases.
- AOP only works on Spring-managed beans, and only on public methods called externally

## Event System

```java
// Domain event
public record OrderPlacedEvent(UUID orderId, Instant timestamp) {}

// Publisher
@Service
public class OrderService {
    private final ApplicationEventPublisher publisher;

    @Transactional
    public Order placeOrder(CreateOrderRequest request) {
        var order = Order.create(request);
        orderRepo.save(order);
        publisher.publishEvent(new OrderPlacedEvent(order.getId(), Instant.now()));
        return order;
    }
}

// Listener
@Component
public class NotificationListener {

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOrderPlaced(OrderPlacedEvent event) {
        // Runs after transaction commits — safe to send notifications
    }
}
```

### Event Rules
- Use `@TransactionalEventListener` — not `@EventListener` — for transactional operations
- `AFTER_COMMIT` for side effects (notifications, external calls)
- Events are synchronous by default; use `@Async` for non-blocking listeners
- Events decouple services — prefer over direct method calls between services

## Scheduling

```java
@Configuration
@EnableScheduling
public class SchedulerConfig {}

@Component
public class CleanupScheduler {
    private final CleanupService cleanupService;

    @Scheduled(fixedRate = 60_000)  // every 60 seconds
    public void cleanExpiredSessions() {
        cleanupService.removeExpired();
    }

    @Scheduled(cron = "0 0 2 * * *")  // daily at 2 AM
    public void dailyReport() {
        cleanupService.generateDailyReport();
    }
}
```

- Use `fixedRate` for periodic tasks, `cron` for calendar-based
- `@Scheduled` methods must be `void` with no arguments
- For distributed scheduling, use ShedLock or Quartz
