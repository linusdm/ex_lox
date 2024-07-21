defmodule ExLox.Parser do
  alias ExLox.Parser
  alias ExLox.Token
  alias ExLox.Expr.{Literal, Binary, Unary}

  defstruct [:tokens, :status, :expression]

  def parse(tokens, status) do
    %Parser{tokens: tokens, status: status} |> expression() |> unwrap_result()
  end

  defp expression(%Parser{} = parser) do
    equality(parser)
  end

  @equality_token_types [:bang_equal, :equal_equal]
  defp equality(%Parser{} = parser) do
    # It's impossible to call an anonymous function, recursively.
    # This trick allows you to call the function if you pass it in explicitly.
    # I don't know how I feel about this...
    recur = fn
      %Parser{tokens: [token | rest]} = parser, recur when token.type in @equality_token_types ->
        right_parser = parser |> with_tokens(rest) |> comparison()
        exp = %Binary{left: parser.expression, operator: token, right: right_parser.expression}
        right_parser |> with_expression(exp) |> recur.(recur)

      parser, _recur ->
        parser
    end

    parser |> comparison() |> recur.(recur)
  end

  @comp_token_types [:greater, :greater_equal, :less, :less_equal]
  defp comparison(parser) do
    recur = fn
      %Parser{tokens: [token | rest]} = parser, recur when token.type in @comp_token_types ->
        right_parser = parser |> with_tokens(rest) |> term()
        exp = %Binary{left: parser.expression, operator: token, right: right_parser.expression}
        right_parser |> with_expression(exp) |> recur.(recur)

      parser, _recur ->
        parser
    end

    parser |> term() |> recur.(recur)
  end

  @term_token_types [:minus, :plus]
  defp term(parser) do
    recur = fn
      %Parser{tokens: [token | rest]} = parser, recur when token.type in @term_token_types ->
        right_parser = parser |> with_tokens(rest) |> factor()
        exp = %Binary{left: parser.expression, operator: token, right: right_parser.expression}
        right_parser |> with_expression(exp) |> recur.(recur)

      parser, _recur ->
        parser
    end

    parser |> factor() |> recur.(recur)
  end

  @factor_token_types [:slash, :star]
  defp factor(parser) do
    recur = fn
      %Parser{tokens: [token | rest]} = parser, recur when token.type in @factor_token_types ->
        right_parser = parser |> with_tokens(rest) |> unary()
        exp = %Binary{left: parser.expression, operator: token, right: right_parser.expression}
        right_parser |> with_expression(exp) |> recur.(recur)

      parser, _recur ->
        parser
    end

    parser |> unary() |> recur.(recur)
  end

  @unary_token_types [:bang, :minus]
  defp unary(%Parser{tokens: [token | rest]} = parser) when token.type in @unary_token_types do
    right_parser = parser |> with_tokens(rest) |> unary()
    exp = %Unary{operator: token, right: right_parser.expression}
    right_parser |> with_expression(exp)
  end

  defp unary(parser) do
    primary(parser)
  end

  defp primary(%Parser{} = parser) do
    case parser.tokens do
      [%Token{type: type} | rest] when type in [nil, false, true] ->
        parser |> with_expression(%Literal{value: type}) |> with_tokens(rest)

      [%Token{type: type, literal: literal} | rest] when type in [:number, :string] ->
        parser |> with_expression(%Literal{value: literal}) |> with_tokens(rest)

      # [%Token{type: :left_paren} | rest] ->
      #   case expression(rest, status) do
      #     {[%Token{type: :right_paren} | rest], expression} -> {status, rest, expression}
      #     [token | _] = tokens -> ExLox.error_at_token(token, "Expect ')' after expression.")
      #   end

      [token | rest] ->
        ExLox.error_at_token(token, "Expect expression.")
        parser |> with_error() |> with_tokens(rest)
    end
  end

  defp with_tokens(%Parser{} = parser, tokens), do: %{parser | tokens: tokens}
  defp with_expression(%Parser{} = parser, expression), do: %{parser | expression: expression}
  defp with_error(%Parser{} = parser), do: %{parser | status: :error}
  defp unwrap_result(%Parser{} = parser), do: {parser.status, parser.expression}
end
