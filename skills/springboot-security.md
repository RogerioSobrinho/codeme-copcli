---
name: springboot-security
description: Spring Security 6 knowledge base for Java/Spring Boot. Covers JWT, OAuth2, method security, CSRF/CORS configuration, and OWASP-aligned security patterns.
tools: ["Read", "Grep", "Bash"]
model: claude-sonnet-4-5
activation: ["spring security", "jwt", "oauth2", "security config", "spring boot security"]
---

# Spring Boot Security

## Purpose

Comprehensive Spring Security 6 reference for Java/Spring Boot applications. Covers the modern `SecurityFilterChain` DSL, stateless JWT authentication, OAuth2 resource server configuration, method-level authorization, CSRF/CORS policies, and OWASP Top 10 mitigations. Use this skill to configure, audit, or evolve the security posture of a Spring Boot service.

---

## SecurityFilterChain — Modern Spring Security 6 Config

### Rule
Never extend `WebSecurityConfigurerAdapter` (removed in Spring Security 6). Use `SecurityFilterChain` beans exclusively.

### Pattern
```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)          // stateless APIs — disable CSRF
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

### Pitfalls
- `permitAll()` on `anyRequest()` disables all authentication — never use in production.
- Always define `requestMatchers` from most specific to most general.

---

## JWT Authentication — Stateless Filter

### When to Use
- Stateless REST APIs where sessions are not maintained server-side
- Microservices where tokens are passed between services

### JWT Filter Pattern
```java
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtTokenValidator tokenValidator;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        var token = extractBearerToken(request);
        if (token != null) {
            var authentication = tokenValidator.validate(token);
            SecurityContextHolder.getContext().setAuthentication(authentication);
        }
        chain.doFilter(request, response);
    }

    private String extractBearerToken(HttpServletRequest request) {
        var header = request.getHeader(HttpHeaders.AUTHORIZATION);
        if (StringUtils.hasText(header) && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        return null;
    }
}
```

### Token Validation
```java
@Component
public class JwtTokenValidator {

    private final JwtDecoder jwtDecoder;

    public Authentication validate(String token) {
        var jwt = jwtDecoder.decode(token);  // throws JwtException on invalid
        var authorities = extractAuthorities(jwt);
        return new JwtAuthenticationToken(jwt, authorities);
    }
}
```

### Pitfalls
- Never log raw JWT tokens — they are bearer credentials.
- Validate `exp`, `iss`, and `aud` claims. Do NOT skip audience validation.
- Use asymmetric keys (RS256/ES256) for production — symmetric (HS256) is only acceptable for internal services with a single secret owner.

---

## OAuth2 Resource Server — `oauth2ResourceServer(jwt())`

### Pattern
```java
// application.yml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: https://auth.example.com
          jwk-set-uri: https://auth.example.com/.well-known/jwks.json
```

```java
http.oauth2ResourceServer(oauth2 ->
    oauth2.jwt(jwt ->
        jwt.jwtAuthenticationConverter(customJwtConverter())
    )
);
```

### Custom Claims Converter
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

### Pitfalls
- If `issuer-uri` is set, Spring Boot auto-configures JWK set fetching. Do NOT manually configure both.
- Ensure the JWKS endpoint is accessible from the service. Cache failures cause 401 storms.

---

## Method Security — `@PreAuthorize`, `@PostAuthorize`

### Enable
```java
@EnableMethodSecurity  // replaces @EnableGlobalMethodSecurity
```

### Patterns
```java
@PreAuthorize("hasRole('ADMIN')")
public void deleteUser(UUID userId) { ... }

@PreAuthorize("hasAuthority('order:write') and #order.customerId == authentication.name")
public Order updateOrder(Order order) { ... }

@PostAuthorize("returnObject.ownerId == authentication.name")
public Document findDocument(UUID id) { ... }

@PreAuthorize("@orderAuthorizationService.canAccess(authentication, #orderId)")
public Order getOrder(UUID orderId) { ... }
```

### SpEL Security Expressions
| Expression | Meaning |
|---|---|
| `hasRole('X')` | User has `ROLE_X` authority |
| `hasAuthority('X')` | User has exact authority `X` |
| `isAuthenticated()` | Not anonymous |
| `#param` | Method parameter named `param` |
| `authentication.name` | Current principal's username |
| `@beanName.method(...)` | Delegate to a Spring bean |

### Pitfalls
- `@PreAuthorize` on `private` methods is ignored — Spring AOP cannot intercept them.
- Use `@PostAuthorize` sparingly; the method executes before the check.

---

## CSRF — Enable vs Disable

| Scenario | CSRF Setting | Reason |
|---|---|---|
| Stateless JWT REST API | `disable` | No session cookie; CSRF not applicable |
| Form-based login (Thymeleaf, MVC) | `enable` (default) | Session cookie exists; CSRF attack is possible |
| Mixed (API + form) | Enable with path exclusions | Protect form routes; exclude `/api/**` |

### Exclude API Paths from CSRF
```java
.csrf(csrf -> csrf
    .ignoringRequestMatchers("/api/**")
)
```

### Pitfalls
- Disabling CSRF globally on a service that serves HTML forms is a critical vulnerability.
- Custom CSRF token repositories require careful implementation — prefer the default `HttpSessionCsrfTokenRepository`.

---

## CORS — `CorsConfigurationSource` Bean

### Pattern
```java
@Bean
CorsConfigurationSource corsConfigurationSource() {
    var config = new CorsConfiguration();
    config.setAllowedOrigins(List.of("https://app.example.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setAllowCredentials(true);
    config.setMaxAge(3600L);

    var source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/api/**", config);
    return source;
}
```

```java
http.cors(cors -> cors.configurationSource(corsConfigurationSource()));
```

### Pitfalls
- `allowedOrigins("*")` with `allowCredentials(true)` is invalid and throws at startup. Use explicit origins when credentials are required.
- CORS is NOT a server-side security boundary — it only controls browser access. Server-to-server calls ignore CORS.

---

## Password Encoding — BCrypt vs Argon2

| Algorithm | Spring Bean | Use When |
|---|---|---|
| BCrypt | `new BCryptPasswordEncoder(12)` | Default choice; widely supported; strength 12 recommended |
| Argon2 | `new Argon2PasswordEncoder(...)` | Highest security requirement; memory-hard; use when compliance demands it |
| PBKDF2 | `new Pbkdf2PasswordEncoder(...)` | FIPS-140 compliance required |

### Pattern
```java
@Bean
PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
}
```

### Pitfalls
- Never use `NoOpPasswordEncoder` — it stores passwords in plain text.
- Never use MD5 or SHA-1 for passwords.
- Use `DelegatingPasswordEncoder` when migrating from a weaker algorithm to BCrypt.

---

## Security Testing

### `@WithMockUser`
```java
@Test
@WithMockUser(roles = "ADMIN")
void adminCanDeleteUser() throws Exception {
    mockMvc.perform(delete("/users/123"))
        .andExpect(status().isNoContent());
}

@Test
void anonymousCannotDeleteUser() throws Exception {
    mockMvc.perform(delete("/users/123"))
        .andExpect(status().isUnauthorized());
}
```

### JWT Token in MockMvc
```java
mockMvc.perform(get("/orders")
    .with(jwt().authorities(new SimpleGrantedAuthority("ROLE_USER"))
               .jwt(jwt -> jwt.claim("sub", "user-123"))))
    .andExpect(status().isOk());
```

### Pitfalls
- `@WithMockUser` does NOT go through the JWT filter — use `SecurityMockMvcRequestPostProcessors.jwt()` for token-based auth tests.
- Always test the unauthorized path, not just the authorized path.

---

## Common Misconfigurations

| Misconfiguration | Risk | Fix |
|---|---|---|
| `permitAll()` on `anyRequest()` | No authentication enforced | Default to `authenticated()`; explicitly permit public paths |
| Hardcoded JWT secret in `application.properties` | Secret exposure in VCS | Use environment variable or secrets manager |
| HTTP (not HTTPS) in production | Token interception | Enforce HTTPS via load balancer or `http.requiresChannel()` |
| Missing `exp` validation | Expired tokens accepted | Spring Security validates `exp` by default — do NOT disable |
| Broad CORS (`allowedOrigins("*")`) | Cross-origin data access | Specify exact allowed origins |
| Logging request bodies containing credentials | Credential leak in logs | Filter sensitive headers/bodies in logging filters |

---

## OWASP Top 10 Mapping

| OWASP Risk | Spring Security Mitigation |
|---|---|
| A01 Broken Access Control | `@PreAuthorize`, `authorizeHttpRequests`, method security |
| A02 Cryptographic Failures | BCryptPasswordEncoder, HTTPS enforcement, no plain-text secrets |
| A03 Injection | Spring Data parameterized queries (out of scope but adjacent) |
| A05 Security Misconfiguration | Disable unused actuator endpoints, review `permitAll()` scopes |
| A07 Identification & Auth Failures | JWT expiry, strong password encoding, brute-force protection |
| A09 Security Logging Failures | Audit login events, mask credentials in logs |

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `grep -r "SecurityFilterChain\|WebSecurityConfigurerAdapter" src/main --include="*.java" -l`
- `grep -r "spring-security\|spring-boot-starter-security" pom.xml`
- Pros: Fast, zero extra agent invocations
- Cons: Partial context; may miss cross-cutting concerns

**Option 2 — Invoke `codebase-explorer-agent` First**
Ask the user to run `codebase-explorer-agent`, wait for `.copilot-runtime/artifacts/context.json`, then re-run this agent.
- Pros: Richer, consistent context shared with all downstream agents
- Cons: Extra manual step; slightly slower

**Option 3 (RECOMMENDED) — Auto-Bootstrap then Proceed**
Invoke `codebase-explorer-agent` automatically, consume the resulting `context.json`, then continue execution without user intervention.
- Pros: Fully autonomous; deterministic context; no coordination overhead
- Cons: Slightly longer cold start
- **Why recommended:** Eliminates user coordination overhead and guarantees all agents share the same project baseline.

After context is available via any option, resume normal execution flow.
