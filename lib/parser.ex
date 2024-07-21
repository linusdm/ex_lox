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

  defp equality(%Parser{} = parser) do
    parse_binary_expression(parser, [:bang_equal, :equal_equal], &comparison/1)
  end

  defp comparison(%Parser{} = parser) do
    parse_binary_expression(parser, [:greater, :greater_equal, :less, :less_equal], &term/1)
  end

  defp term(%Parser{} = parser) do
    parse_binary_expression(parser, [:minus, :plus], &factor/1)
  end

  defp factor(%Parser{} = parser) do
    parse_binary_expression(parser, [:slash, :star], &unary/1)
  end

  defp parse_binary_expression(parser, token_types, next_rule) do
    # It's impossible to call an anonymous function, recursively.
    # This trick allows you to call the function if you pass it in explicitly.
    # I don't know how I feel about this...
    recur = fn parser, recur ->
      %Parser{tokens: [token | rest]} = parser

      if token.type in token_types do
        right_parser = parser |> with_tokens(rest) |> next_rule.()
        exp = %Binary{left: parser.expression, operator: token, right: right_parser.expression}
        right_parser |> with_expression(exp) |> recur.(recur)
      else
        parser
      end
    end

    parser |> next_rule.() |> recur.(recur)
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
        end

      [token | rest] ->
        ExLox.error_at_token(token, "Expect expression.")
        parser |> with_tokens(rest) |> with_error()
    end
  end

  defp with_tokens(%Parser{} = parser, tokens), do: %{parser | tokens: tokens}
  defp with_expression(%Parser{} = parser, expression), do: %{parser | expression: expression}
  defp with_error(%Parser{} = parser), do: %{parser | status: :error}
  defp unwrap_result(%Parser{} = parser), do: {parser.status, parser.expression}
end
