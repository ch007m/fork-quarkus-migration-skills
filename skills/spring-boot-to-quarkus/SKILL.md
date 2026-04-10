---
name: spring-boot-to-quarkus
description: Migrate Spring Boot applications to Quarkus. Supports full migration (idiomatic JAX-RS/CDI/Panache) and compatibility migration (using quarkus-spring-* extensions). Use when the user wants to convert a Spring Boot project to Quarkus.
---

# Spring Boot to Quarkus Migration

Migrate a Spring Boot application to Quarkus. This skill guides a systematic, file-by-file migration.

## Strategy Selection

Ask the user which strategy to use (or decide based on project complexity):

- **Full migration** — Rewrite to idiomatic Quarkus (JAX-RS, CDI, Panache, Qute). Best for smaller projects or when the goal is a clean Quarkus codebase.
- **Compatibility migration** — Use Quarkus Spring compatibility extensions (`quarkus-spring-web`, `quarkus-spring-di`, `quarkus-spring-data-jpa`). Faster migration, less rewriting, but not idiomatic Quarkus.

If not specified, default to **full migration**.

## Migration Procedure

### Step 1: Analyze the Source Project

Before changing anything, understand the project:

1. Read `pom.xml` (or `build.gradle`) — list all Spring dependencies
2. Read `application.properties` / `application.yml` — note all config keys
3. Scan `src/main/java/` — identify:
   - REST controllers (`@RestController`, `@Controller`)
   - Services (`@Service`, `@Component`)
   - Repositories (`@Repository`, Spring Data interfaces)
   - Configuration classes (`@Configuration`, `@Bean`)
   - Security config (`WebSecurityConfigurerAdapter`, `SecurityFilterChain`)
   - Scheduled tasks (`@Scheduled`)
   - Event listeners (`@EventListener`)
   - The main application class (`@SpringBootApplication`)
4. Scan `src/main/resources/templates/` — identify template engine (Thymeleaf, Freemarker)
5. Scan `src/test/java/` — identify test patterns

Produce a brief migration plan listing each file and what needs to change.

### Step 2: Migrate the Build File

Replace the Spring Boot build with Quarkus.

**For Maven (`pom.xml`):**

1. Remove `spring-boot-starter-parent` and replace with Quarkus BOM:
   ```xml
   <dependencyManagement>
     <dependencies>
       <dependency>
         <groupId>io.quarkus.platform</groupId>
         <artifactId>quarkus-bom</artifactId>
         <version>3.21.3</version>
         <type>pom</type>
         <scope>import</scope>
       </dependency>
     </dependencies>
   </dependencyManagement>
   ```

2. Replace `spring-boot-maven-plugin` with:
   ```xml
   <plugin>
     <groupId>io.quarkus.platform</groupId>
     <artifactId>quarkus-maven-plugin</artifactId>
     <version>3.21.3</version>
     <extensions>true</extensions>
     <executions>
       <execution>
         <goals>
           <goal>build</goal>
           <goal>generate-code</goal>
           <goal>generate-code-tests</goal>
           <goal>native-image-agent</goal>
         </goals>
       </execution>
     </executions>
   </plugin>
   ```

3. Add the Quarkus compiler plugin configuration:
   ```xml
   <plugin>
     <artifactId>maven-compiler-plugin</artifactId>
     <version>3.14.0</version>
     <configuration>
       <parameters>true</parameters>
     </configuration>
   </plugin>
   <plugin>
     <artifactId>maven-surefire-plugin</artifactId>
     <version>3.5.2</version>
     <configuration>
       <systemPropertyVariables>
         <java.util.logging.manager>org.jboss.logmanager.LogManager</java.util.logging.manager>
       </systemPropertyVariables>
     </configuration>
   </plugin>
   ```

4. Map all Spring dependencies to Quarkus equivalents using [the dependency map](../shared/references/dependency-map.md).

5. Remove all `org.springframework*` dependencies (unless using compatibility strategy).

### Step 3: Migrate Configuration

Convert `application.properties` / `application.yml` using [the config map](../shared/references/config-map.md).

Key patterns:
- `spring.datasource.url` → `quarkus.datasource.jdbc.url`
- `spring.jpa.hibernate.ddl-auto` → `quarkus.hibernate-orm.database.generation`
- `server.port` → `quarkus.http.port`
- Spring profiles (`application-dev.properties`) → Quarkus profiles (`%dev.` prefix or `application-dev.properties`)

If the project uses `application.yml` and you want to keep YAML, add `quarkus-config-yaml` dependency. Otherwise convert to `application.properties`.

### Step 4: Migrate Source Code

Work through files systematically using [the annotation map](../shared/references/annotation-map.md).

#### 4a. Main Application Class
- **Delete** the `@SpringBootApplication` main class (Quarkus doesn't need one)
- If it has `CommandLineRunner` or `ApplicationRunner` logic, move to a bean with `void onStart(@Observes StartupEvent ev)`

#### 4b. REST Controllers
**Full migration:**
- `@RestController` → `@Path("/...") @ApplicationScoped`
- `@GetMapping("/path")` → `@GET @Path("/path")`
- `@PostMapping` → `@POST`, etc.
- `@PathVariable` → `@PathParam` (or `@RestPath`)
- `@RequestParam` → `@QueryParam` (or `@RestQuery`)
- `@RequestBody` → just the parameter (no annotation needed in Quarkus REST)
- `ResponseEntity<T>` → return `T` directly, or `RestResponse<T>` for status control
- `@ExceptionHandler` → `@ServerExceptionMapper` or `ExceptionMapper<T>`

**Compatibility migration:**
- Keep Spring annotations, add `quarkus-spring-web` dependency

#### 4c. Services and Components
**Full migration:**
- `@Service` / `@Component` → `@ApplicationScoped`
- `@Autowired` → `@Inject`
- Constructor injection works the same (preferred)
- `@Value("${prop}")` → `@ConfigProperty(name = "prop")`
- `@Configuration` + `@Bean` → `@ApplicationScoped` class with `@Produces` methods

**Compatibility migration:**
- Keep Spring annotations, add `quarkus-spring-di` dependency

#### 4d. Data / Repositories
**Full migration (Panache Active Record):**
```java
// Before: Spring Data
public interface PetRepository extends JpaRepository<Pet, Long> {
    List<Pet> findByName(String name);
}

// After: Panache Active Record
@Entity
public class Pet extends PanacheEntity {
    public String name;
    public static List<Pet> findByName(String name) {
        return find("name", name).list();
    }
}
```

**Full migration (Panache Repository):**
```java
@ApplicationScoped
public class PetRepository implements PanacheRepository<Pet> {
    public List<Pet> findByName(String name) {
        return find("name", name).list();
    }
}
```

**Compatibility migration:**
- Keep Spring Data interfaces, add `quarkus-spring-data-jpa`

#### 4e. Templates (Thymeleaf → Qute)

**Full migration (recommended):**
- Convert Thymeleaf templates to Qute templates
- Place templates in `src/main/resources/templates/`
- Key syntax changes:
  - `th:text="${name}"` → `{name}`
  - `th:each="item : ${items}"` → `{#for item in items}...{/for}`
  - `th:if="${condition}"` → `{#if condition}...{/if}`
  - `th:href="@{/path}"` → `href="/path"`
  - Fragment includes: `th:replace="fragments/header"` → `{#include header /}`
- In controllers: return `TemplateInstance` from Qute type-safe templates

**Keeping Thymeleaf:**
- Use `quarkus-thymeleaf` community extension (if available) or serve as raw templates
- Less idiomatic but reduces migration scope

#### 4f. Security
- Replace `SecurityFilterChain` / `WebSecurityConfigurerAdapter` with `application.properties` config
- `@PreAuthorize("hasRole('X')")` → `@RolesAllowed("X")`
- For basic auth: `quarkus-elytron-security-properties-file`
- For OAuth2/OIDC: `quarkus-oidc`
- For form login: `quarkus-security` with form auth config

#### 4g. Scheduling
- `@Scheduled(cron = "...")` → `@io.quarkus.scheduler.Scheduled(cron = "...")`
- Remove `@EnableScheduling`

### Step 5: Migrate Tests

- `@SpringBootTest` → `@QuarkusTest`
- `@MockBean` → `@InjectMock` (from `quarkus-junit5-mockito`)
- `TestRestTemplate` → RestAssured: `given().when().get("/path").then().statusCode(200)`
- `@ActiveProfiles("test")` → `@TestProfile(...)` or `%test.` config prefix
- `@WebMvcTest` → `@QuarkusTest` with RestAssured
- `@DataJpaTest` → `@QuarkusTest` (test with real DB or H2 via `%test.` datasource config)

### Step 6: Clean Up

1. Remove `src/main/java/*Application.java` (the main class) if not already done
2. Remove any `spring-boot-devtools` references
3. Remove `META-INF/spring.factories` or `META-INF/spring/` auto-configuration files
4. Verify no `org.springframework` imports remain (unless compatibility strategy)
5. Run `./mvnw compile` to check for compilation errors, fix iteratively
6. Run `./mvnw test` to check tests pass, fix iteratively
7. Run `./mvnw quarkus:dev` to verify the app starts and basic endpoints work

### Step 7: Verify

1. Confirm the app compiles: `./mvnw compile`
2. Confirm tests pass: `./mvnw test`
3. Confirm the app starts: `./mvnw quarkus:dev`
4. Test key endpoints manually or describe what to test

## Common Pitfalls

- **Missing `@Transactional`**: Quarkus uses `jakarta.transaction.Transactional`, not Spring's
- **Bean discovery**: Quarkus uses build-time CDI; beans must have a scope annotation
- **No OSIV**: Quarkus doesn't have Open Session in View; lazy loading outside transactions will fail
- **Static resources**: Place in `src/main/resources/META-INF/resources/` (not `static/`)
- **Test port**: Quarkus tests run on port 8081 by default (`quarkus.http.test-port`)
- **No component scanning**: Quarkus discovers beans at build time in the application module; beans in external JARs need a Jandex index or `quarkus.index-dependency`
