defmodule ExLox.Stmt do
  defmodule Expression do
    @enforce_keys [:expression]
    defstruct [:expression]
  end

  defmodule Function do
    @enforce_keys [:name, :params, :body]
    defstruct [:name, :params, :body]
  end

  defmodule If do
    @enforce_keys [:condition, :then_branch, :else_branch]
    defstruct [:condition, :then_branch, :else_branch]
  end

  defmodule Print do
    @enforce_keys [:value]
    defstruct [:value]
  end

  defmodule Var do
    @enforce_keys [:name, :initializer]
    defstruct [:name, :initializer]
  end

  defmodule Block do
    @enforce_keys [:statements]
    defstruct [:statements]
  end

  defmodule While do
    @enforce_keys [:condition, :body]
    defstruct [:condition, :body]
  end
end
