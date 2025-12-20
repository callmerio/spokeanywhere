# React Development Guidelines

## Component Patterns
- Prefer functional components with hooks
- Use `React.FC` sparingly (prefer explicit prop types)
- Component file structure: Component → hooks → helpers → types

## Hooks Usage
```typescript
// Custom hook pattern
function useUser(userId: string) {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  
  useEffect(() => {
    fetchUser(userId).then(setUser).finally(() => setLoading(false));
  }, [userId]);
  
  return { user, loading };
}
```

## State Management
- Local state: useState/useReducer
- Server state: React Query / SWR
- Global state: Context (simple) or Zustand/Redux (complex)

## Performance
- Use `React.memo` for expensive components
- Use `useMemo` for expensive calculations
- Use `useCallback` for callback props
- Avoid inline objects/functions in render

## Styling
- CSS Modules or styled-components
- Tailwind CSS if project uses it
- Avoid inline styles except for dynamic values

## File Structure
```
components/
  Button/
    Button.tsx
    Button.module.css
    Button.test.tsx
    index.ts
```
