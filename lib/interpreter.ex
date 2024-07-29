defmodule ExLox.Interpreter do
  alias ExLox.RuntimeError
  alias ExLox.Environment

  defprotocol Interpretable do
    @spec evaluate(t, Environment.t()) :: {any(), Environment.t()} | Environment.t()
    def evaluate(expression, env)
  end

  defmodule Util do
    def check_number_operand(operator, operand) do
      if not is_number(operand) do
        raise RuntimeError, message: "Operand must be a number.", token: operator
      end
    end

    def check_number_operands(operator, left_operand, right_operand) do
      unless is_number(left_operand) and is_number(right_operand) do
        raise RuntimeError, message: "Operands must be numbers.", token: operator
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

  def interpret(statements, env) do
    try do
      env = Enum.reduce(statements, env, &Interpretable.evaluate/2)
      {:ok, env}
    rescue
      e in RuntimeError ->
        ExLox.runtime_error(e)
        :error
    end
  end

  defimpl Interpretable, for: ExLox.Expr.Literal do
    def evaluate(%ExLox.Expr.Literal{value: value}, env) do
      {value, env}
    end
  end

  defimpl Interpretable, for: ExLox.Expr.Grouping do
    def evaluate(%ExLox.Expr.Grouping{expression: expression}, env) do
      Interpretable.evaluate(expression, env)
    end
  end

  defimpl Interpretable, for: ExLox.Expr.Unary do
    def evaluate(%ExLox.Expr.Unary{} = expr, env) do
      {right, env} = Interpretable.evaluate(expr.right, env)

      case expr.operator.type do
        :minus ->
          Util.check_number_operand(expr.operator, right)
          {-right, env}

        :bang ->
          {not is_truthy(right), env}
      end
    end

    defp is_truthy(nil), do: false
    defp is_truthy(bool) when is_boolean(bool), do: bool
    defp is_truthy(_), do: true
  end

  defimpl Interpretable, for: ExLox.Expr.Binary do
    def evaluate(%ExLox.Expr.Binary{} = expr, env) do
      {left, env} = Interpretable.evaluate(expr.left, env)
      {right, env} = Interpretable.evaluate(expr.right, env)

      result =
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
                raise RuntimeError,
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

      {result, env}
    end

    defimpl Interpretable, for: ExLox.Expr.Variable do
      def evaluate(%ExLox.Expr.Variable{} = expr, env) do
        {Environment.get(env, expr.name), env}
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Expression do
      def evaluate(%ExLox.Stmt.Expression{expression: expression}, env) do
        {_result, env} = Interpretable.evaluate(expression, env)
        env
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Print do
      def evaluate(%ExLox.Stmt.Print{value: value}, env) do
        {result, env} = Interpretable.evaluate(value, env)
        result |> Util.stringify() |> IO.puts()
        env
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Var do
      def evaluate(%ExLox.Stmt.Var{name: name, initializer: initializer}, env) do
        {value, env} =
          if initializer, do: Interpretable.evaluate(initializer, env), else: {nil, env}

        Environment.define(env, name, value)
      end
    end
  end
end
