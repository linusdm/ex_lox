defmodule ExLox.Resolver do
  alias __MODULE__

  defstruct scopes: [], status: :ok, current_function_type: nil

  defprotocol Resolvable do
    @spec resolve(t, Resolver.t()) :: Resolver.t()
    def resolve(expr_or_stmt, resolver)
  end

  defmodule Util do
    def begin_scope(%Resolver{scopes: scopes} = resolver) do
      %Resolver{resolver | scopes: [%{} | scopes]}
    end

    def end_scope(%Resolver{scopes: scopes} = resolver) do
      %Resolver{resolver | scopes: tl(scopes)}
    end

    def resolve_statements(%Resolver{} = resolver, statements) do
      for statement <- statements, reduce: resolver do
        acc -> Resolvable.resolve(statement, acc)
      end
    end

    def declare(%Resolver{scopes: scopes} = resolver, %ExLox.Token{} = token) do
      case scopes do
        [] ->
          resolver

        [hd | tl] ->
          resolver =
            if Map.has_key?(hd, token.lexeme) do
              ExLox.error_at_token(token, "Already a variable with this name in this scope.")
              %Resolver{resolver | status: :error}
            else
              resolver
            end

          %Resolver{resolver | scopes: [Map.put(hd, token.lexeme, false) | tl]}
      end
    end

    def define(%Resolver{scopes: scopes} = resolver, %ExLox.Token{} = token) do
      case scopes do
        [] -> resolver
        [hd | tl] -> %Resolver{resolver | scopes: [Map.put(hd, token.lexeme, true) | tl]}
      end
    end

    def resolve_function(
          %Resolver{} = resolver,
          %ExLox.Stmt.Function{params: params, body: body},
          function_type
        ) do
      enclosing_function_type = resolver.current_function_type

      resolver
      |> with_current_function_type(function_type)
      |> begin_scope()
      |> then(fn resolver ->
        for %ExLox.Token{} = param <- params, reduce: resolver do
          acc -> acc |> declare(param) |> define(param)
        end
      end)
      |> Util.resolve_statements(body)
      |> end_scope()
      |> with_current_function_type(enclosing_function_type)
    end

    defp with_current_function_type(%Resolver{} = resolver, type) do
      %Resolver{resolver | current_function_type: type}
    end

    def resolve(%Resolver{} = resolver, expr_or_stmt) do
      Resolvable.resolve(expr_or_stmt, resolver)
    end
  end

  def resolve(statements) do
    %Resolver{status: status} = Enum.reduce(statements, %Resolver{}, &Resolvable.resolve/2)
    status
  end

  defimpl Resolvable, for: ExLox.Stmt.Block do
    def resolve(%ExLox.Stmt.Block{statements: statements}, resolver) do
      resolver
      |> Util.begin_scope()
      |> Util.resolve_statements(statements)
      |> Util.end_scope()
    end
  end

  defimpl Resolvable, for: ExLox.Expr.Literal do
    def resolve(%ExLox.Expr.Literal{} = _expr, resolver) do
      resolver
    end
  end

  defimpl Resolvable, for: ExLox.Expr.Logical do
    def resolve(%ExLox.Expr.Logical{} = expr, resolver) do
      resolver
      |> Util.resolve(expr.left)
      |> Util.resolve(expr.right)
    end
  end

  defimpl Resolvable, for: ExLox.Expr.Grouping do
    def resolve(%ExLox.Expr.Grouping{} = expr, resolver) do
      Util.resolve(resolver, expr.expression)
    end
  end

  defimpl Resolvable, for: ExLox.Expr.Unary do
    def resolve(%ExLox.Expr.Unary{} = expr, resolver) do
      Util.resolve(resolver, expr.right)
    end
  end

  defimpl Resolvable, for: ExLox.Expr.Binary do
    def resolve(%ExLox.Expr.Binary{} = expr, resolver) do
      resolver
      |> Util.resolve(expr.left)
      |> Util.resolve(expr.right)
    end

    defimpl Resolvable, for: ExLox.Expr.Call do
      def resolve(%ExLox.Expr.Call{} = expr, resolver) do
        Util.resolve(resolver, expr.callee)

        Enum.reduce(expr.arguments, resolver, fn argument, acc ->
          Util.resolve(acc, argument)
        end)
      end
    end

    defimpl Resolvable, for: ExLox.Expr.Variable do
      def resolve(%ExLox.Expr.Variable{} = expr, resolver) do
        lexeme = expr.name.lexeme

        case resolver do
          %Resolver{scopes: [%{^lexeme => false} | _]} ->
            ExLox.error_at_token(expr.name, "Can't read local variable in its own initializer.")
            %Resolver{resolver | status: :error}

          _ ->
            resolver
        end
      end
    end

    defimpl Resolvable, for: ExLox.Expr.Assign do
      def resolve(%ExLox.Expr.Assign{} = expr, resolver) do
        Util.resolve(resolver, expr.value)
      end
    end

    defimpl Resolvable, for: ExLox.Stmt.Expression do
      def resolve(%ExLox.Stmt.Expression{} = expr, resolver) do
        Util.resolve(resolver, expr.expression)
      end
    end

    defimpl Resolvable, for: ExLox.Stmt.If do
      def resolve(%ExLox.Stmt.If{} = stmt, resolver) do
        resolver
        |> Util.resolve(stmt.condition)
        |> Util.resolve(stmt.then_branch)
        |> then(fn resolver ->
          if stmt.else_branch do
            Util.resolve(resolver, stmt.else_branch)
          else
            resolver
          end
        end)
      end
    end

    defimpl Resolvable, for: ExLox.Stmt.Print do
      def resolve(%ExLox.Stmt.Print{} = stmt, resolver) do
        Util.resolve(resolver, stmt.expression)
      end
    end

    defimpl Resolvable, for: ExLox.Stmt.Return do
      def resolve(%ExLox.Stmt.Return{} = stmt, resolver) do
        resolver =
          if resolver.current_function_type == nil do
            ExLox.error_at_token(stmt.keyword, "Can't return from top-level code.")
            %Resolver{resolver | status: :error}
          else
            resolver
          end

        if stmt.value do
          Util.resolve(resolver, stmt.value)
        else
          resolver
        end
      end
    end

    defimpl Resolvable, for: ExLox.Stmt.While do
      def resolve(%ExLox.Stmt.While{} = stmt, resolver) do
        resolver
        |> Util.resolve(stmt.condition)
        |> Util.resolve(stmt.body)
      end
    end

    defimpl Resolvable, for: ExLox.Stmt.Var do
      def resolve(%ExLox.Stmt.Var{} = stmt, resolver) do
        resolver
        |> Util.declare(stmt.name)
        |> then(fn resolver ->
          if stmt.initializer do
            Util.resolve(resolver, stmt.initializer)
          else
            resolver
          end
        end)
        |> Util.define(stmt.name)
      end
    end

    defimpl Resolvable, for: ExLox.Stmt.Function do
      def resolve(%ExLox.Stmt.Function{} = stmt, resolver) do
        resolver
        |> Util.declare(stmt.name)
        |> Util.define(stmt.name)
        |> Util.resolve_function(stmt, :function)
      end
    end
  end
end
