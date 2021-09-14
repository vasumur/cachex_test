defmodule CachexTest.Warmers.PbdWarmer do
  require Logger
  use Cachex.Warmer
  alias CachexTest.Util

  def interval() do
    :timer.hours(2)
  end

  def execute(_connection) do
    Logger.info("Started PBD/CBD Cache")

    ret =
      try do
        {:ok, [{:pbd, Util.fetch_pbd(:pbd)}]}
      rescue
        error ->
          Logger.error("Error While Warming PBD - #{inspect(error)}")
          Logger.error(Exception.format(:error, error, __STACKTRACE__))

          :ignore
      end

    Logger.info("Completed PBD/CBD Cache")
    ret
  end
end
