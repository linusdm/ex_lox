defmodule ExLox do
  alias ExLox.Environment

  def run_prompt(env \\ Environment.new()) do
    case IO.gets("> ") do
      :eof ->
        :ok

      source ->
        case run(source, env) do
          {:ok, updated_env} -> run_prompt(updated_env)
          _ -> run_prompt(env)
        end
    end
  end

  def run_file(path) do
    case File.read!(path) |> run() do
      :error -> exit({:shutdown, 65})
      :runtime_error -> exit({:shutdown, 70})
      {:ok, _env} -> :ok
    end
  end

  defp run(source, env \\ Environment.new()) do
    with {scan_status, tokens} <- ExLox.Scanner.scan_tokens(source),
         {:ok, statements} <- ExLox.Parser.parse(tokens, scan_status) do
      case ExLox.Interpreter.interpret(statements, env) do
        {:ok, env} -> {:ok, env}
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
    IO.puts(:stderr, "[line #{line}] Error#{where}: #{msg}")
  end

  def runtime_error(%ExLox.RuntimeError{} = error) do
    IO.puts(:stderr, "#{error.message}\n[line #{error.token.line}]")
  end
end
