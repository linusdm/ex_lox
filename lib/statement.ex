defmodule ExLox.Stmt do
  defmodule Expression do
    @enforce_keys [:expression]
    defstruct [:expression]
  end

  defmodule Print do
    @enforce_keys [:value]
    defstruct [:value]
  end
end
