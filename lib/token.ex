defmodule ExLox.Token do
  defstruct [:type, :lexeme, :literal, :line]
end

defimpl String.Chars, for: ExLox.Token do
  def to_string(token) do
    # upcase to match jlox implementation
    type = token.type |> Atom.to_string() |> String.upcase()
    # print "null" when there is no literal, to match jlox implementation
    literal = token.literal || "null"
    "#{type} #{token.lexeme} #{literal}"
  end
end
