# Security Guidelines

## Pre-Commit Checklist (Mandatory)

Before ANY commit:
- [ ] No hardcoded secrets (API keys, passwords, tokens)
- [ ] All user inputs validated at system boundaries
- [ ] SQL injection prevention (parameterized queries only)
- [ ] XSS prevention (sanitized output)
- [ ] CSRF protection enabled
- [ ] Authentication/authorization verified
- [ ] Rate limiting on public endpoints
- [ ] Error messages don't leak sensitive data (stack traces, paths, SQL)

## Secret Management

- NEVER hardcode secrets in source code
- ALWAYS use environment variables or a secret manager (Vault, AWS Secrets Manager)
- Validate that required secrets are present at startup — fail fast if missing
- Rotate any secrets that may have been exposed immediately

## OWASP Mindset

- **Injection:** Prevent SQL, NoSQL, command, and LDAP injection — parameterized queries only.
- **XSS:** Sanitize all user-supplied HTML. Never use `innerHTML` with untrusted input.
- **Broken Auth:** Use established auth libraries. Never roll custom crypto. Use bcrypt/Argon2 for passwords.
- **IDOR:** Enforce ownership checks at the service layer, not just at the route level.

## Data Scrubbing

- Mask PII (emails, tokens, IDs, CPF, phone numbers) in all log output.
- Never log passwords, tokens, credit card numbers, or any sensitive personal data.
- Apply `@JsonIgnore` (or equivalent) to sensitive fields before serialization.

## Error Messages to Clients

- Never expose stack traces, internal paths, SQL errors, or exception class names in API responses.
- Log detailed errors server-side.
- Return generic, user-safe messages to clients: `"Resource not found"`, `"Internal server error"`.

## Least Privilege

- Apply to all service accounts, IAM roles, and logic permissions.
- Database users should have only the permissions they need (no DBA role for app users).

## Security Response Protocol

If a security issue is found:
1. STOP immediately
2. Use the **secure** agent
3. Fix CRITICAL issues before continuing
4. Rotate any exposed secrets
5. Review the entire codebase for similar patterns
