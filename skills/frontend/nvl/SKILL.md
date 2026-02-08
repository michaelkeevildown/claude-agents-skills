---
name: nvl
description: Neo4j Visualization Library (NVL) — graph rendering, node/relationship styling, layout configuration, and interaction handling.
---

# NVL (Neo4j Visualization Library)

## When to Use
Use this skill when building graph visualizations with NVL. Covers rendering setup, styling nodes and relationships, layout algorithms, user interaction handling, and proven patterns from production FinSight usage.

---

## 1. Installation & Packages

```bash
npm install @neo4j-nvl/base @neo4j-nvl/react @neo4j-nvl/interaction-handlers
```

| Package | Purpose |
|---|---|
| `@neo4j-nvl/base` | Core NVL class, types (`Node`, `Relationship`, `NvlOptions`) |
| `@neo4j-nvl/react` | `BasicNvlWrapper`, `InteractiveNvlWrapper`, `StaticPictureWrapper` |
| `@neo4j-nvl/interaction-handlers` | `ZoomInteraction`, `PanInteraction`, `ClickInteraction`, etc. |

---

## 2. React Wrappers

All wrappers accept a `ref` for imperative access to the underlying NVL instance.

```tsx
import type NVL from '@neo4j-nvl/base';
const nvlRef = useRef<NVL>(null);
// Then: nvlRef.current.setZoom(1.5)
```

### BasicNvlWrapper
Minimal wrapper — renders the graph, syncs prop changes, no built-in interaction handlers.

```tsx
import { BasicNvlWrapper } from '@neo4j-nvl/react';

<BasicNvlWrapper
  ref={nvlRef}
  nodes={nodes}
  rels={relationships}
  layout="forceDirected"
  layoutOptions={{ enableCytoscape: true }}
  nvlOptions={{ initialZoom: 1 }}
  nvlCallbacks={{ onLayoutDone: () => console.log('done') }}
  zoom={0.8}
  pan={{ x: 0, y: 0 }}
  positions={nodePositions}               // Apply positions via setNodePositions
  onInitializationError={(err) => {}}
  onClick={(event) => {}}                  // Native DOM events passed as props
/>
```

### InteractiveNvlWrapper (primary choice)
Full mouse event support — click, drag, hover, zoom, pan, box select, lasso.

```tsx
import { InteractiveNvlWrapper } from '@neo4j-nvl/react';

<InteractiveNvlWrapper
  ref={nvlRef}
  nodes={nodes}
  rels={relationships}
  layout="forceDirected"
  layoutOptions={layoutOptions}
  nvlOptions={nvlOptions}
  nvlCallbacks={callbacks}
  zoom={0.8}
  pan={{ x: 0, y: 0 }}
  mouseEventCallbacks={{
    onNodeClick: (node, hitTargets, evt) => {},
    onNodeDoubleClick: (node, hitTargets, evt) => {},
    onNodeRightClick: (node, hitTargets, evt) => {},
    onRelationshipClick: (rel, hitTargets, evt) => {},
    onRelationshipDoubleClick: (rel, hitTargets, evt) => {},
    onRelationshipRightClick: (rel, hitTargets, evt) => {},
    onCanvasClick: (evt) => {},
    onCanvasDoubleClick: (evt) => {},
    onCanvasRightClick: (evt) => {},
    onHover: (element, hitTargets, evt) => {},
    onDrag: (nodes) => {},
    onPan: (evt) => {},
    onZoom: (zoomLevel) => {},
    onBoxSelect: ({ nodes, rels }) => {},
    onLassoSelect: ({ nodes, rels }) => {},
  }}
  interactionOptions={{}}                  // Toggle interaction behaviors
  onInitializationError={(err) => {}}
/>
```

### StaticPictureWrapper
Non-interactive render — for thumbnails, exports, or read-only views. Same props as BasicNvlWrapper minus interaction-related ones.

---

## 3. Node Interface

```typescript
interface Node {
  // Required
  id: string;                              // Unique across all nodes AND relationships

  // Visual
  color?: string;                          // Background color
  size?: number;                           // Node dimensions
  icon?: string;                           // URL or data URI (must be square, must be black)
  overlayIcon?: { url: string; position?: number[]; size?: number };

  // Captions
  caption?: string;                        // Simple text label
  captions?: StyledCaption[];              // Multiple styled captions (overrides caption)
  captionSize?: number;
  captionAlign?: 'center' | 'top' | 'bottom';

  // State
  selected?: boolean;                      // Blue border highlight
  hovered?: boolean;                       // Hover visual state
  activated?: boolean;                     // Activation state
  disabled?: boolean;                      // Grayed out
  pinned?: boolean;                        // Immune to layout forces

  // Experimental
  html?: HTMLElement;                      // DOM element rendered on top of node
}

type StyledCaption = {
  key?: string;
  value?: string;
  styles?: string[];                       // e.g. ['bold', 'italic']
};
```

### FinSight node mapping pattern

```tsx
// Label-based style config → NVL node
const nvlNodes: NVLNode[] = visibleNodes.map((node) => {
  const primaryLabel = getPrimaryLabel(node);           // node.labels[0]
  const styleConfig = getNodeStyleConfig(primaryLabel); // { baseColor, baseSize, icon }
  const displayName = getNodeDisplayName(node);         // Label-aware formatting
  const iconDataUri = getCachedIconDataUri(iconName, '#000000'); // Black SVG data URI

  return {
    id: node.id,
    caption: displayName,
    captionAlign: 'top',
    size: styleConfig.baseSize,
    color: styleConfig.baseColor,
    icon: iconDataUri,
    disabled: hiddenNodeIds.has(node.id),
    selected: selectedNodeIds.has(node.id),
    hovered: highlightedNodeIds.has(node.id),
  };
});
```

---

## 4. Relationship Interface

```typescript
interface Relationship {
  // Required
  id: string;                              // Unique across all nodes AND relationships
  from: string;                            // Source node ID
  to: string;                              // Target node ID

  // Visual
  color?: string;
  width?: number;
  type?: string;                           // Relationship type label

  // Captions
  caption?: string;
  captions?: StyledCaption[];              // Overrides caption when set
  captionSize?: number;
  captionAlign?: 'center' | 'top' | 'bottom';
  captionHtml?: HTMLElement;               // Experimental

  // State
  selected?: boolean;
  hovered?: boolean;
  disabled?: boolean;

  // Overlay
  overlayIcon?: { url: string; position?: number[]; size?: number };
}
```

### FinSight relationship mapping pattern

```tsx
const nvlRelationships: NVLRelationship[] = visibleRelationships.map((rel) => {
  const styleConfig = getRelationshipStyleConfig(rel.type); // { color, width }
  return {
    id: rel.id,
    from: rel.source,
    to: rel.target,
    caption: rel.type,
    type: rel.type,
    width: styleConfig.width,
    color: styleConfig.color,
    disabled: hiddenNodeIds.has(rel.source) || hiddenNodeIds.has(rel.target),
    hovered: highlightedNodeIds.has(rel.source) || highlightedNodeIds.has(rel.target),
  };
});
```

---

## 5. NvlOptions

```typescript
interface NvlOptions {
  // Zoom & Pan
  initialZoom?: number;
  minZoom?: number;                        // Default: 0.075
  maxZoom?: number;                        // Default: 10
  allowDynamicMinZoom?: boolean;           // Default: true — exceed minZoom if content doesn't fit
  panX?: number;
  panY?: number;

  // Rendering
  renderer?: 'webgl' | 'canvas';          // Default: 'webgl'
  disableWebWorkers?: boolean;             // Use synchronous layout fallback
  minimapContainer?: HTMLElement;          // DOM element for minimap rendering

  // Layout
  layout?: Layout;
  layoutOptions?: LayoutOptions;

  // Instance
  instanceId?: string;
  callbacks?: ExternalCallbacks;

  // Accessibility & Telemetry
  disableAria?: boolean;                   // Default: false
  disableTelemetry?: boolean;              // Default: false

  // Styling defaults
  styling?: {
    defaultNodeColor?: string;
    defaultRelationshipColor?: string;
    disabledItemColor?: string;
    disabledItemFontColor?: string;
    selectedBorderColor?: string;
    selectedInnerBorderColor?: string;
    dropShadowColor?: string;
    nodeDefaultBorderColor?: string;
    minimapViewportBoxColor?: string;
    iconStyle?: { scale?: number };        // e.g. 0.6 = 60% of node size
  };
}
```

### FinSight options pattern

```tsx
const nvlOptions = useMemo(() => ({
  disableWebWorkers: true,
  renderer: 'canvas' as const,
  minimapContainer: minimapElement || undefined,
  styling: {
    minimapViewportBoxColor: '#3B82F6',
    iconStyle: { scale: 0.6 },
  },
}), [minimapElement]);
```

---

## 6. Layout Configuration

```typescript
type Layout = 'forceDirected' | 'hierarchical' | 'd3Force' | 'grid' | 'free';
```

### forceDirected (default)

```typescript
interface ForceDirectedOptions {
  enableCytoscape?: boolean;     // CoseBilkent for smaller graphs — better initial positioning
  enableVerlet?: boolean;        // New physics engine (default: true)
  intelWorkaround?: boolean;     // Fixes Intel GPU WebGL shader issues
}
```

### hierarchical

```typescript
interface HierarchicalOptions {
  direction?: 'left' | 'right' | 'up' | 'down';
  packing?: 'bin' | 'stack';
}
```

### Changing layouts at runtime

```tsx
// Via ref — use setTimeout to avoid race conditions with NVL initialization
useEffect(() => {
  const timer = setTimeout(() => {
    nvlRef.current?.setLayout(layout);
  }, 50);
  return () => clearTimeout(timer);
}, [layout]);

// Update layout options without changing algorithm
nvlRef.current.setLayoutOptions({ direction: 'up' });

// Check if layout is still animating
nvlRef.current.isLayoutMoving(); // boolean
```

---

## 7. Interaction Handlers

Used with `BasicNvlWrapper` (or vanilla JS) when you need manual control. `InteractiveNvlWrapper` handles these internally via `mouseEventCallbacks`.

```tsx
import { ZoomInteraction, PanInteraction, ClickInteraction,
         DragNodeInteraction, HoverInteraction,
         BoxSelectInteraction, LassoInteraction } from '@neo4j-nvl/interaction-handlers';
```

### Registering handlers (via ref)

```tsx
// Must wait for NVL initialization — use setTimeout
useEffect(() => {
  const timer = setTimeout(() => {
    if (nvlRef.current) {
      new ZoomInteraction(nvlRef.current);
      new PanInteraction(nvlRef.current);
    }
  });
  return () => clearTimeout(timer);
}, []);
```

### Handler classes and callbacks

| Handler | Constructor | Callback | Signature |
|---|---|---|---|
| `ZoomInteraction` | `new ZoomInteraction(nvl)` | `onZoom` | `(zoomLevel: number) => void` |
| `PanInteraction` | `new PanInteraction(nvl)` | `onPan` | `(panning: any) => void` |
| `ClickInteraction` | `new ClickInteraction(nvl)` | `onNodeClick`, `onNodeDoubleClick`, `onNodeRightClick`, `onRelationshipClick`, `onRelationshipDoubleClick`, `onRelationshipRightClick`, `onSceneClick` | Various |
| `DragNodeInteraction` | `new DragNodeInteraction(nvl)` | `onDrag` | `(nodes: Node[]) => void` |
| `HoverInteraction` | `new HoverInteraction(nvl)` | `onHover` | `(element, hitTargets, event) => void` |
| `BoxSelectInteraction` | `new BoxSelectInteraction(nvl)` | `onBoxSelect` | `({ nodes, rels }) => void` |
| `LassoInteraction` | `new LassoInteraction(nvl)` | `onLassoSelect` | `({ nodes, rels }) => void` |

```tsx
// Update callback after construction
handler.updateCallback('onNodeClick', (node: Node) => {
  console.log('clicked', node);
});
```

---

## 8. NVL Instance Methods (via ref)

### Graph Manipulation

```typescript
// Add elements
nvl.addElementsToGraph(nodes: Node[], relationships: Relationship[]): void

// Add new + update existing (matches by ID)
nvl.addAndUpdateElementsInGraph(nodes?: Node[] | PartialNode[], rels?: Relationship[] | PartialRelationship[]): void

// Update properties on existing elements only
nvl.updateElementsInGraph(nodes: Node[] | PartialNode[], rels: Relationship[] | PartialRelationship[]): void

// Remove by ID (removes adjacent relationships too)
nvl.removeNodesWithIds(nodeIds: string[]): void
nvl.removeRelationshipsWithIds(relIds: string[]): void
```

### Data Retrieval

```typescript
nvl.getNodes(): Node[]
nvl.getNodeById(id: string): Node
nvl.getRelationships(): Relationship[]
nvl.getRelationshipById(id: string): Relationship
nvl.getNodePositions(): (Node & Point)[]
nvl.getPositionById(id: string): Node
nvl.getNodesOnScreen(): { nodes: Node[]; rels: Relationship[] }
```

### Viewport

```typescript
nvl.setZoom(zoomValue: number): void
nvl.resetZoom(): void                     // Resets to 0.75
nvl.getScale(): number
nvl.setPan(panX: number, panY: number): void
nvl.getPan(): Point                        // { x, y }
nvl.setZoomAndPan(zoom: number, panX: number, panY: number): void
nvl.fit(nodeIds: string[], zoomOptions?: ZoomOptions): void
```

```typescript
type ZoomOptions = {
  animated?: boolean;
  maxZoom?: number;
  minZoom?: number;
  noPan?: boolean;                         // Zoom without panning
  outOnly?: boolean;                       // Only zoom out, never in
};
```

### Selection

```typescript
nvl.getSelectedNodes(): (Node & Point)[]
nvl.getSelectedRelationships(): Relationship[]
nvl.deselectAll(): void
```

### Node Positioning

```typescript
nvl.setNodePositions(data: Node[], updateLayout?: boolean): void
nvl.pinNode(nodeId: string): void
nvl.unPinNode(nodeIds: string[]): void
```

### Layout

```typescript
nvl.setLayout(layout: Layout): void
nvl.setLayoutOptions(options: LayoutOptions): void
nvl.isLayoutMoving(): boolean
```

### Export

```typescript
nvl.saveToFile(options?: { backgroundColor?: string; filename?: string }): void
nvl.saveFullGraphToLargeFile(options?: { backgroundColor?: string; filename?: string }): void
nvl.getImageDataUrl(options?: { backgroundColor?: string }): string
```

### Hit Detection

```typescript
nvl.getHits(
  evt: MouseEvent,
  targets?: ('node' | 'relationship')[],
  hitOptions?: { hitNodeMarginWidth: number }
): NvlMouseEvent
```

### Lifecycle

```typescript
nvl.restart(options?: NvlOptions, retainPositions?: boolean): void
nvl.destroy(): void                        // MUST call on unmount
nvl.getCurrentOptions(): NvlOptions
nvl.getContainer(): HTMLElement
nvl.setRenderer(renderer: string): void
nvl.setDisableWebGL(disabled?: boolean): void  // Experimental
```

### ExternalCallbacks (lifecycle hooks)

```typescript
interface ExternalCallbacks {
  onError?: (error: Error) => void;
  onInitialization?: () => void;
  onLayoutComputing?: (isComputing: boolean) => void;
  onLayoutDone?: () => void;
  onLayoutStep?: (nodes: Node[]) => void;
  onWebGLContextLost?: (event: WebGLContextEvent) => void;
  onZoomTransitionDone?: () => void;
  restart?: () => void;
}
```

---

## 9. Patterns (from FinSight)

### Label-based node style registry

Centralized config mapping node labels to visual properties:

```typescript
type NodeStyleConfig = {
  icon: string;       // Lucide icon name
  baseColor: string;  // Hex color
  baseSize: number;   // Node size
  shape: string;
};

const nodeStyleConfig: Record<string, NodeStyleConfig> = {
  Customer:    { icon: 'User',         baseColor: '#3B82F6', baseSize: 30, shape: 'circle' },
  Account:     { icon: 'Landmark',     baseColor: '#10B981', baseSize: 28, shape: 'circle' },
  Transaction: { icon: 'ArrowLeftRight', baseColor: '#F59E0B', baseSize: 24, shape: 'circle' },
  // ...
};

function getNodeStyleConfig(label: string): NodeStyleConfig {
  return nodeStyleConfig[label] ?? defaultConfig;
}
```

### Lucide icon → SVG data URI with caching

NVL `icon` expects a URL or data URI. Convert Lucide React components:

```typescript
import { renderToStaticMarkup } from 'react-dom/server';

const iconCache = new Map<string, string>();

function getCachedIconDataUri(iconName: string, color: string): string {
  const key = `${iconName}-${color}`;
  if (iconCache.has(key)) return iconCache.get(key)!;

  const IconComponent = getLucideIcon(iconName);
  const svgString = renderToStaticMarkup(<IconComponent color={color} size={24} />);
  const dataUri = `data:image/svg+xml,${encodeURIComponent(svgString)}`;
  iconCache.set(key, dataUri);
  return dataUri;
}
```

**Critical:** Pass `'#000000'` (black) as the icon color. NVL handles color inversion for dark node backgrounds automatically.

### Node display name formatting

Format captions based on node label:

```typescript
function getNodeDisplayName(node: GraphNode): string {
  const label = getPrimaryLabel(node);
  switch (label) {
    case 'Customer':    return `${node.properties.firstName} ${node.properties.lastName}`;
    case 'Account':     return `Account ***${node.properties.accountNumber?.slice(-4)}`;
    case 'Transaction': return `TXN-${node.properties.amount}`;
    case 'Email':       return node.properties.address;
    case 'Phone':       return node.properties.number;
    default:            return node.properties.name ?? node.id;
  }
}
```

### Visibility filtering

Filter out removed/hidden nodes before passing to NVL:

```tsx
const visibleNodes = nodes.filter((n) => !removedNodeIds.has(n.id));
const visibleRelationships = relationships.filter(
  (r) => !removedNodeIds.has(r.source) && !removedNodeIds.has(r.target)
);
// Hidden (but not removed) nodes: pass to NVL with disabled: true
```

### Minimap setup

Create the minimap container via `useLayoutEffect` (before NVL initializes), then pass as option:

```tsx
const [minimapElement, setMinimapElement] = useState<HTMLDivElement | null>(null);

useLayoutEffect(() => {
  const minimapDiv = document.createElement('div');
  minimapDiv.className = 'absolute bottom-4 right-4 w-64 h-64 rounded-lg border bg-white';
  minimapDiv.style.pointerEvents = 'auto';
  graphContainerRef.current!.appendChild(minimapDiv);
  setMinimapElement(minimapDiv);
  return () => { minimapDiv.remove(); setMinimapElement(null); };
}, []);

// Pass to NVL — only render when element is ready
const nvlOptions = useMemo(() => ({
  minimapContainer: minimapElement || undefined,
}), [minimapElement]);

// Guard rendering on minimapElement
{nvlNodes.length > 0 && minimapElement ? (
  <InteractiveNvlWrapper nvlOptions={nvlOptions} ... />
) : null}
```

### Stats bar

Show node/relationship counts above the graph:

```tsx
<div className="border-b px-4 py-2 flex items-center gap-4 text-sm">
  <div>Nodes: <span className="font-medium">{visibleNodes.length}</span></div>
  <div>Relationships: <span className="font-medium">{visibleRelationships.length}</span></div>
  {hiddenCount > 0 && <div>Hidden: <span className="text-orange-600">{hiddenCount}</span></div>}
</div>
```

### Layout change with setTimeout guard

NVL needs a tick to initialize before `setLayout` calls work:

```tsx
useEffect(() => {
  if (!nvlRef.current) return;
  const timer = setTimeout(() => {
    nvlRef.current?.setLayout(layout);
  }, 50);
  return () => clearTimeout(timer);
}, [layout]);
```

### Resize handling

Hide graph during panel resize to avoid NVL rendering glitches, show on release:

```tsx
<div style={{
  opacity: isResizing ? 0 : 1,
  pointerEvents: isResizing ? 'none' : 'auto',
  transition: 'opacity 0.15s ease-out'
}}>
  <InteractiveNvlWrapper ... />
</div>
{isResizing && (
  <div className="absolute inset-0 flex items-center justify-center">
    <p>Release to view graph</p>
  </div>
)}
```

### Zoom controls via ref

```tsx
const handleZoomIn = useCallback(() => {
  if (nvlRef.current) {
    nvlRef.current.setZoom(nvlRef.current.getScale() * 1.2);
  }
}, []);

const handleFitView = useCallback(() => {
  if (nvlRef.current && visibleNodes.length > 0) {
    nvlRef.current.fit(visibleNodes.map((n) => n.id));
  }
}, [visibleNodes]);
```

### Export image

```tsx
const handleExportImage = useCallback(() => {
  if (nvlRef.current) {
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5);
    nvlRef.current.saveToFile({ filename: `graph-${timestamp}.png` });
  }
}, []);
```

---

## 10. Anti-Patterns

| Anti-Pattern | Why It Fails | Fix |
|---|---|---|
| Missing container height | NVL renders into a 0-height div and nothing appears | Ensure parent has explicit height (`h-full`, `flex-1`, or fixed px) |
| Setting both `caption` and `captions` | `captions` array wins and `caption` is ignored silently | Use one or the other |
| Non-black icons | NVL expects black SVGs; it applies node color automatically | Always pass `color: '#000000'` when generating icon data URIs |
| Non-square icon images | Icons render distorted | Use square images/SVGs (e.g. 24x24) |
| Forgetting `destroy()` on unmount | Memory leak — canvas, event listeners, workers stay alive | Call `nvl.destroy()` in cleanup (React wrappers handle this) |
| WebGL renderer + captions/arrowheads | Some caption and arrowhead features only work with canvas renderer | Use `renderer: 'canvas'` when captions or arrowheads are needed |
| Calling `setLayout` immediately after init | NVL hasn't finished initializing — call is silently dropped | Wrap in `setTimeout(() => {}, 50)` or use `onInitialization` callback |
| Arbitrary `waitForTimeout` for layout | Brittle timing — may fire too early or too late | Use `isLayoutMoving()` or the `onLayoutDone` callback instead |
| Non-unique IDs across nodes and relationships | NVL requires IDs unique across the entire graph — not just within nodes or rels | Prefix or namespace IDs if source data may collide |
| Mutating node/rel arrays in place | React wrappers diff by reference — mutations are invisible | Always create new arrays: `[...nodes]` or `.map()` |
