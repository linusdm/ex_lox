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
    path
    |> File.read!()
    |> run()
    |> case do
      :error -> exit({:shutdown, 65})
      :ok -> :ok
    end
  end

  defp run(source) do
    ExLox.Scanner.scan_tokens(source)
    |> Enum.each(&IO.puts/1)
  end

  defp error(line, msg), do: report(line, "", msg)

  defp report(line, where, msg) do
    # TODO: had_error -> true
    IO.puts("[line #{line}] Error#{where}: #{msg}")
  end
end
