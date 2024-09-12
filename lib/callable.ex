defprotocol ExLox.Callable do
  @spec arity(t) :: non_neg_integer()
  def arity(callee)

  @spec call(t, [any()], Environment.t()) :: {any(), Environment.t()}
  def call(callee, arguments, env)
end
