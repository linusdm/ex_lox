defmodule ExLox.Scanner do
  alias ExLox.Token

  def scan_tokens(source) do
    {status, tokens, last_line} = scan_tokens_recursive(source)
    tokens = add_token(tokens, :eof, "", last_line)
    {status, Enum.reverse(tokens)}
  end

  defp scan_tokens_recursive(source, status \\ :ok, tokens \\ [], line \\ 1)

  defp scan_tokens_recursive("", status, tokens, line) do
    {status, tokens, line}
  end

  @lexemes_to_types %{
    "(" => :left_paren,
    ")" => :right_paren,
    "{" => :left_brace,
    "}" => :right_brace,
    "," => :comma,
    "." => :dot,
    "-" => :minus,
    "+" => :plus,
    ";" => :semicolon,
    "*" => :star,
    "!" => :bang,
    "!=" => :bang_equal,
    "=" => :equal,
    "==" => :equal_equal,
    "<" => :less,
    "<=" => :less_equal,
    ">" => :greater,
    ">=" => :greater_equal,
    "/" => :slash
  }
  @one_char_lexemes Map.keys(@lexemes_to_types) |> Enum.filter(&(byte_size(&1) == 1))
  @two_char_lexemes Map.keys(@lexemes_to_types) |> Enum.filter(&(byte_size(&1) == 2))

  defp scan_tokens_recursive(source, status, tokens, line) do
    # order matters here: to achieve 'maximal munch' (see page 53) lexemes with more characters
    # should be matched first.
    # Maximal munch: when two lexical grammar rules can both maatch a chunk of code that the scanner
    # is looking at, whichever one matches the most characters wins.
    {rest, status, tokens, line} =
      case source do
        "//" <> rest ->
          {consume_rest_of_line(rest), status, tokens, line}

        <<lexeme::binary-size(2)>> <> rest when lexeme in @two_char_lexemes ->
          {rest, status, add_token(tokens, @lexemes_to_types[lexeme], lexeme, line), line}

        <<lexeme::binary-size(1)>> <> rest when lexeme in @one_char_lexemes ->
          {rest, status, add_token(tokens, @lexemes_to_types[lexeme], lexeme, line), line}

        <<lexeme::binary-size(1)>> <> rest when lexeme in [" ", "\r", "\t"] ->
          {rest, status, tokens, line}

        "\n" <> rest ->
          {rest, status, tokens, line + 1}

        "\"" <> _rest = source ->
          case consume_string_literal(source, line) do
            {:ok, lexeme, literal, rest, line} ->
              {rest, status, add_token(tokens, :string, lexeme, line, literal), line}

            {:error, line} ->
              {"", :error, tokens, line}
          end

        <<_::binary-size(1)>> <> rest ->
          ExLox.error(line, "Unexpected character.")
          {rest, :error, tokens, line}
      end

    scan_tokens_recursive(rest, status, tokens, line)
  end

  # TODO: inline if only used once
  defp add_token(tokens, type, lexeme, line, literal \\ nil) do
    [%Token{type: type, lexeme: lexeme, line: line, literal: literal} | tokens]
  end

  defp consume_rest_of_line("" = source), do: source
  defp consume_rest_of_line("\n" <> _ = source), do: source
  defp consume_rest_of_line(<<_::binary-size(1)>> <> rest), do: consume_rest_of_line(rest)

  defp consume_string_literal(source, lexeme \\ "", line)

  defp consume_string_literal("\"" <> rest, _lexeme = "", line) do
    consume_string_literal(rest, "\"", line)
  end

  defp consume_string_literal("\"" <> rest, lexeme, line) do
    # add closing quote
    lexeme = "\"" <> lexeme

    # reverse accumulated bytes for lexeme
    # (reversing with String.reverse/1 doesn't work, when using multi-byte UTF-8 characters)
    lexeme =
      for <<char <- lexeme>>, reduce: <<>> do
        acc -> <<char, acc::binary>>
      end

    # literal = lexeme without the two quotes
    literal = String.slice(lexeme, 1..-2//1)
    {:ok, lexeme, literal, rest, line}
  end

  defp consume_string_literal("\n" <> rest, lexeme, line) do
    consume_string_literal(rest, "\n" <> lexeme, line + 1)
  end

  defp consume_string_literal(<<char::binary-size(1)>> <> rest, lexeme, line) do
    consume_string_literal(rest, char <> lexeme, line)
  end

  defp consume_string_literal("", _lexeme, line) do
    ExLox.error(line, "Unterminated string.")
    {:error, line}
  end
end
