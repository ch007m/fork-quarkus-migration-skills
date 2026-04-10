# Spring → Quarkus Annotation Map

## Dependency Injection

| Spring | Quarkus (Full Migration) | Notes |
|--------|--------------------------|-------|
| `@Component` | `@ApplicationScoped` | Or `@Singleton` for no proxy |
| `@Service` | `@ApplicationScoped` | No semantic equivalent; just a CDI bean |
| `@Repository` | `@ApplicationScoped` | Or use Panache repositories |
| `@Autowired` | `@Inject` | CDI standard injection |
| `@Qualifier` | `@jakarta.inject.Named` or custom `@Qualifier` | CDI qualifiers |
| `@Value("${prop}")` | `@ConfigProperty(name = "prop")` | Use `@io.smallrye.config.ConfigMapping` for groups |
| `@Configuration` | `@ApplicationScoped` | Produce beans via `@Produces` methods |
| `@Bean` | `@Produces` | CDI producer method |
| `@Primary` | `@io.quarkus.arc.DefaultBean` or `@Alternative` + `@Priority` | |
| `@Conditional*` | `@io.quarkus.arc.profile.IfBuildProfile` or `@io.quarkus.arc.lookup.LookupIfProperty` | Build-time conditions |
| `@Scope("prototype")` | `@Dependent` | New instance per injection point |
| `@Lazy` | No direct equivalent | Quarkus beans are lazy by default in CDI |
| `@PostConstruct` | `@PostConstruct` | Same (jakarta.annotation) |
| `@PreDestroy` | `@PreDestroy` | Same (jakarta.annotation) |

## REST / Web

| Spring | Quarkus (Full Migration) | Notes |
|--------|--------------------------|-------|
| `@RestController` | `@Path` + `@ApplicationScoped` | Class-level |
| `@RequestMapping("/path")` | `@Path("/path")` | |
| `@GetMapping` | `@GET` | jakarta.ws.rs |
| `@PostMapping` | `@POST` | jakarta.ws.rs |
| `@PutMapping` | `@PUT` | jakarta.ws.rs |
| `@DeleteMapping` | `@DELETE` | jakarta.ws.rs |
| `@PatchMapping` | `@PATCH` | jakarta.ws.rs |
| `@PathVariable` | `@PathParam` | Or `@RestPath` (Quarkus REST) |
| `@RequestParam` | `@QueryParam` | Or `@RestQuery` (Quarkus REST) |
| `@RequestBody` | No annotation needed | Quarkus REST auto-detects body param |
| `@RequestHeader` | `@HeaderParam` | Or `@RestHeader` |
| `@CookieValue` | `@CookieParam` | Or `@RestCookie` |
| `@ResponseStatus` | Return `Response` or `RestResponse` | Or use exception mappers |
| `@ExceptionHandler` | `@ServerExceptionMapper` | Or implement `ExceptionMapper<T>` |
| `@ControllerAdvice` | `@ServerExceptionMapper` on a class | |
| `@CrossOrigin` | Configure `quarkus.http.cors` in properties | |
| `@ResponseBody` | Default in Quarkus REST | |
| `@Produces/@Consumes` (Spring) | `@Produces/@Consumes` (JAX-RS) | Same concept, different imports |

## Data / JPA

| Spring | Quarkus (Full Migration) | Notes |
|--------|--------------------------|-------|
| `@Entity` | `@Entity` | Same (jakarta.persistence) |
| `@Table` | `@Table` | Same (jakarta.persistence) |
| `@Id` | `@Id` | Same |
| `@GeneratedValue` | `@GeneratedValue` | Same |
| `@Transactional` | `@Transactional` | `jakarta.transaction.Transactional` (not Spring's) |
| `@Query` (Spring Data) | Panache `find()` / `list()` / named queries | |
| `CrudRepository<T,ID>` | `PanacheRepository<T>` or Active Record pattern | |
| `JpaRepository<T,ID>` | `PanacheRepository<T>` | |

## Scheduling

| Spring | Quarkus (Full Migration) | Notes |
|--------|--------------------------|-------|
| `@Scheduled(cron=...)` | `@io.quarkus.scheduler.Scheduled(cron=...)` | |
| `@EnableScheduling` | Not needed | Auto-enabled with `quarkus-scheduler` |
| `@Async` | Return `Uni<T>` or `CompletionStage` | Or use `@ActivateRequestContext` + managed executor |

## Security

| Spring | Quarkus (Full Migration) | Notes |
|--------|--------------------------|-------|
| `@PreAuthorize("hasRole('ADMIN')")` | `@RolesAllowed("ADMIN")` | jakarta.annotation.security |
| `@Secured` | `@RolesAllowed` | |
| `@EnableWebSecurity` | Not needed | Configure in `application.properties` |
| `@AuthenticationPrincipal` | `@Context SecurityContext` | Or inject `io.quarkus.security.identity.SecurityIdentity` |

## Testing

| Spring | Quarkus (Full Migration) | Notes |
|--------|--------------------------|-------|
| `@SpringBootTest` | `@QuarkusTest` | |
| `@WebMvcTest` | `@QuarkusTest` + RestAssured | |
| `@DataJpaTest` | `@QuarkusTest` with test profile | |
| `@MockBean` | `@InjectMock` (`quarkus-junit5-mockito`) | |
| `@TestConfiguration` | `@QuarkusTestResource` | |
| `@ActiveProfiles("test")` | `@TestProfile(TestProfile.class)` | |
| `TestRestTemplate` | RestAssured (`given().when().get(...)`) | |
| `@LocalServerPort` | `@TestHTTPResource` | |

## Application Lifecycle

| Spring | Quarkus | Notes |
|--------|---------|-------|
| `@SpringBootApplication` | No equivalent needed | Quarkus auto-discovers beans |
| `SpringApplication.run()` | `Quarkus.run()` or just `quarkus:dev` | Usually no main class needed |
| `CommandLineRunner` | `@Observes StartupEvent` | `io.quarkus.runtime.StartupEvent` |
| `ApplicationRunner` | `@Observes StartupEvent` | |
| `@EventListener` | `@Observes` | CDI events |
