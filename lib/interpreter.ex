defmodule ExLox.Interpreter do
  alias ExLox.RuntimeError
  alias ExLox.Environment

  defprotocol Interpretable do
    @spec evaluate(t, Environment.t()) :: {any(), Environment.t()} | Environment.t()
    def evaluate(expression, env)
  end

  defmodule Return do
    defexception [:value]

    @impl true
    def message(%__MODULE__{value: value}) do
      "returning #{inspect(value)}"
    end
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

    def is_truthy(value), do: value not in [false, nil]
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

  defimpl Interpretable, for: ExLox.Expr.Logical do
    def evaluate(%ExLox.Expr.Logical{} = expr, env) do
      {left, env} = Interpretable.evaluate(expr.left, env)

      short_circuit? =
        case expr.operator.type do
          :or -> Util.is_truthy(left)
          :and -> not Util.is_truthy(left)
        end

      if short_circuit?, do: {left, env}, else: Interpretable.evaluate(expr.right, env)
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
          {not Util.is_truthy(right), env}
      end
    end
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

    defimpl Interpretable, for: ExLox.Expr.Call do
      def evaluate(%ExLox.Expr.Call{} = expr, env) do
        {callee, env} = Interpretable.evaluate(expr.callee, env)

        {arguments, env} =
          for arg <- expr.arguments, reduce: {[], env} do
            {args, env} ->
              {arg, env} = Interpretable.evaluate(arg, env)
              {[arg | args], env}
          end

        unless ExLox.Callable.impl_for(callee) do
          raise RuntimeError,
            message: "Can only call functions and classes.",
            token: expr.paren
        end

        unless ExLox.Callable.arity(callee) == length(arguments) do
          raise RuntimeError,
            message:
              "Expected #{ExLox.Callable.arity(callee)} arguments but got #{length(arguments)}.",
            token: expr.paren
        end

        {ExLox.Callable.call(callee, Enum.reverse(arguments)), env}
      end
    end

    defimpl Interpretable, for: ExLox.Expr.Variable do
      def evaluate(%ExLox.Expr.Variable{} = expr, env) do
        {Environment.get(env, expr.name), env}
      end
    end

    defimpl Interpretable, for: ExLox.Expr.Assign do
      def evaluate(%ExLox.Expr.Assign{} = expr, env) do
        {value, env} = Interpretable.evaluate(expr.value, env)
        {value, Environment.assign(env, expr.name, value)}
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Expression do
      def evaluate(%ExLox.Stmt.Expression{expression: expression}, env) do
        {_result, env} = Interpretable.evaluate(expression, env)
        env
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.If do
      def evaluate(%ExLox.Stmt.If{} = stmt, env) do
        {condition_value, env} = Interpretable.evaluate(stmt.condition, env)

        cond do
          Util.is_truthy(condition_value) ->
            Interpretable.evaluate(stmt.then_branch, env)

          stmt.else_branch ->
            Interpretable.evaluate(stmt.else_branch, env)

          true ->
            env
        end
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Print do
      def evaluate(%ExLox.Stmt.Print{value: value}, env) do
        {result, env} = Interpretable.evaluate(value, env)
        result |> Util.stringify() |> IO.puts()
        env
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Return do
      def evaluate(%ExLox.Stmt.Return{value: value}, env) do
        {value, _env} =
          case value do
            nil -> {nil, env}
            value -> Interpretable.evaluate(value, env)
          end

        raise Return, value: value
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.While do
      def evaluate(%ExLox.Stmt.While{condition: condition, body: body} = stmt, env) do
        {condition, env} = Interpretable.evaluate(condition, env)

        if Util.is_truthy(condition) do
          env = Interpretable.evaluate(body, env)
          Interpretable.evaluate(stmt, env)
        else
          env
        end
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Var do
      def evaluate(%ExLox.Stmt.Var{name: name, initializer: initializer}, env) do
        {value, env} =
          if initializer, do: Interpretable.evaluate(initializer, env), else: {nil, env}

        Environment.define(env, name, value)
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Block do
      def evaluate(%ExLox.Stmt.Block{statements: statements}, env) do
        env = Enum.reduce(statements, Environment.new(env), &Interpretable.evaluate/2)
        env.enclosing
      end
    end

    defimpl Interpretable, for: ExLox.Stmt.Function do
      def evaluate(%ExLox.Stmt.Function{} = stmt, env) do
        function = %ExLox.Function{stmt: stmt, closure: env}
        Environment.define(env, stmt.name, function)
      end
    end
  end
end
