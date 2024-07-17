defprotocol ExLox.AstPrintable do
  @spec print(t) :: String.t()
  def print(expression)
end

defmodule ExLox.AstPrintable.Util do
  def parenthesize(name, expressions) do
    args = Enum.map(expressions, &ExLox.AstPrintable.print(&1))
    "(#{name} #{Enum.join(args, " ")})"
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Binary do
  def print(binary) do
    ExLox.AstPrintable.Util.parenthesize(binary.operator.lexeme, [binary.left, binary.right])
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Grouping do
  def print(grouping) do
    ExLox.AstPrintable.Util.parenthesize("group", [grouping.expression])
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Literal do
  def print(%ExLox.Expr.Literal{value: value}) do
    if value == nil, do: "nil", else: value
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Unary do
  def print(%ExLox.Expr.Unary{operator: operator, right: right}) do
    ExLox.AstPrintable.Util.parenthesize(operator.lexeme, right)
  end
end
