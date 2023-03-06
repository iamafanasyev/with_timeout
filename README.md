# WithTimeout

[![Elixir CI](https://github.com/iamafanasyev/with_timeout/actions/workflows/elixir.yml/badge.svg)](https://github.com/iamafanasyev/with_timeout/actions/workflows/elixir.yml)

Both total and time limited evaluation of expressions

## Usage

```elixir
iex> fn -> 42 end |> WithTimeout.evaluate(within_milliseconds: 100)
{:ok, 42}

iex> fn -> Process.sleep(200); 42 end |> WithTimeout.evaluate(within_milliseconds: 100)
{:error, :timeout}

iex> fn -> raise "42" end |> WithTimeout.evaluate(within_milliseconds: 100)
{:error, {:exception, %RuntimeError{message: "42"}, [...]}}
```

More advanced usages can be found in tests 

## Installation

The package can be installed by adding `with_timeout` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:with_timeout, "~> 0.1.0"}
  ]
end
```

Documentation can be found at <https://hexdocs.pm/with_timeout>

