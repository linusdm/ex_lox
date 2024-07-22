defprotocol ExLox.Interpreter do
  @spec evaluate(t) :: any()
  def evaluate(expression)
end

defimpl ExLox.Interpreter, for: ExLox.Expr.Literal do
  def evaluate(%ExLox.Expr.Literal{value: value}) do
    value
  end
end

defimpl ExLox.Interpreter, for: ExLox.Expr.Grouping do
  def evaluate(%ExLox.Expr.Grouping{expression: expression}) do
    ExLox.Interpreter.evaluate(expression)
  end
end

defimpl ExLox.Interpreter, for: ExLox.Expr.Unary do
  def evaluate(%ExLox.Expr.Unary{} = expr) do
    right = ExLox.Interpreter.evaluate(expr.right)

    case expr.operator.type do
      :minus -> -right
      :bang -> not is_truthy(right)
    end
  end

  defp is_truthy(nil), do: false
  defp is_truthy(bool) when is_boolean(bool), do: bool
  defp is_truthy(_), do: true
end
