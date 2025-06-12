defmodule SupervisedProcess do
  @enforce_keys [:module]
  defstruct [:module, :sgp?, :restart?]

  def new({module, args}) do
    sgp? = Keyword.get(args, :sgp?, false)
    restart? = Keyword.get(args, :restart?, false)

    if sgp? and restart? do
      raise "sgp? and restart? cannot be true at the same time"
    end

    %__MODULE__{module: module, sgp?: sgp?, restart?: restart?}
  end
end
