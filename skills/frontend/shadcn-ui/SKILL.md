---
name: shadcn-ui
description: shadcn/ui component library — installation, usage patterns, theming, form integration, and accessibility.
---

# shadcn/ui

## When to Use

**shadcn/ui is the default component and styling approach for all frontend projects.** Always prefer shadcn/ui components (`<Button>`, `<Input>`, `<Card>`, etc.) over raw HTML elements or hand-styled Tailwind.

Use this skill for:
- Component installation, composition, and customization
- Theming with CSS variables (OKLCH color space)
- Form integration with react-hook-form + zod
- Accessible UI patterns (via Radix UI primitives)

Only skip shadcn/ui when a project explicitly uses a different component system (e.g., MUI, Chakra).

## Installation and Setup

### Initialize in a Next.js Project

```bash
npx shadcn@latest init
```

This creates:
- `components.json` — configuration file (style is always `"new-york"`, the only supported style)
- `lib/utils.ts` — the `cn()` utility (clsx + tailwind-merge)
- `components/ui/` — raw shadcn/ui components (avoid heavy modifications)
- Recommended additional directories: `components/primitives/` (lightly customized wrappers), `components/blocks/` (product-level compositions)

Key `components.json` fields:
- `tailwind.config`: Leave blank for Tailwind v4 projects
- `tailwind.cssVariables`: `true` (default, uses OKLCH color space)
- `registries`: Optional array for custom component registries

### CLI Commands

```bash
npx shadcn@latest init            # Initialize project
npx shadcn@latest add button      # Add component(s)
npx shadcn@latest add --all       # Add all components
npx shadcn@latest list            # List available components
npx shadcn@latest diff button     # Show changes vs registry
npx shadcn@latest build           # Build registry for publishing
npx shadcn@latest migrate radix   # Migrate to unified radix-ui package
```

Use `--rtl` flag with `init` for right-to-left layout support.

Components are copied into your codebase (not installed as dependencies). You own the code and can modify it.

### Ecosystem Notes

- **Tailwind v4**: CSS-first configuration via `@theme` directive in `globals.css`. No `tailwind.config.js` needed. Tailwind v3 projects are still supported.
- **tw-animate-css**: Replaces deprecated `tailwindcss-animate`. Install with `npm install tw-animate-css` and import in `globals.css`: `@import "tw-animate-css";`
- **Unified Radix package**: The `radix-ui` package replaces individual `@radix-ui/react-*` packages. Migrate with `npx shadcn@latest migrate radix`.
- **React 19**: `forwardRef` is no longer needed. Components accept `ref` as a regular prop. Both patterns work in existing codebases.
- **"new-york" only**: The old "default" style is deprecated. All new projects use "new-york".

### The `cn()` Utility

Always use `cn()` for conditional/merged class names:

```tsx
import { cn } from "@/lib/utils"

<div className={cn(
  "flex items-center gap-2",
  isActive && "bg-primary text-primary-foreground",
  className  // always forward className prop
)} />
```

## Component Usage Patterns

### Dialog

```tsx
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"

function DeleteDialog({ onConfirm }: { onConfirm: () => void }) {
  const [open, setOpen] = useState(false)

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="destructive">Delete</Button>
      </DialogTrigger>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Are you sure?</DialogTitle>
          <DialogDescription>
            This action cannot be undone.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <Button variant="outline" onClick={() => setOpen(false)}>
            Cancel
          </Button>
          <Button
            variant="destructive"
            onClick={() => {
              onConfirm()
              setOpen(false)
            }}
          >
            Delete
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
```

### Sheet (Side Panel)

```tsx
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetHeader,
  SheetTitle,
  SheetTrigger,
} from "@/components/ui/sheet"

<Sheet>
  <SheetTrigger asChild>
    <Button variant="outline">Open Settings</Button>
  </SheetTrigger>
  <SheetContent side="right" className="w-[400px]">
    <SheetHeader>
      <SheetTitle>Settings</SheetTitle>
      <SheetDescription>Configure your preferences.</SheetDescription>
    </SheetHeader>
    {/* Content here */}
  </SheetContent>
</Sheet>
```

### Command (Command Palette / Combobox)

```tsx
import {
  Command,
  CommandDialog,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
  CommandSeparator,
} from "@/components/ui/command"

function CommandMenu() {
  const [open, setOpen] = useState(false)

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault()
        setOpen((open) => !open)
      }
    }
    document.addEventListener("keydown", down)
    return () => document.removeEventListener("keydown", down)
  }, [])

  return (
    <CommandDialog open={open} onOpenChange={setOpen}>
      <CommandInput placeholder="Type a command or search..." />
      <CommandList>
        <CommandEmpty>No results found.</CommandEmpty>
        <CommandGroup heading="Actions">
          <CommandItem onSelect={() => {}}>
            <span>New Document</span>
          </CommandItem>
        </CommandGroup>
      </CommandList>
    </CommandDialog>
  )
}
```

### DataTable (with TanStack Table)

```tsx
import {
  Table, TableBody, TableCell, TableHead, TableHeader, TableRow,
} from "@/components/ui/table"
import { ColumnDef, flexRender, getCoreRowModel, useReactTable } from "@tanstack/react-table"

// Add getSortedRowModel, getFilteredRowModel, getPaginationRowModel as needed

function DataTable<TData, TValue>({
  columns,
  data,
}: {
  columns: ColumnDef<TData, TValue>[]
  data: TData[]
}) {
  const table = useReactTable({ data, columns, getCoreRowModel: getCoreRowModel() })

  return (
    <Table>
      <TableHeader>
        {table.getHeaderGroups().map((headerGroup) => (
          <TableRow key={headerGroup.id}>
            {headerGroup.headers.map((header) => (
              <TableHead key={header.id}>
                {header.isPlaceholder ? null : flexRender(header.column.columnDef.header, header.getContext())}
              </TableHead>
            ))}
          </TableRow>
        ))}
      </TableHeader>
      <TableBody>
        {table.getRowModel().rows.map((row) => (
          <TableRow key={row.id}>
            {row.getVisibleCells().map((cell) => (
              <TableCell key={cell.id}>
                {flexRender(cell.column.columnDef.cell, cell.getContext())}
              </TableCell>
            ))}
          </TableRow>
        ))}
      </TableBody>
    </Table>
  )
}
```

### Other Notable Components

These are available via `npx shadcn@latest add <name>` (see official docs for usage):

- **Sidebar** — app-level navigation with collapsible groups
- **Chart** — chart components built on Recharts
- **Drawer** — mobile-friendly bottom sheet (Vaul-based)
- **Carousel** — content carousel (Embla-based)
- **Resizable** — resizable panel layouts
- **Field, Input Group, Button Group** — form layout helpers
- **Spinner** — loading spinner component
- **Kbd** — keyboard shortcut display
- **Empty** — empty state component

## Composition Patterns

### Controlled vs Uncontrolled

Most shadcn/ui components support both patterns:

```tsx
// Uncontrolled — component manages its own state
<Dialog>
  <DialogTrigger>Open</DialogTrigger>
  <DialogContent>...</DialogContent>
</Dialog>

// Controlled — you manage the state
const [open, setOpen] = useState(false)
<Dialog open={open} onOpenChange={setOpen}>
  <DialogContent>...</DialogContent>
</Dialog>
```

Use controlled when you need to:
- Close on form submit
- Open programmatically (e.g., after an action)
- Prevent closing under certain conditions

### The `asChild` Pattern

Use `asChild` to render a different element while keeping the trigger behavior:

```tsx
// Renders a <button> wrapping an <a> — BAD
<DialogTrigger>
  <Link href="/settings">Settings</Link>
</DialogTrigger>

// Renders just the <a> with trigger behavior — GOOD
<DialogTrigger asChild>
  <Link href="/settings">Settings</Link>
</DialogTrigger>
```

### Forwarding className

Always forward `className` in custom components built on shadcn/ui:

```tsx
interface CustomCardProps extends React.ComponentProps<typeof Card> {
  title: string
}

function CustomCard({ title, className, ...props }: CustomCardProps) {
  return (
    <Card className={cn("p-6", className)} {...props}>
      <CardTitle>{title}</CardTitle>
    </Card>
  )
}
```

With React 19, `ref` is a regular prop — no `forwardRef` wrapper needed. `React.ComponentProps<typeof Card>` already includes `ref` in React 19.

## Styling and Theming

### CSS Variables

shadcn/ui uses CSS variables for theming, defined in `globals.css`. New projects use OKLCH color space. In Tailwind v4 projects, theme tokens are registered with `@theme inline` instead of `tailwind.config.js`. Existing HSL-based projects continue to work.

```css
:root {
  --background: oklch(1 0 0);
  --foreground: oklch(0.141 0.005 285.823);
  --primary: oklch(0.21 0.006 285.885);
  --primary-foreground: oklch(0.985 0.002 247.858);
  --secondary: oklch(0.967 0.001 286.375);
  --secondary-foreground: oklch(0.21 0.006 285.885);
  --muted: oklch(0.967 0.001 286.375);
  --muted-foreground: oklch(0.552 0.016 285.938);
  --destructive: oklch(0.577 0.245 27.325);
  --border: oklch(0.92 0.004 286.32);
  --input: oklch(0.92 0.004 286.32);
  --ring: oklch(0.705 0.015 286.067);
  --radius: 0.625rem;
}

.dark {
  --background: oklch(0.141 0.005 285.823);
  --foreground: oklch(0.985 0.002 247.858);
  /* ... dark mode values */
}
```

### Extending with Tailwind

Use Tailwind utilities to customize components. The `cn()` function handles merge conflicts:

```tsx
<Button className="w-full justify-start text-left font-normal">
  Select a date
</Button>
```

### Dark Mode

shadcn/ui supports dark mode via the `dark` class on `<html>`. Use `next-themes`:

```tsx
import { ThemeProvider } from "next-themes"

// In layout.tsx
<ThemeProvider attribute="class" defaultTheme="system" enableSystem>
  {children}
</ThemeProvider>
```

Toggle:

```tsx
import { useTheme } from "next-themes"

function ThemeToggle() {
  const { setTheme, theme } = useTheme()
  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
    >
      <Sun className="h-5 w-5 rotate-0 scale-100 dark:-rotate-90 dark:scale-0" />
      <Moon className="absolute h-5 w-5 rotate-90 scale-0 dark:rotate-0 dark:scale-100" />
    </Button>
  )
}
```

## Form Integration (react-hook-form + zod)

### Schema Definition

```tsx
import { z } from "zod"

const formSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  email: z.string().email("Invalid email address"),
  role: z.enum(["admin", "user", "viewer"]),
  notifications: z.boolean().default(false),
})

type FormValues = z.infer<typeof formSchema>
```

### Form Component

```tsx
import { useForm } from "react-hook-form"
import { zodResolver } from "@hookform/resolvers/zod"
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form"

function UserForm() {
  const form = useForm<FormValues>({
    resolver: zodResolver(formSchema),
    defaultValues: {
      name: "",
      email: "",
      role: "user",
      notifications: false,
    },
  })

  function onSubmit(values: FormValues) {
    // values is fully typed and validated
    console.log(values)
  }

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-6">
        <FormField
          control={form.control}
          name="name"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Name</FormLabel>
              <FormControl>
                <Input placeholder="John Doe" {...field} />
              </FormControl>
              <FormDescription>Your display name.</FormDescription>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Email</FormLabel>
              <FormControl>
                <Input type="email" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <FormField
          control={form.control}
          name="role"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Role</FormLabel>
              <Select onValueChange={field.onChange} defaultValue={field.value}>
                <FormControl>
                  <SelectTrigger>
                    <SelectValue placeholder="Select a role" />
                  </SelectTrigger>
                </FormControl>
                <SelectContent>
                  <SelectItem value="admin">Admin</SelectItem>
                  <SelectItem value="user">User</SelectItem>
                  <SelectItem value="viewer">Viewer</SelectItem>
                </SelectContent>
              </Select>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit">Save</Button>
      </form>
    </Form>
  )
}
```

## Accessibility

### Built-in Defaults

shadcn/ui components (via Radix UI) include:
- Keyboard navigation (Tab, Enter, Escape, Arrow keys)
- Focus management (focus trap in dialogs, return focus on close)
- ARIA attributes (role, aria-expanded, aria-controls, etc.)
- Screen reader announcements

### Required Additions

You must still provide:

```tsx
// 1. Always include DialogDescription (or visually hide it)
<DialogHeader>
  <DialogTitle>Edit Profile</DialogTitle>
  <DialogDescription>Make changes to your profile here.</DialogDescription>
</DialogHeader>

// If no visible description, use VisuallyHidden:
<DialogDescription className="sr-only">
  Dialog for editing profile settings
</DialogDescription>

// 2. Label form inputs
<FormField
  name="email"
  render={({ field }) => (
    <FormItem>
      <FormLabel>Email</FormLabel>  {/* Required for accessibility */}
      <FormControl>
        <Input {...field} />
      </FormControl>
    </FormItem>
  )}
/>

// 3. Add aria-label for icon-only buttons
<Button variant="ghost" size="icon" aria-label="Close menu">
  <X className="h-4 w-4" />
</Button>

// 4. data-testid for testing
<Button data-testid="submit-form">Submit</Button>
```

## Common UI Patterns

### Loading States

```tsx
import { Loader2 } from "lucide-react"

<Button disabled={isLoading}>
  {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
  {isLoading ? "Saving..." : "Save Changes"}
</Button>

// Skeleton for content loading
import { Skeleton } from "@/components/ui/skeleton"

<Card>
  <CardHeader>
    <Skeleton className="h-6 w-[200px]" />
    <Skeleton className="h-4 w-[300px]" />
  </CardHeader>
  <CardContent>
    <Skeleton className="h-20 w-full" />
  </CardContent>
</Card>
```

### Empty States

Use the `<Empty>` component from shadcn/ui, or build a simple one:

```tsx
<div className="flex flex-col items-center justify-center py-12 text-center">
  <InboxIcon className="h-12 w-12 text-muted-foreground" />
  <h3 className="mt-4 text-lg font-semibold">No results</h3>
  <p className="mt-2 text-sm text-muted-foreground">Get started by creating your first item.</p>
  <Button className="mt-4">Create New</Button>
</div>
```

### Error Display

```tsx
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert"
import { AlertCircle } from "lucide-react"

function ErrorAlert({ message }: { message: string }) {
  return (
    <Alert variant="destructive">
      <AlertCircle className="h-4 w-4" />
      <AlertTitle>Error</AlertTitle>
      <AlertDescription>{message}</AlertDescription>
    </Alert>
  )
}
```

### Toast Notifications (Sonner)

The old `useToast` hook is deprecated. Use `sonner` instead:

```bash
npx shadcn@latest add sonner
```

Add `<Toaster />` once in your root layout:

```tsx
import { Toaster } from "@/components/ui/sonner"

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <Toaster />
      </body>
    </html>
  )
}
```

```tsx
import { toast } from "sonner"

function SaveButton() {
  async function handleSave() {
    try {
      await save()
      toast.success("Your changes have been saved.")
    } catch {
      toast.error("Failed to save changes.")
    }
  }

  return <Button onClick={handleSave}>Save</Button>
}
```

## Anti-Patterns

### 1. Raw HTML Instead of Components

```tsx
// BAD
<button className="bg-blue-500 text-white px-4 py-2 rounded">Click</button>

// GOOD
<Button>Click</Button>
```

### 2. Not Using `asChild` for Custom Triggers

```tsx
// BAD — nested interactive elements
<DialogTrigger><button>Open</button></DialogTrigger>

// GOOD
<DialogTrigger asChild><Button>Open</Button></DialogTrigger>
```

### 3. Hardcoding Colors Instead of CSS Variables

```tsx
// BAD
<div className="bg-gray-100 text-gray-900 dark:bg-gray-800 dark:text-white">

// GOOD — uses theme variables, dark mode automatic
<div className="bg-background text-foreground">
```

Never hardcode `oklch(...)` values either — always use semantic class names like `bg-primary`, `text-muted-foreground`.

### 4. Missing Form Validation Feedback

```tsx
// BAD — no error message shown
<FormField
  name="email"
  render={({ field }) => (
    <FormItem>
      <Input {...field} />
    </FormItem>
  )}
/>

// GOOD — shows validation errors
<FormField
  name="email"
  render={({ field }) => (
    <FormItem>
      <FormLabel>Email</FormLabel>
      <FormControl><Input {...field} /></FormControl>
      <FormMessage />  {/* Shows zod validation errors */}
    </FormItem>
  )}
/>
```

### 5. Not Forwarding Props

```tsx
// BAD — className, onClick, etc. are lost
function MyButton({ label }: { label: string }) {
  return <Button>{label}</Button>
}

// GOOD — all button props forwarded
function MyButton({ label, ...props }: { label: string } & React.ComponentProps<typeof Button>) {
  return <Button {...props}>{label}</Button>
}
```

### 6. Using Deprecated useToast

```tsx
// DEPRECATED — do not use
import { useToast } from "@/hooks/use-toast"
const { toast } = useToast()

// CORRECT — use sonner
import { toast } from "sonner"
toast.success("Saved")
```
