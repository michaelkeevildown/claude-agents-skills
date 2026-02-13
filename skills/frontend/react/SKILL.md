---
name: react
description: React core patterns — components, hooks, TypeScript integration, state management, performance, and error handling.
---

# React

## When to Use

Use this skill for React component architecture, hooks, TypeScript integration, state management, performance optimization, and error handling.

Defer to other skills for:

- **shadcn-ui skill**: Component library APIs, form integration (react-hook-form + zod), theming
- **tailwind skill**: CSS utility patterns and styling conventions
- **testing-playwright skill**: E2E testing patterns

Targets React 19+ with TypeScript. React 18 differences noted where relevant.

## Component Patterns

### Functional Components with TypeScript

```tsx
// Props as a type alias (convention for component props)
type UserCardProps = {
  name: string;
  email: string;
  avatar?: string;
};

function UserCard({ name, email, avatar }: UserCardProps) {
  return (
    <div className="flex items-center gap-3">
      {avatar && <img src={avatar} alt={name} />}
      <div>
        <p className="font-medium">{name}</p>
        <p className="text-sm text-muted-foreground">{email}</p>
      </div>
    </div>
  );
}
```

### Extending HTML Element Props

```tsx
// Extend native element props to accept className, onClick, etc.
type ButtonProps = React.ComponentPropsWithoutRef<"button"> & {
  variant?: "primary" | "secondary";
};

function Button({
  variant = "primary",
  className,
  children,
  ...props
}: ButtonProps) {
  return (
    <button
      className={cn(
        variant === "primary" ? "bg-primary" : "bg-secondary",
        className,
      )}
      {...props}
    >
      {children}
    </button>
  );
}
```

### Extending Component Props

```tsx
// Extend another component's props
type CustomCardProps = React.ComponentProps<typeof Card> & {
  title: string;
};

function CustomCard({ title, className, ...props }: CustomCardProps) {
  return (
    <Card className={cn("p-6", className)} {...props}>
      <CardTitle>{title}</CardTitle>
    </Card>
  );
}
```

### Ref Forwarding

```tsx
// React 19: ref is a regular prop — no forwardRef needed
type InputProps = React.ComponentProps<"input"> & {
  label: string;
};

function LabeledInput({ label, ref, ...props }: InputProps) {
  return (
    <label>
      {label}
      <input ref={ref} {...props} />
    </label>
  );
}

// React 18: forwardRef required
type InputProps = React.ComponentPropsWithoutRef<"input"> & {
  label: string;
};

const LabeledInput = React.forwardRef<HTMLInputElement, InputProps>(
  ({ label, ...props }, ref) => {
    return (
      <label>
        {label}
        <input ref={ref} {...props} />
      </label>
    );
  },
);
```

### Composition over Configuration

```tsx
// BAD — mega-component with many props
<Card
  title="Settings"
  subtitle="Manage preferences"
  showFooter
  footerActions={[{ label: "Save" }, { label: "Cancel" }]}
  headerIcon={<Settings />}
/>

// GOOD — composable parts
<Card>
  <CardHeader>
    <Settings />
    <CardTitle>Settings</CardTitle>
    <CardDescription>Manage preferences</CardDescription>
  </CardHeader>
  <CardContent>{/* ... */}</CardContent>
  <CardFooter>
    <Button variant="outline">Cancel</Button>
    <Button>Save</Button>
  </CardFooter>
</Card>
```

### Compound Components

Share state between related components using Context:

```tsx
const TabsContext = React.createContext<{
  activeTab: string;
  setActiveTab: (tab: string) => void;
} | null>(null);

function useTabsContext() {
  const ctx = React.useContext(TabsContext);
  if (!ctx) throw new Error("Tab components must be used within <Tabs>");
  return ctx;
}

function Tabs({
  defaultTab,
  children,
}: {
  defaultTab: string;
  children: React.ReactNode;
}) {
  const [activeTab, setActiveTab] = React.useState(defaultTab);
  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      {children}
    </TabsContext.Provider>
  );
}

function TabTrigger({
  value,
  children,
}: {
  value: string;
  children: React.ReactNode;
}) {
  const { activeTab, setActiveTab } = useTabsContext();
  return (
    <button
      onClick={() => setActiveTab(value)}
      data-active={activeTab === value}
    >
      {children}
    </button>
  );
}

function TabContent({
  value,
  children,
}: {
  value: string;
  children: React.ReactNode;
}) {
  const { activeTab } = useTabsContext();
  return activeTab === value ? <>{children}</> : null;
}
```

### Discriminated Union Props

```tsx
// Component that renders an anchor OR a button, never both
type LinkButtonProps =
  | { href: string; onClick?: never; children: React.ReactNode }
  | { href?: never; onClick: () => void; children: React.ReactNode };

function LinkButton(props: LinkButtonProps) {
  if (props.href) {
    return <a href={props.href}>{props.children}</a>;
  }
  return <button onClick={props.onClick}>{props.children}</button>;
}
```

## Hooks

### useState

```tsx
// Type is inferred from initial value
const [count, setCount] = useState(0);

// Explicit type when initial value doesn't capture the full type
const [user, setUser] = useState<User | null>(null);

// Lazy initialization for expensive defaults
const [data, setData] = useState(() => parseExpensiveData(raw));

// Updater function to avoid stale closures
setCount((prev) => prev + 1);
```

### useEffect

```tsx
useEffect(() => {
  const controller = new AbortController();

  async function fetchData() {
    const res = await fetch(`/api/users/${id}`, { signal: controller.signal });
    const data = await res.json();
    setUser(data);
  }

  fetchData();

  // Cleanup: abort fetch if id changes or component unmounts
  return () => controller.abort();
}, [id]);
```

Effects run after paint. They are for synchronizing with external systems (network, DOM APIs, timers), not for deriving state from props.

### useRef

```tsx
// DOM ref
const inputRef = useRef<HTMLInputElement>(null);
const focusInput = () => inputRef.current?.focus();

// Mutable value ref (does not trigger re-render)
const timerRef = useRef<ReturnType<typeof setInterval>>(undefined);

useEffect(() => {
  timerRef.current = setInterval(() => tick(), 1000);
  return () => clearInterval(timerRef.current);
}, []);
```

### useMemo and useCallback

Only use these when:

1. Passing a value/callback to a `React.memo` child
2. The computation is genuinely expensive (filtering/sorting large arrays)
3. The value is a dependency of another hook

```tsx
// useMemo: memoize an expensive computation
const sortedItems = useMemo(
  () => items.sort((a, b) => a.name.localeCompare(b.name)),
  [items]
)

// useCallback: stable function reference for memoized children
const handleSelect = useCallback((id: string) => {
  setSelected(id)
}, [])

<MemoizedList items={sortedItems} onSelect={handleSelect} />
```

### useReducer

Prefer over useState when state transitions are complex or state values are related:

```tsx
type State = {
  status: "idle" | "loading" | "success" | "error";
  data: User[] | null;
  error: string | null;
};

type Action =
  | { type: "fetch" }
  | { type: "success"; data: User[] }
  | { type: "error"; error: string };

function reducer(state: State, action: Action): State {
  switch (action.type) {
    case "fetch":
      return { status: "loading", data: null, error: null };
    case "success":
      return { status: "success", data: action.data, error: null };
    case "error":
      return { status: "error", data: null, error: action.error };
  }
}

const [state, dispatch] = useReducer(reducer, {
  status: "idle",
  data: null,
  error: null,
});
```

### useContext

```tsx
// Typed context with a "use or throw" hook
type AuthContext = { user: User; logout: () => void };

const AuthContext = React.createContext<AuthContext | null>(null);

function useAuth() {
  const ctx = React.useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within <AuthProvider>");
  return ctx;
}

function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const logout = useCallback(() => setUser(null), []);
  if (!user) return <LoginScreen onLogin={setUser} />;
  return (
    <AuthContext.Provider value={{ user, logout }}>
      {children}
    </AuthContext.Provider>
  );
}
```

### React 19 Hooks

```tsx
// use() — read a promise or context (can be called conditionally)
function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise); // suspends until resolved
  return <p>{user.name}</p>;
}

// useActionState — form actions with pending state
function AddToCart({ itemId }: { itemId: string }) {
  const [state, formAction, isPending] = useActionState(
    async (prev: { error?: string }, formData: FormData) => {
      const result = await addToCart(itemId);
      return result.success ? {} : { error: result.message };
    },
    {},
  );
  return (
    <form action={formAction}>
      <Button type="submit" disabled={isPending}>
        {isPending ? "Adding..." : "Add to Cart"}
      </Button>
      {state.error && <p className="text-destructive">{state.error}</p>}
    </form>
  );
}

// useOptimistic — show optimistic UI while action is pending
function MessageList({ messages }: { messages: Message[] }) {
  const [optimistic, addOptimistic] = useOptimistic(
    messages,
    (current, newMsg: Message) => [...current, { ...newMsg, sending: true }],
  );
  // Call addOptimistic(msg) before the server responds
}

// useTransition — mark state updates as non-blocking
function SearchResults() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Item[]>([]);
  const [isPending, startTransition] = useTransition();

  function handleSearch(value: string) {
    setQuery(value); // urgent: update input immediately
    startTransition(() => {
      setResults(filterItems(value)); // non-urgent: can be interrupted
    });
  }
}
```

## Custom Hooks

### Conventions

- Always prefix with `use`.
- Return patterns: single value, tuple `[value, setter]`, or object `{ data, isLoading, error }`.
- Extract when logic is shared across components OR a component's hook setup exceeds ~10 lines.

### Examples

```tsx
// useLocalStorage — generic, persisted state
function useLocalStorage<T>(key: string, initialValue: T) {
  const [value, setValue] = useState<T>(() => {
    const stored = localStorage.getItem(key);
    return stored ? (JSON.parse(stored) as T) : initialValue;
  });

  useEffect(() => {
    localStorage.setItem(key, JSON.stringify(value));
  }, [key, value]);

  return [value, setValue] as const;
}

// useDebounce — delay value updates
function useDebounce<T>(value: T, delay: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debounced;
}

// useMediaQuery — responsive behavior in JS
function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(
    () => window.matchMedia(query).matches,
  );

  useEffect(() => {
    const mql = window.matchMedia(query);
    const handler = (e: MediaQueryListEvent) => setMatches(e.matches);
    mql.addEventListener("change", handler);
    return () => mql.removeEventListener("change", handler);
  }, [query]);

  return matches;
}
```

## TypeScript + React

### Typing Props

```tsx
// Use type for props (convention)
type CardProps = {
  title: string;
  description?: string;
  children: React.ReactNode;
};

// Use interface when extending across files
interface BaseFieldProps {
  label: string;
  error?: string;
}
```

### Generic Components

```tsx
// Typed list that works with any item type
function List<T>({
  items,
  renderItem,
  keyExtractor,
}: {
  items: T[];
  renderItem: (item: T) => React.ReactNode;
  keyExtractor: (item: T) => string;
}) {
  return (
    <ul>
      {items.map((item) => (
        <li key={keyExtractor(item)}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}

// Usage: type is inferred from items
<List
  items={users}
  renderItem={(u) => <span>{u.name}</span>}
  keyExtractor={(u) => u.id}
/>;
```

### Event Handler Typing

```tsx
// Inline — type is inferred
<input onChange={(e) => setQuery(e.target.value)} />;

// Extracted — needs explicit type
const handleChange: React.ChangeEventHandler<HTMLInputElement> = (e) => {
  setQuery(e.target.value);
};

// Common event types
// React.ChangeEvent<HTMLInputElement>
// React.FormEvent<HTMLFormElement>
// React.MouseEvent<HTMLButtonElement>
// React.KeyboardEvent<HTMLDivElement>
```

### Utility Types

```tsx
// Get all props of a component
type BtnProps = React.ComponentProps<typeof Button>;

// Get the ref type of a component
type BtnRef = React.ComponentRef<typeof Button>;

// Pick/Omit specific props
type VariantOnly = Pick<BtnProps, "variant" | "size">;
type NoBtnClassName = Omit<BtnProps, "className">;
```

## State Management

### Local State First

Keep state as close to where it is used as possible. Start with `useState` and only escalate when needed.

### Lifting State

When siblings need shared state, lift it to their nearest common parent:

```tsx
function Parent() {
  const [selected, setSelected] = useState<string | null>(null);
  return (
    <>
      <Sidebar items={items} selected={selected} onSelect={setSelected} />
      <Detail itemId={selected} />
    </>
  );
}
```

### Context

Use for values many components at different nesting levels need (theme, auth, locale):

```tsx
// Typed provider with a convenience hook
type Theme = "light" | "dark";
const ThemeCtx = React.createContext<{
  theme: Theme;
  toggle: () => void;
} | null>(null);

function useTheme() {
  const ctx = React.useContext(ThemeCtx);
  if (!ctx) throw new Error("useTheme must be used within <ThemeProvider>");
  return ctx;
}
```

Context is **not** a state management library. It is a dependency injection mechanism. Every consumer re-renders when the context value changes.

### Global State with Zustand

Zustand is the default for global/shared state that outgrows Context. Use it when:

- Frequent updates cause re-renders across the tree (e.g., filters, selections, real-time data)
- State must be accessed outside React (event listeners, callbacks registered before mount)
- Multiple contexts are being composed and performance suffers

```tsx
// store/use-filter-store.ts
import { create } from "zustand";

type FilterStore = {
  query: string;
  category: string | null;
  setQuery: (query: string) => void;
  setCategory: (category: string | null) => void;
  reset: () => void;
};

export const useFilterStore = create<FilterStore>((set) => ({
  query: "",
  category: null,
  setQuery: (query) => set({ query }),
  setCategory: (category) => set({ category }),
  reset: () => set({ query: "", category: null }),
}));
```

```tsx
// In components — select only what you need to minimize re-renders
function SearchInput() {
  const query = useFilterStore((s) => s.query);
  const setQuery = useFilterStore((s) => s.setQuery);
  return <Input value={query} onChange={(e) => setQuery(e.target.value)} />;
}

function CategoryFilter() {
  const category = useFilterStore((s) => s.category);
  const setCategory = useFilterStore((s) => s.setCategory);
  return <Select value={category} onValueChange={setCategory} />;
}

// Access outside React (e.g., in a utility function)
const currentQuery = useFilterStore.getState().query;
```

**Zustand conventions:**

- One store per domain (e.g., `useFilterStore`, `useCartStore`, `useAuthStore`)
- Name stores with the `use` prefix and `Store` suffix
- Place in `store/` or `lib/store/` directory
- Always use selectors to avoid unnecessary re-renders:

```tsx
// BAD — re-renders on any store change
const { query, setQuery } = useFilterStore();

// GOOD — only re-renders when query changes
const query = useFilterStore((s) => s.query);
const setQuery = useFilterStore((s) => s.setQuery);
```

- Keep actions inside the store, not in components
- For persisted state, use the `persist` middleware:

```tsx
import { create } from "zustand";
import { persist } from "zustand/middleware";

export const useSettingsStore = create<SettingsStore>()(
  persist(
    (set) => ({
      theme: "system" as const,
      setTheme: (theme) => set({ theme }),
    }),
    { name: "settings-storage" },
  ),
);
```

**Escalation path:** local `useState` → lifted state → Context (dependency injection, infrequent changes) → Zustand (frequent updates, shared across tree, access outside React).

### URL as State

Anything that should be shareable or bookmarkable belongs in the URL:

```tsx
// Next.js App Router
import { useSearchParams, useRouter } from "next/navigation";

function FilteredList() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const query = searchParams.get("q") ?? "";

  function setQuery(q: string) {
    const params = new URLSearchParams(searchParams);
    params.set("q", q);
    router.replace(`?${params.toString()}`);
  }
}
```

## Data Fetching

### React 19: use() with Suspense

```tsx
// Server Component passes a promise to Client Component
async function Page() {
  const usersPromise = fetchUsers(); // starts fetching, does NOT await
  return (
    <Suspense fallback={<UsersSkeleton />}>
      <UserList usersPromise={usersPromise} />
    </Suspense>
  );
}

// Client Component reads the promise
("use client");
function UserList({ usersPromise }: { usersPromise: Promise<User[]> }) {
  const users = use(usersPromise);
  return (
    <ul>
      {users.map((u) => (
        <li key={u.id}>{u.name}</li>
      ))}
    </ul>
  );
}
```

### Client-Side Fetching

The manual pattern is verbose — prefer a library (TanStack Query, SWR) for production:

```tsx
// Manual pattern (fine for simple cases)
function useUsers() {
  const [data, setData] = useState<User[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const controller = new AbortController();
    fetch("/api/users", { signal: controller.signal })
      .then((res) => res.json())
      .then(setData)
      .catch((e) => {
        if (e.name !== "AbortError") setError(e.message);
      })
      .finally(() => setIsLoading(false));
    return () => controller.abort();
  }, []);

  return { data, error, isLoading };
}
```

### Loading, Error, and Success States

Every fetch must handle all three:

```tsx
function UserList() {
  const { data, error, isLoading } = useUsers();

  if (isLoading) return <Skeleton className="h-40 w-full" />;
  if (error)
    return (
      <Alert variant="destructive">
        <AlertDescription>{error}</AlertDescription>
      </Alert>
    );
  if (!data?.length) return <EmptyState message="No users found" />;

  return (
    <ul>
      {data.map((u) => (
        <li key={u.id}>{u.name}</li>
      ))}
    </ul>
  );
}
```

## Performance

### React.memo

Skip re-renders when props haven't changed (shallow comparison):

```tsx
const ExpensiveList = React.memo(function ExpensiveList({
  items,
}: {
  items: Item[];
}) {
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id}>{item.name}</li>
      ))}
    </ul>
  );
});
```

Use when: a component receives the same props frequently while its parent re-renders.
Skip when: the component almost always receives new props anyway.

### Code Splitting with lazy()

```tsx
const HeavyChart = React.lazy(() => import("./HeavyChart"));

function Dashboard() {
  return (
    <Suspense fallback={<Skeleton className="h-64 w-full" />}>
      <HeavyChart data={data} />
    </Suspense>
  );
}
```

Default strategy: split at the route level. Also split modals, drawers, and heavy third-party widgets.

### Virtualization

For lists with 1000+ items, render only visible rows:

```tsx
// Use react-window or TanStack Virtual instead of rendering all items
import { FixedSizeList } from "react-window";

<FixedSizeList height={600} width="100%" itemSize={50} itemCount={items.length}>
  {({ index, style }) => <div style={style}>{items[index].name}</div>}
</FixedSizeList>;
```

### Key Prop

```tsx
// Stable keys for lists — use unique IDs, never array index for dynamic lists
{
  items.map((item) => <ListItem key={item.id} item={item} />);
}

// Reset component state by changing key
<UserForm key={selectedUserId} userId={selectedUserId} />;
```

## Error Handling

### Error Boundaries

The only remaining use case for class components:

```tsx
type Props = { fallback: React.ReactNode; children: React.ReactNode };
type State = { hasError: boolean; error: Error | null };

class ErrorBoundary extends React.Component<Props, State> {
  state: State = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error("ErrorBoundary caught:", error, info.componentStack);
  }

  render() {
    if (this.state.hasError) return this.props.fallback;
    return this.props.children;
  }
}
```

### Placement Strategy

```tsx
// Route level — page-wide fallback
<ErrorBoundary fallback={<ErrorPage />}>
  <Route path="/dashboard" element={<Dashboard />} />
</ErrorBoundary>

// Granular — isolate risky subtrees
<ErrorBoundary fallback={<p>Chart failed to load</p>}>
  <ThirdPartyChart data={data} />
</ErrorBoundary>
```

### Recovery

Reset an error boundary by changing its `key`:

```tsx
const [resetKey, setResetKey] = useState(0)

<ErrorBoundary key={resetKey} fallback={
  <Button onClick={() => setResetKey(k => k + 1)}>Retry</Button>
}>
  <RiskyComponent />
</ErrorBoundary>
```

### What Error Boundaries Do NOT Catch

- Event handler errors (use try/catch in the handler)
- Async errors (setTimeout, promises not wrapped in use())
- Server-side rendering errors
- Errors in the error boundary itself

## Anti-Patterns

### 1. Derived State in useState

```tsx
// BAD — duplicates items prop into state, gets out of sync
const [sorted, setSorted] = useState(() => items.sort(compareFn));
useEffect(() => {
  setSorted(items.sort(compareFn));
}, [items]);

// GOOD — compute during render
const sorted = useMemo(() => [...items].sort(compareFn), [items]);
```

### 2. useEffect for Synchronous Derived Values

```tsx
// BAD — unnecessary render cycle
const [fullName, setFullName] = useState("");
useEffect(() => {
  setFullName(`${first} ${last}`);
}, [first, last]);

// GOOD — compute inline
const fullName = `${first} ${last}`;
```

### 3. Missing Cleanup in useEffect

```tsx
// BAD — event listener leaks on every re-render
useEffect(() => {
  window.addEventListener("resize", handleResize);
}, []);

// GOOD — clean up
useEffect(() => {
  window.addEventListener("resize", handleResize);
  return () => window.removeEventListener("resize", handleResize);
}, []);
```

### 4. Unstable References in Dependency Arrays

```tsx
// BAD — new object every render causes infinite loop
useEffect(() => {
  fetchData(options);
}, [{ page: 1, limit: 10 }]); // new object reference each render

// GOOD — memoize or use primitives
const options = useMemo(() => ({ page, limit }), [page, limit]);
useEffect(() => {
  fetchData(options);
}, [options]);
```

### 5. Prop Drilling Through Many Levels

```tsx
// BAD — intermediate components pass props they don't use
<App user={user}>
  <Layout user={user}>
    <Sidebar user={user}>
      <UserMenu user={user} />

// GOOD — Context or composition
<AuthProvider value={user}>
  <App>
    <Layout>
      <Sidebar>
        <UserMenu /> {/* calls useAuth() */}
```

### 6. Giant Components

A component exceeding ~200 lines likely does too much. Extract:

- Repeated JSX blocks into sub-components
- Complex hook logic into custom hooks
- Data transformation into utility functions

### 7. Index as Key in Dynamic Lists

```tsx
// BAD — causes bugs when items are reordered, inserted, or deleted
{
  items.map((item, i) => <ListItem key={i} item={item} />);
}

// GOOD — stable unique identifier
{
  items.map((item) => <ListItem key={item.id} item={item} />);
}
```

Index as key is only safe for static lists that never change order.

### 8. State for Values That Don't Trigger Re-renders

```tsx
// BAD — re-renders on every tick but nothing visual changes
const [timerId, setTimerId] = useState<number | null>(null);

// GOOD — ref for non-visual mutable values
const timerRef = useRef<number | null>(null);
```

### 9. Mutating State Directly

```tsx
// BAD — mutation, React won't detect the change
state.items.push(newItem);
setState(state);

// GOOD — new reference
setState((prev) => ({ ...prev, items: [...prev.items, newItem] }));
```

### 10. Fetching Without Cancellation

```tsx
// BAD — race condition: fast clicks cause stale data to overwrite fresh data
useEffect(() => {
  fetch(`/api/users/${id}`)
    .then((res) => res.json())
    .then(setUser);
}, [id]);

// GOOD — abort previous fetch when id changes
useEffect(() => {
  const controller = new AbortController();
  fetch(`/api/users/${id}`, { signal: controller.signal })
    .then((res) => res.json())
    .then(setUser)
    .catch((e) => {
      if (e.name !== "AbortError") setError(e.message);
    });
  return () => controller.abort();
}, [id]);
```
