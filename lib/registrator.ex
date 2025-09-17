defmodule ExSynodse.Registrator do
  ## Todo: monitor the leader in the database with heartbeats
  use GenServer

  import Ecto.Query

  require Logger

  @enforce_keys [:supervisor]
  defstruct [:supervisor, processes: [], cluster_join_retries: 0]

  def new(processes) do
    processes = Enum.map(processes, &ExSynodse.SupervisedProcess.new(&1))
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
  def handle_info(:check_if_connected_to_cluster, state) do
    leader =  :global.whereis_name(:leader)

    ## TODO: add health check for the leader (by database)

    maybe_monitor_and_notify_leader(leader, state)
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, exited_pid, reason}, state) do
    Logger.info("Node #{inspect(exited_pid)} is down, reason: #{inspect(reason)}")

    ## todo; handle leader election in case the leader is down + register again :global.register_name(:leader, self())
    processes_to_restart = Enum.filter(state.processes, & &1.restart?)
    supervise_processes(processes_to_restart, state.supervisor)

    {:noreply, state}
  end

  defp register(%__MODULE__{} = state) do
    case try_to_become_leader() do
      {:ok, _leader} ->
        Logger.info("I am the leader, #{inspect(self())}")
        supervise_processes(state.processes, state.supervisor)
        :global.register_name(:leader, self())

      {:error, error} ->
        Logger.warning("Failed to become leader, #{inspect(error)}")

        leader = :global.whereis_name(:leader)
        maybe_monitor_and_notify_leader(leader, state)
    end

    state
  end

  defp try_to_become_leader do
    repo = ExSynodse.Repo.repo()
    era = "1"
    valid_until = DateTime.add(DateTime.utc_now(), 15)
    node_id = Atom.to_string(Node.self())

    repo.transaction(fn ->
      latest_epoch_query =
        ExSynodse.LeaderHeartbeat
        |> from(as: :leader_heartbeat)
        |> where([leader_heartbeat: leader_heartbeat], leader_heartbeat.era == ^era)
        |> select([leader_heartbeat: leader_heartbeat], max(leader_heartbeat.epoch))

      latest_epoch = repo.one(latest_epoch_query) || 1

      changeset =
        ExSynodse.LeaderHeartbeat.changeset(%ExSynodse.LeaderHeartbeat{}, %{
          era: era,
          epoch: latest_epoch,
          node_id: node_id,
          valid_until: valid_until
        })

      case repo.insert(changeset) do
        {:ok, leader_heartbeat} ->
          {:ok, leader_heartbeat}

        {:error, changeset} ->
          repo.rollback({:error, changeset})
      end
    end)
  end

  defp monitor_node(node_pid), do: Process.monitor(node_pid)

  defp supervise_processes(processes, supervisor) do
    Enum.each(processes, fn %ExSynodse.SupervisedProcess{module: module} ->
      Logger.info("Supervising #{inspect(module)}")

      Supervisor.start_child(supervisor, module)
    end)
  end

  defp maybe_monitor_and_notify_leader(:undefined, state) do
    Logger.warning("Leader is undefined - #{inspect(Node.self())} is probably not connected to the cluster, retrying #{state.cluster_join_retries} times")

    Process.send_after(self(), :check_if_connected_to_cluster, 1000)

    state = %{state | cluster_join_retries: state.cluster_join_retries + 1}

    {:noreply, state}
  end

  defp maybe_monitor_and_notify_leader(leader, state) do
    Logger.info("Leader is #{inspect(leader)}")
    send(leader, {:monitor_me, self()})
    monitor_node(leader)
    {:noreply, state}
  end

  defp start_leader_supervisor do
    Supervisor.start_link([], strategy: :one_for_one)
  end
end
