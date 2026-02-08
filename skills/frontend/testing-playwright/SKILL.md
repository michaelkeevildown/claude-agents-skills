---
name: testing-playwright
description: Playwright end-to-end testing — locator strategy, page objects, fixtures, auth via setup projects, ARIA snapshots, Clock API, visual regression, and CI integration.
---

# Playwright Testing

## When to Use

Use this skill when writing, reviewing, or debugging Playwright end-to-end tests. Covers locator strategy, test patterns, fixtures, authentication, waiting, accessibility snapshots, time manipulation, visual regression, network interception, CI integration, and flaky test prevention.

Targets Playwright v1.49+ (ARIA snapshots, Clock API, setup projects). Check version with `npx playwright --version`.

## Project Structure

```
tests/
  e2e/
    auth.setup.ts             # Auth setup project
    auth.spec.ts              # Test files use .spec.ts
    dashboard.spec.ts
    checkout.spec.ts
  fixtures/
    auth.fixture.ts           # Custom fixtures
    db.fixture.ts
  pages/
    login.page.ts             # Page object models
    dashboard.page.ts
    checkout.page.ts
  helpers/
    test-data.ts              # Test data factories
    api-helpers.ts            # Direct API calls for setup
  .auth/                      # Stored auth state (gitignored)
    admin.json
playwright.config.ts          # Configuration
```

### Configuration

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { open: 'never' }],
    ['list'],
  ],
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
  },

  // v1.52+: fail CI if tests only pass on retry (flaky)
  failOnFlakyTests: !!process.env.CI,
  // v1.50+: only regenerate snapshots that actually changed
  updateSnapshots: 'changed',

  projects: [
    // Auth setup runs first — produces storageState files
    { name: 'setup', testMatch: /.*\.setup\.ts/ },

    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        storageState: 'tests/.auth/admin.json',
      },
      dependencies: ['setup'],
    },
    {
      name: 'firefox',
      use: {
        ...devices['Desktop Firefox'],
        storageState: 'tests/.auth/admin.json',
      },
      dependencies: ['setup'],
    },
    {
      name: 'mobile',
      use: { ...devices['Pixel 5'] },
      dependencies: ['setup'],
    },
  ],

  webServer: {
    command: 'npm run dev',
    port: 3000,
    reuseExistingServer: !process.env.CI,
  },
})
```

## Selector Strategy

### Priority Order (Official Recommendation)

1. **`getByRole()`** — best: mirrors how users and assistive tech see the page
2. **`getByLabel()`** — form fields associated with a label
3. **`getByText()`** — visible text content
4. **`getByPlaceholder()`**, **`getByAltText()`**, **`getByTitle()`** — secondary semantic locators
5. **`getByTestId()`** — fallback when no semantic locator works
6. **CSS / XPath** — last resort only

### Selector Examples

```typescript
// 1. Role selectors (preferred — reflects user-facing semantics)
page.getByRole('button', { name: 'Submit' })
page.getByRole('heading', { name: 'Dashboard' })
page.getByRole('link', { name: 'Settings' })
page.getByRole('textbox', { name: 'Email' })
page.getByRole('dialog')

// 2. Label (form fields)
page.getByLabel('Email address')

// 3. Text
page.getByText('Welcome back')

// 4. Secondary semantic locators
page.getByPlaceholder('Enter your email')
page.getByAltText('Company logo')

// 5. Test ID (fallback)
page.getByTestId('submit-button')

// 6. CSS (avoid unless necessary)
page.locator('.nav-menu >> li:first-child')
```

### Locator Combinators

```typescript
// Match either locator with .or()
const saveBtn = page.getByRole('button', { name: 'Save' })
const submitBtn = page.getByRole('button', { name: 'Submit' })
await saveBtn.or(submitBtn).click()

// Combine conditions with .and()
const enabledDialog = page.getByRole('dialog').and(page.locator(':visible'))

// Exclude elements with .filter({ hasNot })
const activeRows = page.getByRole('row').filter({
  hasNot: page.getByText('Archived'),
})

// Chain and filter for complex UIs
await page
  .getByRole('listitem')
  .filter({ hasText: 'Product 2' })
  .getByRole('button', { name: 'Add to cart' })
  .click()
```

### Selector Anti-Patterns

```typescript
// BAD: fragile, tied to implementation
page.locator('#root > div > div:nth-child(2) > button')
page.locator('.css-1a2b3c')  // generated class names
page.locator('button.MuiButton-root')  // library internals

// GOOD: stable, semantic
page.getByRole('button', { name: 'Checkout' })
page.getByTestId('checkout-button')
```

## Test Patterns

### Arrange / Act / Assert

```typescript
import { test, expect } from '@playwright/test'

test('user can submit feedback form', async ({ page }) => {
  // Arrange
  await page.goto('/feedback')

  // Act
  await page.getByLabel('Message').fill('Great product!')
  await page.getByRole('button', { name: 'Submit' }).click()

  // Assert
  await expect(page.getByText('Thank you for your feedback')).toBeVisible()
})
```

### Page Object Model

```typescript
// tests/pages/login.page.ts
import { type Page, type Locator } from '@playwright/test'

export class LoginPage {
  readonly page: Page
  readonly emailInput: Locator
  readonly passwordInput: Locator
  readonly submitButton: Locator
  readonly errorMessage: Locator

  constructor(page: Page) {
    this.page = page
    this.emailInput = page.getByLabel('Email')
    this.passwordInput = page.getByLabel('Password')
    this.submitButton = page.getByRole('button', { name: 'Sign in' })
    this.errorMessage = page.getByTestId('login-error')
  }

  async goto() {
    await this.page.goto('/login')
  }

  async login(email: string, password: string) {
    await this.emailInput.fill(email)
    await this.passwordInput.fill(password)
    await this.submitButton.click()
  }
}

// tests/e2e/auth.spec.ts
import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/login.page'

test('successful login redirects to dashboard', async ({ page }) => {
  const loginPage = new LoginPage(page)
  await loginPage.goto()
  await loginPage.login('user@example.com', 'password123')
  await expect(page).toHaveURL('/dashboard')
})

test('invalid credentials show error', async ({ page }) => {
  const loginPage = new LoginPage(page)
  await loginPage.goto()
  await loginPage.login('user@example.com', 'wrong')
  await expect(loginPage.errorMessage).toBeVisible()
  await expect(loginPage.errorMessage).toContainText('Invalid credentials')
})
```

### Custom Fixtures

```typescript
// tests/fixtures/auth.fixture.ts
import { test as base, type Page } from '@playwright/test'
import { LoginPage } from '../pages/login.page'

type AuthFixtures = {
  loginPage: LoginPage
  authenticatedPage: Page
}

export const test = base.extend<AuthFixtures>({
  loginPage: async ({ page }, use) => {
    const loginPage = new LoginPage(page)
    await loginPage.goto()
    await use(loginPage)
  },

  authenticatedPage: async ({ page }, use) => {
    await page.goto('/login')
    await page.getByLabel('Email').fill('test@example.com')
    await page.getByLabel('Password').fill('password123')
    await page.getByRole('button', { name: 'Sign in' }).click()
    await page.waitForURL('/dashboard')
    await use(page)
  },
})

export { expect } from '@playwright/test'
```

### Test Isolation

Each test should be independent. Use API calls for setup instead of UI flows:

```typescript
// BAD: test depends on previous test creating data
test('edit user', async ({ page }) => {
  // assumes "create user" test ran first
  await page.goto('/users')
  // ...
})

// GOOD: each test sets up its own data
test('edit user', async ({ page, request }) => {
  // Create user via API
  const response = await request.post('/api/users', {
    data: { name: 'Test User', email: 'test@example.com' },
  })
  const user = await response.json()

  await page.goto(`/users/${user.id}/edit`)
  await page.getByLabel('Name').fill('Updated Name')
  await page.getByRole('button', { name: 'Save' }).click()
  await expect(page.getByText('Updated Name')).toBeVisible()
})
```

### Authentication via Setup Projects

Use setup projects with `dependencies` instead of `globalSetup` — they integrate with traces, HTML reports, and the test runner:

```typescript
// tests/e2e/auth.setup.ts
import { test as setup, expect } from '@playwright/test'

const authFile = 'tests/.auth/admin.json'

setup('authenticate', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill('admin@example.com')
  await page.getByLabel('Password').fill('admin123')
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.waitForURL('/dashboard')
  await page.context().storageState({ path: authFile })
})

// In playwright.config.ts — projects reference this (see Configuration):
// { name: 'setup', testMatch: /.*\.setup\.ts/ }
// { name: 'chromium', dependencies: ['setup'],
//   use: { storageState: 'tests/.auth/admin.json' } }
```

For API-based auth (faster when a login endpoint exists):

```typescript
setup('authenticate via API', async ({ request }) => {
  await request.post('/api/auth/login', {
    data: { email: 'admin@example.com', password: 'admin123' },
  })
  await request.storageState({ path: authFile })
})
```

### Tag-Based Filtering

```typescript
// Tag individual tests (v1.42+)
test('checkout flow', { tag: ['@smoke', '@checkout'] }, async ({ page }) => {
  // ...
})

// Tag groups
test.describe('payment flow', { tag: '@payment' }, () => {
  test('credit card', async ({ page }) => { /* ... */ })
  test('PayPal', async ({ page }) => { /* ... */ })
})
```

```bash
# Run from CLI
npx playwright test --grep @smoke
npx playwright test --grep-invert @slow
```

### Soft Assertions

```typescript
// Collect multiple failures instead of stopping at the first
test('form validation shows all errors', async ({ page }) => {
  await page.goto('/register')
  await page.getByRole('button', { name: 'Submit' }).click()

  await expect.soft(page.getByText('Name is required')).toBeVisible()
  await expect.soft(page.getByText('Email is required')).toBeVisible()
  await expect.soft(page.getByText('Password is required')).toBeVisible()
  // Test reports all failures, not just the first
})
```

## Accessibility Testing

### ARIA Snapshots (v1.49+)

Compare the accessibility tree structure rather than pixels — more resilient to styling changes:

```typescript
test('navigation has correct structure', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('navigation')).toMatchAriaSnapshot(`
    - navigation:
      - link "Home"
      - link "Products"
      - link "About"
      - link "Contact"
  `)
})

// Partial matching with regex for dynamic content
test('user menu shows name', async ({ page }) => {
  await expect(page.getByRole('menu')).toMatchAriaSnapshot(`
    - menu:
      - menuitem /Hello, .+/
      - menuitem "Settings"
      - menuitem "Sign out"
  `)
})
```

Update snapshots: `npx playwright test --update-snapshots`

### Accessibility Assertions (v1.44+)

```typescript
await expect(page.getByTestId('submit')).toHaveRole('button')
await expect(page.getByRole('textbox')).toHaveAccessibleName('Email address')
await expect(page.getByRole('textbox')).toHaveAccessibleDescription(
  'We will never share your email'
)
// v1.50+
await expect(page.getByRole('textbox')).toHaveAccessibleErrorMessage('Email is required')
```

## Time Manipulation (Clock API)

Control time in tests without depending on real timers (v1.45+):

```typescript
// Fix time to a specific moment
test('shows greeting based on time of day', async ({ page }) => {
  await page.clock.setFixedTime(new Date('2025-12-25T08:00:00'))
  await page.goto('/')
  await expect(page.getByText('Good morning')).toBeVisible()
})

// Install fake timers and advance
test('session timeout warning', async ({ page }) => {
  await page.clock.install({ time: new Date('2025-01-01T00:00:00') })
  await page.goto('/dashboard')

  await page.clock.fastForward('29:00')  // 29 minutes
  await expect(page.getByText('Session expiring')).not.toBeVisible()

  await page.clock.fastForward('01:30')  // 30:30 total
  await expect(page.getByText('Session expiring')).toBeVisible()
})
```

Overrides: `Date`, `setTimeout`, `setInterval`, `requestAnimationFrame`, `performance`.

## Waiting Strategies

### Auto-Wait (Default)

Playwright auto-waits for elements to be actionable before interacting:

```typescript
// Playwright automatically waits for:
// - element to be visible
// - element to be stable (no animations)
// - element to be enabled
// - element to receive events
await page.getByRole('button', { name: 'Submit' }).click()
```

### Assertions with Auto-Retry

`expect` with web-first assertions auto-retries until timeout:

```typescript
// These auto-retry until condition is met or timeout
await expect(page.getByText('Success')).toBeVisible()
await expect(page.getByTestId('count')).toHaveText('5')
await expect(page).toHaveURL('/dashboard')
await expect(page).toHaveTitle('Dashboard')

// Negate assertions also auto-retry
await expect(page.getByTestId('spinner')).not.toBeVisible()
```

### Explicit Waits (When Needed)

```typescript
// Wait for a specific network response
const responsePromise = page.waitForResponse('**/api/users')
await page.getByRole('button', { name: 'Load' }).click()
const response = await responsePromise

// Wait for navigation (sequential — Playwright handles auto-waiting)
await page.getByRole('button', { name: 'Submit' }).click()
await page.waitForURL('/dashboard')

// Wait for network idle (use sparingly)
await page.waitForLoadState('networkidle')
```

### Overlay / Popup Handling (v1.42+)

Auto-dismiss overlays that appear unpredictably during tests:

```typescript
// Register once — handler runs whenever overlay appears
await page.addLocatorHandler(
  page.getByRole('dialog', { name: 'Cookie consent' }),
  async (dialog) => {
    await dialog.getByRole('button', { name: 'Accept' }).click()
  }
)
// All subsequent actions auto-dismiss the cookie dialog if it appears
```

### Waiting Anti-Patterns

```typescript
// BAD: arbitrary sleep
await page.waitForTimeout(3000)

// BAD: polling for element
while (!(await page.getByText('Ready').isVisible())) {
  await page.waitForTimeout(100)
}

// GOOD: auto-retrying assertion
await expect(page.getByText('Ready')).toBeVisible({ timeout: 10000 })

// GOOD: wait for specific condition
await page.waitForResponse(resp =>
  resp.url().includes('/api/data') && resp.status() === 200
)
```

## Visual Regression

### Screenshot Comparison

```typescript
test('homepage matches snapshot', async ({ page }) => {
  await page.goto('/')
  await expect(page).toHaveScreenshot('homepage.png')
})

// Element screenshot
test('sidebar matches snapshot', async ({ page }) => {
  await page.goto('/dashboard')
  const sidebar = page.getByTestId('sidebar')
  await expect(sidebar).toHaveScreenshot('sidebar.png')
})
```

### Configuration

```typescript
// playwright.config.ts
export default defineConfig({
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,  // Allow 1% pixel difference
      threshold: 0.2,           // Per-pixel color threshold
      animations: 'disabled',   // Disable CSS animations for consistency
    },
  },
  // v1.50+: only regenerate changed snapshots
  updateSnapshots: 'changed',
})
```

### Best Practices for Visual Tests

```typescript
// Hide dynamic content before screenshot
test('dashboard layout', async ({ page }) => {
  await page.goto('/dashboard')

  // Mask dynamic elements
  await expect(page).toHaveScreenshot('dashboard.png', {
    mask: [
      page.getByTestId('timestamp'),
      page.getByTestId('random-avatar'),
    ],
  })
})

// Use consistent viewport
test.use({ viewport: { width: 1280, height: 720 } })
```

## Network Interception

### Route-Based Mocking

```typescript
// Mock API with json shorthand
test('shows error on API failure', async ({ page }) => {
  await page.route('**/api/users', route =>
    route.fulfill({ status: 500, json: { error: 'Internal Server Error' } })
  )

  await page.goto('/users')
  await expect(page.getByText('Failed to load users')).toBeVisible()
})

// Mock empty state
test('shows empty state', async ({ page }) => {
  await page.route('**/api/users', route =>
    route.fulfill({ status: 200, json: [] })
  )

  await page.goto('/users')
  await expect(page.getByText('No users found')).toBeVisible()
})

// Intercept and modify real responses
test('injects extra item', async ({ page }) => {
  await page.route('**/api/products', async route => {
    const response = await route.fetch()
    const json = await response.json()
    json.push({ id: 999, name: 'Injected Product' })
    await route.fulfill({ json })
  })

  await page.goto('/products')
  await expect(page.getByText('Injected Product')).toBeVisible()
})
```

Register routes **before** `page.goto()` to intercept early requests.

### WebSocket Interception (v1.48+)

```typescript
// Full WebSocket mock (no server connection)
test('receives live updates', async ({ page }) => {
  await page.routeWebSocket('wss://example.com/ws', ws => {
    ws.onMessage(message => {
      if (message === 'ping') ws.send('pong')
    })
  })

  await page.goto('/live-dashboard')
  await expect(page.getByTestId('status')).toHaveText('Connected')
})

// Intercept and modify messages between page and server
await page.routeWebSocket('wss://example.com/ws', ws => {
  const server = ws.connectToServer()
  ws.onMessage(message => server.send(message))         // forward to server
  server.onMessage(message => ws.send(message))          // forward to page
})
```

## CI Integration

### GitHub Actions

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on: [push, pull_request]
jobs:
  e2e:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        shard: [1/4, 2/4, 3/4, 4/4]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci
      # Install only the browsers you need
      - run: npx playwright install --with-deps chromium
      - run: npx playwright test --shard=${{ matrix.shard }}
      - uses: actions/upload-artifact@v4
        if: ${{ !cancelled() }}
        with:
          name: playwright-report-${{ matrix.shard }}
          path: playwright-report/
          retention-days: 7
```

### Configuration for CI

```typescript
// Key CI settings in playwright.config.ts
export default defineConfig({
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  forbidOnly: !!process.env.CI,
  failOnFlakyTests: !!process.env.CI,
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'on-first-retry',
  },
})
```

### Useful CLI Options

```bash
# Re-run only tests that failed in the last run (v1.44+)
npx playwright test --last-failed

# Run only tests in files changed since last commit (v1.46+)
npx playwright test --only-changed

# Update only changed snapshots (v1.50+)
npx playwright test --update-snapshots
```

### Trace Viewer

When a test fails in CI, download the trace and inspect:

```bash
npx playwright show-trace trace.zip
```

Traces include:
- Step-by-step screenshots
- DOM snapshots at each action
- Network requests
- Console logs

## Common Pitfalls

### Flaky Test Prevention

```typescript
// 1. Don't rely on timing
// BAD
await page.getByTestId('button').click()
await page.waitForTimeout(1000)
expect(await page.textContent('#result')).toBe('Done')

// GOOD
await page.getByTestId('button').click()
await expect(page.getByTestId('result')).toHaveText('Done')

// 2. Don't depend on test order
// BAD: shared state between tests
let userId: string
test('create user', async ({ page }) => {
  // ... creates user
  userId = '123'
})
test('delete user', async ({ page }) => {
  // uses userId from previous test
})

// GOOD: each test is self-contained
test('delete user', async ({ page, request }) => {
  const user = await request.post('/api/users', { data: { name: 'temp' } })
  // ... delete the user
})

// 3. Don't use exact text matching for dynamic content
// BAD
await expect(page.getByText('Created 2 seconds ago')).toBeVisible()

// GOOD
await expect(page.getByText(/Created \d+ \w+ ago/)).toBeVisible()
```

### Test Data Management

```typescript
// Use factories for consistent test data
function createTestUser(overrides = {}) {
  return {
    name: `Test User ${Date.now()}`,
    email: `test-${Date.now()}@example.com`,
    ...overrides,
  }
}

// Clean up after tests
test.afterEach(async ({ request }) => {
  await request.delete('/api/test/cleanup')
})
```

### Deprecated APIs

```typescript
// BAD: page.type() is deprecated
await page.type('#email', 'user@example.com')

// GOOD: use fill() or pressSequentially()
await page.getByLabel('Email').fill('user@example.com')
await page.getByLabel('Search').pressSequentially('query', { delay: 50 })

// REMOVED in v1.57: page.accessibility — use ARIA snapshots instead
// REMOVED in v1.58: _react and _vue selectors — use getByRole/getByTestId
```

## Anti-Patterns

### 1. Testing Implementation Details

```typescript
// BAD: tests CSS class, not behavior
expect(await button.getAttribute('class')).toContain('btn-primary')

// GOOD: tests what user sees
await expect(button).toBeVisible()
await expect(button).toBeEnabled()

// If you must check a class (rare), use the dedicated assertion (v1.52+):
await expect(button).toContainClass('btn-primary')
```

### 2. Over-Specifying Assertions

```typescript
// BAD: brittle, breaks on any text change
await expect(page.getByTestId('message')).toHaveText(
  'Successfully created user John Doe with ID 12345 at 2024-01-15T10:30:00Z'
)

// GOOD: assert on the meaningful part
await expect(page.getByTestId('message')).toContainText('Successfully created')
```

### 3. Not Using Test Hooks for Setup

```typescript
// BAD: repeating setup in every test
test('test 1', async ({ page }) => {
  await page.goto('/login')
  await page.getByLabel('Email').fill('admin@test.com')
  await page.getByLabel('Password').fill('password')
  await page.getByRole('button', { name: 'Sign in' }).click()
  // ... actual test
})

// GOOD: use beforeEach or fixtures
test.beforeEach(async ({ page }) => {
  await page.goto('/dashboard')
})
```

### 4. Not Waiting for Page State

```typescript
// BAD: navigates and immediately asserts
await page.goto('/dashboard')
const count = await page.textContent('#count')

// GOOD: wait for the page to be ready
await page.goto('/dashboard')
await expect(page.getByTestId('count')).toBeVisible()
const count = await page.getByTestId('count').textContent()
```

### 5. Using Promise.all for Navigation

```typescript
// BAD: unnecessary — Playwright auto-waits for navigation
await Promise.all([
  page.waitForURL('/dashboard'),
  page.getByRole('button', { name: 'Submit' }).click(),
])

// GOOD: sequential is fine — Playwright handles the race
await page.getByRole('button', { name: 'Submit' }).click()
await page.waitForURL('/dashboard')
```

### 6. Not Handling Random Overlays

```typescript
// BAD: test fails when cookie banner appears unpredictably
await page.getByRole('button', { name: 'Checkout' }).click()

// GOOD: register a handler once, auto-dismiss overlays (v1.42+)
await page.addLocatorHandler(
  page.getByRole('dialog', { name: 'Cookie consent' }),
  async (d) => d.getByRole('button', { name: 'Accept' }).click()
)
```
