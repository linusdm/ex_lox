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
  alias ExLox.Expr.Binary
  alias ExLox.Token

  def print(%Binary{operator: %Token{} = operator, left: left, right: right}) do
    ExLox.AstPrintable.Util.parenthesize(operator.lexeme, [left, right])
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Grouping do
  alias ExLox.Expr.Grouping

  def print(%Grouping{expression: expression}) do
    ExLox.AstPrintable.Util.parenthesize("group", [expression])
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Literal do
  alias ExLox.Expr.Literal

  def print(%Literal{value: value}) do
    if value == nil, do: "nil", else: value
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Unary do
  alias ExLox.Expr.Unary
  alias ExLox.Token

  def print(%Unary{operator: %Token{} = operator, right: right}) do
    ExLox.AstPrintable.Util.parenthesize(operator.lexeme, right)
  end
end
