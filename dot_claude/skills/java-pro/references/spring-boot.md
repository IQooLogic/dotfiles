# Spring Boot Patterns

## Auto-Configuration

Spring Boot auto-configures beans based on classpath and properties. Understand what
gets auto-configured before adding manual `@Bean` definitions.

```java
// Check active auto-configurations
// application.yml:
// debug: true    # prints auto-config report on startup
```

### Rules
- Never duplicate what auto-configuration already provides
- Use `@ConditionalOnProperty` or `@ConditionalOnMissingBean` for custom auto-config
- Override auto-config by defining your own `@Bean` of the same type

## Starters

Use Spring Boot starters — never add individual Spring dependencies manually.

| Need | Starter |
|------|---------|
| Web/REST | `spring-boot-starter-web` |
| WebFlux reactive | `spring-boot-starter-webflux` |
| JPA + Hibernate | `spring-boot-starter-data-jpa` |
| Security | `spring-boot-starter-security` |
| Actuator | `spring-boot-starter-actuator` |
| Validation | `spring-boot-starter-validation` |
| Test | `spring-boot-starter-test` |

## Actuator & Health Checks

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  endpoint:
    health:
      show-details: when_authorized
      probes:
        enabled: true  # Kubernetes liveness/readiness
  metrics:
    export:
      prometheus:
        enabled: true
```

### Custom Health Indicator

```java
@Component
public class DatabaseHealthIndicator implements HealthIndicator {
    private final DataSource dataSource;

    public DatabaseHealthIndicator(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public Health health() {
        try (var conn = dataSource.getConnection()) {
            return Health.up()
                .withDetail("database", conn.getMetaData().getDatabaseProductName())
                .build();
        } catch (SQLException e) {
            return Health.down(e).build();
        }
    }
}
```

## Profiles

```yaml
# application.yml (default)
spring:
  profiles:
    active: ${SPRING_PROFILES_ACTIVE:dev}

---
# application-dev.yml
spring:
  config:
    activate:
      on-profile: dev
  datasource:
    url: jdbc:h2:mem:devdb

---
# application-prod.yml
spring:
  config:
    activate:
      on-profile: prod
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/${DB_NAME}
```

### Rules
- Never put secrets in YAML files — use environment variables
- `dev` profile for local development with H2/embedded
- `prod` profile reads all config from environment
- Use `@Profile` on beans only when behavior genuinely differs by environment

## Configuration Properties

```java
@ConfigurationProperties(prefix = "app.engine")
@Validated
public record EngineProperties(
    @NotNull Duration timeout,
    @Min(1) @Max(100) int maxRetries,
    @NotNull URI targetUrl
) {}

// Enable in a @Configuration class:
@Configuration
@EnableConfigurationProperties(EngineProperties.class)
public class EngineConfig {
    @Bean
    public EngineClient engineClient(EngineProperties props) {
        return new EngineClient(props.targetUrl(), props.timeout());
    }
}
```

```yaml
app:
  engine:
    timeout: 5s
    max-retries: 3
    target-url: https://api.example.com
```

## REST Controllers

```java
@RestController
@RequestMapping("/api/v1/events")
public class EventController {
    private final EventService eventService;

    public EventController(EventService eventService) {
        this.eventService = eventService;
    }

    @GetMapping
    public List<EventResponse> list(@RequestParam(defaultValue = "0") int page,
                                     @RequestParam(defaultValue = "20") int size) {
        return eventService.findAll(PageRequest.of(page, size))
            .map(EventResponse::from)
            .getContent();
    }

    @GetMapping("/{id}")
    public EventResponse get(@PathVariable UUID id) {
        return EventResponse.from(eventService.findById(id));
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public EventResponse create(@Valid @RequestBody CreateEventRequest request) {
        return EventResponse.from(eventService.create(request));
    }
}
```

### Rules
- Controllers are thin — delegate to services immediately
- Use `@Valid` on request bodies
- Return DTOs, not domain entities
- Use proper HTTP status codes via `@ResponseStatus`
- Pagination via `Pageable` and `Page<T>`

## Exception Handling

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ProblemDetail handleNotFound(NotFoundException ex) {
        return ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        var problem = ProblemDetail.forStatus(HttpStatus.BAD_REQUEST);
        problem.setTitle("Validation Failed");
        var errors = ex.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.toMap(
                FieldError::getField,
                fe -> fe.getDefaultMessage() != null ? fe.getDefaultMessage() : "invalid"
            ));
        problem.setProperty("errors", errors);
        return problem;
    }
}
```

## Docker

```dockerfile
# Multi-stage build
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw dependency:resolve -q
COPY src src
RUN ./mvnw package -DskipTests -q

FROM eclipse-temurin:21-jre-alpine
WORKDIR /app
COPY --from=build /app/target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

Use layered jars for better Docker layer caching in production.

## Clean Architecture Project Structure

```
src/main/java/com/example/
├── domain/              # Core business logic
│   ├── model/          # Entities, value objects
│   ├── repository/     # Repository interfaces
│   └── service/        # Domain services
├── application/         # Use cases
│   ├── dto/            # Request/Response DTOs
│   ├── mapper/         # Entity <-> DTO mappers
│   └── service/        # Application services
├── infrastructure/      # External concerns
│   ├── persistence/    # JPA implementations
│   ├── config/         # Spring configuration
│   └── security/       # Security setup
└── presentation/        # API layer
    └── rest/           # REST controllers
```

### Rules
- `domain` has zero Spring dependencies — pure Java
- `application` depends on `domain` only
- `infrastructure` implements interfaces defined in `domain`
- `presentation` calls `application` services, never `domain` directly

## Modern pom.xml Template (Spring Boot 3.2)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
    <modelVersion>4.0.0</modelVersion>

    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.1</version>
    </parent>

    <groupId>com.example</groupId>
    <artifactId>demo-service</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <java.version>21</java.version>
        <mapstruct.version>1.5.5.Final</mapstruct.version>
        <testcontainers.version>1.19.3</testcontainers.version>
    </properties>

    <dependencies>
        <!-- Spring Boot Starters -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-validation</artifactId>
        </dependency>

        <!-- Database -->
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
        <dependency>
            <groupId>org.flywaydb</groupId>
            <artifactId>flyway-core</artifactId>
        </dependency>

        <!-- Mappers -->
        <dependency>
            <groupId>org.mapstruct</groupId>
            <artifactId>mapstruct</artifactId>
            <version>${mapstruct.version}</version>
        </dependency>

        <!-- Testing -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>postgresql</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <configuration>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.mapstruct</groupId>
                            <artifactId>mapstruct-processor</artifactId>
                            <version>${mapstruct.version}</version>
                        </path>
                        <path>
                            <groupId>org.projectlombok</groupId>
                            <artifactId>lombok</artifactId>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

### Key Points
- Java 21 target with Spring Boot 3.2 parent
- MapStruct for compile-time DTO mapping (no reflection)
- Testcontainers for integration tests with real PostgreSQL
- Annotation processors configured for both MapStruct and Lombok
- Flyway for schema migrations (pair with `spring.jpa.hibernate.ddl-auto=validate`)

## OpenAPI/Swagger Configuration

```java
package com.example.infrastructure.config;

import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
            .info(new Info()
                .title("Demo Service API")
                .version("1.0.0")
                .description("Enterprise microservice API"));
    }
}
```

### Setup
Add the SpringDoc dependency to `pom.xml`:

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

### Access Points
- Swagger UI: `http://localhost:8080/swagger-ui.html`
- OpenAPI JSON: `http://localhost:8080/v3/api-docs`
- OpenAPI YAML: `http://localhost:8080/v3/api-docs.yaml`

### Rules
- Use `@Operation` and `@ApiResponse` annotations on controllers for richer docs
- Never expose Swagger UI in production — guard with a profile or security config
- Keep the `Info` metadata accurate — it becomes your API contract documentation
