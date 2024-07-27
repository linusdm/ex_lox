defmodule ExLox.Parser do
  alias ExLox.Parser
  alias ExLox.Token
  alias ExLox.Expr.{Binary, Literal, Unary, Grouping}

  # tokens wrapped in a struct, because I suspect there will be more data that needs to be passed
  # down the parser (e.g. status)
  defstruct [:tokens]

  defmodule ParseError do
    defexception [:message, :token]
  end

  def parse(tokens) do
    try do
      {_, expr} = expression(%Parser{tokens: tokens})
      {:ok, expr}
    rescue
      e in ParseError ->
        ExLox.error_at_token(e.token, e.message)
        :error
    end
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
          expr = %Binary{left: expr, operator: token, right: right_expr}
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
        {parser, %Unary{operator: token, right: expr}}

      parser ->
        primary(parser)
    end
  end

  defp primary(%Parser{} = parser) do
    case parser.tokens do
      [%Token{type: type} | rest] when type in [nil, false, true] ->
        {with_tokens(parser, rest), %Literal{value: type}}

      [%Token{type: type, literal: literal} | rest] when type in [:number, :string] ->
        {with_tokens(parser, rest), %Literal{value: literal}}

      [%Token{type: :left_paren} | rest] ->
        parser
        |> with_tokens(rest)
        |> expression()
        |> case do
          {%Parser{tokens: [%Token{type: :right_paren} | rest]} = parser, expr} ->
            {with_tokens(parser, rest), %Grouping{expression: expr}}

          {%Parser{tokens: [%Token{} = token | _rest]}, _expr} ->
            raise ParseError, message: "Expect ')' after expression.", token: token
        end

      [token | _rest] ->
        raise ParseError, message: "Expect expression.", token: token
    end
  end

  defp with_tokens(%Parser{} = parser, tokens), do: %{parser | tokens: tokens}
end
