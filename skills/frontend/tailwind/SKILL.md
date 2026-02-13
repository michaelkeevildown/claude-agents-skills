---
name: tailwind
description: Tailwind CSS v4 — utility-first patterns, responsive design, custom themes, and component styling conventions.
---

# Tailwind CSS

## When to Use

**shadcn/ui is the primary component framework.** This skill covers the Tailwind CSS utility system that powers shadcn components — use it for layout, responsive design, spacing, theming, and custom styling beyond what shadcn provides out of the box.

Use this skill for:

- Page layout (flex, grid, positioning, spacing)
- Responsive design (breakpoints, container queries)
- Theming and design tokens (`@theme` directive, CSS variables)
- Customizing shadcn/ui components with utility overrides
- Animation and transitions
- State-based styling (hover, focus, disabled)

Defer to the **shadcn-ui skill** for: component selection, composition patterns (Dialog, Sheet, Command), form integration (react-hook-form + zod), and accessibility.

## Setup (v4)

Tailwind v4 uses CSS-first configuration. No `tailwind.config.js` needed.

### Import

```css
/* globals.css */
@import "tailwindcss";
```

This single import replaces the v3 directives (`@tailwind base`, `@tailwind components`, `@tailwind utilities`). Template files are auto-discovered — no content paths required.

### Installation

```bash
# Next.js / Vite (PostCSS)
npm install tailwindcss @tailwindcss/postcss

# Vite plugin (alternative)
npm install tailwindcss @tailwindcss/vite
```

PostCSS config:

```js
// postcss.config.mjs
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

Vite plugin (if not using PostCSS):

```js
// vite.config.ts
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
  plugins: [tailwindcss()],
});
```

**Important:** Sass and Less are incompatible with Tailwind v4. Use plain CSS with `@theme` and `@layer` directives.

## Theming with @theme

The `@theme` directive defines design tokens in CSS. Each token creates both a utility class and a CSS variable.

### Defining Tokens

```css
@import "tailwindcss";

@theme {
  --font-display: "Satoshi", sans-serif;
  --color-brand: oklch(0.72 0.18 50);
  --color-brand-light: oklch(0.92 0.05 50);
  --radius-lg: 0.75rem;
  --breakpoint-3xl: 120rem;
}
```

This generates:

- `font-display` utility class
- `bg-brand`, `text-brand` color utilities
- `rounded-lg` using the custom radius
- `3xl:` responsive breakpoint
- CSS variables: `var(--font-display)`, `var(--color-brand)`, etc.

### Overriding vs Extending Defaults

```css
/* Extend — adds to existing colors */
@theme {
  --color-brand: oklch(0.72 0.18 50);
}

/* Override — replaces ALL colors */
@theme {
  --color-*: initial;
  --color-brand: oklch(0.72 0.18 50);
  --color-white: #fff;
  --color-black: #000;
}
```

Use `--color-*: initial` (namespace wildcard) to clear defaults before defining your own.

### Aligning with shadcn/ui Tokens

shadcn/ui defines semantic tokens in `:root` and `.dark` (see shadcn-ui skill for full setup). Tailwind's `@theme` can reference these:

```css
@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-primary: var(--primary);
  --color-primary-foreground: var(--primary-foreground);
  --color-muted: var(--muted);
  --color-muted-foreground: var(--muted-foreground);
  --color-destructive: var(--destructive);
  --color-border: var(--border);
  --color-ring: var(--ring);
  --radius-sm: calc(var(--radius) - 4px);
  --radius-md: calc(var(--radius) - 2px);
  --radius-lg: var(--radius);
}
```

The `inline` keyword tells Tailwind not to emit the variables (shadcn already defines them in `:root`).

## Utility-First Patterns

### Core Principle

Style by composing utility classes directly in markup:

```tsx
<div className="flex items-center gap-3 rounded-lg border p-4">
  <Avatar className="h-10 w-10" />
  <div>
    <p className="text-sm font-medium">Jane Doe</p>
    <p className="text-xs text-muted-foreground">jane@example.com</p>
  </div>
</div>
```

### Spacing

```
p-4       → padding: 1rem (all sides)
px-6      → padding-left + padding-right: 1.5rem
py-2      → padding-top + padding-bottom: 0.5rem
m-auto    → margin: auto
mt-8      → margin-top: 2rem
gap-4     → gap: 1rem (flex/grid)
space-y-4 → vertical spacing between children (margin-based)
```

### Typography

```
text-sm           → 0.875rem / 1.25rem
text-lg           → 1.125rem / 1.75rem
font-semibold     → font-weight: 600
tracking-tight    → letter-spacing: -0.025em
leading-relaxed   → line-height: 1.625
truncate          → overflow hidden + text-overflow ellipsis + whitespace nowrap
line-clamp-3      → clamp to 3 lines
```

### Arbitrary Values

Use brackets for one-off values not in the theme:

```tsx
<div className="w-[calc(100%-2rem)] top-[117px] grid-cols-[1fr_2fr_1fr]">
```

Use underscores for spaces in arbitrary values: `grid-cols-[1fr_2fr_1fr]`.

Prefer theme tokens (`w-96`, `gap-4`) over arbitrary values. Only use brackets when the design truly requires a one-off value not in your design system.

### State Variants

```tsx
<button className="bg-primary hover:bg-primary/90 focus-visible:ring-2 focus-visible:ring-ring disabled:opacity-50 disabled:pointer-events-none">
  Save
</button>
```

Common variants: `hover:`, `focus:`, `focus-visible:`, `active:`, `disabled:`, `aria-selected:`, `data-[state=open]:`.

### Group and Peer Modifiers

```tsx
{/* Parent hover affects children */}
<div className="group rounded-lg border p-4 hover:border-primary">
  <h3 className="font-medium group-hover:text-primary">Title</h3>
  <p className="text-muted-foreground group-hover:text-foreground">Description</p>
</div>

{/* Peer state affects siblings */}
<input className="peer" type="email" />
<p className="hidden text-sm text-destructive peer-invalid:block">
  Invalid email
</p>
```

### @apply (Use Sparingly)

`@apply` extracts utilities into custom CSS classes. In v4, **variant modifiers (`hover:`, `md:`, `focus:`) cannot be used inside `@apply`** — use native CSS pseudo-classes and media queries instead, or prefer React components for stateful patterns.

```css
/* OK — simple atomic pattern */
@layer components {
  .prose-link {
    @apply text-primary underline underline-offset-4;
  }
}

/* Prefer a React component instead of @apply for anything with variants */
```

## Layout Patterns

### Flexbox

```tsx
{
  /* Horizontal bar with items centered, space between */
}
<div className="flex items-center justify-between gap-4">
  <Logo />
  <nav className="flex items-center gap-6">{/* links */}</nav>
  <UserMenu />
</div>;

{
  /* Vertical stack */
}
<div className="flex flex-col gap-4">
  <Card />
  <Card />
</div>;
```

### Grid

```tsx
{
  /* Equal-width columns */
}
<div className="grid grid-cols-3 gap-6">
  <Card />
  <Card />
  <Card />
</div>;

{
  /* Spanning columns */
}
<div className="grid grid-cols-4 gap-6">
  <div className="col-span-3">{/* Main */}</div>
  <div>{/* Sidebar */}</div>
</div>;

{
  /* Auto-fill responsive grid (no breakpoints needed) */
}
<div className="grid grid-cols-[repeat(auto-fill,minmax(280px,1fr))] gap-6">
  {items.map((item) => (
    <Card key={item.id} />
  ))}
</div>;
```

### Common Recipes

**Sticky header + scrollable content:**

```tsx
<div className="flex h-screen flex-col">
  <header className="sticky top-0 z-10 border-b bg-background px-6 py-3">
    {/* Header */}
  </header>
  <main className="flex-1 overflow-y-auto p-6">{/* Scrollable content */}</main>
</div>
```

**Sidebar layout:**

```tsx
<div className="flex h-screen">
  <aside className="w-64 shrink-0 border-r bg-muted/40 p-4">
    {/* Sidebar */}
  </aside>
  <main className="flex-1 overflow-y-auto p-6">{/* Content */}</main>
</div>
```

**Centered content (both axes):**

```tsx
<div className="flex min-h-screen items-center justify-center">
  <Card className="w-full max-w-md">{/* Centered card */}</Card>
</div>
```

## Responsive Design

### Mobile-First Breakpoints

Unprefixed utilities apply to **all screen sizes**. Prefixed utilities apply at that breakpoint **and above**.

| Prefix | Min-width | Target                  |
| ------ | --------- | ----------------------- |
| (none) | 0px       | All sizes (mobile base) |
| `sm:`  | 640px     | Large phones            |
| `md:`  | 768px     | Tablets                 |
| `lg:`  | 1024px    | Laptops                 |
| `xl:`  | 1280px    | Desktops                |
| `2xl:` | 1536px    | Large desktops          |

### Responsive Stacking to Grid

```tsx
{
  /* Single column on mobile, 2 cols on tablet, 3 cols on desktop */
}
<div className="grid grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
  <Card />
  <Card />
  <Card />
</div>;
```

### Responsive Typography

```tsx
<h1 className="text-2xl font-bold md:text-3xl lg:text-4xl">Dashboard</h1>
```

### Responsive Spacing

```tsx
<section className="px-4 py-8 md:px-8 md:py-12 lg:px-16 lg:py-16">
  {/* Content with increasing padding on larger screens */}
</section>
```

### Show/Hide by Breakpoint

```tsx
{
  /* Mobile navigation toggle — hidden on desktop */
}
<Button className="md:hidden" variant="ghost" size="icon">
  <Menu className="h-5 w-5" />
</Button>;

{
  /* Desktop sidebar — hidden on mobile */
}
<aside className="hidden md:block w-64">{/* Sidebar */}</aside>;
```

### Container Queries

Container queries respond to a parent container's size instead of the viewport:

```tsx
{
  /* Define container */
}
<div className="@container">
  {/* Respond to container size */}
  <div className="flex flex-col @md:flex-row @md:items-center gap-4">
    <Avatar />
    <div>
      <p className="text-sm @lg:text-base">Name</p>
    </div>
  </div>
</div>;
```

Container breakpoints: `@sm` (320px), `@md` (448px), `@lg` (512px), `@xl` (576px), etc.

### Custom Breakpoints

```css
@theme {
  --breakpoint-3xl: 120rem;
  --breakpoint-xs: 480px;
}
```

## Dark Mode

### With shadcn/ui (Preferred Approach)

When using shadcn/ui, dark mode is handled by CSS variables. The `:root` and `.dark` selectors define token values, and utilities like `bg-background`, `text-foreground`, `border-border` automatically switch. **No `dark:` prefix needed for themed elements.**

```tsx
{
  /* These auto-switch between light/dark — no dark: prefix */
}
<div className="bg-background text-foreground border-border">
  <p className="text-muted-foreground">Auto-themed content</p>
</div>;
```

See the shadcn-ui skill for `next-themes` setup and theme toggle implementation.

### dark: Variant (For Non-Themed Values)

Use `dark:` only when you need behavior outside the shadcn token system:

```tsx
{
  /* Custom illustration that needs different treatment in dark mode */
}
<div className="bg-blue-50 dark:bg-blue-950">
  <img className="opacity-100 dark:opacity-80" src="/illustration.svg" />
</div>;
```

### Media Query Strategy

For system-only dark mode (no toggle), Tailwind uses `prefers-color-scheme` by default. The class-based strategy (required for `next-themes` toggle) is configured by shadcn's setup.

## Customizing shadcn Components with Tailwind

### Using cn() to Override Styles

shadcn components accept `className`. Use `cn()` (from `@/lib/utils`) to merge your utilities with the component's defaults:

```tsx
import { Button } from "@/components/ui/button";

{
  /* Full-width button with left-aligned text */
}
<Button className="w-full justify-start text-left font-normal">
  Select a date
</Button>;

{
  /* Card with custom max-width and shadow */
}
<Card className="max-w-lg shadow-lg">
  <CardContent>{/* ... */}</CardContent>
</Card>;
```

`cn()` handles class conflicts — your overrides win over component defaults (e.g., adding `justify-start` replaces the button's default `justify-center`).

### Adding Responsive Behavior

```tsx
{
  /* Dialog content that's full-width on mobile, constrained on desktop */
}
<DialogContent className="w-full max-w-full sm:max-w-lg">
  {/* ... */}
</DialogContent>;

{
  /* Sidebar that collapses on mobile */
}
<SheetContent side="left" className="w-[280px] sm:w-[350px]">
  {/* ... */}
</SheetContent>;
```

### When to Customize via Utilities vs Component Source

| Scenario                                | Approach                                  |
| --------------------------------------- | ----------------------------------------- |
| One-off sizing/spacing tweak            | `className` override                      |
| Consistent variant across the app       | Edit component source in `components/ui/` |
| New variant (e.g., `variant="warning"`) | Add to component's `cva()` variants       |
| Layout around component                 | Wrapper div with utilities                |

## Animation and Transitions

### Transitions

```tsx
{
  /* Smooth hover effect */
}
<div className="transition-colors duration-200 hover:bg-muted">
  {/* content */}
</div>;

{
  /* Transform on hover */
}
<div className="transition-transform duration-300 hover:scale-105">
  {/* content */}
</div>;

{
  /* Multiple properties */
}
<div className="transition-all duration-200 ease-in-out">{/* content */}</div>;
```

Common duration values: `duration-75`, `duration-100`, `duration-150`, `duration-200`, `duration-300`, `duration-500`.

### Built-in Animations

```tsx
<Loader2 className="h-4 w-4 animate-spin" />      {/* Spinning loader */}
<div className="animate-pulse">Loading...</div>      {/* Pulsing skeleton */}
<div className="animate-bounce">↓</div>              {/* Bouncing arrow */}
```

### tw-animate-css

The `tw-animate-css` package replaces the deprecated `tailwindcss-animate` plugin. It provides enter/exit animations used by shadcn/ui components (Dialog, Sheet, Popover, etc.).

```bash
npm install tw-animate-css
```

```css
/* globals.css */
@import "tailwindcss";
@import "tw-animate-css";
```

### Custom Keyframes

```css
/* globals.css */
@theme {
  --animate-fade-in: fade-in 0.3s ease-out;
  --animate-slide-up: slide-up 0.4s ease-out;
}

@keyframes fade-in {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes slide-up {
  from {
    transform: translateY(1rem);
    opacity: 0;
  }
  to {
    transform: translateY(0);
    opacity: 1;
  }
}
```

Usage: `<div className="animate-fade-in">`.

## Anti-Patterns

### 1. Dynamic Class Construction

```tsx
// BAD — Tailwind can't scan dynamically built class names
function Badge({ color }: { color: string }) {
  return <span className={`bg-${color}-500 text-${color}-50`}>...</span>;
}

// GOOD — use a static lookup map
const colorStyles = {
  red: "bg-red-500 text-red-50",
  blue: "bg-blue-500 text-blue-50",
  green: "bg-green-500 text-green-50",
} as const;

function Badge({ color }: { color: keyof typeof colorStyles }) {
  return <span className={colorStyles[color]}>...</span>;
}
```

Tailwind scans source files for complete class names at build time. String interpolation produces class names that don't exist in the source, so they won't be generated.

### 2. @apply Overuse

```css
/* BAD — reimplements what a React component does better */
.card {
  @apply flex flex-col gap-4 rounded-lg border bg-background p-6 shadow-sm;
}
.card-title {
  @apply text-lg font-semibold leading-none tracking-tight;
}

/* GOOD — use shadcn's <Card> component, or a custom React component */
```

`@apply` hides styles from the markup, makes them harder to override, and in v4, modifiers like `hover:` and responsive prefixes don't work on custom classes. Prefer React components for anything with variants or state.

### 3. Hardcoded Colors Instead of Theme Tokens

```tsx
// BAD — breaks dark mode, ignores theme
<div className="bg-white text-gray-900 border-gray-200">

// GOOD — uses semantic tokens (auto-switches in dark mode)
<div className="bg-background text-foreground border-border">
```

Always use semantic token classes (`bg-primary`, `text-muted-foreground`, `border-border`) instead of raw color values. The tokens are defined by shadcn's CSS variables and switch automatically between light/dark.

### 4. Redundant dark: With CSS Variables

```tsx
// BAD — unnecessary when using shadcn tokens
<div className="bg-background dark:bg-background text-foreground dark:text-foreground">

// ALSO BAD — fighting the token system
<div className="bg-white dark:bg-gray-900 text-black dark:text-white">

// GOOD — tokens handle light/dark automatically
<div className="bg-background text-foreground">
```

If you're using shadcn/ui's CSS variable system, `dark:` prefixes on themed properties are redundant. Only use `dark:` for values outside the token system.

### 5. Desktop-First Design

```tsx
// BAD — styles for large screens, then overrides for small
<div className="grid grid-cols-3 gap-8 sm:grid-cols-1 sm:gap-4">

// GOOD — mobile base, enhance for larger screens
<div className="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3 lg:gap-8">
```

Tailwind breakpoints are `min-width` (mobile-first). Start with mobile styles (no prefix), then add complexity at larger breakpoints.

### 6. Mixing Sass/Less with v4

```scss
// BAD — Sass is incompatible with Tailwind v4's Oxide engine
$primary: #3b82f6;
.button {
  background: $primary;
  @apply rounded-lg px-4 py-2;
}
```

```css
/* GOOD — use native CSS with @theme */
@theme {
  --color-primary: oklch(0.62 0.21 255);
}
```

Tailwind v4 processes CSS natively through its Rust-based engine. Sass/Less syntax causes build failures.

### 7. Overly Long Class Strings Without Extraction

```tsx
// BAD — same pattern repeated in 5 places
<div className="flex items-center gap-3 rounded-lg border bg-card p-4 shadow-sm transition-colors hover:bg-accent">
  ...
</div>;
{
  /* ...repeated 4 more times */
}

// GOOD — extract to a component
function ListItem({ children, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      className={cn(
        "flex items-center gap-3 rounded-lg border bg-card p-4 shadow-sm transition-colors hover:bg-accent",
        props.className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}
```

If a utility combination repeats more than twice, extract it to a React component. Always forward `className` via `cn()` so consumers can override styles.
