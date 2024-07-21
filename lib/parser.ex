defmodule ExLox.Parser do
  alias ExLox.Parser
  alias ExLox.Token
  alias ExLox.Expr.{Literal, Binary}

  defstruct [:tokens, :status, :expression]

  def parse(tokens, status) do
    %Parser{tokens: tokens, status: status} |> expression() |> unwrap_result()
  end

  defp expression(%Parser{} = parser) do
    equality(parser)
  end

  defp equality(%Parser{} = parser) do
    # It's impossible to call an anonymous function, recursively.
    # This trick allows you to call the function if you pass it in explicitly.
    # I don't know how I feel about this...
    recur = fn
      %Parser{tokens: [token | rest]} = parser, recur
      when token.type in [:bang_equal, :equal_equal] ->
        comp_parser = parser |> with_tokens(rest) |> comparison()
        exp = %Binary{left: parser.expression, operator: token, right: comp_parser.expression}
        comp_parser |> with_expression(exp) |> recur.(recur)

      parser, _recur ->
        parser
    end

    parser |> comparison() |> recur.(recur)
  end

  defp comparison(parser) do
    primary(parser)
  end

  # defp term(parser) do
  # end

  # defp factor(parser) do
  # end

  # defp unary(parser) do
  # end

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
