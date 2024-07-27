defmodule ExLox.Interpreter do
  alias __MODULE__

  defprotocol Interpretable do
    @spec evaluate(t) :: any()
    def evaluate(expression)
  end

  defmodule RuntimeError do
    defexception [:message, :token]
  end

  defmodule Util do
    def check_number_operand(operator, operand) do
      if not is_number(operand) do
        raise Interpreter.RuntimeError, message: "Operand must be a number.", token: operator
      end
    end

    def check_number_operands(operator, left_operand, right_operand) do
      unless is_number(left_operand) and is_number(right_operand) do
        raise Interpreter.RuntimeError, message: "Operands must be numbers.", token: operator
      end
    end

    def stringify(value) do
      cond do
        value == nil -> "nil"
        is_number(value) -> String.trim_trailing("#{value}", ".0")
        true -> "#{value}"
      end
    end
  end

  def interpret(statements) do
    try do
      Enum.each(statements, &Interpretable.evaluate/1)
    rescue
      e in RuntimeError ->
        ExLox.runtime_error(e)
        :error
    end
  end

  defimpl Interpretable, for: ExLox.Expr.Literal do
    def evaluate(%ExLox.Expr.Literal{value: value}) do
      value
    end
  end

  defimpl Interpretable, for: ExLox.Expr.Grouping do
    def evaluate(%ExLox.Expr.Grouping{expression: expression}) do
      Interpretable.evaluate(expression)
    end
  end

  defimpl Interpretable, for: ExLox.Expr.Unary do
    def evaluate(%ExLox.Expr.Unary{} = expr) do
      right = Interpretable.evaluate(expr.right)

      case expr.operator.type do
        :minus ->
          Util.check_number_operand(expr.operator, right)
          -right

        :bang ->
          not is_truthy(right)
      end
    end

    defp is_truthy(nil), do: false
    defp is_truthy(bool) when is_boolean(bool), do: bool
    defp is_truthy(_), do: true
  end

  defimpl Interpretable, for: ExLox.Expr.Binary do
    def evaluate(%ExLox.Expr.Binary{} = expr) do
      left = Interpretable.evaluate(expr.left)
      right = Interpretable.evaluate(expr.right)

      case expr.operator.type do
        :bang_equal ->
          left != right

        :equal_equal ->
          left == right

        :greater ->
          Util.check_number_operands(expr.operator, left, right)
          left > right

        :greater_equal ->
          Util.check_number_operands(expr.operator, left, right)
          left >= right

        :less ->
          Util.check_number_operands(expr.operator, left, right)
          left < right

        :less_equal ->
          Util.check_number_operands(expr.operator, left, right)
          left <= right

        :minus ->
          Util.check_number_operands(expr.operator, left, right)
          left - right

        :plus ->
          cond do
            is_number(left) and is_number(right) ->
              left + right

            is_binary(left) and is_binary(right) ->
              left <> right

            true ->
              raise Interpreter.RuntimeError,
                message: "Operands must be two numbers or two strings.",
                token: expr.operator
          end

        :slash ->
          Util.check_number_operands(expr.operator, left, right)

          # TODO: division by zero evaluates to NaN in jlox, and NaN == NaN (_not_ IEEE 754 compliant)
          #       see page 103 (sidebar)
          #       now this throws an ArithmeticError
          left / right

        :star ->
          Util.check_number_operands(expr.operator, left, right)
          left * right
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Expression do
      def evaluate(%ExLox.Stmt.Expression{expression: expression}) do
        Interpretable.evaluate(expression)
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Print do
      def evaluate(%ExLox.Stmt.Print{value: value}) do
        value |> Interpretable.evaluate() |> Util.stringify() |> IO.puts()
      end
    end
  end
end
