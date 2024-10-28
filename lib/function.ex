defmodule ExLox.Function do
  @enforce_keys [:stmt, :closure]
  defstruct [:stmt, :closure]

  alias __MODULE__

  defimpl ExLox.Callable do
    alias ExLox.Environment
    alias ExLox.Interpreter.Interpretable

    def arity(%Function{stmt: stmt}), do: length(stmt.params)

    def call(%Function{} = function, arguments) do
      closure =
        Environment.new(function.closure)
        # This allows functions to call themselves.
        # Defining this function when interpreting the function definition doesn't work
        # as it would create a circular dependency between the function struct and the environment.
        |> Environment.define(function.stmt.name, function)

      call_env =
        Enum.zip_reduce(function.stmt.params, arguments, closure, fn
          param, arg, env -> Environment.define(env, param, arg)
        end)

      try do
        Enum.reduce(function.stmt.body, call_env, &Interpretable.evaluate/2)
        nil
      rescue
        r in ExLox.Interpreter.Return ->
          r.value
      end
    end
  end

  defimpl String.Chars do
    def to_string(%Function{stmt: stmt}) do
      "<fn #{stmt.name.lexeme}>"
    end
  end
end
