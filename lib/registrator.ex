defmodule ExSynodse.Registrator do
  ## Todo: monitor the leader in the database with heartbeats
  use GenServer

  require Logger

  @enforce_keys [:supervisor]
  defstruct [:supervisor, processes: []]

  def new(processes) do
    processes = Enum.map(processes, &(SupervisedProcess.new(&1)))
    {:ok, supervisor} = start_leader_supervisor()

    %__MODULE__{processes: processes, supervisor: supervisor}
  end

  def start_link(args), do: GenServer.start_link(__MODULE__, args, name: __MODULE__)

  @impl true
  def init(args) do
    Logger.info("Registrator started..")
    state = new(args)

    {:ok, register(state)}
  end

  @impl true
  def handle_info({:monitor_me, node_to_monitor}, state) do
    Logger.info("Monitoring #{inspect(node_to_monitor)}")
    monitor_node(node_to_monitor)

    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, exited_pid, reason}, state) do
    Logger.info("Node #{inspect(exited_pid)} is down, reason: #{inspect(reason)}")

    ## todo; handle leader election in case the leader is down
    processes_to_restart = Enum.filter(state.processes, &(&1.restart?))
    supervise_processes(processes_to_restart, state.supervisor)

    {:noreply, state}
  end

  defp register(%__MODULE__{} = state) do
    node = self()

    ## register the process globally under the leadership name
    case :global.register_name(:leader, node) do
      :yes ->
        Logger.info("I am the leader, #{inspect(node)}")
        supervise_processes(state.processes, state.supervisor)

      :no ->
        leader = :global.whereis_name(:leader)
        Logger.info("I am not the leader, I will monitor the leader, #{inspect(leader)}")
        ## notify the leader about new node
        send(leader, {:monitor_me, node})
        ## monitor the leader
        monitor_node(leader)
    end

    state
  end

  defp monitor_node(node_pid), do: Process.monitor(node_pid)

  defp supervise_processes(processes, supervisor) do
    Enum.each(processes, fn %SupervisedProcess{module: module} ->
      Logger.info("Supervising #{inspect(module)}")

      Supervisor.start_child(supervisor, module)
    end)
  end

  defp start_leader_supervisor do
    Supervisor.start_link([], strategy: :one_for_one)
  end
end
