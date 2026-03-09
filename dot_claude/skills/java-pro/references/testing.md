# Java Testing Patterns

## JUnit 5

```java
@DisplayName("EventProcessor")
class EventProcessorTest {

    private EventProcessor processor;
    private EventRepository repository;

    @BeforeEach
    void setUp() {
        repository = Mockito.mock(EventRepository.class);
        processor = new EventProcessor(repository, Clock.fixed(
            Instant.parse("2024-01-15T10:00:00Z"), ZoneOffset.UTC));
    }

    @Test
    @DisplayName("processes valid event and persists it")
    void processesValidEvent() {
        var event = TestFixtures.validEvent();
        when(repository.save(any())).thenReturn(event);

        var result = processor.process(event);

        assertThat(result).isNotNull();
        assertThat(result.status()).isEqualTo(Status.PROCESSED);
        verify(repository).save(event);
    }

    @Test
    @DisplayName("rejects event with missing source")
    void rejectsEventWithMissingSource() {
        var event = TestFixtures.eventWithoutSource();

        assertThatThrownBy(() -> processor.process(event))
            .isInstanceOf(ValidationException.class)
            .hasMessageContaining("source");
    }
}
```

### Rules
- Use `@DisplayName` on classes and tests — readable test output
- One assertion concern per test (multiple asserts on one object is fine)
- Use AssertJ for assertions — not JUnit's `assertEquals`
- Test names describe behavior, not implementation
- `@BeforeEach` for test setup, never `@BeforeAll` with mutable state

## Parameterized Tests

```java
@ParameterizedTest
@CsvSource({
    "valid@email.com,   true",
    "invalid,           false",
    "'',                false",
    "a@b.c,             true",
})
@DisplayName("validates email addresses")
void validatesEmail(String email, boolean expected) {
    assertThat(validator.isValid(email)).isEqualTo(expected);
}

@ParameterizedTest
@MethodSource("invalidEvents")
@DisplayName("rejects invalid events")
void rejectsInvalidEvents(Event event, String expectedError) {
    assertThatThrownBy(() -> processor.process(event))
        .isInstanceOf(ValidationException.class)
        .hasMessageContaining(expectedError);
}

static Stream<Arguments> invalidEvents() {
    return Stream.of(
        arguments(TestFixtures.eventWithoutSource(), "source"),
        arguments(TestFixtures.eventWithFutureTimestamp(), "timestamp"),
        arguments(TestFixtures.eventWithEmptyPayload(), "payload")
    );
}
```

## Mockito

```java
// Stub behavior
when(repository.findById(any())).thenReturn(Optional.of(event));
when(repository.findById(unknownId)).thenReturn(Optional.empty());

// Verify interactions
verify(repository).save(event);
verify(repository, never()).delete(any());
verify(repository, times(2)).findById(any());

// Argument captor
var captor = ArgumentCaptor.forClass(Event.class);
verify(repository).save(captor.capture());
assertThat(captor.getValue().status()).isEqualTo(Status.PROCESSED);
```

### Rules
- Mock interfaces, not concrete classes
- Prefer `when().thenReturn()` over `doReturn().when()`
- Use `verify` sparingly — test behavior (outputs), not interactions
- Never mock value objects or DTOs
- Use `@Mock` + `@ExtendWith(MockitoExtension.class)` for cleaner setup

## Spring Boot Integration Tests

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureMockMvc
class EventControllerIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private EventRepository eventRepository;

    @BeforeEach
    void setUp() {
        eventRepository.deleteAll();
    }

    @Test
    @DisplayName("POST /api/v1/events creates event and returns 201")
    void createsEvent() throws Exception {
        var request = """
            {
                "source": "webhook",
                "payload": {"key": "value"}
            }
            """;

        mockMvc.perform(post("/api/v1/events")
                .contentType(MediaType.APPLICATION_JSON)
                .content(request))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.source").value("webhook"))
            .andExpect(jsonPath("$.id").isNotEmpty());

        assertThat(eventRepository.count()).isEqualTo(1);
    }
}
```

## Testcontainers

```java
@SpringBootTest
@Testcontainers
class EventRepositoryIntegrationTest {

    @Container
    @ServiceConnection  // Spring Boot 3.1+ auto-configures datasource
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired
    private EventRepository repository;

    @Test
    @DisplayName("persists and retrieves events")
    void persistsAndRetrieves() {
        var event = TestFixtures.validEvent();
        repository.save(event);

        var found = repository.findById(event.getId());
        assertThat(found).isPresent()
            .get()
            .extracting(Event::source)
            .isEqualTo(event.source());
    }
}
```

### Rules
- `@ServiceConnection` for automatic datasource configuration (Spring Boot 3.1+)
- `static` containers shared across tests in the class
- Use `@Testcontainers` + `@Container` annotations
- Always use Alpine/slim images for faster startup

## Test Fixtures

```java
public final class TestFixtures {
    private TestFixtures() {}

    public static Event validEvent() {
        return new Event(UUID.randomUUID(), "webhook",
            Map.of("key", "value"), Instant.now());
    }

    public static Event eventWithoutSource() {
        return new Event(UUID.randomUUID(), null,
            Map.of("key", "value"), Instant.now());
    }
}
```

- Central fixture class per domain concept
- Factory methods with descriptive names
- Never share mutable state between tests

## Slice Tests

```java
// Test only the web layer
@WebMvcTest(EventController.class)
class EventControllerTest {
    @Autowired MockMvc mockMvc;
    @MockitoBean EventService eventService;
    // Only web-layer beans loaded
}

// Test only the data layer
@DataJpaTest
class EventRepositoryTest {
    @Autowired TestEntityManager entityManager;
    @Autowired EventRepository repository;
    // Only JPA beans loaded, uses embedded H2
}
```

Prefer slice tests over full `@SpringBootTest` when testing a single layer.

## Fluent Test Data Builders

```java
package com.example.test.builders;

import com.example.domain.model.User;

public class UserTestBuilder {

    private Long id = 1L;
    private String email = "test@example.com";
    private String username = "testuser";
    private Boolean active = true;

    public static UserTestBuilder aUser() {
        return new UserTestBuilder();
    }

    public UserTestBuilder withId(Long id) {
        this.id = id;
        return this;
    }

    public UserTestBuilder withEmail(String email) {
        this.email = email;
        return this;
    }

    public UserTestBuilder inactive() {
        this.active = false;
        return this;
    }

    public User build() {
        return User.builder()
            .id(id)
            .email(email)
            .username(username)
            .active(active)
            .build();
    }
}

// Usage
User user = aUser()
    .withEmail("custom@example.com")
    .inactive()
    .build();
```

- One builder per domain entity, placed in `test/builders` package
- Static factory entry point (`aUser()`) for readability
- Sensible defaults so tests only specify what they care about
- Semantic mutators (`inactive()`) over raw setters where intent is clear

## Performance Testing with JMH

```java
package com.example.benchmark;

import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.runner.Runner;
import org.openjdk.jmh.runner.options.Options;
import org.openjdk.jmh.runner.options.OptionsBuilder;

import java.util.concurrent.TimeUnit;

@BenchmarkMode(Mode.AverageTime)
@OutputTimeUnit(TimeUnit.MICROSECONDS)
@State(Scope.Benchmark)
@Fork(value = 2, warmups = 1)
@Warmup(iterations = 3)
@Measurement(iterations = 5)
public class UserServiceBenchmark {

    private UserService userService;

    @Setup
    public void setup() {
        // Initialize test data
        userService = new UserService();
    }

    @Benchmark
    public void benchmarkFindUser() {
        userService.findById(1L);
    }

    public static void main(String[] args) throws Exception {
        Options opt = new OptionsBuilder()
            .include(UserServiceBenchmark.class.getSimpleName())
            .build();
        new Runner(opt).run();
    }
}
```

- Place benchmarks in a separate source set (`src/jmh/java`)
- Use `@Fork` to isolate JVM effects between benchmarks
- Use `@Warmup` to let JIT compilation stabilize before measuring
- Avoid dead-code elimination by returning values or using `Blackhole`

## Abstract Testcontainers Base Class

```java
package com.example.test;

import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;

public abstract class AbstractIntegrationTest {

    static final PostgreSQLContainer<?> postgres;

    static {
        postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withReuse(true);
        postgres.start();
    }

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
}
```

- Single shared container instance across all subclasses (faster test suite)
- `withReuse(true)` keeps the container alive between test runs (requires `~/.testcontainers.properties` with `testcontainers.reuse.enable=true`)
- Static initializer block starts the container once per JVM
- Subclasses inherit `@DynamicPropertySource` configuration automatically
- Add additional containers (Redis, Kafka) following the same static block pattern
