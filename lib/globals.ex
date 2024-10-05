defmodule ExLox.Globals do
  defmodule Clock do
    defstruct []

    defimpl ExLox.Callable do
      def arity(_callee), do: 0
      def call(_callee, []), do: System.system_time(:millisecond)
    end

    defimpl String.Chars do
      def to_string(_), do: "<native fn>"
    end
  end
end
