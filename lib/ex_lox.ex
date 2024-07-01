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
    File.read!(path) |> run()
  end

  defp run(source) do
    IO.puts("running #{source}")
  end
end
