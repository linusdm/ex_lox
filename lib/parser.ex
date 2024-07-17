defmodule ExLox.Parser do
  alias ExLox.Token
  alias ExLox.Expr.{Literal}

  def parse(tokens, status \\ :ok) do
    with {status, expression} <- primary(tokens, status) do
      {status, expression}
    end
  end

  # defp expression(tokens, status) do
  # end

  # defp equality(tokens, status) do
  # end

  # defp comparison(tokens, status) do
  # end

  # defp term(tokens, status) do
  # end

  # defp factor(tokens, status) do
  # end

  # defp unary(tokens, status) do
  # end

  defp primary(tokens, status) do
    case tokens do
      [%Token{type: type} | _] when type in [nil, false, true] ->
        {status, %Literal{value: type}}

      [%Token{type: type, literal: literal} | _] when type in [:number, :string] ->
        {status, %Literal{value: literal}}

      # [%Token{type: :left_paren} | rest] ->
      #   case expression(rest, status) do
      #     {[%Token{type: :right_paren} | rest], expression} -> {status, rest, expression}
      #     [token | _] = tokens -> ExLox.error_at_token(token, "Expect ')' after expression.")
      #   end

      [token | _] ->
        ExLox.error_at_token(token, "Expect expression.")
        :error
    end
  end
end
