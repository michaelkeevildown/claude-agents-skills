---
name: zustand-state
description: Zustand 5 state management — store creation, tab-based isolation, slice composition, selectors, middleware, and multi-view synchronization.
---

# Zustand State Management

## When to Use

Use this skill when creating or modifying state that crosses component boundaries. Covers store creation, tab-based state isolation, slice composition, selector performance, middleware (devtools, persist, immer), and multi-view synchronization patterns.

---

## 1. Store Creation

### Basic Store with TypeScript

```typescript
import { create } from 'zustand';

interface CounterStore {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
}

const useCounterStore = create<CounterStore>((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
  reset: () => set({ count: 0 }),
}));
```

### Reading State Without Subscribing

Use `get()` inside actions to read state without causing re-renders:

```typescript
const useStore = create<Store>((set, get) => ({
  nodes: [],
  addNodeIfNotExists: (node) => {
    const existing = get().nodes.find((n) => n.id === node.id);
    if (!existing) {
      set((state) => ({ nodes: [...state.nodes, node] }));
    }
  },
}));
```

### Reading State Outside Components

```typescript
// Get current state snapshot (no subscription)
const currentNodes = useStore.getState().nodes;

// Call actions outside React
useStore.getState().addNode(newNode);

// Subscribe to changes outside React
const unsub = useStore.subscribe((state) => console.log(state.nodes));
```

---

## 2. Tab-Based State Isolation

**Critical pattern for multi-tab applications.** Each tab maintains isolated state within a single store using a `Record<tabId, TabState>` structure.

### Store Structure

```typescript
interface Tab {
  id: string;
  type: 'investigation' | 'case' | 'alert';
  title: string;
  metadata: Record<string, unknown>;
  createdAt: Date;
  lastAccessedAt: Date;
}

interface TabState {
  nodes: Node[];
  relationships: Relationship[];
  hiddenNodeIds: Set<string>;
  removedNodeIds: Set<string>;
  selectedNodeIds: Set<string>;
  isDirty: boolean;
}

interface InvestigationStore {
  tabs: Tab[];
  activeTabId: string | null;
  tabStates: Record<string, TabState>;

  addTab: (tab: Tab, initialState?: Partial<TabState>) => void;
  closeTab: (tabId: string) => void;
  switchTab: (tabId: string) => void;
  updateTabState: (tabId: string, updates: Partial<TabState>) => void;
  getActiveTabState: () => TabState | null;
}
```

### Implementation

```typescript
import { create } from 'zustand';

const defaultTabState: TabState = {
  nodes: [],
  relationships: [],
  hiddenNodeIds: new Set(),
  removedNodeIds: new Set(),
  selectedNodeIds: new Set(),
  isDirty: false,
};

const useInvestigationStore = create<InvestigationStore>((set, get) => ({
  tabs: [],
  activeTabId: null,
  tabStates: {},

  addTab: (tab, initialState = {}) =>
    set((state) => ({
      tabs: [...state.tabs, tab],
      activeTabId: tab.id,
      tabStates: {
        ...state.tabStates,
        [tab.id]: { ...defaultTabState, ...initialState },
      },
    })),

  closeTab: (tabId) =>
    set((state) => {
      const newTabs = state.tabs.filter((t) => t.id !== tabId);
      // CRITICAL: Remove tab state to prevent memory leaks
      const { [tabId]: _removed, ...remainingTabStates } = state.tabStates;
      const newActiveTabId =
        state.activeTabId === tabId
          ? newTabs.length > 0
            ? newTabs[newTabs.length - 1].id
            : null
          : state.activeTabId;

      return {
        tabs: newTabs,
        tabStates: remainingTabStates,
        activeTabId: newActiveTabId,
      };
    }),

  switchTab: (tabId) =>
    set((state) => ({
      tabs: state.tabs.map((tab) =>
        tab.id === tabId ? { ...tab, lastAccessedAt: new Date() } : tab
      ),
      activeTabId: tabId,
    })),

  updateTabState: (tabId, updates) =>
    set((state) => ({
      tabStates: {
        ...state.tabStates,
        [tabId]: {
          ...state.tabStates[tabId],
          ...updates,
          isDirty: true,
        },
      },
    })),

  getActiveTabState: () => {
    const state = get();
    return state.activeTabId ? state.tabStates[state.activeTabId] ?? null : null;
  },
}));
```

### Accessing Tab State in Components

```typescript
// Always scope state access to the active tab
const GraphCanvas = () => {
  const activeTabId = useInvestigationStore((state) => state.activeTabId);
  const nodes = useInvestigationStore((state) =>
    state.activeTabId ? state.tabStates[state.activeTabId]?.nodes ?? [] : []
  );
  const hiddenNodeIds = useInvestigationStore((state) =>
    state.activeTabId
      ? state.tabStates[state.activeTabId]?.hiddenNodeIds ?? new Set()
      : new Set()
  );

  if (!activeTabId) return <EmptyState />;

  const handleNodeClick = (nodeId: string) => {
    useInvestigationStore.getState().updateTabState(activeTabId, {
      selectedNodeIds: new Set([nodeId]),
    });
  };

  return <NVL nodes={nodes.filter((n) => !hiddenNodeIds.has(n.id))} />;
};
```

### Custom Hook for Tab State

```typescript
const useTabState = () => {
  const activeTabId = useInvestigationStore((state) => state.activeTabId);
  const tabState = useInvestigationStore((state) =>
    state.activeTabId ? state.tabStates[state.activeTabId] ?? null : null
  );
  return { activeTabId, tabState };
};
```

---

## 3. Selectors and Performance

### Fine-Grained Selectors

```typescript
// ✅ Only re-renders when nodes change for the active tab
const nodes = useStore((state) =>
  state.activeTabId ? state.tabStates[state.activeTabId]?.nodes ?? [] : []
);

// ✅ Computed value — only re-renders when inputs change
const visibleNodeCount = useStore((state) => {
  const tabState = state.activeTabId
    ? state.tabStates[state.activeTabId]
    : null;
  if (!tabState) return 0;
  return tabState.nodes.filter((n) => !tabState.removedNodeIds.has(n.id)).length;
});

// ❌ Subscribes to entire store — re-renders on ANY change
const store = useStore();

// ❌ Subscribes to all tab states — re-renders when ANY tab changes
const tabStates = useStore((state) => state.tabStates);
```

### Shallow Equality for Object/Array Selectors

When a selector returns a new object or array reference each time, use `useShallow` to compare by shallow equality:

```typescript
import { useShallow } from 'zustand/react/shallow';

// Without useShallow: re-renders on every store update (new object each time)
// With useShallow: only re-renders when the values inside change
const { nodes, relationships } = useStore(
  useShallow((state) => {
    const tabState = state.activeTabId
      ? state.tabStates[state.activeTabId]
      : null;
    return {
      nodes: tabState?.nodes ?? [],
      relationships: tabState?.relationships ?? [],
    };
  })
);
```

### Batch Updates

```typescript
// ❌ Three separate set() calls = three re-renders
set({ nodes: newNodes });
set({ relationships: newRelationships });
set({ isDirty: true });

// ✅ Single set() call = one re-render
set({
  nodes: newNodes,
  relationships: newRelationships,
  isDirty: true,
});
```

---

## 4. Multi-View Synchronization

When multiple views (table, graph, timeline) share state, one Zustand action updates the store and all subscribed components re-render automatically.

### Synchronization Flow

```
User clicks node in Graph
    → Store action: updateTabState(tabId, { selectedNodeIds: new Set([nodeId]) })
        → Graph re-renders (highlights selected node)
        → Table re-renders (highlights selected row)
        → Timeline re-renders (highlights related events)
```

### Example: Hide Node (Propagates to All Views)

```typescript
// Store action
hideNode: (tabId: string, nodeId: string) =>
  set((state) => ({
    tabStates: {
      ...state.tabStates,
      [tabId]: {
        ...state.tabStates[tabId],
        hiddenNodeIds: new Set([
          ...state.tabStates[tabId].hiddenNodeIds,
          nodeId,
        ]),
        isDirty: true,
      },
    },
  })),

// Graph component: filters out hidden nodes
const visibleNodes = nodes.filter((n) => !hiddenNodeIds.has(n.id));

// Table component: shows hidden nodes as dimmed
const rowClass = hiddenNodeIds.has(node.id) ? 'opacity-30' : '';

// Timeline component: excludes events for hidden nodes
const visibleEvents = events.filter((e) => !hiddenNodeIds.has(e.nodeId));
```

---

## 5. Middleware

### DevTools

```typescript
import { devtools } from 'zustand/middleware';

const useStore = create<Store>()(
  devtools(
    (set, get) => ({
      // ... store implementation
    }),
    { name: 'InvestigationStore' }
  )
);
```

### Immer (Mutable Draft Syntax)

Use immer for deeply nested updates (like tab state):

```typescript
import { immer } from 'zustand/middleware/immer';

const useStore = create<Store>()(
  immer((set) => ({
    tabs: [],
    activeTabId: null,
    tabStates: {},

    hideNode: (tabId, nodeId) =>
      set((state) => {
        state.tabStates[tabId].hiddenNodeIds.add(nodeId);
        state.tabStates[tabId].isDirty = true;
      }),
  }))
);
```

### Persist (Selective)

Persist tab metadata but not full state (too large):

```typescript
import { persist } from 'zustand/middleware';

const useStore = create<Store>()(
  persist(
    (set, get) => ({
      // ... store implementation
    }),
    {
      name: 'finsight-investigation-storage',
      partialize: (state) => ({
        tabs: state.tabs,
        activeTabId: state.activeTabId,
        // Do NOT persist tabStates — too large, reconstruct on load
      }),
      onRehydrateStorage: () => (state) => {
        if (state) {
          // Reinitialize empty tab states for persisted tabs
          const tabStates: Record<string, TabState> = {};
          state.tabs.forEach((tab) => {
            tabStates[tab.id] = { ...defaultTabState };
          });
          state.tabStates = tabStates;
        }
      },
    }
  )
);
```

### Combining Middleware

Order matters — outermost wraps first:

```typescript
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import { immer } from 'zustand/middleware/immer';

const useStore = create<Store>()(
  devtools(
    persist(
      immer((set, get) => ({
        // ... store implementation
      })),
      { name: 'storage-key', partialize: (state) => ({ /* ... */ }) }
    ),
    { name: 'StoreName' }
  )
);
```

---

## 6. Store Organization

Separate stores by domain. Don't create one massive store.

```
src/stores/
├── investigation.ts    # Per-tab investigation state (graph, table, timeline)
├── timeline.ts         # Per-tab timeline/changelog entries
├── layout.ts           # UI layout state (panel positions, sidebar)
├── settings.ts         # Global user preferences
├── cases.ts            # Shared case list (cross-tab)
├── alerts.ts           # Shared alert list (cross-tab)
└── index.ts            # Re-export all stores
```

**Per-tab stores** (investigation, timeline): State keyed by `tabId`, cleaned up on tab close.
**Global stores** (settings, layout): Single state shared across all tabs.
**Shared domain stores** (cases, alerts): Cross-tab data that multiple tabs can subscribe to.

---

## 7. Testing Zustand Stores

### Reset State Between Tests

```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import useInvestigationStore from './investigation';

describe('InvestigationStore', () => {
  beforeEach(() => {
    // Reset store to initial state before each test
    useInvestigationStore.setState({
      tabs: [],
      activeTabId: null,
      tabStates: {},
    });
  });

  it('should add a new tab with default state', () => {
    const tab = {
      id: 'tab-1',
      type: 'investigation' as const,
      title: 'Test Investigation',
      metadata: {},
      createdAt: new Date(),
      lastAccessedAt: new Date(),
    };

    useInvestigationStore.getState().addTab(tab);

    const state = useInvestigationStore.getState();
    expect(state.tabs).toHaveLength(1);
    expect(state.activeTabId).toBe('tab-1');
    expect(state.tabStates['tab-1']).toBeDefined();
    expect(state.tabStates['tab-1'].nodes).toEqual([]);
  });

  it('should clean up state when closing a tab', () => {
    const tab = {
      id: 'tab-1',
      type: 'investigation' as const,
      title: 'Test',
      metadata: {},
      createdAt: new Date(),
      lastAccessedAt: new Date(),
    };

    useInvestigationStore.getState().addTab(tab);
    useInvestigationStore.getState().closeTab('tab-1');

    const state = useInvestigationStore.getState();
    expect(state.tabs).toHaveLength(0);
    expect(state.tabStates['tab-1']).toBeUndefined();
    expect(state.activeTabId).toBeNull();
  });
});
```

---

## Anti-Patterns

| Anti-Pattern | Why It Fails | Fix |
|---|---|---|
| `const store = useStore()` | Subscribes to entire store — re-renders on every change | Use a selector: `useStore((s) => s.nodes)` |
| Creating stores inside components | New store on every render, loses all state | Create stores at module level or in a factory |
| Forgetting to remove tab state on close | Memory leak — closed tabs keep data in memory | Destructure out the tab: `const { [tabId]: _, ...rest } = state.tabStates` |
| `set({ nodes: state.nodes.push(newNode) })` | Mutating state directly — Zustand won't detect the change | Spread into new array: `set({ nodes: [...state.nodes, newNode] })` or use immer |
| Subscribing to `state.tabStates` | Re-renders when ANY tab changes, not just the active tab | Select only the active tab: `state.tabStates[state.activeTabId]` |
| Multiple `set()` calls in one action | Each `set()` triggers a re-render | Combine into a single `set()` call |
| Storing derived state | Stale data if source changes and derived isn't updated | Compute derived values in selectors |
| Using Zustand when local state suffices | Unnecessary global state, extra complexity | Use `useState` for component-local UI state (open/closed, hover, input values) |
