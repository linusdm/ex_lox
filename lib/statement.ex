defmodule ExLox.Stmt do
  defmodule Expression do
    @enforce_keys [:expression]
    defstruct [:expression]
  end

  defmodule Print do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule Var do
    @enforce_keys [:name, :initializer]
    defstruct [:name, :initializer]
  end
end
