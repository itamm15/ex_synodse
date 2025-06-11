defmodule ExSynodse.Registrator do
  ## Todo: monitor the leader in the database with heartbeats
  use GenServer

  require Logger

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(args) do
    Logger.info("Registrator started..")

    {:ok, register(args)}
  end

  @impl true
  def handle_info({:monitor_me, node_to_monitor}, _state) do
    Logger.info("Monitoring #{inspect(node_to_monitor)}")
    monitor_node(node_to_monitor)

    {:noreply, nil}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, exited_pid, reason}, _state) do
    Logger.info("Node #{inspect(exited_pid)} is down, reason: #{inspect(reason)}")

    ## todo; handle leader election in case the leader is down
    {:noreply, nil}
  end

  defp register(args) do
    node = self()

    ## register the process globally under the leadership name
    case :global.register_name(:leader, node) do
      :yes ->
        Logger.info("I am the leader, #{inspect(node)}")
        {:ok, supervisor} = start_leader_supervisor()
        supervise_processes(args, supervisor)

      :no ->
        leader = :global.whereis_name(:leader)
        Logger.info("I am not the leader, I will monitor the leader, #{inspect(leader)}")
        ## notify the leader about new node
        send(leader, {:monitor_me, node})
        ## monitor the leader
        monitor_node(leader)
    end
  end

  defp start_leader_supervisor do
    Supervisor.start_link([], strategy: :one_for_one)
  end

  defp monitor_node(node_pid), do: Process.monitor(node_pid)

  defp supervise_processes(args, supervisor) do
    Enum.each(args, fn {module, args} ->
      Logger.info("Supervising #{inspect(module)}")

      Supervisor.start_child(supervisor, {module, args})
    end)
  end
end
