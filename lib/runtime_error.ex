defmodule ExLox.RuntimeError do
  defexception [:message, :token]
end
