defmodule ExLox.Parser do
  alias ExLox.Parser
  alias ExLox.Token
  alias ExLox.Expr.{Binary, Literal, Unary, Grouping}

  defstruct [:tokens, :status, :expression]

  def parse(tokens, status) do
    %Parser{tokens: tokens, status: status} |> expression() |> unwrap_result()
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
      # It's impossible to call an anonymous function, recursively.
      # This trick allows you to call the function if you pass it in explicitly.
      # I don't know how I feel about this...
      recur = fn
        %Parser{tokens: [token | rest]} = parser, recur when token.type in unquote(token_types) ->
          right_parser = parser |> with_tokens(rest) |> unquote(next_rule)()
          exp = %Binary{left: parser.expression, operator: token, right: right_parser.expression}
          right_parser |> with_expression(exp) |> recur.(recur)

        parser, _recur ->
          parser
      end

      parser |> unquote(next_rule)() |> recur.(recur)
    end
  end

  defp unary(%Parser{} = parser) do
    case parser do
      %Parser{tokens: [token | rest]} = parser when token.type in [:bang, :minus] ->
        right_parser = parser |> with_tokens(rest) |> unary()
        exp = %Unary{operator: token, right: right_parser.expression}
        right_parser |> with_expression(exp)

      parser ->
        primary(parser)
    end
  end

  defp primary(%Parser{} = parser) do
    case parser.tokens do
      [%Token{type: type} | rest] when type in [nil, false, true] ->
        parser |> with_tokens(rest) |> with_expression(%Literal{value: type})

      [%Token{type: type, literal: literal} | rest] when type in [:number, :string] ->
        parser |> with_tokens(rest) |> with_expression(%Literal{value: literal})

      [%Token{type: :left_paren} | rest] ->
        parser
        |> with_tokens(rest)
        |> expression()
        |> case do
          %Parser{tokens: [%Token{type: :right_paren} | rest]} = parser ->
            parser
            |> with_tokens(rest)
            |> with_expression(%Grouping{expression: parser.expression})

          %Parser{tokens: [%Token{} = token | rest]} = parser ->
            ExLox.error_at_token(token, "Expect ')' after expression.")
            parser |> with_tokens(rest) |> with_error()

            # TODO: maybe we're not supposed to keep going, when things go wrong... jlox throws at this point in the parser
        end

      [token | rest] ->
        ExLox.error_at_token(token, "Expect expression.")
        parser |> with_tokens(rest) |> with_error()

        # TODO: maybe we're not supposed to keep going, when things go wrong... jlox throws at this point in the parser
    end
  end

  defp with_tokens(%Parser{} = parser, tokens), do: %{parser | tokens: tokens}
  defp with_expression(%Parser{} = parser, expression), do: %{parser | expression: expression}
  defp with_error(%Parser{} = parser), do: %{parser | status: :error}
  defp unwrap_result(%Parser{status: :ok} = parser), do: {:ok, parser.expression}
  defp unwrap_result(%Parser{status: :error}), do: :error
end
