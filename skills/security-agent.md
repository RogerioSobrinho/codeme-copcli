# Security Agent

## Purpose

Audits a Java/Spring Boot feature or project against OWASP Top 10 and Spring Security best practices. Identifies authentication, authorization, input validation, secrets management, and injection vulnerabilities. Produces a security report with severity-classified findings and remediation options.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/artifacts/implementation-spec.json` | API endpoints, data flows |
| `.copilot-runtime/artifacts/requirements.json` | Security requirements, user roles |
| `.copilot-runtime/artifacts/context.json` | Auth mechanism (JWT, OAuth2, Session), Spring Security version |
| `.copilot-runtime/analysis/impact-report.json` | External-facing endpoints, data sensitivity |

---

## Outputs

Writes to: `.copilot-runtime/analysis/security-report.json`

Structure:

```json
{
  "owasp_coverage": {
    "A01_broken_access_control": { "status": "pass | fail | review", "findings": [] },
    "A02_cryptographic_failures": { "status": "pass | fail | review", "findings": [] },
    "A03_injection": { "status": "pass | fail | review", "findings": [] },
    "A04_insecure_design": { "status": "pass | fail | review", "findings": [] },
    "A05_security_misconfiguration": { "status": "pass | fail | review", "findings": [] },
    "A06_vulnerable_components": { "status": "pass | fail | review", "findings": [] },
    "A07_auth_failures": { "status": "pass | fail | review", "findings": [] },
    "A08_integrity_failures": { "status": "pass | fail | review", "findings": [] },
    "A09_logging_monitoring": { "status": "pass | fail | review", "findings": [] },
    "A10_ssrf": { "status": "pass | fail | review", "findings": [] }
  },
  "spring_security_audit": {
    "method_security_enabled": false,
    "csrf_configured": false,
    "cors_configured": false,
    "issues": []
  },
  "secrets_management": {
    "hardcoded_secrets": [],
    "env_variable_usage": true,
    "vault_integration": false
  },
  "input_validation": {
    "missing_validation": [],
    "injection_risks": []
  },
  "data_exposure_risks": [],
  "findings": [
    {
      "severity": "critical | high | medium | low | info",
      "owasp_category": "",
      "description": "",
      "location": "",
      "remediation_options": []
    }
  ]
}
```

---

## Execution Steps

1. Read `implementation-spec.json` — map all API endpoints and data flows
2. Read `requirements.json` — identify security requirements and user roles
3. Read `context.json` — identify auth mechanism, Spring Security configuration
4. Evaluate each OWASP Top 10 category against the implementation
5. Audit Spring Security configuration: method security, CSRF, CORS
6. Scan for hardcoded secrets, credentials, API keys
7. Validate input validation at all boundaries (DTOs, path/query params)
8. Identify data exposure risks (PII in logs, over-fetching in responses)
9. Write `security-report.json`
10. Return `ok` or `fail` based on presence of critical/high findings

---

## Security Rules Enforced

### Authentication & Authorization
- `@PreAuthorize` or `@Secured` required on all non-public endpoints
- `SecurityContext` must never be passed as a method parameter — use `SecurityContextHolder`
- JWT secrets must be ≥ 256 bits and loaded from environment variables
- Token expiry must be defined — no eternal tokens
- Password storage must use BCrypt, Argon2, or SCrypt — never MD5/SHA-1/plain

### Input Validation (OWASP A03)
- Bean Validation (`@Valid`, `@NotNull`, `@Size`) required on all incoming DTOs
- Path variables and query parameters must be validated
- No raw SQL concatenation — use parameterized queries or Spring Data
- XML input must disable external entity processing (XXE prevention)
- File uploads must validate MIME type and size — never trust `Content-Type` header

### Secrets Management
- No secrets in `application.properties` committed to source control
- Prefer Spring Cloud Vault, AWS Secrets Manager, or environment variables
- Secrets must not appear in logs — mask in MDC and exception messages

### Data Exposure
- API responses must use DTOs — never expose JPA entities directly
- PII fields (email, phone, SSN) must be masked in logs
- Error responses must not expose stack traces or internal details in production

### CORS & CSRF
- CORS must be explicitly configured — never `allowedOrigins("*")` in production
- CSRF protection required for session-based auth — can be disabled only for stateless JWT APIs

---

## Questions When Input Missing

- "What authentication mechanism is used? (JWT, OAuth2, Session-based)"
- "Are there multi-tenant or role-based access control requirements?"
- "Are there any endpoints that handle file uploads or binary data?"
- "Is there any PII (Personally Identifiable Information) processed by this feature?"

---

## Validation Rules

- Hardcoded secret in code → `critical`
- Missing `@PreAuthorize` on admin endpoint → `critical`
- Raw SQL concatenation → `critical`
- `allowedOrigins("*")` in production config → `high`
- PII in logs → `high`
- Missing `@Valid` on DTO → `medium`

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/analysis/security-report.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "Critical and high findings must be resolved before failure-chaos-agent."
}
```

---

## Definition of Ready

- API endpoints or data flows available from `implementation-spec.json` or description
- Auth mechanism known

---

## Definition of Done

- `security-report.json` written with all 10 OWASP categories assessed
- All hardcoded secrets identified
- Input validation gaps listed
- All critical/high findings have 3-option remediation
