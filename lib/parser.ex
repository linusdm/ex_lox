defmodule ExLox.Parser do
  alias __MODULE__
  alias ExLox.{Token, Expr, Stmt}

  @enforce_keys [:tokens, :status]
  defstruct [:tokens, :status]

  defmodule ParseError do
    defexception [:message, :parser]
  end

  def parse(tokens, status \\ :ok) do
    {parser, statements} = parse_recursive(%Parser{tokens: tokens, status: status})
    {parser.status, Enum.reverse(statements)}
  end

  defp parse_recursive(%Parser{} = parser, statements \\ []) do
    {parser, stmt} = declaration(parser)
    statements = if stmt, do: [stmt | statements], else: statements

    case parser.tokens do
      [%Token{type: :eof}] -> {parser, statements}
      _ -> parse_recursive(parser, statements)
    end
  end

  defp declaration(%Parser{} = parser) do
    try do
      case parser do
        %Parser{tokens: [%Token{type: :var} | rest]} ->
          parser |> with_tokens(rest) |> var_declaration()

        parser ->
          statement(parser)
      end
    rescue
      e in ParseError ->
        %{parser: %Parser{tokens: [token | _rest]} = parser} = e
        ExLox.error_at_token(token, e.message)
        {parser |> with_error() |> synchronize(), nil}
    end
  end

  @start_of_statement_types [:class, :for, :fun, :if, :print, :return, :var, :while]
  defp synchronize(%Parser{} = parser) do
    case parser.tokens do
      [%Token{type: :semicolon} | rest] -> parser |> with_tokens(rest)
      [%Token{type: type} | _rest] when type in @start_of_statement_types -> parser
      [%Token{type: :eof}] -> parser
      [_skipped_token | rest] -> parser |> with_tokens(rest) |> synchronize()
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
      %Parser{tokens: [%Token{type: :print} | rest]} ->
        parser |> with_tokens(rest) |> print_statement()

      parser ->
        expression_statement(parser)
    end
  end

  defp print_statement(parser) do
    {parser, expr} = expression(parser)
    {parser, _token} = consume_token(parser, :semicolon, "Expect ';' after value.")
    {parser, %Stmt.Print{value: expr}}
  end

  defp expression_statement(parser) do
    {parser, expr} = expression(parser)
    {parser, _token} = consume_token(parser, :semicolon, "Expect ';' after expression.")
    {parser, %Stmt.Expression{expression: expr}}
  end

  defp expression(%Parser{} = parser) do
    equality(parser)
  end

  @binary_rules equality: [:bang_equal, :equal_equal],
                comparison: [:greater, :greater_equal, :less, :less_equal],
                term: [:minus, :plus],
                factor: [:slash, :star]

  for {rule, token_types} <- @binary_rules do
    rules = Keyword.keys(@binary_rules)
    rule_index = Enum.find_index(rules, &(&1 == rule))
    next_rule = Enum.at(rules, rule_index + 1, :unary)

    defp unquote(rule)(%Parser{} = parser) do
      # It's impossible to call an anonymous function recursively by name.
      # This trick allows to call the passed in anonymous function recursively.
      # I don't know how I feel about this...
      recur = fn
        %{tokens: [token | rest]} = parser, expr, recur when token.type in unquote(token_types) ->
          {right_parser, right_expr} = parser |> with_tokens(rest) |> unquote(next_rule)()
          expr = %Expr.Binary{left: expr, operator: token, right: right_expr}
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
        primary(parser)
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
