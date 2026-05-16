"""Sample Python module for IDE testing."""

from dataclasses import dataclass


@dataclass
class Greeter:
    """Greets people."""

    name: str

    def greet(self) -> str:
        """Return a greeting."""
        return f"Hello, {self.name}!"


def add(a: int, b: int) -> int:
    """Add two numbers."""
    return a + b


def main() -> None:
    """Entry point."""
    g = Greeter(name="World")
    print(g.greet())
    print(add(1, 2))


if __name__ == "__main__":
    main()
