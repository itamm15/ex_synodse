defmodule ExSynodse.Registrator do
  ## Todo: monitor the leader in the database with heartbeats
  use GenServer

  require Logger

  def start_link(_args), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(_args) do
    Logger.info("Registrator started..")

    {:ok, register()}
  end

  defp register do
    node = self()

    ## register the process globally under the leadership name
    case :global.register_name(:leader, node) do
      :yes ->
        Logger.info("I am the leader, #{inspect(node)}")

      :no ->
        leader = :global.whereis_name(:leader)
        Logger.info("I am not the leader, I will monitor the leader, #{inspect(leader)}")
        ## notify the leader about new node
        # TBD
        ## monitor the leader
        monitor_node(leader)
    end
  end

  defp monitor_node(node_pid), do: Process.monitor(node_pid)
end
