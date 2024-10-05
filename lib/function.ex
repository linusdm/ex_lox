defmodule ExLox.Function do
  @enforce_keys [:stmt, :closure]
  defstruct [:stmt, :closure]

  defimpl ExLox.Callable do
    alias ExLox.Environment
    alias ExLox.Token
    alias ExLox.Interpreter.Interpretable

    def arity(%ExLox.Function{stmt: stmt}), do: length(stmt.params)

    def call(%ExLox.Function{stmt: stmt, closure: closure}, arguments) do
      %ExLox.Stmt.Function{params: params, body: body} = stmt

      call_env =
        Enum.zip_reduce(params, arguments, Environment.new(closure), fn
          %Token{} = param, arg, env -> Environment.define(env, param, arg)
        end)

      try do
        Interpretable.evaluate(body, call_env)
        nil
      rescue
        r in ExLox.Interpreter.Return ->
          r.value
      end
    end
  end

  defimpl String.Chars do
    def to_string(%ExLox.Function{stmt: stmt}) do
      "<fn #{stmt.name.lexeme}>"
    end
  end
end
