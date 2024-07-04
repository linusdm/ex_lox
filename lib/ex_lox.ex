defmodule ExLox do
  def run_prompt do
    case IO.gets("> ") do
      # TODO: werkt dit zo?
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
      :ok -> :ok
    end
  end

  defp run(source) do
    {status, tokens} = ExLox.Scanner.scan_tokens(source)
    Enum.each(tokens, &IO.puts/1)
    status
  end

  def error(line, msg), do: report(line, "", msg)

  defp report(line, where, msg) do
    IO.puts("[line #{line}] Error#{where}: #{msg}")
  end
end
