---
name: jakarta-ee-to-quarkus
description: Migrate Jakarta EE (Java EE) applications to Quarkus. Handles EJB to CDI conversion, WAR/EAR to JAR packaging, app-server removal, and modernization. Use when converting a Jakarta EE or Java EE project to Quarkus.
---

# Jakarta EE to Quarkus Migration

Migrate a Jakarta EE (or legacy Java EE) application to Quarkus. Since Quarkus already uses CDI and JAX-RS, this migration is often simpler than Spring Boot migration — the main work is removing app-server dependencies and EJB patterns.

## Migration Procedure

### Step 1: Analyze the Source Project

1. Read `pom.xml` / `build.gradle` — identify:
   - Jakarta EE / Java EE BOM or API dependencies
   - Application server plugins (WildFly, Payara, Liberty, TomEE)
   - Packaging type (WAR, EAR)
2. Scan source code for:
   - EJBs (`@Stateless`, `@Stateful`, `@Singleton`, `@MessageDriven`)
   - JAX-RS resources (`@Path`, `@GET`, etc.) — these mostly stay as-is
   - JPA entities — these mostly stay as-is
   - CDI beans — these mostly stay as-is
   - JMS usage (`@MessageDriven`, `ConnectionFactory`)
   - JNDI lookups
   - `persistence.xml` configuration
   - `web.xml`, `beans.xml` configuration
3. Identify EE features in use: EJB, JPA, JAX-RS, CDI, JMS, JTA, Bean Validation, JSONB/JSONP, WebSocket, etc.

### Step 2: Migrate the Build File

1. Change packaging from `war`/`ear` to `jar`
2. Remove application server plugins and dependencies
3. Add Quarkus BOM and plugin (see spring-boot-to-quarkus skill for exact XML)
4. Replace Jakarta EE API dependency with specific Quarkus extensions:

| Jakarta EE Feature | Quarkus Extension |
|-------|---------|
| JAX-RS (`jakarta.ws.rs`) | `quarkus-rest` (included, replaces `jaxrs-api`) |
| CDI (`jakarta.inject`, `jakarta.enterprise`) | `quarkus-arc` (included) |
| JPA (`jakarta.persistence`) | `quarkus-hibernate-orm` or `quarkus-hibernate-orm-panache` |
| Bean Validation | `quarkus-hibernate-validator` |
| JTA (`jakarta.transaction`) | `quarkus-narayana-jta` (included with hibernate-orm) |
| JSON-B | `quarkus-rest-jsonb` or `quarkus-jsonb` |
| JSON-P | `quarkus-jsonp` |
| WebSocket | `quarkus-websockets-next` |
| Servlet (if needed) | `quarkus-undertow` (try to avoid; prefer REST) |
| JAXB | `quarkus-jaxb` |
| Mail | `quarkus-mailer` |

5. Add database driver: `quarkus-jdbc-postgresql`, `quarkus-jdbc-h2`, etc.

### Step 3: Convert EJBs to CDI Beans

This is the core of the migration.

#### Stateless Session Beans
```java
// Before
@Stateless
public class OrderService {
    @PersistenceContext
    EntityManager em;
    
    public Order createOrder(Order order) {
        em.persist(order);
        return order;
    }
}

// After
@ApplicationScoped
@Transactional
public class OrderService {
    @Inject
    EntityManager em;
    
    public Order createOrder(Order order) {
        em.persist(order);
        return order;
    }
}
```

Key changes:
- `@Stateless` → `@ApplicationScoped` + `@Transactional` (EJBs are transactional by default)
- `@PersistenceContext` → `@Inject` (Quarkus produces `EntityManager` automatically)

#### Stateful Session Beans
```java
// Before
@Stateful
public class ShoppingCart { ... }

// After — usually rethink the design
@SessionScoped  // or @Dependent, or use request-scoped + external state
public class ShoppingCart { ... }
```

#### EJB Singletons
```java
// Before
@Singleton
@Startup
@Lock(LockType.READ)
public class CacheService {
    @PostConstruct
    void init() { ... }
}

// After
@ApplicationScoped
public class CacheService {
    void onStart(@Observes StartupEvent ev) { ... }
}
```

- `@jakarta.ejb.Singleton` → `@ApplicationScoped` (or `@jakarta.inject.Singleton`)
- `@Startup` → `@Observes StartupEvent`
- `@Lock` → use `java.util.concurrent` locks if needed

#### Message-Driven Beans
```java
// Before
@MessageDriven(activationConfig = {
    @ActivationConfigProperty(propertyName = "destinationType", propertyValue = "jakarta.jms.Queue"),
    @ActivationConfigProperty(propertyName = "destination", propertyValue = "order-queue")
})
public class OrderProcessor implements MessageListener {
    public void onMessage(Message message) { ... }
}

// After (using SmallRye Reactive Messaging)
@ApplicationScoped
public class OrderProcessor {
    @Incoming("order-queue")
    public void process(String message) { ... }
}
```

### Step 4: Remove JNDI Lookups

Replace any `InitialContext` / JNDI lookups with CDI injection:

```java
// Before
Context ctx = new InitialContext();
DataSource ds = (DataSource) ctx.lookup("java:jboss/datasources/MyDS");

// After — just inject
@Inject
DataSource ds;
```

### Step 5: Migrate Configuration

#### persistence.xml
- Usually **remove** `persistence.xml` entirely
- Move config to `application.properties`:
  ```properties
  quarkus.datasource.db-kind=postgresql
  quarkus.datasource.jdbc.url=jdbc:postgresql://localhost:5432/mydb
  quarkus.datasource.username=user
  quarkus.datasource.password=pass
  quarkus.hibernate-orm.database.generation=update
  ```
- If you must keep `persistence.xml`, Quarkus supports it but properties-based config is preferred

#### web.xml
- **Remove** `web.xml`
- Servlet filters → JAX-RS `ContainerRequestFilter` / `ContainerResponseFilter`
- Servlet mappings → `@Path` on JAX-RS resources
- Error pages → exception mappers
- Security constraints → `quarkus.http.auth.*` config or `@RolesAllowed`

#### beans.xml
- Quarkus uses `annotated` bean discovery by default
- Usually **remove** `beans.xml`, or keep an empty one if needed
- If you had `bean-discovery-mode="all"`, make sure all beans have scope annotations

### Step 6: Migrate JAX-RS Resources

JAX-RS resources mostly work as-is. Key changes:
- Remove any `@Stateless` on resource classes → add `@ApplicationScoped`
- Remove `Application` subclass (JAX-RS `@ApplicationPath`) → configure `quarkus.rest.path` if needed
- EJB injection (`@EJB`) → `@Inject`

### Step 7: Migrate JPA Entities

JPA entities usually work unchanged. Optional improvements:
- Consider Panache for simpler data access patterns
- Move from `@PersistenceContext EntityManager` to `@Inject EntityManager`
- Remove any `@Cacheable` EJB annotations → configure Hibernate second-level cache via properties

### Step 8: Static Resources

Move static resources:
- `src/main/webapp/` → `src/main/resources/META-INF/resources/`

### Step 9: Migrate Tests

- Use `@QuarkusTest` instead of Arquillian
- Remove Arquillian dependencies and `arquillian.xml`
- Remove `@Deployment` methods and ShrinkWrap
- Use RestAssured for endpoint testing
- Use `@InjectMock` for mocking

### Step 10: Clean Up and Verify

1. Remove all `jakarta.ejb` imports
2. Remove application server descriptors (`jboss-web.xml`, `glassfish-web.xml`, etc.)
3. Remove `webapp/WEB-INF/` directory if empty
4. `./mvnw compile` — fix compilation errors
5. `./mvnw test` — fix test failures
6. `./mvnw quarkus:dev` — verify startup

## Common Pitfalls

- **EJB transactions**: EJBs are transactional by default; CDI beans are not. Add `@Transactional` explicitly.
- **`@PersistenceContext` → `@Inject`**: Quarkus doesn't support `@PersistenceContext`, use `@Inject EntityManager`
- **Timer service**: Replace `@Schedule` (EJB) with `@io.quarkus.scheduler.Scheduled`
- **Interceptors**: CDI interceptors work, but EJB-specific interceptors need conversion
- **Remote EJB**: Not supported in Quarkus — use REST or gRPC instead
- **JNDI**: Not available — use CDI injection
