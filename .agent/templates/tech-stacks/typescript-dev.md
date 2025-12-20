# TypeScript Development Guidelines

## File Conventions
- Use `.ts` for pure TypeScript, `.tsx` for React components
- Use `camelCase` for variables/functions, `PascalCase` for types/classes
- Prefer `interface` over `type` for object shapes

## Type Safety
- Enable `strict: true` in tsconfig.json
- Avoid `any` - use `unknown` if type is truly unknown
- Use type guards for narrowing

## Code Patterns
```typescript
// Prefer explicit return types for public functions
function calculateTotal(items: Item[]): number {
  return items.reduce((sum, item) => sum + item.price, 0);
}

// Use readonly for immutable data
interface Config {
  readonly apiUrl: string;
  readonly timeout: number;
}

// Prefer nullish coalescing over OR
const value = input ?? defaultValue;
```

## Error Handling
- Use custom error classes for domain errors
- Always handle Promise rejections
- Type-safe error handling with discriminated unions

## Imports
- Use ES module imports
- Absolute imports with path aliases (e.g., `@/components`)
- Group: external → internal → relative
