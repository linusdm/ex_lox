defmodule ExLox.Globals do
  defmodule Clock do
    defstruct []

    defimpl ExLox.Callable do
      def arity(_callee), do: 0

      def call(_callee, [], env) do
        {System.system_time(:millisecond) / 1000, env}
      end
    end

    defimpl String.Chars do
      def to_string(_) do
        "<native fn>"
      end
    end
  end
end
