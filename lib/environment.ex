defmodule ExLox.Environment do
  alias __MODULE__
  alias ExLox.Token

  defstruct values: %{}

  def new(), do: %Environment{}

  def define(%Environment{} = env, %Token{type: :identifier, lexeme: name}, value) do
    %{env | values: Map.put(env.values, name, value)}
  end

  def assign(%Environment{} = env, %Token{type: :identifier, lexeme: name} = token, value) do
    case env.values do
      %{^name => _old_value} -> %{env | values: Map.put(env.values, name, value)}
      _ -> raise ExLox.RuntimeError, message: "Undefined variable '#{name}'.", token: token
    end
  end

  def get(%Environment{} = env, %Token{type: :identifier, lexeme: name} = token) do
    case env.values do
      %{^name => value} -> value
      _ -> raise ExLox.RuntimeError, message: "Undefined variable '#{name}'.", token: token
    end
  end
end
