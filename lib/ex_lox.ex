defmodule ExLox do
  def run_prompt do
    case IO.gets("> ") do
      :eof ->
        :ok

      source ->
        run(source)
        run_prompt()
    end
  end

  def run_file(path) do
    case File.read!(path) |> run() do
      :error -> exit({:shutdown, 65})
      :runtime_error -> exit({:shutdown, 70})
      :ok -> :ok
    end
  end

  defp run(source) do
    with {:ok, tokens} <- ExLox.Scanner.scan_tokens(source),
         {:ok, statements} <- ExLox.Parser.parse(tokens) do
      case ExLox.Interpreter.interpret(statements) do
        :ok -> :ok
        :error -> :runtime_error
      end
    end
  end

  def error_at_line(line, msg), do: report(line, "", msg)

  def error_at_token(%ExLox.Token{} = token, msg) do
    where =
      case token do
        %{type: :eof} -> " at end"
        %{lexeme: lexeme} -> " at '#{lexeme}'"
      end

    report(token.line, where, msg)
  end

  defp report(line, where, msg) do
    IO.puts("[line #{line}] Error#{where}: #{msg}")
  end

  def runtime_error(%ExLox.Interpreter.RuntimeError{} = error) do
    IO.puts("#{error.message} \n[line #{error.token.line}]")
  end
end
