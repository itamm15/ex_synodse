defmodule ExSynodse.Repo do
  def repo do
    Application.fetch_env!(:ex_synodse, :repo)
  end
end
