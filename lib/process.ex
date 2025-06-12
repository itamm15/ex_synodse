defmodule SupervisedProcess do
  @enforce_keys [:module]
  defstruct [:module, :sgp?, :restart?]

  def new({module, args}) do
    sgp? = Keyword.get(args, :sgp?, false)
    restart? = Keyword.get(args, :restart?, false)

    %__MODULE__{module: module, sgp?: sgp?, restart?: restart?}
  end
end
