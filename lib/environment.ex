defmodule ExLox.Environment do
  alias __MODULE__
  alias ExLox.Token
  alias ExLox.RuntimeError

  @enforce_keys [:id]
  defstruct [:id, :enclosing]

  def new() do
    id = :rand.uniform()
    Process.put(id, %{"clock" => %ExLox.Globals.Clock{}})
    %Environment{id: id}
  end

  def new(%Environment{} = enclosing), do: %Environment{id: :rand.uniform(), enclosing: enclosing}

  def define(%Environment{} = env, %Token{type: :identifier, lexeme: name}, value) do
    values = Process.get(env.id, %{}) |> Map.put(name, value)
    Process.put(env.id, values)
    env
  end

  def assign(%Environment{} = env, %Token{type: :identifier, lexeme: name} = token, value) do
    case Process.get(env.id, %{}) do
      %{^name => _old_value} = values ->
        values = values |> Map.put(name, value)
        Process.put(env.id, values)

      _ ->
        if env.enclosing do
          assign(env.enclosing, token, value)
        else
          raise RuntimeError, message: "Undefined variable '#{name}'.", token: token
        end
    end

    env
  end

  def get(%Environment{} = env, %Token{type: :identifier, lexeme: name} = token) do
    case Process.get(env.id, %{}) do
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
