defmodule ExLox.Expr do
  defmodule Binary do
    @enforce_keys [:left, :operator, :right]
    defstruct [:left, :operator, :right]
  end

  defmodule Grouping do
    @enforce_keys [:expression]
    defstruct [:expression]
  end

  defmodule Literal do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule Unary do
    @enforce_keys [:operator, :right]
    defstruct [:operator, :right]
  end
end
