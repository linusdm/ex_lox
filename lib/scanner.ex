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
        <<"//", rest::binary>> ->
          {consume_rest_of_line(rest), status, tokens, line}

        <<lexeme::binary-size(2), rest::binary>> when lexeme in @two_char_lexemes ->
          {rest, status, add_token(tokens, @lexemes_to_types[lexeme], lexeme, line), line}

        <<lexeme::binary-size(1), rest::binary>> when lexeme in @one_char_lexemes ->
          {rest, status, add_token(tokens, @lexemes_to_types[lexeme], lexeme, line), line}

        <<lexeme::binary-size(1), rest::binary>> when lexeme in [" ", "\r", "\t"] ->
          {rest, status, tokens, line}

        <<"\n", rest::binary>> ->
          {rest, status, tokens, line + 1}

        <<"\"", _rest::binary>> = source ->
          case consume_string_literal(source, line) do
            {:ok, lexeme, literal, rest, line} ->
              {rest, status, add_token(tokens, :string, lexeme, line, literal), line}

            {:error, rest, line} ->
              {rest, :error, tokens, line}
          end

        <<lexeme::utf8, _rest::binary>> = source when lexeme in ?0..?9 ->
          {lexeme, literal, rest} = consume_number_literal(source)
          {rest, status, add_token(tokens, :number, lexeme, line, literal), line}

        <<_::binary-size(1), rest::binary>> ->
          ExLox.error(line, "Unexpected character.")
          {rest, :error, tokens, line}
      end

    scan_tokens_recursive(rest, status, tokens, line)
  end

  defp add_token(tokens, type, lexeme, line, literal \\ nil) do
    [%Token{type: type, lexeme: lexeme, line: line, literal: literal} | tokens]
  end

  defp consume_rest_of_line("" = source), do: source
  defp consume_rest_of_line(<<"\n", source::binary>>), do: source
  defp consume_rest_of_line(<<_::binary-size(1), rest::binary>>), do: consume_rest_of_line(rest)

  defp consume_string_literal(source, lexeme \\ "", line)

  defp consume_string_literal(<<"\"", rest::binary>>, _lexeme = "", line) do
    consume_string_literal(rest, "\"", line)
  end

  defp consume_string_literal(<<"\"", rest::binary>>, <<"\"", literal::binary>> = lexeme, line) do
    {:ok, <<lexeme::binary, "\"">>, literal, rest, line}
  end

  defp consume_string_literal(<<"\n", rest::binary>>, lexeme, line) do
    consume_string_literal(rest, <<lexeme::binary, "\n">>, line + 1)
  end

  defp consume_string_literal(<<byte::binary-size(1), rest::binary>>, lexeme, line) do
    consume_string_literal(rest, <<lexeme::binary, byte::binary>>, line)
  end

  defp consume_string_literal("", _lexeme, line) do
    ExLox.error(line, "Unterminated string.")
    {:error, "", line}
  end

  defp consume_number_literal(<<num_char::utf8, _rest::binary>> = source)
       when num_char in ?0..?9 do
    {lexeme, rest} =
      case consume_integer_literal(source) do
        {lexeme_integer_part, <<".", num_char::utf8, rest::binary>>} when num_char in ?0..?9 ->
          {lexeme_decimal_part, rest} = consume_integer_literal(<<num_char, rest::binary>>)
          {lexeme_integer_part <> "." <> lexeme_decimal_part, rest}

        {lexeme, rest} ->
          {lexeme, rest}
      end

    {literal, ""} = Float.parse(lexeme)
    {lexeme, literal, rest}
  end

  defp consume_integer_literal(source, lexeme \\ "") do
    case source do
      <<char::utf8, rest::binary>> when char in ?0..?9 ->
        consume_integer_literal(rest, <<lexeme::binary, char>>)

      source ->
        {lexeme, source}
    end
  end
end
