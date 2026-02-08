---
name: react-patterns
description: React 19 + TypeScript strict mode patterns — component architecture, hooks, performance, error boundaries, and accessibility.
---

# React Patterns

## When to Use

Use this skill when building React components with TypeScript in strict mode. Covers React 19 changes, component architecture, custom hooks, performance optimization, error boundaries, code splitting, and accessibility patterns.

---

## 1. React 19 Changes

### ref as Regular Prop

`forwardRef` is no longer needed. Components accept `ref` directly:

```tsx
// React 19 — ref is a regular prop
function Input({ ref, className, ...props }: React.ComponentProps<'input'>) {
  return <input ref={ref} className={cn('border rounded px-3 py-2', className)} {...props} />;
}

// Usage
const inputRef = useRef<HTMLInputElement>(null);
<Input ref={inputRef} placeholder="Search..." />
```

`React.ComponentProps<typeof Component>` already includes `ref` in React 19.

### use() Hook

Read promises and context directly in render:

```tsx
import { use } from 'react';

function UserProfile({ userPromise }: { userPromise: Promise<User> }) {
  const user = use(userPromise);  // Suspends until resolved
  return <div>{user.name}</div>;
}

// Must be wrapped in Suspense
<Suspense fallback={<Skeleton />}>
  <UserProfile userPromise={fetchUser(id)} />
</Suspense>
```

### useActionState

Replace manual form state management:

```tsx
import { useActionState } from 'react';

function LoginForm() {
  const [state, submitAction, isPending] = useActionState(
    async (_prevState: { error?: string }, formData: FormData) => {
      const result = await login(formData.get('email'), formData.get('password'));
      if (!result.success) return { error: result.message };
      return {};
    },
    {}
  );

  return (
    <form action={submitAction}>
      <Input name="email" type="email" />
      <Input name="password" type="password" />
      {state.error && <p className="text-destructive">{state.error}</p>}
      <Button type="submit" disabled={isPending}>
        {isPending ? 'Signing in...' : 'Sign in'}
      </Button>
    </form>
  );
}
```

### useOptimistic

Show optimistic UI while an async action is in progress:

```tsx
import { useOptimistic } from 'react';

function NodeList({ nodes }: { nodes: Node[] }) {
  const [optimisticNodes, addOptimisticNode] = useOptimistic(
    nodes,
    (current, newNode: Node) => [...current, newNode]
  );

  const handleAdd = async (node: Node) => {
    addOptimisticNode(node);       // Immediately show in UI
    await saveNodeToDatabase(node); // Actually save
  };

  return optimisticNodes.map((n) => <NodeCard key={n.id} node={n} />);
}
```

---

## 2. TypeScript Strict Patterns

### Extending Component Props

```tsx
// Extend native HTML element props
interface SearchInputProps extends React.ComponentProps<'input'> {
  onSearch: (term: string) => void;
}

// Extend a shadcn/ui component
interface CustomCardProps extends React.ComponentProps<typeof Card> {
  title: string;
  riskScore?: number;
}
```

### Discriminated Unions for Variants

```tsx
type NodeDetailProps =
  | { type: 'person'; person: Person; accounts: Account[] }
  | { type: 'account'; account: Account; transactions: Transaction[] }
  | { type: 'transaction'; transaction: Transaction };

function NodeDetail(props: NodeDetailProps) {
  switch (props.type) {
    case 'person':
      return <PersonDetail person={props.person} accounts={props.accounts} />;
    case 'account':
      return <AccountDetail account={props.account} transactions={props.transactions} />;
    case 'transaction':
      return <TransactionDetail transaction={props.transaction} />;
  }
}
```

### Generic Components

```tsx
interface DataTableProps<T> {
  data: T[];
  columns: ColumnDef<T>[];
  onRowClick?: (row: T) => void;
}

function DataTable<T extends { id: string }>({
  data,
  columns,
  onRowClick,
}: DataTableProps<T>) {
  // Table implementation
}
```

### satisfies for Type-Safe Configs

```tsx
const nodeStyleConfig = {
  Customer: { icon: 'User', baseColor: '#3B82F6', baseSize: 30 },
  Account: { icon: 'Landmark', baseColor: '#10B981', baseSize: 28 },
  Transaction: { icon: 'ArrowLeftRight', baseColor: '#F59E0B', baseSize: 24 },
} satisfies Record<string, { icon: string; baseColor: string; baseSize: number }>;
```

---

## 3. Component Architecture

### Functional Components Only

```tsx
// ✅ Functional component with hooks
const NodesTable = ({ nodes, onSelect }: Props) => {
  const [sortField, setSortField] = useState('name');
  return (/* ... */);
};

// ❌ Class components — do not use
```

### Single Responsibility

```tsx
// ✅ Focused components
const InvestigationPanel = () => (
  <div>
    <NodesTable />       {/* Table logic only */}
    <GraphCanvas />      {/* Graph rendering only */}
    <CaseTimeline />     {/* Timeline logic only */}
  </div>
);

// ❌ One massive component doing everything
```

### Composition Over Prop Drilling

Use Zustand stores or context instead of threading props through many layers:

```tsx
// ✅ Components access state directly from Zustand
const GraphCanvas = () => {
  const nodes = useStore((s) => s.tabStates[s.activeTabId]?.nodes ?? []);
  return <NVL nodes={nodes} />;
};

// ❌ Drilling props through 4+ levels
<App nodes={nodes}>
  <Layout nodes={nodes}>
    <Panel nodes={nodes}>
      <Graph nodes={nodes} />
```

---

## 4. Custom Hooks

### useTabState — Access Active Tab State

```tsx
const useTabState = () => {
  const activeTabId = useStore((s) => s.activeTabId);
  const tabState = useStore((s) =>
    s.activeTabId ? s.tabStates[s.activeTabId] ?? null : null
  );
  return { activeTabId, tabState };
};
```

### useDebounce — Debounce a Value

```tsx
const useDebounce = <T,>(value: T, delay: number): T => {
  const [debouncedValue, setDebouncedValue] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);
  return debouncedValue;
};

// Usage
const [search, setSearch] = useState('');
const debouncedSearch = useDebounce(search, 300);
useEffect(() => { fetchNodes(debouncedSearch); }, [debouncedSearch]);
```

### useLocalStorage — Persist UI State

```tsx
const useLocalStorage = <T,>(key: string, initial: T) => {
  const [value, setValue] = useState<T>(() => {
    try {
      const item = localStorage.getItem(key);
      return item ? JSON.parse(item) : initial;
    } catch {
      return initial;
    }
  });

  const setAndPersist = useCallback(
    (newValue: T | ((prev: T) => T)) => {
      setValue((prev) => {
        const resolved = newValue instanceof Function ? newValue(prev) : newValue;
        localStorage.setItem(key, JSON.stringify(resolved));
        return resolved;
      });
    },
    [key]
  );

  return [value, setAndPersist] as const;
};
```

---

## 5. Performance

### React.memo for Expensive List Items

```tsx
export const NodesRow = memo(({ node, onSelect }: Props) => (
  <tr onClick={() => onSelect(node.id)}>
    <td>{node.name}</td>
    <td>{node.riskScore}</td>
  </tr>
));
```

### useCallback for Stable Event Handlers

```tsx
const NodesTable = ({ nodes }: Props) => {
  // ✅ Stable reference — doesn't change between renders
  const handleRowClick = useCallback((id: string) => {
    useStore.getState().updateTabState(activeTabId, {
      selectedNodeIds: new Set([id]),
    });
  }, [activeTabId]);

  return nodes.map((n) => <NodesRow key={n.id} node={n} onClick={handleRowClick} />);
};
```

### useMemo for Expensive Computations

```tsx
const filteredNodes = useMemo(
  () => nodes.filter((n) => !removedNodeIds.has(n.id) && matchesFilter(n, filter)),
  [nodes, removedNodeIds, filter]
);
```

### useTransition for Non-Blocking Updates

Keep the UI responsive while filtering large datasets:

```tsx
const [isPending, startTransition] = useTransition();

const handleFilterChange = (newFilter: string) => {
  setFilterInput(newFilter);        // Urgent: update the input immediately
  startTransition(() => {
    setAppliedFilter(newFilter);    // Non-urgent: filter the table in background
  });
};

return (
  <>
    <Input value={filterInput} onChange={(e) => handleFilterChange(e.target.value)} />
    {isPending && <Spinner />}
    <DataTable data={filteredByAppliedFilter} />
  </>
);
```

### Code Splitting with React.lazy

```tsx
const GraphCanvas = lazy(() => import('@/components/graph/GraphCanvas'));
const CaseTimeline = lazy(() => import('@/components/investigation/CaseTimeline'));

const InvestigationPage = () => (
  <Suspense fallback={<Skeleton className="h-full w-full" />}>
    <GraphCanvas />
  </Suspense>
);
```

---

## 6. Error Boundaries

Isolate failures per tab — one crashing tab shouldn't take down others.

```tsx
import { Component, type ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback?: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error boundary caught:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback ?? (
        <div className="flex flex-col items-center justify-center p-8">
          <AlertCircle className="h-12 w-12 text-destructive" />
          <h2 className="mt-4 text-lg font-semibold">Something went wrong</h2>
          <p className="mt-2 text-sm text-muted-foreground">{this.state.error?.message}</p>
        </div>
      );
    }
    return this.props.children;
  }
}

// Usage: wrap each tab's content
<ErrorBoundary>
  <InvestigationTab tabId={tab.id} />
</ErrorBoundary>
```

---

## 7. Accessibility

### Required Additions to shadcn/ui Components

```tsx
// 1. aria-label on icon-only buttons
<Button variant="ghost" size="icon" aria-label="Close tab">
  <X className="h-4 w-4" />
</Button>

// 2. DialogDescription (required by Radix, can be visually hidden)
<DialogHeader>
  <DialogTitle>Confirm Delete</DialogTitle>
  <DialogDescription className="sr-only">
    Confirm deletion of the selected nodes
  </DialogDescription>
</DialogHeader>

// 3. data-testid on interactive elements
<Button data-testid="submit-investigation">Submit</Button>
<Input data-testid="search-input" />
```

### Keyboard Navigation for Custom Interactive Elements

```tsx
const NodeRow = ({ node, onSelect }: Props) => {
  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      onSelect(node.id);
    }
  };

  return (
    <tr
      tabIndex={0}
      role="button"
      onClick={() => onSelect(node.id)}
      onKeyDown={handleKeyDown}
      aria-label={`Select ${node.name}`}
    >
      {/* ... */}
    </tr>
  );
};
```

---

## Anti-Patterns

| Anti-Pattern | Why It Fails | Fix |
|---|---|---|
| `useEffect` for data fetching on mount | Missing cleanup, race conditions on rapid re-mounts | Use a service layer or React Query; call from event handlers |
| Props drilling through 4+ levels | Fragile, every intermediate component must forward props | Use Zustand selectors or React context |
| Class components | Cannot use hooks, more boilerplate | Functional components only (error boundaries are the one exception) |
| `dangerouslySetInnerHTML` without sanitization | XSS vulnerability | Sanitize with DOMPurify first, or avoid entirely |
| Inline object/array props on memoized children | `memo()` is bypassed — new object reference every render | Extract to `useMemo` or module-level constant |
| Overusing `useEffect` | Effects run after render, cause waterfalls, hard to reason about | Prefer event handlers for user actions, `useMemo` for derived values |
| Not wrapping lazy components in Suspense | Runtime error: "A component suspended while responding to synchronous input" | Always pair `React.lazy()` with a `<Suspense>` boundary |
| Missing `key` prop on list items | React can't track which items changed, causing incorrect re-renders or stale state | Always use a stable unique `key` (element ID, not array index) |
