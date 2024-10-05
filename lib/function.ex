defimpl ExLox.Callable, for: ExLox.Stmt.Function do
  alias ExLox.Stmt.Function
  alias ExLox.Environment
  alias ExLox.Token
  alias ExLox.Interpreter.Interpretable

  def arity(%Function{} = function), do: length(function.params)

  def call(%Function{params: params, body: body}, arguments, env) do
    call_env =
      Enum.zip_reduce(params, arguments, Environment.new(env), fn
        %Token{} = param, arg, env -> Environment.define(env, param, arg)
      end)

    try do
      {nil, Interpretable.evaluate(body, call_env)}
    rescue
      r in ExLox.Interpreter.Return ->
        {r.value, env}
    end
  end
end

defimpl String.Chars, for: ExLox.Stmt.Function do
  def to_string(%ExLox.Stmt.Function{name: name}) do
    "<fn #{name.lexeme}>"
  end
end
