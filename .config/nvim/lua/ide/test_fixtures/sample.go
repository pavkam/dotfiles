package main

import "fmt"

// Greeter greets people
type Greeter struct {
	Name string
}

// Greet returns a greeting
func (g *Greeter) Greet() string {
	return fmt.Sprintf("Hello, %s!", g.Name)
}

func main() {
	g := &Greeter{Name: "World"}
	fmt.Println(g.Greet())
}
