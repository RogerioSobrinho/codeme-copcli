---
name: angular-security
description: >
  Load when implementing Angular auth guards (CanActivateFn, CanMatchFn), JWT token
  interceptors, token refresh logic, protecting routes by role or permission, sanitizing
  dynamic HTML with DomSanitizer, preventing XSS in templates, configuring CSRF protection,
  handling Angular CSP (Content Security Policy), or when asked "how do I protect this route",
  "is this Angular code XSS-safe", "how do I implement role-based access in Angular",
  "how do I store tokens safely on the client".
---

# Angular Security

## Authentication Guards

### Functional Guards (Angular 15+)

```typescript
// auth.guard.ts
export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (authService.isAuthenticated()) return true;

  // Preserve the intended URL for post-login redirect
  return router.createUrlTree(['/login'], {
    queryParams: { returnUrl: state.url }
  });
};

// Role guard — checks specific roles
export const roleGuard = (requiredRoles: string[]): CanActivateFn => {
  return () => {
    const authService = inject(AuthService);
    const router = inject(Router);

    if (requiredRoles.some(role => authService.hasRole(role))) return true;

    return router.createUrlTree(['/forbidden']);
  };
};

// Usage in routes
export const routes: Routes = [
  {
    path: 'admin',
    loadChildren: () => import('./features/admin/admin.routes'),
    canActivate: [authGuard, roleGuard(['ADMIN', 'SUPER_ADMIN'])]
  }
];
```

### CanMatch Guard (prevents module loading for unauthorized users)

```typescript
export const canMatchAdmin: CanMatchFn = () => {
  const authService = inject(AuthService);
  // CanMatch runs before lazy loading — unauthorized users never download admin bundle
  return authService.hasRole('ADMIN');
};
```

---

## JWT Token Interceptor

```typescript
export const jwtInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  
  // Don't add auth header to public endpoints
  if (isPublicEndpoint(req.url)) return next(req);
  
  const token = authService.getAccessToken();
  if (!token) return next(req);
  
  return next(req.clone({
    setHeaders: { Authorization: `Bearer ${token}` }
  }));
};

// Public endpoint check — prefer allowlist over blocklist
function isPublicEndpoint(url: string): boolean {
  const PUBLIC_ENDPOINTS = ['/api/auth/login', '/api/auth/register', '/api/auth/refresh'];
  return PUBLIC_ENDPOINTS.some(endpoint => url.includes(endpoint));
}
```

---

## Token Refresh Flow

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly storage = inject(TokenStorageService);
  
  private refreshTokenInProgress = false;
  private refreshSubject = new BehaviorSubject<string | null>(null);
  
  refreshToken(): Observable<string> {
    if (this.refreshTokenInProgress) {
      // Queue callers behind the in-progress refresh
      return this.refreshSubject.pipe(
        filter(token => token !== null),
        take(1),
        map(token => token!)
      );
    }
    
    this.refreshTokenInProgress = true;
    this.refreshSubject.next(null);
    
    return this.http.post<TokenResponse>('/api/auth/refresh', {
      refreshToken: this.storage.getRefreshToken()
    }).pipe(
      tap(response => {
        this.storage.setAccessToken(response.accessToken);
        this.refreshSubject.next(response.accessToken);
        this.refreshTokenInProgress = false;
      }),
      map(response => response.accessToken),
      catchError(error => {
        this.refreshTokenInProgress = false;
        this.logout();
        return throwError(() => error);
      })
    );
  }
}
```

---

## Token Storage

```typescript
@Injectable({ providedIn: 'root' })
export class TokenStorageService {
  // Use sessionStorage for access tokens (cleared on tab close)
  // Use localStorage ONLY if "remember me" is explicitly requested
  private readonly ACCESS_TOKEN_KEY = 'access_token';
  private readonly REFRESH_TOKEN_KEY = 'refresh_token';
  
  setAccessToken(token: string): void {
    sessionStorage.setItem(this.ACCESS_TOKEN_KEY, token);
  }
  
  getAccessToken(): string | null {
    return sessionStorage.getItem(this.ACCESS_TOKEN_KEY);
  }
  
  setRefreshToken(token: string): void {
    // Refresh tokens are longer-lived — localStorage acceptable here
    // Best practice: backend sets refresh token as HttpOnly cookie instead
    localStorage.setItem(this.REFRESH_TOKEN_KEY, token);
  }
  
  clear(): void {
    sessionStorage.removeItem(this.ACCESS_TOKEN_KEY);
    localStorage.removeItem(this.REFRESH_TOKEN_KEY);
  }
}
```

**Best practice for token storage:**
- Access token in `sessionStorage` (never survives tab close)
- Refresh token as `HttpOnly` cookie (server sets it — client JS cannot read it, preventing XSS theft)
- If `HttpOnly` cookie is not an option, `localStorage` for refresh token is acceptable but document the risk

---

## XSS Prevention

Angular's template engine escapes all interpolated values by default. XSS risk occurs only when bypassing this:

```typescript
// ❌ DANGEROUS — bypasses Angular's sanitization
@Component({
  template: `<div [innerHTML]="userContent"></div>` // Never with unsanitized user input
})

// ✅ SAFE — use DomSanitizer only for known-safe HTML
@Component({
  template: `<div [innerHTML]="safeContent"></div>`
})
export class RichTextComponent {
  private readonly sanitizer = inject(DomSanitizer);
  
  // Only call bypassSecurityTrustHtml for content you KNOW is safe
  // (e.g., from your own CMS, not from user input)
  readonly safeContent = this.sanitizer.bypassSecurityTrustHtml(this.markdownHtml);
}
```

**Never use `bypassSecurityTrust*` with user-generated content.** If you need to render rich text from users, use a sanitizing library (DOMPurify) before passing to Angular.

```typescript
import DOMPurify from 'dompurify';

// Sanitize user-provided HTML before rendering
readonly safeUserContent = this.sanitizer.bypassSecurityTrustHtml(
  DOMPurify.sanitize(this.userProvidedHtml)
);
```

---

## CSRF Protection

For Angular apps with cookie-based sessions (not JWT):

```typescript
// app.config.ts — Angular's built-in XSRF protection
export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(
      withXsrfConfiguration({
        cookieName: 'XSRF-TOKEN',      // Cookie name set by backend
        headerName: 'X-XSRF-TOKEN'    // Header Angular sends
      })
    )
  ]
};
```

Spring Boot backend configuration:
```java
// Spring Security CSRF token configuration
.csrf(csrf -> csrf
    .csrfTokenRepository(CookieCsrfTokenRepository.withHttpOnlyFalse())
)
```

For JWT-authenticated SPAs, CSRF is not required (no cookies carrying auth state).

---

## Content Security Policy

Configure CSP at the HTTP response level (not in Angular):

```
Content-Security-Policy:
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self' https://api.yourdomain.com;
  font-src 'self';
  frame-ancestors 'none';
```

**Angular-specific CSP notes:**
- Angular does not use `eval` — `script-src 'unsafe-eval'` is NOT required.
- If using Angular CDK overlays, `style-src 'unsafe-inline'` may be required (styles injected dynamically).
- Nonces are the recommended approach for Angular Universal (SSR) to avoid `'unsafe-inline'`.

---

## Security Checklist

| Risk | Angular mitigation |
|---|---|
| XSS via template | Angular escapes by default; only `bypassSecurityTrust*` introduces risk |
| XSS via `innerHTML` | Use `DomSanitizer` + DOMPurify for user content |
| Token theft via JS | Access token in `sessionStorage`; refresh token as `HttpOnly` cookie |
| CSRF | `withXsrfConfiguration` for cookie auth; not needed for JWT |
| Clickjacking | CSP `frame-ancestors 'none'` or `X-Frame-Options: DENY` |
| Sensitive data in URL | Never put tokens or PII in query params (logged by servers/proxies) |
| Route access control | `CanActivateFn` + `CanMatchFn` guards on all protected routes |
| Privilege escalation | Backend always re-checks permissions — frontend guards are UX, not security |
