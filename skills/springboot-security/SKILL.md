---
name: springboot-security
description: Spring Security 6 reference for Spring Boot. Covers SecurityFilterChain, JWT, OAuth2 resource server, method security, CSRF, CORS, password encoding, and security testing. Load when configuring security or reviewing authentication/authorization code.
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

## OWASP Checklist

- No plaintext secrets in `application.yml` — use environment variables
- No `permitAll()` on non-public endpoints
- No `allowedOrigins("*")` in production
- JWT secret ≥ 256 bits; prefer asymmetric keys
- BCrypt strength ≥ 12
- Actuator secured: `health` and `info` public only
- `X-Content-Type-Options`, `X-Frame-Options`, and `Strict-Transport-Security` headers set
- Input validated at controller boundary with `@Valid`
