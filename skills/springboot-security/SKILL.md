---
name: springboot-security
description: >
  Load when configuring SecurityFilterChain, writing JwtAuthenticationFilter or
  OncePerRequestFilter, setting up OAuth2 resource server (jwt.issuer-uri, jwk-set-uri),
  applying @PreAuthorize/@PostAuthorize method security, configuring CorsConfigurationSource,
  CSRF policy for stateless APIs, BCryptPasswordEncoder strength, or writing security tests
  with @WithMockUser, @WebMvcTest, and Spring Security Test.
---

# Spring Boot Security

## SecurityFilterChain — Spring Security 6

Never extend `WebSecurityConfigurerAdapter` (removed in Spring Security 6). Use `SecurityFilterChain` beans.

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)          // stateless APIs
            .sessionManagement(s -> s.sessionCreationPolicy(STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health", "/actuator/info").permitAll()
                .requestMatchers(HttpMethod.POST, "/auth/token").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            .build();
    }
}
```

---

## JWT Authentication Filter

```java
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenValidator tokenValidator;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
        throws ServletException, IOException {
        var token = extractBearerToken(request);
        if (token != null) {
            SecurityContextHolder.getContext().setAuthentication(tokenValidator.validate(token));
        }
        chain.doFilter(request, response);
    }

    private String extractBearerToken(HttpServletRequest request) {
        var header = request.getHeader(HttpHeaders.AUTHORIZATION);
        return (StringUtils.hasText(header) && header.startsWith("Bearer ")) ? header.substring(7) : null;
    }
}
```

**Pitfalls:** Never log raw JWT tokens. Validate `exp`, `iss`, and `aud` claims. Use RS256 (asymmetric) in production — HS256 only for internal services with a single secret owner.

---

## OAuth2 Resource Server

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com
          jwk-set-uri: https://auth.example.com/.well-known/jwks.json
```

```java
@Bean
JwtAuthenticationConverter customJwtConverter() {
    var converter = new JwtGrantedAuthoritiesConverter();
    converter.setAuthoritiesClaimName("roles");
    converter.setAuthorityPrefix("ROLE_");
    var authConverter = new JwtAuthenticationConverter();
    authConverter.setJwtGrantedAuthoritiesConverter(converter);
    return authConverter;
}
```

---

## Method Security

```java
@EnableMethodSecurity  // replaces @EnableGlobalMethodSecurity

@PreAuthorize("hasRole('ADMIN')")
public void deleteUser(UUID userId) { ... }

@PreAuthorize("hasAuthority('order:write') and #order.customerId == authentication.name")
public Order updateOrder(Order order) { ... }

@PostAuthorize("returnObject.ownerId == authentication.name")
public Document findDocument(UUID id) { ... }

@PreAuthorize("@orderAuthorizationService.canAccess(authentication, #orderId)")
public Order getOrder(UUID orderId) { ... }
```

**Pitfall:** `@PreAuthorize` on `private` methods is ignored — Spring AOP cannot intercept them.

---

## SQL Injection Prevention

```java
// BAD — string concatenation in native query
@Query(value = "SELECT * FROM users WHERE name = '" + name + "'", nativeQuery = true)

// GOOD — parameterized native query
@Query(value = "SELECT * FROM users WHERE name = :name", nativeQuery = true)
List<User> findByName(@Param("name") String name);

// GOOD — Spring Data derived query (auto-parameterized, no injection surface)
List<User> findByEmailAndActiveTrue(String email);
```

**Rule:** Never concatenate user input into JPQL or SQL strings. Spring Data derived queries and `:param` bindings are the only safe options.

---

## CSRF

| Scenario | Setting | Reason |
|---|---|---|
| Stateless JWT REST API | `disable` | No session cookie; CSRF not applicable |
| Form-based login | `enable` (default) | Session cookie exists |
| Mixed API + form | Enable with path exclusions | Exclude `/api/**` |

---

## CORS

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com"));  // NEVER "*" in production
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);

    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

---

## Password Encoding

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);  // strength 12; never use MD5 or SHA-1
}

// Usage
String encoded = passwordEncoder.encode(rawPassword);
boolean matches = passwordEncoder.matches(rawPassword, encodedPassword);
```

---

## Secrets Management

```yaml
# BAD — hardcoded in application.yml
spring:
  datasource:
    password: mySecretPassword123

# GOOD — environment variable placeholder
spring:
  datasource:
    password: ${DB_PASSWORD}

# GOOD — Spring Cloud Vault integration
spring:
  cloud:
    vault:
      uri: https://vault.example.com
      token: ${VAULT_TOKEN}
```

**Rules:** No secrets in source control. Use env vars for simple deployments, Vault/AWS Secrets Manager for production. Rotate credentials regularly. Never log secret values — scrub or mask before any log statement.

---

## Security Headers

```java
http
    .headers(headers -> headers
        .contentSecurityPolicy(csp -> csp
            .policyDirectives("default-src 'self'"))
        .frameOptions(HeadersConfigurer.FrameOptionsConfig::sameOrigin)
        .xssProtection(Customizer.withDefaults())
        .referrerPolicy(rp -> rp
            .policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER)));
```

Minimum required headers for all HTTP responses:

| Header | Value | Purpose |
|---|---|---|
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `X-Frame-Options` | `SAMEORIGIN` | Prevent clickjacking |
| `Strict-Transport-Security` | `max-age=31536000` | Enforce HTTPS |
| `Content-Security-Policy` | `default-src 'self'` | Prevent XSS/injection |
| `Referrer-Policy` | `no-referrer` | Prevent referrer leakage |

---

## Security Testing with @WithMockUser

```java
@WebMvcTest(OrderController.class)
class OrderControllerSecurityTest {

    @Autowired MockMvc mockMvc;
    @MockBean OrderService orderService;

    @Test
    @WithMockUser(roles = "USER")
    void shouldAllowUserToCreateOrder() throws Exception {
        mockMvc.perform(post("/orders").contentType(APPLICATION_JSON).content("{}"))
            .andExpect(status().isCreated());
    }

    @Test
    void shouldRejectUnauthenticatedRequest() throws Exception {
        mockMvc.perform(get("/orders"))
            .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "USER")
    void shouldForbidUserFromAdminEndpoint() throws Exception {
        mockMvc.perform(delete("/admin/users/1"))
            .andExpect(status().isForbidden());
    }
}
```

---

## File Uploads

```java
@PostMapping("/upload")
public ResponseEntity<String> upload(@RequestParam MultipartFile file) {
    // Validate size
    if (file.getSize() > 10 * 1024 * 1024) {
        throw new IllegalArgumentException("File exceeds 10 MB limit");
    }
    // Validate content type — do NOT trust the client-supplied MIME type alone
    String contentType = file.getContentType();
    if (!Set.of("image/jpeg", "image/png", "application/pdf").contains(contentType)) {
        throw new IllegalArgumentException("Unsupported file type");
    }
    // Validate extension
    String filename = StringUtils.cleanPath(file.getOriginalFilename());
    if (filename.contains("..")) {
        throw new IllegalArgumentException("Invalid filename");
    }
    // Store outside web root; never in a path derived from user input
    storageService.store(file);
    return ResponseEntity.ok("Uploaded");
}
```

**Rules:** Validate size, MIME type, and extension server-side. Store outside the web root. Use a random UUID as the stored filename — never the original. Virus-scan in high-risk environments.

---

## Dependency Security

- Run OWASP Dependency-Check or Snyk in CI — fail builds on known CVEs
- Keep Spring Boot and Spring Security on the current support branch
- Subscribe to [Spring Security advisories](https://spring.io/security) and patch promptly
- Use `./mvnw dependency:tree` regularly to spot transitive vulnerabilities

---

## OWASP Checklist

- No plaintext secrets in `application.yml` — use environment variables or Vault
- No `permitAll()` on non-public endpoints
- No `allowedOrigins("*")` in production
- JWT secret ≥ 256 bits; prefer asymmetric keys
- BCrypt strength ≥ 12
- Actuator secured: `health` and `info` public only
- `X-Content-Type-Options`, `X-Frame-Options`, and `Strict-Transport-Security` headers set
- Content-Security-Policy configured
- Input validated at controller boundary with `@Valid`
- No string-concatenated SQL — parameterized queries only
- File uploads validated (size, MIME, extension) and stored outside web root
- Sensitive data (passwords, tokens, PAN) never logged
- OWASP Dependency-Check / Snyk passing in CI
- Rate limiting applied to authentication and expensive endpoints
