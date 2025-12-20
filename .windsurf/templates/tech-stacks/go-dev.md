# Go Development Guidelines

## Code Style
- Follow `gofmt` and `go vet`
- Use `golangci-lint` for linting
- Exported names are PascalCase, internal are camelCase

## Error Handling
```go
// Always handle errors explicitly
result, err := doSomething()
if err != nil {
    return fmt.Errorf("failed to do something: %w", err)
}

// Use custom error types for domain errors
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("%s: %s", e.Field, e.Message)
}
```

## Project Structure
```
cmd/
  myapp/
    main.go
internal/
  handlers/
  services/
  models/
pkg/
  utils/
go.mod
go.sum
```

## Concurrency
- Use channels for communication
- Use `sync.WaitGroup` for waiting on goroutines
- Use `context.Context` for cancellation

## Testing
```go
func TestCalculate(t *testing.T) {
    tests := []struct {
        name     string
        input    int
        expected int
    }{
        {"positive", 5, 10},
        {"zero", 0, 0},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got := Calculate(tt.input)
            if got != tt.expected {
                t.Errorf("got %d, want %d", got, tt.expected)
            }
        })
    }
}
```
