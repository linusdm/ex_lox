defprotocol ExLox.Callable do
  @spec arity(t) :: non_neg_integer()
  def arity(callee)

  @spec call(t, [any()]) :: any()
  def call(callee, arguments)
end
