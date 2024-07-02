defmodule ExLox.Scanner do
  alias ExLox.Token

  def scan_tokens(_source) do
    # state voor: start, current, line
    line = 1
    _tokens = [%Token{type: :eof, lexeme: "", line: line}]
  end
end
