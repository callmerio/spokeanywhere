# Python Development Guidelines

## Code Style
- Follow PEP 8
- Use type hints (Python 3.9+)
- Max line length: 88 (Black default)

## Type Hints
```python
from typing import Optional, List, Dict

def process_items(items: List[str], limit: Optional[int] = None) -> Dict[str, int]:
    """Process items and return counts."""
    result: Dict[str, int] = {}
    for item in items[:limit]:
        result[item] = result.get(item, 0) + 1
    return result
```

## Error Handling
```python
# Use specific exceptions
class ValidationError(Exception):
    """Raised when validation fails."""
    pass

# Context managers for cleanup
with open(path, 'r') as f:
    data = f.read()
```

## Project Structure
```
src/
  __init__.py
  main.py
  models/
  services/
  utils/
tests/
  conftest.py
  test_main.py
pyproject.toml
```

## Dependencies
- Use `pyproject.toml` or `requirements.txt`
- Pin versions for production
- Use virtual environments
