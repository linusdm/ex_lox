defmodule ExLox.Parser do
  alias __MODULE__
  alias ExLox.{Token, Expr, Stmt}

  @enforce_keys [:tokens, :status]
  defstruct [:tokens, :status]

  defmodule ParseError do
    defexception [:message, :parser]
  end

  def parse(tokens, status \\ :ok) do
    case parse_recursive(%Parser{tokens: tokens, status: status}) do
      {%Parser{status: :ok}, statements} -> {:ok, Enum.reverse(statements)}
      {%Parser{status: :error}, _ignored} -> :error
    end
  end

  defp parse_recursive(parser, statements \\ [])

  defp parse_recursive(%Parser{tokens: [%Token{type: :eof}]} = parser, statements) do
    {parser, statements}
  end

  defp parse_recursive(%Parser{} = parser, statements) do
    {parser, stmt} = declaration(parser)
    parse_recursive(parser, [stmt | statements])
  end

  defp declaration(%Parser{} = parser) do
    try do
      case parser do
        %Parser{tokens: [%Token{type: :fun} | rest]} ->
          parser |> with_tokens(rest) |> function("function")

        %Parser{tokens: [%Token{type: :var} | rest]} ->
          parser |> with_tokens(rest) |> var_declaration()

        parser ->
          statement(parser)
      end
    rescue
      e in ParseError ->
        %{parser: %Parser{tokens: [token | _rest]} = parser} = e
        ExLox.error_at_token(token, e.message)
        {parser |> with_error() |> synchronize(), :statement_with_parse_error}
    end
  end

  @start_of_statement_types [:class, :for, :fun, :if, :print, :return, :var, :while]
  defp synchronize(%Parser{} = parser) do
    case parser.tokens do
      [%Token{type: :semicolon} | rest] ->
        parser |> with_tokens(rest)

      [_skipped, token | rest] when token.type in @start_of_statement_types ->
        parser |> with_tokens([token | rest])

      [%Token{type: :eof} = eof] ->
        parser |> with_tokens([eof])

      [_skipped | rest] ->
        parser |> with_tokens(rest) |> synchronize()
    end
  end

  defp var_declaration(%Parser{} = parser) do
    {parser, name} = consume_token(parser, :identifier, "Expect variable name.")

    {parser, initializer} =
      case parser do
        %Parser{tokens: [%Token{type: :equal} | rest]} ->
          parser |> with_tokens(rest) |> expression()

        _ ->
          {parser, nil}
      end

    {parser, _token} = consume_token(parser, :semicolon, "Expect ';' after variable declaration.")
    {parser, %Stmt.Var{name: name, initializer: initializer}}
  end

  defp statement(%Parser{} = parser) do
    case parser do
      %Parser{tokens: [%Token{type: :for} | rest]} ->
        parser |> with_tokens(rest) |> for_statement()

      %Parser{tokens: [%Token{type: :if} | rest]} ->
        parser |> with_tokens(rest) |> if_statement()

      %Parser{tokens: [%Token{type: :print} | rest]} ->
        parser |> with_tokens(rest) |> print_statement()

      %Parser{tokens: [%Token{type: :while} | rest]} ->
        parser |> with_tokens(rest) |> while_statement()

      %Parser{tokens: [%Token{type: :left_brace} | rest]} ->
        {parser, statements} = parser |> with_tokens(rest) |> block()
        {parser, %Stmt.Block{statements: statements}}

      parser ->
        expression_statement(parser)
    end
  end

  defp for_statement(%Parser{} = parser) do
    {parser, _token} = consume_token(parser, :left_paren, "Expect '(' after 'for'.")

    {parser, initializer} =
      case parser do
        %Parser{tokens: [%Token{type: :semicolon} | rest]} ->
          {with_tokens(parser, rest), nil}

        %Parser{tokens: [%Token{type: :var} | rest]} ->
          parser |> with_tokens(rest) |> var_declaration()

        parser ->
          expression_statement(parser)
      end

    {parser, condition} =
      case parser do
        %Parser{tokens: [%Token{type: :semicolon} | _rest]} ->
          {parser, %Expr.Literal{value: true}}

        parser ->
          expression(parser)
      end

    {parser, _token} = consume_token(parser, :semicolon, "Expect ';' after loop condition.")

    {parser, increment} =
      case parser do
        %Parser{tokens: [%Token{type: :right_paren} | _rest]} ->
          {parser, nil}

        parser ->
          expression(parser)
      end

    {parser, _token} = consume_token(parser, :right_paren, "Expect ')' after for clauses.")

    {parser, body} = statement(parser)

    body =
      if increment do
        %Stmt.Block{statements: [body, %Stmt.Expression{expression: increment}]}
      else
        body
      end

    body = %Stmt.While{condition: condition, body: body}

    body =
      if initializer do
        %Stmt.Block{statements: [initializer, body]}
      else
        body
      end

    {parser, body}
  end

  defp if_statement(%Parser{} = parser) do
    {parser, _token} = consume_token(parser, :left_paren, "Expect '(' after 'if'.")
    {parser, condition} = expression(parser)
    {parser, _token} = consume_token(parser, :right_paren, "Expect ')' after if condition.")
    {parser, then_branch} = statement(parser)

    {parser, else_branch} =
      case parser do
        %Parser{tokens: [%Token{type: :else} | rest]} ->
          parser |> with_tokens(rest) |> statement()

        parser ->
          {parser, nil}
      end

    {parser, %Stmt.If{condition: condition, then_branch: then_branch, else_branch: else_branch}}
  end

  defp print_statement(%Parser{} = parser) do
    {parser, expr} = expression(parser)
    {parser, _token} = consume_token(parser, :semicolon, "Expect ';' after value.")
    {parser, %Stmt.Print{value: expr}}
  end

  defp while_statement(%Parser{} = parser) do
    {parser, _token} = consume_token(parser, :left_paren, "Expect '(' after 'while'.")
    {parser, condition} = expression(parser)
    {parser, _token} = consume_token(parser, :right_paren, "Expect ')' after condition.")
    {parser, body} = statement(parser)

    {parser, %Stmt.While{condition: condition, body: body}}
  end

  defp expression_statement(%Parser{} = parser) do
    {parser, expr} = expression(parser)
    {parser, _token} = consume_token(parser, :semicolon, "Expect ';' after expression.")
    {parser, %Stmt.Expression{expression: expr}}
  end

  defp function(%Parser{} = parser, kind) do
    {parser, name} = consume_token(parser, :identifier, "Expect #{kind} name.")
    {parser, _token} = consume_token(parser, :left_paren, "Expect '(' after #{kind} name.")

    {parser, params} = parameters(parser)

    {parser, _token} = consume_token(parser, :right_paren, "Expect ')' after parameters.")
    {parser, _token} = consume_token(parser, :left_brace, "Expect '{' before #{kind} body.")
    {parser, statements} = block(parser)
    body = %Stmt.Block{statements: statements}
    {parser, %Stmt.Function{name: name, params: params, body: body}}
  end

  defp parameters(parser, parameters \\ [])

  defp parameters(parser, []) do
    case parser do
      %Parser{tokens: [%Token{type: :right_paren} | _rest]} ->
        {parser, []}

      parser ->
        {parser, param} = consume_token(parser, :identifier, "Expect parameter name.")
        parameters(parser, [param])
    end
  end

  defp parameters(parser, parameters) do
    case parser do
      %Parser{tokens: [%Token{type: :right_paren} | _rest]} ->
        {parser, Enum.reverse(parameters)}

      %Parser{tokens: [%Token{type: :comma} | rest]} ->
        parser =
          if length(parameters) >= 255 do
            ExLox.error_at_token(hd(rest), "Can't have more than 255 parameters.")
            with_error(parser)
          else
            parser
          end

        {parser, param} =
          parser
          |> with_tokens(rest)
          |> consume_token(:identifier, "Expect parameter name.")

        parameters(parser, [param | parameters])

      parser ->
        {parser, Enum.reverse(parameters)}
    end
  end

  defp block(%Parser{} = parser) do
    parse_recursive = fn
      %Parser{tokens: [%Token{type: type} | _]} = parser, statements, _recur
      when type in [:eof, :right_brace] ->
        {parser, statements}

      parser, statements, recur ->
        {parser, stmt} = declaration(parser)
        recur.(parser, [stmt | statements], recur)
    end

    {parser, statements} = parse_recursive.(parser, [], parse_recursive)

    {parser, _token} = consume_token(parser, :right_brace, "Expect '}' after block.")
    {parser, Enum.reverse(statements)}
  end

  defp expression(%Parser{} = parser) do
    assignment(parser)
  end

  defp assignment(%Parser{} = parser) do
    {parser, expr} = or_(parser)

    case parser.tokens do
      [%Token{type: :equal} = equals | rest] ->
        {parser, value} = parser |> with_tokens(rest) |> assignment()

        case expr do
          %Expr.Variable{name: name} ->
            {parser, %Expr.Assign{name: name, value: value}}

          _ ->
            ExLox.error_at_token(equals, "Invalid assignment target.")
            {with_error(parser), expr}
        end

      _ ->
        {parser, expr}
    end
  end

  @binary_rules or_: {[:or], :and_, Expr.Logical},
                and_: {[:and], :equality, Expr.Logical},
                equality: {[:bang_equal, :equal_equal], :comparison, Expr.Binary},
                comparison: {[:greater, :greater_equal, :less, :less_equal], :term, Expr.Binary},
                term: {[:minus, :plus], :factor, Expr.Binary},
                factor: {[:slash, :star], :unary, Expr.Binary}

  for {rule, {token_types, next_rule, expr_struct}} <- @binary_rules do
    defp unquote(rule)(%Parser{} = parser) do
      # It's impossible to call an anonymous function recursively by name.
      # This trick allows to call the passed in anonymous function recursively.
      # I don't know how I feel about this...
      recur = fn
        %{tokens: [token | rest]} = parser, expr, recur when token.type in unquote(token_types) ->
          {right_parser, right_expr} = parser |> with_tokens(rest) |> unquote(next_rule)()
          expr = %unquote(expr_struct){left: expr, operator: token, right: right_expr}
          recur.(right_parser, expr, recur)

        parser, expr, _recur ->
          {parser, expr}
      end

      {parser, expr} = unquote(next_rule)(parser)
      recur.(parser, expr, recur)
    end
  end

  defp unary(%Parser{} = parser) do
    case parser do
      %Parser{tokens: [token | rest]} = parser when token.type in [:bang, :minus] ->
        {parser, expr} = parser |> with_tokens(rest) |> unary()
        {parser, %Expr.Unary{operator: token, right: expr}}

      parser ->
        call(parser)
    end
  end

  defp call(%Parser{} = parser) do
    {parser, expr} = primary(parser)

    recur = fn
      %Parser{tokens: [%Token{type: :left_paren} | rest]} = parser, expr, recur ->
        parser = with_tokens(parser, rest)
        {parser, expr} = finish_call(parser, expr)
        recur.(parser, expr, recur)

      parser, expr, _recur ->
        {parser, expr}
    end

    recur.(parser, expr, recur)
  end

  defp finish_call(parser, callee) do
    {parser, arguments} = arguments(parser)
    {parser, paren} = consume_token(parser, :right_paren, "Expect ')' after arguments.")
    {parser, %Expr.Call{callee: callee, paren: paren, arguments: arguments}}
  end

  defp arguments(parser, arguments \\ [])

  defp arguments(parser, []) do
    case parser do
      %Parser{tokens: [%Token{type: :right_paren} | _rest]} ->
        {parser, []}

      parser ->
        {parser, arg} = expression(parser)
        arguments(parser, [arg])
    end
  end

  defp arguments(parser, arguments) do
    case parser do
      %Parser{tokens: [%Token{type: :right_paren} | _rest]} ->
        {parser, Enum.reverse(arguments)}

      %Parser{tokens: [%Token{type: :comma} | rest]} ->
        parser =
          if length(arguments) >= 255 do
            ExLox.error_at_token(hd(rest), "Can't have more than 255 arguments.")
            with_error(parser)
          else
            parser
          end

        {parser, arg} = parser |> with_tokens(rest) |> expression()

        arguments(parser, [arg | arguments])

      parser ->
        {parser, Enum.reverse(arguments)}
    end
  end

  defp primary(%Parser{} = parser) do
    case parser.tokens do
      [%Token{type: type} | rest] when type in [nil, false, true] ->
        {with_tokens(parser, rest), %Expr.Literal{value: type}}

      [%Token{type: type, literal: literal} | rest] when type in [:number, :string] ->
        {with_tokens(parser, rest), %Expr.Literal{value: literal}}

      [%Token{type: :identifier} = name | rest] ->
        {with_tokens(parser, rest), %Expr.Variable{name: name}}

      [%Token{type: :left_paren} | rest] ->
        {parser, expr} = parser |> with_tokens(rest) |> expression()
        {parser, _token} = consume_token(parser, :right_paren, "Expect ')' after expression.")
        {parser, %Expr.Grouping{expression: expr}}

      _tokens ->
        raise ParseError, message: "Expect expression.", parser: parser
    end
  end

  defp consume_token(%Parser{} = parser, token_type, error_msg) do
    case parser do
      %Parser{tokens: [%Token{type: ^token_type} = token | rest]} ->
        {with_tokens(parser, rest), token}

      parser ->
        raise ParseError, message: error_msg, parser: parser
    end
  end

  defp with_tokens(%Parser{} = parser, tokens), do: %{parser | tokens: tokens}
  defp with_error(%Parser{} = parser), do: %{parser | status: :error}
end
