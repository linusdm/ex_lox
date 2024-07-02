defmodule ExLox.Token do
  defstruct [:type, :lexeme, :literal, :line]
end

defimpl String.Chars, for: ExLox.Token do
  def to_string(token), do: "#{token.type} #{token.lexeme} #{token.literal}"
end
