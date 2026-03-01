---
name: material3
description: Material 3 for Flutter — theming, ColorScheme, component catalog, forms, accessibility, and adaptive layout.
---

# Material 3

## When to Use

**Material 3 is the default design system for Flutter.** `ThemeData.useMaterial3` is `true` by default since Flutter 3.16. Always use Material 3 widgets (`FilledButton`, `NavigationBar`, `SearchAnchor`, etc.) over their legacy Material 2 equivalents.

Use this skill for:

- Theming with `ColorScheme.fromSeed()` and `ThemeData`
- Component selection and composition (buttons, navigation, dialogs, cards, etc.)
- Form patterns with `TextFormField` and validation
- Dark mode, dynamic color, and `ThemeExtension`
- Accessibility and adaptive layout

Defer to other skills for:

- **flutter skill**: Core widget tree composition, lifecycle, platform channels
- **riverpod skill**: State management, providers, notifiers
- **testing-flutter skill**: Widget tests, golden tests, integration tests

## Setup and Theming

### MaterialApp Configuration

```dart
MaterialApp(
  title: 'My App',
  theme: ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
  darkTheme: ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ),
  ),
  themeMode: ThemeMode.system,
  home: const HomeScreen(),
);
```

### ColorScheme.fromSeed

Generates a full M3-compliant color scheme from a single seed color. Includes primary, secondary, tertiary, surface, error, and all their container/on variants.

```dart
// Basic — one seed color generates the entire palette
final lightScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);
final darkScheme = ColorScheme.fromSeed(
  seedColor: Colors.indigo,
  brightness: Brightness.dark,
);

// Override specific roles when the generated palette needs adjustment
final scheme = ColorScheme.fromSeed(
  seedColor: Colors.indigo,
  primary: const Color(0xFF1A237E),
  error: Colors.red.shade700,
);
```

### Accessing Theme Colors

Always access colors through `Theme.of(context).colorScheme`, never hardcode `Color` values:

```dart
final colorScheme = Theme.of(context).colorScheme;

Container(
  color: colorScheme.primaryContainer,
  child: Text(
    'Hello',
    style: TextStyle(color: colorScheme.onPrimaryContainer),
  ),
);
```

### Key Color Roles

| Role                                                       | Use for                                  |
| ---------------------------------------------------------- | ---------------------------------------- |
| `primary` / `onPrimary`                                    | FABs, prominent buttons, active states   |
| `primaryContainer` / `onPrimaryContainer`                  | Cards, chips, selected items             |
| `secondary` / `onSecondary`                                | Less prominent actions, filter chips     |
| `tertiary` / `onTertiary`                                  | Accent elements, complementary actions   |
| `surface` / `onSurface`                                    | Backgrounds, card surfaces, body text    |
| `surfaceContainerLowest` through `surfaceContainerHighest` | Layered surfaces (elevation replacement) |
| `error` / `onError`                                        | Validation errors, destructive actions   |
| `outline` / `outlineVariant`                               | Borders, dividers                        |

### Typography

```dart
final textTheme = Theme.of(context).textTheme;

Text('Title', style: textTheme.headlineMedium);
Text('Body text', style: textTheme.bodyLarge);
Text('Caption', style: textTheme.labelSmall);
```

M3 text styles: `displayLarge/Medium/Small`, `headlineLarge/Medium/Small`, `titleLarge/Medium/Small`, `bodyLarge/Medium/Small`, `labelLarge/Medium/Small`.

### ThemeExtension for Custom Tokens

When you need colors or styles beyond the standard M3 palette:

```dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
  }) {
    return AppColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
    );
  }
}
```

Register in `ThemeData`:

```dart
ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  extensions: const <ThemeExtension<dynamic>>[
    AppColors(
      success: Color(0xFF2E7D32),
      onSuccess: Colors.white,
      warning: Color(0xFFF57F17),
      onWarning: Colors.black,
    ),
  ],
);
```

Access in widgets:

```dart
final appColors = Theme.of(context).extension<AppColors>()!;
Container(color: appColors.success);
```

### Dynamic Color (Android 12+)

Use the `dynamic_color` package to match the user's wallpaper:

```dart
// pubspec.yaml: dynamic_color: ^1.7.0

import 'package:dynamic_color/dynamic_color.dart';

DynamicColorBuilder(
  builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
    final lightScheme = lightDynamic ?? ColorScheme.fromSeed(
      seedColor: Colors.indigo,
    );
    final darkScheme = darkDynamic ?? ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    );

    return MaterialApp(
      theme: ThemeData(colorScheme: lightScheme),
      darkTheme: ThemeData(colorScheme: darkScheme),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  },
);
```

## Buttons

M3 has five button types with distinct emphasis levels:

```dart
// Highest emphasis — primary actions
FilledButton(
  onPressed: () {},
  child: const Text('Submit'),
);

// Medium emphasis — important but not primary
FilledButton.tonal(
  onPressed: () {},
  child: const Text('Save Draft'),
);

// Standard emphasis — most common actions
ElevatedButton(
  onPressed: () {},
  child: const Text('Open'),
);

// Low emphasis — secondary actions
OutlinedButton(
  onPressed: () {},
  child: const Text('Cancel'),
);

// Lowest emphasis — tertiary actions, inline
TextButton(
  onPressed: () {},
  child: const Text('Learn More'),
);
```

### Icon Buttons

```dart
IconButton(
  icon: const Icon(Icons.favorite_border),
  selectedIcon: const Icon(Icons.favorite),
  isSelected: isFavorite,
  onPressed: () => setState(() => isFavorite = !isFavorite),
);

// Filled variants
IconButton.filled(onPressed: () {}, icon: const Icon(Icons.add));
IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.edit));
IconButton.outlined(onPressed: () {}, icon: const Icon(Icons.share));
```

### Floating Action Button

```dart
FloatingActionButton(
  onPressed: () {},
  child: const Icon(Icons.add),
);

// Extended FAB with label
FloatingActionButton.extended(
  onPressed: () {},
  icon: const Icon(Icons.add),
  label: const Text('New Item'),
);

// Large and small variants
FloatingActionButton.large(onPressed: () {}, child: const Icon(Icons.add));
FloatingActionButton.small(onPressed: () {}, child: const Icon(Icons.add));
```

### Segmented Button

Replaces `ToggleButtons` in M3:

```dart
enum TransportMode { car, bus, train, bike }

SegmentedButton<TransportMode>(
  segments: const [
    ButtonSegment(value: TransportMode.car, label: Text('Car'), icon: Icon(Icons.directions_car)),
    ButtonSegment(value: TransportMode.bus, label: Text('Bus'), icon: Icon(Icons.directions_bus)),
    ButtonSegment(value: TransportMode.train, label: Text('Train'), icon: Icon(Icons.train)),
    ButtonSegment(value: TransportMode.bike, label: Text('Bike'), icon: Icon(Icons.pedal_bike)),
  ],
  selected: {selectedMode},
  onSelectionChanged: (Set<TransportMode> selection) {
    setState(() => selectedMode = selection.first);
  },
);

// Multi-select
SegmentedButton<TransportMode>(
  multiSelectionEnabled: true,
  segments: [...],
  selected: selectedModes,
  onSelectionChanged: (Set<TransportMode> selection) {
    setState(() => selectedModes = selection);
  },
);
```

## Navigation

### NavigationBar (Bottom)

Replaces `BottomNavigationBar` in M3:

```dart
Scaffold(
  body: pages[currentIndex],
  bottomNavigationBar: NavigationBar(
    selectedIndex: currentIndex,
    onDestinationSelected: (index) => setState(() => currentIndex = index),
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
      NavigationDestination(icon: Badge(label: Text('3'), child: Icon(Icons.notifications_outlined)), label: 'Alerts'),
      NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
    ],
  ),
);
```

### NavigationRail (Side — Tablets)

```dart
Row(
  children: [
    NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => setState(() => currentIndex = index),
      labelType: NavigationRailLabelType.selected,
      leading: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      destinations: const [
        NavigationRailDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: Text('Home')),
        NavigationRailDestination(icon: Icon(Icons.search), label: Text('Search')),
        NavigationRailDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: Text('Profile')),
      ],
    ),
    const VerticalDivider(thickness: 1, width: 1),
    Expanded(child: pages[currentIndex]),
  ],
);
```

### NavigationDrawer

```dart
NavigationDrawer(
  selectedIndex: currentIndex,
  onDestinationSelected: (index) {
    setState(() => currentIndex = index);
    Navigator.pop(context); // close drawer
  },
  children: [
    const Padding(
      padding: EdgeInsets.fromLTRB(28, 16, 16, 10),
      child: Text('My App', style: TextStyle(fontSize: 18)),
    ),
    const NavigationDrawerDestination(icon: Icon(Icons.home), label: Text('Home')),
    const NavigationDrawerDestination(icon: Icon(Icons.settings), label: Text('Settings')),
    const Divider(indent: 28, endIndent: 28),
    const NavigationDrawerDestination(icon: Icon(Icons.info), label: Text('About')),
  ],
);
```

### Adaptive Navigation Pattern

Switch between bar, rail, and drawer based on screen width:

```dart
Widget buildNavigation(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;

  if (width >= 1200) {
    return NavigationDrawer(...);      // Desktop
  } else if (width >= 600) {
    return NavigationRail(...);        // Tablet
  } else {
    return NavigationBar(...);         // Phone
  }
}
```

## Dialogs and Sheets

### AlertDialog

```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    icon: const Icon(Icons.warning_amber),
    title: const Text('Delete Item?'),
    content: const Text('This action cannot be undone.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          onDelete();
          Navigator.pop(context);
        },
        child: const Text('Delete'),
      ),
    ],
  ),
);
```

### Bottom Sheet

```dart
showModalBottomSheet(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => DraggableScrollableSheet(
    initialChildSize: 0.4,
    minChildSize: 0.2,
    maxChildSize: 0.9,
    expand: false,
    builder: (context, scrollController) => ListView(
      controller: scrollController,
      children: [
        ListTile(title: Text('Option A'), onTap: () => Navigator.pop(context)),
        ListTile(title: Text('Option B'), onTap: () => Navigator.pop(context)),
      ],
    ),
  ),
);
```

### SnackBar

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('Item deleted'),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: onUndo,
    ),
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
);
```

## Search

### SearchAnchor

The M3 search pattern. Tapping the anchor opens a full-screen or expanded search view:

```dart
SearchAnchor(
  builder: (context, controller) => SearchBar(
    controller: controller,
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
    onTap: () => controller.openView(),
    onChanged: (_) => controller.openView(),
    leading: const Icon(Icons.search),
    hintText: 'Search items...',
  ),
  suggestionsBuilder: (context, controller) async {
    final query = controller.text;
    final results = await searchItems(query);
    return results.map(
      (item) => ListTile(
        title: Text(item.name),
        onTap: () {
          controller.closeView(item.name);
          navigateToItem(item);
        },
      ),
    );
  },
);
```

## Cards

M3 offers three card variants:

```dart
// Filled — default, subtle background
Card.filled(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Title', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Description text', style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  ),
);

// Elevated — raised with shadow
Card(
  elevation: 1,
  child: ListTile(
    leading: const Icon(Icons.album),
    title: const Text('Album Title'),
    subtitle: const Text('Artist Name'),
    trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
  ),
);

// Outlined — bordered, flat
Card.outlined(
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Text('Outlined card content'),
  ),
);
```

## Chips

```dart
// Filter chip — toggleable filters
FilterChip(
  label: const Text('Vegetarian'),
  selected: isVegetarian,
  onSelected: (selected) => setState(() => isVegetarian = selected),
);

// Input chip — user-entered data (removable)
InputChip(
  label: Text(tag),
  onDeleted: () => removeTag(tag),
  avatar: const Icon(Icons.label, size: 18),
);

// Assist chip — smart suggestions
AssistChip(
  label: const Text('Share'),
  avatar: const Icon(Icons.share, size: 18),
  onPressed: onShare,
);

// Suggestion chip — contextual suggestions
ActionChip(
  label: const Text('Nearby'),
  avatar: const Icon(Icons.place, size: 18),
  onPressed: () => filterByNearby(),
);
```

## Forms

### TextFormField with Validation

```dart
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Form is valid — proceed
      login(_emailController.text, _passwordController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) return 'Email is required';
              if (!value.contains('@')) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Password is required';
              if (value.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _submit,
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
```

### DropdownMenu

Replaces `DropdownButton` in M3:

```dart
DropdownMenu<String>(
  initialSelection: selectedValue,
  label: const Text('Category'),
  leadingIcon: const Icon(Icons.category),
  onSelected: (value) => setState(() => selectedValue = value),
  dropdownMenuEntries: const [
    DropdownMenuEntry(value: 'electronics', label: 'Electronics'),
    DropdownMenuEntry(value: 'books', label: 'Books'),
    DropdownMenuEntry(value: 'clothing', label: 'Clothing'),
  ],
);
```

## Loading and Progress

```dart
// Indeterminate — unknown duration
const CircularProgressIndicator();
const LinearProgressIndicator();

// Determinate — known progress
CircularProgressIndicator(value: progress);
LinearProgressIndicator(value: progress);

// Button with loading state
FilledButton(
  onPressed: isLoading ? null : onSubmit,
  child: isLoading
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Submit'),
);
```

## Scaffold Structure

```dart
Scaffold(
  appBar: AppBar(
    title: const Text('My App'),
    actions: [
      IconButton(icon: const Icon(Icons.search), onPressed: onSearch),
      IconButton(icon: const Icon(Icons.more_vert), onPressed: onMore),
    ],
  ),
  body: const Center(child: Text('Content')),
  floatingActionButton: FloatingActionButton(
    onPressed: onCreate,
    child: const Icon(Icons.add),
  ),
  bottomNavigationBar: NavigationBar(
    selectedIndex: currentIndex,
    onDestinationSelected: onNavigate,
    destinations: [...],
  ),
);
```

## Accessibility

### Built-in Defaults

M3 widgets include:

- Minimum 48x48 touch targets on interactive elements
- Color contrast ratios meeting WCAG AA (4.5:1 for text)
- Focus traversal with keyboard and D-pad
- `Semantics` labels on icons and graphics

### Required Additions

```dart
// 1. Label icon-only buttons
IconButton(
  icon: const Icon(Icons.delete),
  tooltip: 'Delete item',     // required for screen readers and hover
  onPressed: onDelete,
);

// 2. Provide semantics for decorative images
Semantics(
  label: 'Profile photo of $userName',
  child: CircleAvatar(backgroundImage: NetworkImage(photoUrl)),
);

// 3. Exclude decorative elements from semantics
Semantics(
  excludeSemantics: true,
  child: Icon(Icons.chevron_right),
);

// 4. Mark custom widgets as interactive
Semantics(
  button: true,
  label: 'Add to cart',
  child: GestureDetector(
    onTap: onAddToCart,
    child: const CustomCartIcon(),
  ),
);
```

## Anti-Patterns

| Anti-Pattern                                                                  | Why It Fails                                                              | Fix                                                                                 |
| ----------------------------------------------------------------------------- | ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Hardcoding `Color(0xFF...)` values in widgets                                 | Breaks dark mode, ignores theme changes, creates visual inconsistency     | Use `Theme.of(context).colorScheme.primary` (or other role)                         |
| Using `BottomNavigationBar` instead of `NavigationBar`                        | M2 component with different styling, no M3 motion or indicator            | Replace with `NavigationBar` and `NavigationDestination`                            |
| `ToggleButtons` instead of `SegmentedButton`                                  | M2 component, no M3 styling, different interaction model                  | Replace with `SegmentedButton<T>` with `ButtonSegment` entries                      |
| Setting `useMaterial3: false`                                                 | Opts out of the entire M3 design system, will be deprecated               | Remove the flag (defaults to `true`) and update any M2-specific code                |
| Building custom buttons instead of using M3 variants                          | Misses theme integration, accessibility, ink effects, and state handling  | Use `FilledButton`, `OutlinedButton`, `TextButton`, or `ElevatedButton`             |
| `showDialog` without `AlertDialog` icon or description                        | Missing semantic context for screen readers                               | Add `icon` for visual type hint and clear `title`/`content` text                    |
| Wrapping `TextFormField` in custom padding instead of using `InputDecoration` | Inconsistent spacing, breaks label floating animation, misses error state | Use `InputDecoration` properties: `contentPadding`, `prefixIcon`, `suffixIcon`      |
| `Navigator.push` for all navigation instead of GoRouter                       | Breaks deep linking, back button handling, and URL-based state            | Use GoRouter for declarative navigation; reserve imperative push for dialogs/sheets |
| Creating custom `ThemeData()` without `ColorScheme.fromSeed`                  | Missing half the M3 color roles (containers, surface variants)            | Always start with `ColorScheme.fromSeed()` and override specific roles as needed    |
| Not disposing `TextEditingController`                                         | Memory leaks, stale listeners, potential crashes                          | Always call `controller.dispose()` in `State.dispose()`                             |
