defmodule ExLox.Globals do
  defmodule Clock do
    defstruct []

    defimpl ExLox.Callable do
      def arity(_callee), do: 0

      def call(_callee, [], env) do
        {NaiveDateTime.diff(NaiveDateTime.utc_now(), ~N[1970-01-01 00:00:00]), env}
      end
    end
  end
end
