# Spring Boot Backend — Agent & Subagent Guidelines

## 1. Subagent & Parallel Execution Strategy

- **Parallel Discovery (`@explore`)**: When tracing an API flow, launch parallel `@explore` subagents simultaneously:
    - Subagent 1: Locate `@RestController`, request/response DTOs, and OpenAPI annotations.
    - Subagent 2: Locate `@Service`, `@Transactional` boundaries, Spring Data `@Repository` interfaces, and
      Liquibase/Flyway migrations.
- **Offload Boilerplate (`@fast-edit`)**: Delegate Java records (DTOs), MapStruct mappers, JUnit 5 / Mockito unit tests,
  and Flyway/Liquibase SQL scripts to `@fast-edit`.
- **Primary Model (`build`)**: Reserve for complex business rules, Spring Security filter chains, transaction
  propagation, and multi-service refactors.

## 2. Context & Token Efficiency Rules

- **Ignore Generated & Build Artifacts**: Never read `target/`, `build/`, `.mvn/`, `.gradle/`, or generated
  MapStruct/Q-classes.
- **Minimal Diffs**: Use targeted search/replace edits. Never rewrite full classes when updating a single method,
  annotation, or query.

## 3. Fast Build & Verification Loops

- **Compile check only (fastest)**:
    - Maven: `./mvnw test-compile -q` (or `mvn test-compile -q`)
    - Gradle: `./gradlew testClasses --quiet`
- **Single unit test execution**:
    - Maven: `./mvnw test -Dtest=TargetServiceTest -Dsurefire.failIfNoSpecifiedTests=false -q`
    - Gradle: `./gradlew test --tests "*TargetServiceTest" --quiet`
- **Avoid**: Running `mvn clean install` or full `@SpringBootTest` / Testcontainers suites unless explicitly requested.

## 4. Spring Boot Coding Conventions

- **Dependency Injection**: Use constructor injection (`final` fields or `@RequiredArgsConstructor`). Never use
  `@Autowired` field injection.
- **DTOs & Validation**: Use Java `record` types for immutable request/response DTOs. Validate inputs at the controller
  boundary with `@Valid` and Jakarta Validation (`@NotNull`, `@NotBlank`, `@Size`). Never expose JPA `@Entity` classes
  directly in REST responses.
- **Persistence & Transactions**: Keep `@Transactional` on `@Service` methods (never on controllers). Use
  `@Transactional(readOnly = true)` for query methods and watch for N+1 lazy-loading issues (`@EntityGraph` or
  `JOIN FETCH`).
- **Error Handling**: Throw domain-specific exceptions handled centrally by `@RestControllerAdvice` returning RFC 9457
  `ProblemDetail`.
