defmodule ExLox.CLI do
  def main(args) do
    case args do
      [] -> ExLox.run_prompt()
      [path] -> ExLox.run_file(path)
      _ -> IO.puts("Usage: mix lox [script]") && exit({:shutdown, 64})
    end
  end
end
