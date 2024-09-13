defmodule ExLox.Environment do
  alias __MODULE__
  alias ExLox.Token
  alias ExLox.RuntimeError

  defstruct [:enclosing, values: %{}]

  def new() do
    %Environment{values: %{"clock" => %ExLox.Globals.Clock{}}}
  end

  def new(%Environment{} = enclosing), do: %Environment{enclosing: enclosing}

  def define(%Environment{} = env, %Token{type: :identifier, lexeme: name}, value) do
    %{env | values: Map.put(env.values, name, value)}
  end

  def assign(%Environment{} = env, %Token{type: :identifier, lexeme: name} = token, value) do
    case env.values do
      %{^name => _old_value} ->
        %{env | values: Map.put(env.values, name, value)}

      _ ->
        if env.enclosing do
          %{env | enclosing: assign(env.enclosing, token, value)}
        else
          raise RuntimeError, message: "Undefined variable '#{name}'.", token: token
        end
    end
  end

  def get(%Environment{} = env, %Token{type: :identifier, lexeme: name} = token) do
    case env.values do
      %{^name => value} ->
        value

      _ ->
        if env.enclosing do
          get(env.enclosing, token)
        else
          raise RuntimeError, message: "Undefined variable '#{name}'.", token: token
        end
    end
  end
end
