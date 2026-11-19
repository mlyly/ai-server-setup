# Quarkus Backend — Agent & Subagent Guidelines

## 1. Subagent & Parallel Execution Strategy

- **Parallel Discovery (`@explore`)**: Spawn parallel `@explore` subagents when tracing endpoints:
    - Subagent 1: Locate JAX-RS `@Path` resources, DTOs, and MicroProfile OpenAPI annotations.
    - Subagent 2: Locate `@ApplicationScoped` CDI beans, Panache entities/repositories, and `application.properties`
      profiles (`%dev`, `%test`, `%prod`).
- **Offload Boilerplate (`@fast-edit`)**: Delegate DTO records, Panache query methods, `@QuarkusTest` REST Assured
  specs, and SQL migrations to `@fast-edit`.
- **Primary Model (`build`)**: Reserve for reactive/imperative concurrency boundaries, CDI interceptor/security logic,
  and multi-resource refactors.

## 2. Context & Token Efficiency Rules

- **Ignore Generated & Build Artifacts**: Never read `target/`, `build/`, `quarkus-app/`, or native image build logs.
- **Minimal Diffs**: Apply targeted search/replace edits rather than rewriting entire resource or service classes.

## 3. Fast Build & Verification Loops

- **Compile check only (fastest)**:
    - Maven: `./mvnw test-compile -q`
    - Gradle: `./gradlew testClasses --quiet`
- **Single test execution**:
    - Maven: `./mvnw test -Dtest=TargetResourceTest -Dquarkus.log.level=WARN -q`
    - Gradle: `./gradlew test --tests "*TargetResourceTest" --quiet`
- **Avoid**: Building native GraalVM executables (`-Dnative`) or running full integration test suites unless explicitly
  requested.

## 4. Quarkus Coding Conventions

- **CDI & Injection**: Use `@ApplicationScoped` or `@RequestScoped` with constructor injection. Avoid field injection (
  `@Inject` on fields) unless required for test mocks (`@InjectMock`).
- **Reactive vs. Imperative Execution**: Do not mix blocking JDBC/Hibernate ORM calls onto the Vert.x event loop. Use
  `@Blocking` or standard imperative JAX-RS signatures when using blocking Hibernate/Panache, and `Uni<T>` / `Multi<T>`
  only with reactive drivers (Hibernate Reactive / Mutiny).
- **Persistence & Transactions**: Annotate mutating service methods with `@Transactional` (
  `jakarta.transaction.Transactional`). Prefer Panache Repository pattern over Active Record for complex domain logic to
  keep entities clean and testable.
- **Configuration**: Bind typed configuration groups using `@ConfigMapping(prefix = "...")` rather than scattering
  `@ConfigProperty` annotations across classes.
