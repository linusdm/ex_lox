defprotocol ExLox.AstPrintable do
  @spec to_string(t) :: String.t()
  def to_string(expression)
end

defmodule ExLox.AstPrintable.Util do
  def parenthesize(name, expressions) do
    args = Enum.map(expressions, &ExLox.AstPrintable.to_string(&1))
    "(#{name} #{Enum.join(args, " ")})"
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Binary do
  alias ExLox.Expr.Binary
  alias ExLox.Token

  def to_string(%Binary{operator: %Token{} = operator, left: left, right: right}) do
    ExLox.AstPrintable.Util.parenthesize(operator.lexeme, [left, right])
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Grouping do
  alias ExLox.Expr.Grouping

  def to_string(%Grouping{expression: expression}) do
    ExLox.AstPrintable.Util.parenthesize("group", [expression])
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Literal do
  alias ExLox.Expr.Literal

  def to_string(%Literal{value: value}) do
    if value == nil, do: "nil", else: value
  end
end

defimpl ExLox.AstPrintable, for: ExLox.Expr.Unary do
  alias ExLox.Expr.Unary
  alias ExLox.Token

  def to_string(%Unary{operator: %Token{} = operator, right: right}) do
    ExLox.AstPrintable.Util.parenthesize(operator.lexeme, [right])
  end
end
