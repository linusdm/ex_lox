defmodule ExLox.AstPrintable do
  alias __MODULE__
  alias ExLox.Token
  alias ExLox.Expr.{Unary, Binary, Grouping, Literal}

  defimpl String.Chars, for: ExLox.Expr.Binary do
    def to_string(%Binary{operator: %Token{} = operator, left: left, right: right}) do
      AstPrintable.parenthesize(operator.lexeme, [left, right])
    end
  end

  defimpl String.Chars, for: ExLox.Expr.Grouping do
    def to_string(%Grouping{expression: expression}) do
      AstPrintable.parenthesize("group", [expression])
    end
  end

  defimpl String.Chars, for: ExLox.Expr.Literal do
    def to_string(%Literal{value: value}) do
      if value == nil, do: "nil", else: Kernel.to_string(value)
    end
  end

  defimpl String.Chars, for: ExLox.Expr.Unary do
    def to_string(%Unary{operator: %Token{} = operator, right: right}) do
      AstPrintable.parenthesize(operator.lexeme, [right])
    end
  end

  def parenthesize(name, expressions) do
    args = Enum.map(expressions, &Kernel.to_string(&1))
    "(#{name} #{Enum.join(args, " ")})"
  end
end
