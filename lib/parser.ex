defmodule ExLox.Parser do
  alias ExLox.Parser
  alias ExLox.Token
  alias ExLox.Expr
  alias ExLox.Stmt

  # tokens wrapped in a struct, because I suspect there will be more data that needs to be passed
  # down the parser (e.g. status)
  defstruct [:tokens]

  defmodule ParseError do
    defexception [:message, :token]
  end

  def parse(tokens) when is_list(tokens) do
    parse(%Parser{tokens: tokens})
  end

  def parse(%Parser{} = parser, statements \\ []) do
    try do
      case statement(parser) do
        {%Parser{tokens: [_]}, stmt} -> {:ok, Enum.reverse([stmt | statements])}
        {parser, stmt} -> parse(parser, [stmt | statements])
      end
    rescue
      e in ParseError ->
        ExLox.error_at_token(e.token, e.message)
        :error
    end
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
    parser = consume_token(parser, :semicolon, "Expect ';' after value.")
    {parser, %Stmt.Print{value: expr}}
  end

  defp expression_statement(parser) do
    {parser, expr} = expression(parser)
    parser = consume_token(parser, :semicolon, "Expect ';' after expression.")
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

      [%Token{type: :left_paren} | rest] ->
        {parser, expr} = parser |> with_tokens(rest) |> expression()
        parser = consume_token(parser, :left_paren, "Expect ')' after expression.")
        {parser, %Expr.Grouping{expression: expr}}

      [token | _rest] ->
        raise ParseError, message: "Expect expression.", token: token
    end
  end

  defp consume_token(%Parser{} = parser, token_type, error_msg) do
    case parser do
      %Parser{tokens: [%Token{type: ^token_type} | rest]} ->
        with_tokens(parser, rest)

      %Parser{tokens: [token | _]} ->
        raise ParseError, message: error_msg, token: token
    end
  end

  defp with_tokens(%Parser{} = parser, tokens), do: %{parser | tokens: tokens}
end
