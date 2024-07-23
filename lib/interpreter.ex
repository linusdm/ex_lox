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
  end

  def interpret(expression) do
    try do
      {:ok, Interpretable.evaluate(expression)}
    rescue
      e in RuntimeError ->
        ExLox.runtime_error(e)
        :error
    end
    |> case do
      {:ok, value} = result ->
        value |> stringify() |> IO.puts()
        result

      :error ->
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
    import Interpreter.Util

    def evaluate(%ExLox.Expr.Unary{} = expr) do
      right = Interpretable.evaluate(expr.right)

      case expr.operator.type do
        :minus ->
          check_number_operand(expr.operator, right)
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
    import Interpreter.Util

    def evaluate(%ExLox.Expr.Binary{} = expr) do
      left = Interpretable.evaluate(expr.left)
      right = Interpretable.evaluate(expr.right)

      case expr.operator.type do
        :bang_equal ->
          left != right

        :equal_equal ->
          left == right

        :greater ->
          check_number_operands(expr.operator, left, right)
          left > right

        :greater_equal ->
          check_number_operands(expr.operator, left, right)
          left >= right

        :less ->
          check_number_operands(expr.operator, left, right)
          left < right

        :less_equal ->
          check_number_operands(expr.operator, left, right)
          left <= right

        :minus ->
          check_number_operands(expr.operator, left, right)
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
          check_number_operands(expr.operator, left, right)

          # TODO: division by zero evaluates to NaN in jlox, and NaN == NaN (_not_ IEEE 754 compliant)
          #       see page 103 (sidebar)
          #       now this throws an ArithmeticError
          left / right

        :star ->
          check_number_operands(expr.operator, left, right)
          left * right
      end
    end
  end

  defp stringify(value) do
    cond do
      value == nil -> "nil"
      is_number(value) -> String.trim_trailing("#{value}", ".0")
      true -> "#{value}"
    end
  end
end
